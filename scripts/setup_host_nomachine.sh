#!/usr/bin/env bash
# NoMachine – prostsza i bardziej niezawodna alternatywa do xRDP.
# Działa z pełnym GNOME out-of-the-box. Klient: nomachine.com/download
#
# Użycie: sudo ./setup_host_nomachine.sh

set -Eeuo pipefail

TAILSCALE_HOSTNAME="${TAILSCALE_HOSTNAME:-zpk-darwina-ai}"
NOMACHINE_PORT="4000"

require_root() { [[ "${EUID}" -ne 0 ]] && { echo "Uruchom jako root: sudo $0" >&2; exit 1; }; }
log() { echo "[INFO] $*"; }

require_root

# Minimalny pulpit (NoMachine potrzebuje X)
if ! dpkg -l | grep -qE 'xfce4|ubuntu-desktop|gnome-session'; then
  log "Instaluję Xfce (minimalny pulpit)..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y xfce4 xfce4-goodies dbus-x11
fi

# Tailscale (jeśli nie ma – instalacja)
if ! command -v tailscale &>/dev/null; then
  log "Instaluję Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi
systemctl enable tailscaled 2>/dev/null || true
systemctl start tailscaled 2>/dev/null || true

# NoMachine – wymaga ręcznego pobrania (URL się zmienia)
DEB_FILE="/tmp/nomachine.deb"
# Próba pobrania – sprawdź https://downloads.nomachine.com/ dla aktualnej wersji
for VER in 8.15.2 8.12.4 8.10.1; do
  URL="https://download.nomachine.com/download/${VER}/Linux/nomachine_${VER}_1_amd64.deb"
  if curl -fsSL -o "${DEB_FILE}" "${URL}" 2>/dev/null && [[ -s "${DEB_FILE}" ]]; then
    break
  fi
  rm -f "${DEB_FILE}"
done

if [[ -f "${DEB_FILE}" && -s "${DEB_FILE}" ]]; then
  log "Instaluję NoMachine..."
  dpkg -i "${DEB_FILE}" 2>/dev/null || apt-get install -f -y
  rm -f "${DEB_FILE}"
else
  echo "Pobierz ręcznie: https://www.nomachine.com/download" >&2
  echo "  Linux 64-bit Deb, zainstaluj: sudo dpkg -i nomachine_*.deb" >&2
  exit 1
fi

systemctl enable nxserver 2>/dev/null || true
systemctl start nxserver 2>/dev/null || true

# Firewall – tylko Tailscale
if command -v ufw &>/dev/null; then
  ufw allow in on tailscale0 to any port "${NOMACHINE_PORT}" proto tcp 2>/dev/null || true
  ufw --force enable 2>/dev/null || true
fi

IP=$(tailscale ip -4 2>/dev/null || echo "???")
echo ""
echo "============================================"
echo " NoMachine gotowe"
echo "============================================"
echo "Host: ${IP}:${NOMACHINE_PORT}"
echo ""
echo "Na Windows: pobierz klienta z nomachine.com"
echo "Połącz się z: ${IP}"
echo "============================================"
