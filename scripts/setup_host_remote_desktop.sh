#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# KONFIGURACJA
############################################

# Tailscale
TAILSCALE_AUTHKEY=""                 # np. tskey-auth-xxxxxxxx ; zostaw puste, jeśli chcesz logowanie interaktywne
TAILSCALE_HOSTNAME="zpk-darwina-ai"
TAILSCALE_ADVERTISE_TAGS=""          # np. "tag:server" ; puste = bez tagów
TAILSCALE_ENABLE_SSH="false"         # true/false

# xRDP / pulpit
RDP_PORT="3389"
# xfce = lekki pulpit, gnome = pełny Ubuntu Desktop (GNOME, wszystkie aplikacje)
DESKTOP_ENV="gnome"                  # xfce | gnome

# Użytkownicy
# Format: "login:haslo:grupa1,grupa2;login2:haslo2:grupa1"
# Jeśli nie chcesz tworzyć użytkowników w tym kroku, zostaw puste.
USER_SPECS=""
# Istniejący użytkownik do RDP (jeśli nie w USER_SPECS). Np. "jan" lub "jan piotr"
RDP_USERS=""

# Współdzielone zasoby
CREATE_SHARED_DIR="true"
SHARED_GROUP="teamshare"
SHARED_DIR="/srv/shared/team"

# Firewall
ALLOW_SSH="true"
SSH_PORT="22"

# System
TIMEZONE="Europe/Warsaw"
APT_NONINTERACTIVE="true"

############################################
# KONIEC KONFIGURACJI
############################################

export DEBIAN_FRONTEND=noninteractive

log()  { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
err()  { echo "[ERROR] $*" >&2; }
die()  { err "$*"; exit 1; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Uruchom ten skrypt jako root: sudo bash $0"
  fi
}

detect_os() {
  if [[ ! -r /etc/os-release ]]; then
    die "Nie mogę odczytać /etc/os-release"
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *"debian"* ]] || die "Skrypt wspiera Ubuntu/Debian. Wykryto: ${PRETTY_NAME:-nieznany system}"
}

apt_update_once() {
  if [[ ! -f /var/cache/apt/pkgcache.bin ]]; then
    log "Aktualizuję indeks pakietów APT..."
    apt-get update -y
  else
    log "Odświeżam indeks pakietów APT..."
    apt-get update -y
  fi
}

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

install_packages() {
  local pkgs=("$@")
  local missing=()
  for p in "${pkgs[@]}"; do
    if ! pkg_installed "$p"; then
      missing+=("$p")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    log "Instaluję brakujące pakiety: ${missing[*]}"
    apt-get install -y "${missing[@]}"
  else
    log "Wszystkie wymagane pakiety są już zainstalowane."
  fi
}

set_timezone() {
  if [[ -n "${TIMEZONE}" ]]; then
    log "Ustawiam strefę czasową na ${TIMEZONE}"
    timedatectl set-timezone "${TIMEZONE}" || warn "Nie udało się ustawić strefy czasowej"
  fi
}

ensure_tailscale() {
  if command -v tailscale >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^tailscaled\.service'; then
    log "Tailscale jest już zainstalowany."
  else
    log "Instaluję Tailscale..."
    install_packages curl ca-certificates gnupg lsb-release
    curl -fsSL https://tailscale.com/install.sh | sh
  fi

  systemctl enable tailscaled
  systemctl restart tailscaled

  local up_cmd=("tailscale" "up")
  if [[ -n "${TAILSCALE_AUTHKEY}" ]]; then
    up_cmd+=("--auth-key=${TAILSCALE_AUTHKEY}")
  fi
  if [[ -n "${TAILSCALE_HOSTNAME}" ]]; then
    up_cmd+=("--hostname=${TAILSCALE_HOSTNAME}")
  fi
  if [[ -n "${TAILSCALE_ADVERTISE_TAGS}" ]]; then
    up_cmd+=("--advertise-tags=${TAILSCALE_ADVERTISE_TAGS}")
  fi
  if [[ "${TAILSCALE_ENABLE_SSH}" == "true" ]]; then
    up_cmd+=("--ssh")
  fi

  log "Uruchamiam Tailscale..."
  if ! "${up_cmd[@]}"; then
    warn "tailscale up nie zakończył się pełnym sukcesem. Jeśli nie podałeś TAILSCALE_AUTHKEY, dokończ logowanie ręcznie poleceniem:"
    warn "  sudo tailscale up --hostname=${TAILSCALE_HOSTNAME}"
  fi
}

ensure_xrdp_stack() {
  local pkgs=(
    xrdp
    xorgxrdp
    dbus-x11
    x11-xserver-utils
    acl
    ufw
    policykit-1
  )

  case "${DESKTOP_ENV}" in
    gnome)
      log "Instaluję pełny Ubuntu Desktop (GNOME)..."
      pkgs+=(ubuntu-desktop gnome-session)
      ;;
    xfce)
      pkgs+=(xfce4 xfce4-goodies)
      ;;
    *)
      die "Nieznany DESKTOP_ENV=${DESKTOP_ENV}. Użyj: xfce | gnome"
      ;;
  esac

  install_packages "${pkgs[@]}"

  log "Dodaję użytkownika xrdp do grupy ssl-cert..."
  adduser xrdp ssl-cert >/dev/null 2>&1 || true

  log "Konfiguruję startwm.sh dla ${DESKTOP_ENV}..."
  if [[ ! -f /etc/xrdp/startwm.sh.backup-by-chatgpt ]]; then
    cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.backup-by-chatgpt
  fi

  if [[ "${DESKTOP_ENV}" == "gnome" ]]; then
    cat >/etc/xrdp/startwm.sh <<'STARTWM_GNOME'
#!/bin/sh
if [ -r /etc/profile ]; then . /etc/profile; fi
if [ -r "$HOME/.profile" ]; then . "$HOME/.profile"; fi

export DESKTOP_SESSION=ubuntu
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_TYPE=x11

test -x /etc/X11/Xsession && exec /etc/X11/Xsession
exec /bin/sh /etc/X11/Xsession
STARTWM_GNOME
  else
    cat >/etc/xrdp/startwm.sh <<'STARTWM_XFCE'
#!/bin/sh
if [ -r /etc/profile ]; then . /etc/profile; fi
if [ -r "$HOME/.profile" ]; then . "$HOME/.profile"; fi

export DESKTOP_SESSION=xfce
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11

exec startxfce4
STARTWM_XFCE
  fi
  chmod 755 /etc/xrdp/startwm.sh

  log "Przygotowuję domyślną sesję w /etc/skel dla ${DESKTOP_ENV}..."
  if [[ "${DESKTOP_ENV}" == "gnome" ]]; then
    echo "gnome-session" >/etc/skel/.xsession
    cat >/etc/skel/.xsessionrc <<'XSESSIONRC'
export XAUTHORITY=${HOME}/.Xauthority
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
XSESSIONRC
  else
    echo "startxfce4" >/etc/skel/.xsession
    rm -f /etc/skel/.xsessionrc
  fi
  chmod 644 /etc/skel/.xsession
  [[ -f /etc/skel/.xsessionrc ]] && chmod 644 /etc/skel/.xsessionrc

  if [[ -f /etc/xrdp/xrdp.ini ]]; then
    sed -i "s/^port=.*/port=${RDP_PORT}/" /etc/xrdp/xrdp.ini || true
  fi

  systemctl enable xrdp
  systemctl restart xrdp
}

ensure_polkit_colord() {
  # Polkit blokuje sesję xRDP („Authentication required to create color profile").
  # Bez tego sesja się zamyka zaraz po zalogowaniu.
  local rule_file="/etc/polkit-1/rules.d/45-allow-colord.rules"
  if [[ ! -f "${rule_file}" ]]; then
    log "Dodaję regułę polkit dla colord (fix xRDP)..."
    cat > "${rule_file}" <<'POLKIT'
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.freedesktop.color-manager.") === 0) {
    return polkit.Result.YES;
  }
});
POLKIT
    chmod 644 "${rule_file}"
  else
    log "Reguła polkit dla colord już istnieje."
  fi
}

add_users_to_xrdp_group() {
  local users=()
  if [[ -n "${USER_SPECS}" ]]; then
    while IFS= read -r -d ';' entry; do
      [[ -z "${entry}" ]] && continue
      local uname
      uname="${entry%%:*}"
      [[ -n "${uname}" ]] && users+=("${uname}")
    done <<< "${USER_SPECS};"
  fi
  if [[ -n "${RDP_USERS}" ]]; then
    for u in ${RDP_USERS//[,]/ }; do
      [[ -n "${u}" ]] && users+=("${u}")
    done
  fi
  for u in "${users[@]}"; do
    if id "${u}" &>/dev/null; then
      if groups "${u}" | grep -q '\bxrdp\b'; then
        log "Użytkownik ${u} jest już w grupie xrdp."
      else
        log "Dodaję ${u} do grupy xrdp."
        usermod -aG xrdp "${u}"
      fi
    else
      warn "Użytkownik ${u} nie istnieje – pomijam dodanie do xrdp."
    fi
  done
}

ensure_xsession_for_rdp_users() {
  local users=()
  if [[ -n "${USER_SPECS}" ]]; then
    while IFS= read -r -d ';' entry; do
      [[ -z "${entry}" ]] && continue
      local uname="${entry%%:*}"
      [[ -n "${uname}" ]] && users+=("${uname}")
    done <<< "${USER_SPECS};"
  fi
  if [[ -n "${RDP_USERS}" ]]; then
    for u in ${RDP_USERS//[,]/ }; do
      [[ -n "${u}" ]] && users+=("${u}")
    done
  fi
  for u in "${users[@]}"; do
    local home
    home="$(getent passwd "${u}" 2>/dev/null | cut -d: -f6)"
    [[ -z "${home}" || ! -d "${home}" ]] && continue
    local xsession="${home}/.xsession"
    if [[ ! -f "${xsession}" ]]; then
      log "Tworzę ${xsession} dla ${u} (${DESKTOP_ENV})"
      if [[ "${DESKTOP_ENV}" == "gnome" ]]; then
        echo 'gnome-session' > "${xsession}"
        cat > "${home}/.xsessionrc" <<'XSRC'
export XAUTHORITY=${HOME}/.Xauthority
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
XSRC
        chown "${u}:$(id -gn "${u}")" "${home}/.xsessionrc"
        chmod 644 "${home}/.xsessionrc"
      else
        echo 'startxfce4' > "${xsession}"
      fi
      chown "${u}:$(id -gn "${u}")" "${xsession}"
      chmod 644 "${xsession}"
    fi
  done
}

create_group_if_missing() {
  local group="$1"
  if getent group "$group" >/dev/null 2>&1; then
    log "Grupa ${group} już istnieje."
  else
    log "Tworzę grupę ${group}"
    groupadd "$group"
  fi
}

create_or_update_users() {
  if [[ -z "${USER_SPECS}" ]]; then
    log "USER_SPECS jest puste - pomijam tworzenie użytkowników."
    return
  fi

  IFS=';' read -r -a user_entries <<< "${USER_SPECS}"

  for entry in "${user_entries[@]}"; do
    [[ -z "${entry}" ]] && continue

    IFS=':' read -r username password groups_csv <<< "${entry}"

    [[ -n "${username}" ]] || { warn "Pominięto pusty wpis użytkownika"; continue; }
    [[ -n "${password}" ]] || die "Brak hasła dla użytkownika ${username}"

    if id "${username}" >/dev/null 2>&1; then
      log "Użytkownik ${username} już istnieje - aktualizuję hasło i grupy."
    else
      log "Tworzę użytkownika ${username}"
      useradd -m -s /bin/bash "${username}"
      cp -n /etc/skel/.xsession "/home/${username}/.xsession" || true
      chown "${username}:${username}" "/home/${username}/.xsession" || true
      chmod 644 "/home/${username}/.xsession" || true
    fi

    echo "${username}:${password}" | chpasswd

    if [[ -n "${groups_csv:-}" ]]; then
      IFS=',' read -r -a groups_arr <<< "${groups_csv}"
      for grp in "${groups_arr[@]}"; do
        [[ -z "${grp}" ]] && continue
        create_group_if_missing "${grp}"
        usermod -aG "${grp}" "${username}"
      done
    fi

    if [[ "${CREATE_SHARED_DIR}" == "true" && -n "${SHARED_GROUP}" ]]; then
      usermod -aG "${SHARED_GROUP}" "${username}"
    fi
  done
}

setup_shared_dir() {
  if [[ "${CREATE_SHARED_DIR}" != "true" ]]; then
    log "Pomijam konfigurację współdzielonego katalogu."
    return
  fi

  create_group_if_missing "${SHARED_GROUP}"

  log "Tworzę katalog współdzielony ${SHARED_DIR}"
  mkdir -p "${SHARED_DIR}"
  chown root:"${SHARED_GROUP}" "${SHARED_DIR}"
  chmod 2770 "${SHARED_DIR}"

  # ACL: właściciel root ma rwx, grupa ma rwx, nowo tworzone pliki odziedziczą grupę
  setfacl -m "g:${SHARED_GROUP}:rwx" "${SHARED_DIR}" || true
  setfacl -d -m "g:${SHARED_GROUP}:rwx" "${SHARED_DIR}" || true
}

configure_firewall() {
  log "Konfiguruję UFW..."
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  if [[ "${ALLOW_SSH}" == "true" ]]; then
    ufw allow "${SSH_PORT}/tcp"
  fi

  # RDP dostępny tylko po Tailscale
  ufw allow in on tailscale0 to any port "${RDP_PORT}" proto tcp

  ufw --force enable
  ufw reload || true
}

verify_services() {
  systemctl is-active --quiet tailscaled || warn "tailscaled nie jest aktywny"
  systemctl is-active --quiet xrdp || warn "xrdp nie jest aktywny"

  log "Status xRDP:"
  systemctl --no-pager --full status xrdp | sed -n '1,12p' || true

  if command -v tailscale >/dev/null 2>&1; then
    log "Adresy Tailscale hosta:"
    tailscale ip || true
  fi
}

print_summary() {
  echo
  echo "============================================================"
  echo " GOTOWE - HOST SKONFIGUROWANY"
  echo "============================================================"
  echo "Hostname Tailscale : ${TAILSCALE_HOSTNAME}"
  echo "Port RDP           : ${RDP_PORT}"
  echo "Pulpit             : ${DESKTOP_ENV}"
  if [[ "${DESKTOP_ENV}" == "gnome" ]]; then
    echo
    echo "UWAGA (GNOME): Zaloguj się wylogowany lokalnie – nie możesz być na konsoli i RDP jednocześnie."
  fi
  echo "Katalog współdz.   : ${SHARED_DIR}"
  echo
  echo "Sprawdź IP Tailscale poleceniem:"
  echo "  tailscale ip -4"
  echo
  echo "Po stronie Windows w skrypcie klienta ustaw:"
  echo "  HOST_TAILSCALE_IP=<wynik tailscale ip -4>"
  echo
  echo "Jeśli logujesz się istniejącym użytkownikiem (nie z USER_SPECS), dodaj go do xrdp:"
  echo "  sudo usermod -aG xrdp TWOJ_LOGIN"
  if [[ "${DESKTOP_ENV}" == "gnome" ]]; then
    echo "  echo 'gnome-session' > ~/.xsession"
    echo "  # oraz utwórz ~/.xsessionrc (XAUTHORITY, GNOME_SHELL_SESSION_MODE, XDG_*)"
  else
    echo "  echo 'startxfce4' > ~/.xsession"
  fi
  echo
  echo "Jeśli nie podałeś TAILSCALE_AUTHKEY, może być potrzebne ręczne logowanie:"
  echo "  sudo tailscale up --hostname=${TAILSCALE_HOSTNAME}"
  echo "============================================================"
}

main() {
  require_root
  detect_os
  apt_update_once
  set_timezone
  ensure_tailscale
  ensure_xrdp_stack
  ensure_polkit_colord
  setup_shared_dir
  create_or_update_users
  add_users_to_xrdp_group
  ensure_xsession_for_rdp_users
  configure_firewall
  verify_services
  print_summary
}

main "$@"