#!/usr/bin/env bash
# Naprawia zamykanie sesji xRDP przy logowaniu.
# Uruchom na hoście Ubuntu: sudo ./fix_xrdp_session_close.sh LOGIN
# np. sudo ./fix_xrdp_session_close.sh Wilk

set -e
[[ "${EUID}" -ne 0 ]] && { echo "Uruchom jako root: sudo $0 LOGIN" >&2; exit 1; }
[[ -z "${1:-}" ]] && { echo "Podaj login: sudo $0 Wilk" >&2; exit 1; }

USER="$1"
HOME_DIR="$(getent passwd "${USER}" | cut -d: -f6)"
[[ -z "${HOME_DIR}" || ! -d "${HOME_DIR}" ]] && { echo "Użytkownik ${USER} nie istnieje lub brak katalogu domowego." >&2; exit 1; }

echo "[1/5] PAM – gnome_keyring (przeglądarka, hasła)..."
if [[ -f /etc/pam.d/xrdp-sesman ]] && ! grep -q "pam_gnome_keyring" /etc/pam.d/xrdp-sesman 2>/dev/null; then
  sed -i '/@include common-auth/a auth optional pam_gnome_keyring.so' /etc/pam.d/xrdp-sesman
  sed -i '/@include common-session/a session optional pam_gnome_keyring.so auto_start' /etc/pam.d/xrdp-sesman
fi

echo "[2/5] Polkit – colord (blokował sesję)..."
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/45-allow-colord.rules <<'EOF'
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.freedesktop.color-manager.") === 0) {
    return polkit.Result.YES;
  }
});
EOF
chmod 644 /etc/polkit-1/rules.d/45-allow-colord.rules

# Polkit – Odhoduj w Ustawieniach użytkowników
if [[ ! -f /etc/polkit-1/rules.d/46-allow-user-admin.rules ]]; then
  cat > /etc/polkit-1/rules.d/46-allow-user-admin.rules <<'PK'
polkit.addRule(function(action, subject) {
  if (action.id === "org.gnome.controlcenter.user-accounts.administration" && subject.isInGroup("sudo")) {
    return polkit.Result.AUTH_ADMIN;
  }
});
PK
  chmod 644 /etc/polkit-1/rules.d/46-allow-user-admin.rules
fi

echo "[3/5] Dodaję ${USER} do grupy xrdp..."
usermod -aG xrdp "${USER}"

echo "[4/5] .xsession i .xsessionrc (nadpisuję dla pełnego GNOME)..."
if grep -q ubuntu /etc/xrdp/startwm.sh 2>/dev/null; then
  # Pełny Ubuntu Desktop (GNOME)
  echo 'gnome-session' > "${HOME_DIR}/.xsession"
  cat > "${HOME_DIR}/.xsessionrc" <<'XSRC'
export XAUTHORITY=${HOME}/.Xauthority
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
XSRC
else
  # Xfce
  echo 'xfce4-session' > "${HOME_DIR}/.xsession"
  rm -f "${HOME_DIR}/.xsessionrc"
fi
chown "${USER}:$(id -gn "${USER}")" "${HOME_DIR}/.xsession"
chmod 644 "${HOME_DIR}/.xsession"
[[ -f "${HOME_DIR}/.xsessionrc" ]] && { chown "${USER}:$(id -gn "${USER}")" "${HOME_DIR}/.xsessionrc"; chmod 644 "${HOME_DIR}/.xsessionrc"; }

echo "[5/5] Restart xrdp..."
systemctl restart xrdp

echo ""
echo "Gotowe. Wyloguj się z RDP (jeśli byłeś), odczekaj 5 s, połącz ponownie."
