#!/usr/bin/env bash
#
# setup-olares.sh - Konfiguracja środowiska AI Dev Team na Olares/Ubuntu/Debian
# Odporny na błędy: nie przerywa przy błędzie, pomija kroki zależne od nieudanych.
# Uruchom: sudo bash setup-olares.sh
# Konfiguracja: zmienne poniżej lub plik config.env (source przed uruchomieniem)
#
# Zgodność: Ubuntu 22.04/24.04 LTS, Debian 12/13. Olares działa na Ubuntu.
# Wszystkie komendy (apt-get, systemctl, ip, wg, iptables, curl, docker, kubectl)
# są dostępne na Ubuntu lub instalowane przez skrypt.
#

set -uo pipefail
IFS=$'\n\t'

# Załaduj config.env jeśli istnieje w katalogu skryptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

# === Konfigurowalne zmienne (nadpisz przez export lub config.env) ===
HOSTNAME="${HOSTNAME:-ai-dev-host}"
TIMEZONE="${TIMEZONE:-Europe/Warsaw}"
LOCALE="${LOCALE:-pl_PL.UTF-8}"
INSTALL_OLARES="${INSTALL_OLARES:-false}"
INSTALL_NVIDIA="${INSTALL_NVIDIA:-auto}"
INSTALL_K3S="${INSTALL_K3S:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
INSTALL_WIREGUARD="${INSTALL_WIREGUARD:-true}"
INSTALL_OLLAMA="${INSTALL_OLLAMA:-true}"
INSTALL_POSTGRES="${INSTALL_POSTGRES:-true}"
INSTALL_REDIS="${INSTALL_REDIS:-true}"
INSTALL_MINIO="${INSTALL_MINIO:-true}"
INSTALL_N8N="${INSTALL_N8N:-true}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
BASE_DIR="${BASE_DIR:-/opt/ai-dev-team}"

# WireGuard (jeśli INSTALL_WIREGUARD=true)
WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_NETWORK="${WG_NETWORK:-10.100.0.0}"
WG_CIDR="${WG_CIDR:-24}"
# interfejs zewnętrzny (auto: ip -o -4 route show to default | awk '{print $5}')
# ip z iproute2 - dostępne na Ubuntu, instalowane w apt_basics jeśli brak
WG_EXT_IF="${WG_EXT_IF:-$(command -v ip >/dev/null 2>&1 && ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -1)}"
WG_EXT_IF="${WG_EXT_IF:-eth0}"

# === Stałe URL instalatorów ===
URL_OLARES="https://olares.sh"
URL_DOCKER="https://get.docker.com"
URL_K3S="https://get.k3s.io"
URL_OLLAMA="https://ollama.com/install.sh"
URL_MINIO="https://dl.min.io/server/minio/release/linux-amd64/minio"
URL_HELM="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"

# === Inicjalizacja ===
declare -A STEP_SUCCESS
LOG_FILE="/var/log/setup-olares-$(date +%Y%m%d-%H%M%S).log"
FAILED_STEPS=()
SUCCESS_STEPS=()
SKIPPED_STEPS=()

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_ok() {
  log "[OK] $*"
}

log_fail() {
  log "[FAIL] $*"
}

log_skip() {
  log "[SKIP] $*"
}

log_warn() {
  log "[WARN] $*"
}

# Sprawdzenie root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_fail "Uruchom skrypt jako root: sudo bash $0"
    exit 1
  fi
}

# Wykrycie distro
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
  else
    DISTRO_ID="unknown"
    DISTRO_VERSION="unknown"
  fi
  log "Wykryto: $DISTRO_ID $DISTRO_VERSION"
}

# Sprawdzenie czy distro jest wspierane
check_distro() {
  case "$DISTRO_ID" in
    ubuntu|debian)
      return 0
      ;;
    *)
      log_warn "Niewspierana dystrybucja: $DISTRO_ID. Skrypt może nie działać poprawnie."
      return 0
      ;;
  esac
}

# Główna funkcja wykonująca krok z zależnościami
# run_step "nazwa_kroku" "polecenie" "dep1" "dep2" ...
run_step() {
  local name="$1"
  local cmd="$2"
  shift 2
  local deps=("$@")

  for d in "${deps[@]}"; do
    if [[ "${STEP_SUCCESS[$d]:-0}" -eq 0 ]]; then
      log_skip "$name" "(zależność $d nie powiodła się)"
      SKIPPED_STEPS+=("$name (dep: $d)")
      return 1
    fi
  done

  log "Wykonuję: $name"
  if eval "$cmd" >> "$LOG_FILE" 2>&1; then
    STEP_SUCCESS[$name]=1
    SUCCESS_STEPS+=("$name")
    log_ok "$name"
    return 0
  else
    STEP_SUCCESS[$name]=0
    FAILED_STEPS+=("$name")
    log_fail "$name"
    return 1
  fi
}

# Wykonanie kroku bez zależności (np. init)
run_step_standalone() {
  local name="$1"
  local cmd="$2"

  log "Wykonuję: $name"
  if eval "$cmd" >> "$LOG_FILE" 2>&1; then
    STEP_SUCCESS[$name]=1
    SUCCESS_STEPS+=("$name")
    log_ok "$name"
    return 0
  else
    STEP_SUCCESS[$name]=0
    FAILED_STEPS+=("$name")
    log_fail "$name"
    return 1
  fi
}

# Raport końcowy – dobrze widoczny
print_report() {
  echo ""
  echo "=============================================="
  echo " RAPORT KOŃCOWY setup-olares.sh"
  echo "=============================================="
  log "Sukces: ${#SUCCESS_STEPS[@]} kroków"
  for s in "${SUCCESS_STEPS[@]}"; do
    log "  [OK] $s"
  done
  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    echo ""
    log_fail "NIEPOWODZENIE: ${#FAILED_STEPS[@]} kroków – sprawdź log!"
    for s in "${FAILED_STEPS[@]}"; do
      log "  [FAIL] $s"
    done
    echo ""
    log "Szczegóły: $LOG_FILE"
    log "Napraw: sudo bash scripts/setup-olares-robust.sh  (weryfikuje i doinstaluje brakujące)"
  fi
  if [[ ${#SKIPPED_STEPS[@]} -gt 0 ]]; then
    log "Pominięte (zależności): ${#SKIPPED_STEPS[@]} kroków"
    for s in "${SKIPPED_STEPS[@]}"; do
      log "  [SKIP] $s"
    done
  fi
  echo ""
  log "Log: $LOG_FILE"
  log "Weryfikacja serwisów: sudo bash scripts/verify-and-start-olares.sh"
  echo "=============================================="
  echo ""
}

# === FAZA 0: Inicjalizacja ===
phase_init() {
  check_root
  mkdir -p /var/log
  touch "$LOG_FILE"
  log "Start setup-olares.sh"
  detect_distro
  check_distro
  run_step_standalone "init_log" "true"
}

# === FAZA 1: Baza systemowa ===
phase_base() {
  run_step_standalone "apt_update" "apt-get update -qq"
  run_step "apt_upgrade" "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq" "apt_update"
  run_step "apt_basics" "apt-get install -y -qq curl wget gnupg2 ca-certificates lsb-release apt-transport-https software-properties-common jq iproute2 locales pciutils iptables" "apt_update"
  run_step "hostname_set" "hostnamectl set-hostname $HOSTNAME" "apt_basics"
  run_step "timezone_set" "timedatectl set-timezone $TIMEZONE" "apt_basics"
  run_step "locale_set" "locale-gen $LOCALE 2>/dev/null || true; update-locale LANG=$LOCALE 2>/dev/null || true" "apt_basics"
  run_step "dirs_create" "mkdir -p $BASE_DIR/{logs,models,backups} && chmod 755 $BASE_DIR" "apt_basics"
}

# === FAZA 2: Docker ===
phase_docker() {
  if [[ "$INSTALL_DOCKER" != "true" ]]; then
    log_skip "docker_install" "(INSTALL_DOCKER=false)"
    return 0
  fi
  run_step "docker_install" "curl -fsSL $URL_DOCKER | sh" "apt_basics"
  run_step "docker_service" "systemctl enable docker && systemctl start docker" "docker_install"
}

# === FAZA 3: K3s ===
phase_k3s() {
  if [[ "$INSTALL_K3S" != "true" ]]; then
    log_skip "k3s_install" "(INSTALL_K3S=false)"
    return 0
  fi
  local k3s_env=""
  if [[ "${STEP_SUCCESS[docker_install]:-0}" -eq 1 ]]; then
    k3s_env='INSTALL_K3S_EXEC="--docker" '
    log "K3s użyje Dockera jako runtime (Docker już zainstalowany)"
  fi
  run_step "k3s_install" "${k3s_env}curl -sfL $URL_K3S | sh -" "apt_basics"
  run_step "k3s_wait" "sleep 10 && export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get nodes 2>/dev/null || true" "k3s_install"
}

# === FAZA 4: WireGuard ===
phase_wireguard() {
  if [[ "$INSTALL_WIREGUARD" != "true" ]]; then
    log_skip "wireguard_install" "(INSTALL_WIREGUARD=false)"
    return 0
  fi
  run_step "wireguard_install" "apt-get install -y -qq wireguard iptables" "apt_basics"
  if [[ "${STEP_SUCCESS[wireguard_install]:-0}" -eq 1 ]]; then
    run_step "wireguard_config" "
      mkdir -p /etc/wireguard
      wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
      chmod 600 /etc/wireguard/server_private.key
      PRIV=\$(cat /etc/wireguard/server_private.key)
      sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
      grep -q 'net.ipv4.ip_forward' /etc/sysctl.d/99-wireguard.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-wireguard.conf
      echo \"[Interface]
PrivateKey = \$PRIV
Address = ${WG_NETWORK}.1/${WG_CIDR}
ListenPort = ${WG_PORT}
PreUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WG_EXT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WG_EXT_IF} -j MASQUERADE
\" > /etc/wireguard/${WG_INTERFACE}.conf
      echo \"WireGuard klucze wygenerowane. Edytuj /etc/wireguard/${WG_INTERFACE}.conf i dodaj [Peer] dla klientów.\"
    " "wireguard_install"
  fi
}

# === FAZA 5: NVIDIA (opcjonalnie) ===
phase_nvidia() {
  if [[ "$INSTALL_NVIDIA" == "no" ]]; then
    log_skip "nvidia_install" "(INSTALL_NVIDIA=no)"
    return 0
  fi
  if [[ "$INSTALL_NVIDIA" == "auto" ]]; then
    if ! lspci 2>/dev/null | grep -qi nvidia; then
      log_skip "nvidia_install" "(brak GPU NVIDIA)"
      return 0
    fi
  fi
  run_step "nvidia_install" "
    if command -v ubuntu-drivers >/dev/null 2>&1; then
      ubuntu-drivers install --no-interactive 2>/dev/null || apt-get install -y nvidia-driver-535
    else
      apt-get install -y -qq nvidia-driver-535 2>/dev/null || apt-get install -y -qq nvidia-driver
    fi
  " "apt_basics"
}

# === FAZA 6: Ollama ===
phase_ollama() {
  if [[ "$INSTALL_OLLAMA" != "true" ]]; then
    log_skip "ollama_install" "(INSTALL_OLLAMA=false)"
    return 0
  fi
  run_step "ollama_install" "curl -fsSL $URL_OLLAMA | sh" "apt_basics"
  run_step "ollama_service" "systemctl enable ollama 2>/dev/null || true; systemctl start ollama 2>/dev/null || true" "ollama_install"
}

# === FAZA 7: PostgreSQL ===
phase_postgres() {
  if [[ "$INSTALL_POSTGRES" != "true" ]]; then
    log_skip "postgres_install" "(INSTALL_POSTGRES=false)"
    return 0
  fi
  run_step "postgres_install" "apt-get install -y -qq postgresql postgresql-contrib" "apt_basics"
  run_step "postgres_service" "systemctl enable postgresql && systemctl start postgresql" "postgres_install"
}

# === FAZA 8: Redis ===
phase_redis() {
  if [[ "$INSTALL_REDIS" != "true" ]]; then
    log_skip "redis_install" "(INSTALL_REDIS=false)"
    return 0
  fi
  run_step "redis_install" "apt-get install -y -qq redis-server" "apt_basics"
  run_step "redis_service" "systemctl enable redis-server && systemctl start redis-server" "redis_install"
}

# === FAZA 9: MinIO ===
phase_minio() {
  if [[ "$INSTALL_MINIO" != "true" ]]; then
    log_skip "minio_install" "(INSTALL_MINIO=false)"
    return 0
  fi
  run_step "minio_install" "
    (cd /tmp && curl -fsSL -o minio $URL_MINIO)
    chmod +x /tmp/minio
    mv /tmp/minio /usr/local/bin/
    mkdir -p $BASE_DIR/minio-data
    useradd -r -s /bin/false minio 2>/dev/null || true
    chown -R minio:minio $BASE_DIR/minio-data 2>/dev/null || true
  " "apt_basics"
  if [[ "${STEP_SUCCESS[minio_install]:-0}" -eq 1 ]]; then
    run_step "minio_service" "
      cat > /etc/systemd/system/minio.service << MINIOEOF
[Unit]
Description=MinIO
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/minio server $BASE_DIR/minio-data
User=minio
Environment=MINIO_ROOT_USER=$MINIO_ROOT_USER
Environment=MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
Restart=on-failure

[Install]
WantedBy=multi-user.target
MINIOEOF
      systemctl daemon-reload
      systemctl enable minio
      systemctl start minio
    " "minio_install"
  fi
}

# === FAZA 10: n8n ===
phase_n8n() {
  if [[ "$INSTALL_N8N" != "true" ]]; then
    log_skip "n8n_install" "(INSTALL_N8N=false)"
    return 0
  fi
  if [[ "${STEP_SUCCESS[docker_install]:-0}" -eq 1 ]]; then
    run_step "n8n_install" "
      mkdir -p $BASE_DIR/n8n-data
      docker rm -f n8n 2>/dev/null || true
      docker run -d --name n8n --restart unless-stopped \
        -p 5678:5678 \
        -v $BASE_DIR/n8n-data:/home/node/.n8n \
        n8nio/n8n
    " "docker_install"
  else
    run_step "n8n_install" "
      if curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null; then
        apt-get install -y -qq nodejs
      fi
      if ! command -v node >/dev/null 2>&1; then
        apt-get install -y -qq nodejs npm
      fi
      npm install -g n8n
      mkdir -p $BASE_DIR/n8n-data
      N8N_USER_FOLDER=$BASE_DIR/n8n-data n8n start &
      sleep 3
    " "apt_basics"
    log_warn "n8n (npm): proces nie przetrwa rebootu. Preferuj INSTALL_DOCKER=true dla n8n w Dockerze."
  fi
}

# === FAZA 11: Helm (jeśli K3s) ===
phase_helm() {
  if [[ "${STEP_SUCCESS[k3s_install]:-0}" -eq 1 ]]; then
    run_step "helm_install" "curl -fsSL $URL_HELM | bash" "apt_basics"
  else
    log_skip "helm_install" "(K3s nie zainstalowany)"
  fi
}

# === FAZA 12: Olares (opcjonalnie) ===
phase_olares() {
  if [[ "$INSTALL_OLARES" != "true" ]]; then
    log_skip "olares_install" "(INSTALL_OLARES=false)"
    return 0
  fi
  run_step "olares_install" "curl -fsSL $URL_OLARES | bash -" "apt_basics"
  log_warn "Olares wymaga ręcznej aktywacji przez Wizard URL. Zobacz docs/INSTRUKCJA_MANUALNA.md"
}

# === MAIN ===
main() {
  phase_init
  phase_base
  phase_docker
  phase_k3s
  phase_wireguard
  phase_nvidia
  phase_ollama
  phase_postgres
  phase_redis
  phase_minio
  phase_n8n
  phase_helm
  phase_olares

  print_report

  if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
    log_warn "Niektóre kroki się nie powiodły. Sprawdź log: $LOG_FILE"
    exit 1
  fi
}

main "$@"
