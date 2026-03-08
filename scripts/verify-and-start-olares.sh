#!/usr/bin/env bash
#
# verify-and-start-olares.sh – Weryfikacja, uruchomienie i podsumowanie serwisów po setup-olares.sh
# Uruchom: sudo bash verify-and-start-olares.sh
# Lub:     source config.env && sudo -E bash verify-and-start-olares.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

BASE_DIR="${BASE_DIR:-/opt/ai-dev-team}"
HOST_IP="${HOST_IP:-$(hostname -I | awk '{print $1}')}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
info()  { echo "[INFO] $*"; }

check_root() {
  [[ $EUID -ne 0 ]] && { fail "Uruchom jako root: sudo bash $0"; exit 1; }
}

# === Weryfikacja i uruchomienie serwisów ===
check_service() {
  local name="$1"
  local svc="$2"
  local desc="${3:-$name}"

  if ! systemctl list-unit-files | grep -q "^${svc}\."; then
    warn "$desc – nie zainstalowany (pomijam)"
    return 1
  fi
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    ok "$desc – działa"
    return 0
  fi
  info "Uruchamiam $desc..."
  if systemctl start "$svc" 2>/dev/null; then
    ok "$desc – uruchomiono"
    return 0
  else
    fail "$desc – nie udało się uruchomić"
    return 1
  fi
}

check_docker_container() {
  local name="$1"
  local container="$2"

  if ! command -v docker &>/dev/null; then
    warn "$name – Docker nie zainstalowany (pomijam)"
    return 1
  fi
  if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
      ok "$name – kontener działa"
      return 0
    fi
    info "Uruchamiam $name..."
    docker start "$container" 2>/dev/null && { ok "$name – uruchomiono"; return 0; }
  fi
  warn "$name – kontener nie istnieje lub nie działa"
  return 1
}

# === Konfiguracja podstawowa ===
configure_postgres_n8n() {
  if ! systemctl is-active --quiet postgresql 2>/dev/null; then return 0; fi
  local db_user="${N8N_DB_USER:-n8n}"
  local db_name="${N8N_DB_NAME:-n8n}"
  if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'" 2>/dev/null | grep -q 1; then
    ok "Baza PostgreSQL $db_name istnieje"
    return 0
  fi
  info "Tworzę bazę $db_name dla n8n..."
  sudo -u postgres psql -c "CREATE USER $db_user WITH PASSWORD '${N8N_DB_PASSWORD:-n8n}';" 2>/dev/null || true
  sudo -u postgres psql -c "CREATE DATABASE $db_name OWNER $db_user;" 2>/dev/null || true
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;" 2>/dev/null || true
  ok "Baza $db_name gotowa (user: $db_user)"
}

# === MAIN ===
main() {
  check_root
  echo ""
  echo "=============================================="
  echo " Weryfikacja i uruchomienie serwisów Olares"
  echo "=============================================="
  echo ""

  # Serwisy systemd
  check_service "Docker"      "docker"
  check_service "K3s"         "k3s"
  check_service "Ollama"      "ollama"
  check_service "PostgreSQL"  "postgresql"
  check_service "Redis"       "redis-server"
  check_service "MinIO"       "minio"

  # WireGuard – może wymagać konfiguracji [Peer]
  for iface in wg0; do
    if [[ -f "/etc/wireguard/${iface}.conf" ]]; then
      if ip link show "$iface" &>/dev/null; then
        ok "WireGuard $iface – działa"
      else
        info "Uruchamiam WireGuard $iface..."
        systemctl start "wg-quick@${iface}" 2>/dev/null || wg-quick up "$iface" 2>/dev/null
        if ip link show "$iface" &>/dev/null; then
          ok "WireGuard $iface – uruchomiono"
        else
          warn "WireGuard $iface – dodaj [Peer] w /etc/wireguard/${iface}.conf"
        fi
      fi
    fi
  done

  # n8n (Docker)
  check_docker_container "n8n" "n8n"

  # Opcjonalna konfiguracja
  configure_postgres_n8n

  # === Podsumowanie połączeń ===
  echo ""
  echo "=============================================="
  echo " Adresy i porty (HOST: ${HOST_IP})"
  echo "=============================================="
  echo ""
  echo "n8n (workflow):     http://${HOST_IP}:5678"
  echo "MinIO API:          http://${HOST_IP}:9000"
  echo "MinIO Console:      http://${HOST_IP}:9001  (domyślne: minioadmin/minioadmin)"
  echo "PostgreSQL:         ${HOST_IP}:5432"
  echo "Redis:              ${HOST_IP}:6379"
  echo "Ollama API:         http://${HOST_IP}:11434"
  echo "K3s API:            https://${HOST_IP}:6443  (KUBECONFIG=/etc/rancher/k3s/k3s.yaml)"
  echo ""
  echo "Katalog bazowy:     ${BASE_DIR}"
  echo "  - n8n-data:       ${BASE_DIR}/n8n-data"
  echo "  - minio-data:     ${BASE_DIR}/minio-data"
  echo ""
  echo "Aby n8n używał PostgreSQL, dodaj przy docker run:"
  echo "  -e DB_TYPE=postgresdb -e DB_POSTGRESDB_HOST=localhost"
  echo "  -e DB_POSTGRESDB_DATABASE=n8n -e DB_POSTGRESDB_USER=n8n"
  echo "=============================================="
}

main "$@"
