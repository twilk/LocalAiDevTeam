#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# Tworzenie użytkownika Ubuntu
# Użycie: sudo ./create_ubuntu_user.sh LOGIN HASŁO
# Przykład: sudo ./create_ubuntu_user.sh Wilk wilczywilk
############################################

require_root() {
  [[ "${EUID}" -ne 0 ]] && { echo "Uruchom jako root: sudo $0 LOGIN HASŁO" >&2; exit 1; }
}

[[ $# -lt 2 ]] && {
  echo "Użycie: sudo $0 LOGIN HASŁO" >&2
  echo "Przykład: sudo $0 Wilk wilczywilk" >&2
  exit 1
}

LOGIN="$1"
PASS="$2"

require_root

if id "${LOGIN}" &>/dev/null; then
  echo "Użytkownik ${LOGIN} już istnieje. Aktualizuję hasło."
  echo "${LOGIN}:${PASS}" | chpasswd
else
  echo "Tworzę użytkownika ${LOGIN}..."
  useradd -m -s /bin/bash -c "${LOGIN}" "${LOGIN}"
  echo "${LOGIN}:${PASS}" | chpasswd
fi

# RDP – jeśli xrdp jest zainstalowany
if getent group xrdp &>/dev/null; then
  usermod -aG xrdp "${LOGIN}"
  echo "Dodano do grupy xrdp."
fi

# .xsession dla RDP (Xfce – niezawodny)
HOME_DIR="$(getent passwd "${LOGIN}" | cut -d: -f6)"
if [[ -d "${HOME_DIR}" ]]; then
  echo "xfce4-session" > "${HOME_DIR}/.xsession"
  chown "${LOGIN}:$(id -gn "${LOGIN}")" "${HOME_DIR}/.xsession"
  chmod 644 "${HOME_DIR}/.xsession"
fi

echo ""
echo "Gotowe. Użytkownik: ${LOGIN}"
