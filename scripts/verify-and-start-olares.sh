#!/usr/bin/env bash
#
# verify-and-start-olares.sh – Uruchamia serwisy, testuje porty, diagnostykuje błędy
# Uruchom: sudo bash verify-and-start-olares.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

BASE_DIR="${BASE_DIR:-/opt/ai-dev-team}"
HOST_IP="${HOST_IP:-$(hostname -I | awk '{print $1}')}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
info()  { echo "[INFO] $*"; }

# Test portu – zwraca 0 jeśli osiągalny
port_reachable() {
  local host="${1:-127.0.0.1}"
  local port="$2"
  bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null && return 0
  command -v nc &>/dev/null && nc -z -w2 "$host" "$port" 2>/dev/null && return 0
  return 1
}

check_root() {
  [[ $EUID -ne 0 ]] && { fail "Uruchom jako root: sudo bash $0"; exit 1; }
}

# === Weryfikacja – wiele metod (systemctl, command, pliki) ===
svc_installed() {
  local svc="$1"
  systemctl list-unit-files --type=service 2>/dev/null | grep -qE "^\s*${svc}(\.service)?[[:space:]]" ||
  systemctl list-units --all --type=service 2>/dev/null | grep -q "${svc}" ||
  systemctl status "$svc" &>/dev/null
}
check_service() {
  local name="$1"
  local svc="$2"
  local desc="${3:-$name}"
  local alt_check="${4:-}"  # np. "docker" => command -v docker

  if [[ -n "$alt_check" ]]; then
    if eval "$alt_check" 2>/dev/null; then
      if systemctl is-active --quiet "$svc" 2>/dev/null; then
        ok "$desc – działa"
        return 0
      fi
      info "Uruchamiam $desc..."
      systemctl start "$svc" 2>/dev/null && { ok "$desc – uruchomiono"; return 0; }
    fi
  elif ! svc_installed "$svc"; then
    warn "$desc – nie wykryto (sprawdź log setup-olares: czy instalacja się powiodła?)"
    return 1
  elif systemctl is-active --quiet "$svc" 2>/dev/null; then
    ok "$desc – działa"
    return 0
  else
    info "Uruchamiam $desc..."
    systemctl start "$svc" 2>/dev/null && { ok "$desc – uruchomiono"; return 0; }
  fi
  fail "$desc – nie działa"
  return 1
}

# PostgreSQL – Ubuntu używa postgresql lub postgresql@VERSION-main
# Ollama domyślnie nasłuchuje tylko na 127.0.0.1 – napraw dla dostępu zdalnego
ensure_ollama_bind_all() {
  if ! systemctl list-unit-files | grep -q ollama; then return 0; fi
  local conf="/etc/systemd/system/ollama.service.d/override.conf"
  if ! grep -q "OLLAMA_HOST" "$conf" 2>/dev/null; then
    mkdir -p "$(dirname "$conf")"
    cat > "$conf" <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF
    systemctl daemon-reload
    systemctl restart ollama 2>/dev/null
    sleep 2
  fi
}

# MinIO console (9001) – jawny port konsoli
ensure_minio_console() {
  [[ ! -f /etc/systemd/system/minio.service ]] && return 0
  if ! grep -q "console-address" /etc/systemd/system/minio.service 2>/dev/null; then
    sed -i 's|ExecStart=/usr/local/bin/minio server |ExecStart=/usr/local/bin/minio server --console-address :9001 |' /etc/systemd/system/minio.service
    systemctl daemon-reload
    systemctl restart minio 2>/dev/null
    sleep 2
  fi
}

# n8n – sprawdź czy kontener mapuje port na 0.0.0.0
ensure_n8n_bind_all() {
  if ! docker ps -a --format '{{.Names}}' | grep -q ^n8n$; then return 0; fi
  if docker port n8n 5678 2>/dev/null | grep -q "0.0.0.0"; then return 0; fi
  info "n8n – kontener powinien mieć -p 5678:5678 (już ustawione w setup)"
  docker start n8n 2>/dev/null
}

check_postgresql() {
  local desc="PostgreSQL"
  if pg_isready -h localhost -U postgres 2>/dev/null || pg_isready -h localhost 2>/dev/null; then
    ok "$desc – działa"
    return 0
  fi
  if ! dpkg -l postgresql* 2>/dev/null | grep -q ^ii; then
    warn "$desc – nie zainstalowany (apt install postgresql postgresql-contrib)"
    return 1
  fi
  info "Uruchamiam $desc..."
  systemctl start postgresql 2>/dev/null
  # Ubuntu 22.04+: czasem postgresql@16-main zamiast postgresql
  systemctl start $(systemctl list-unit-files -t service --no-pager 2>/dev/null | grep -oE 'postgresql@[^[:space:]]+' | head -1) 2>/dev/null
  sleep 2
  if pg_isready -h localhost 2>/dev/null; then
    ok "$desc – uruchomiono"
    return 0
  fi
  fail "$desc – nie odpowiada"
  info "Diagnostyka: systemctl status postgresql; journalctl -u postgresql -n 30"
  info "Nowa instalacja bez klastra? pg_lsclusters; sudo pg_createcluster 16 main --start"
  return 1
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
  if ! pg_isready -h localhost 2>/dev/null; then return 0; fi
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

  # Serwisy systemd (alt_check = dodatkowa metoda wykrycia)
  check_service "Docker"      "docker"      "Docker"      "command -v docker"
  check_service "K3s"         "k3s"         "K3s"         "[[ -f /etc/rancher/k3s/k3s.yaml ]]"
  check_service "Ollama"      "ollama"      "Ollama"      "command -v ollama"
  ensure_ollama_bind_all
  check_postgresql
  check_service "Redis"       "redis-server" "Redis"      ""
  check_service "MinIO"       "minio"       "MinIO"       "[[ -x /usr/local/bin/minio ]]"
  ensure_minio_console

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

  # === Test łączności na portach ===
  echo ""
  echo "=============================================="
  echo " Test łączności (HOST: ${HOST_IP})"
  echo "=============================================="
  echo ""
  test_port() {
    local name="$1" port="$2" url="$3" svc="$4" http="${5:-}"
    local ok_msg fix_msg
    if port_reachable "$HOST_IP" "$port" || port_reachable "127.0.0.1" "$port"; then
      ok "$name (port $port) – osiągalny"
      return 0
    fi
    fail "$name (port $port) – nie odpowiada"
    if [[ -n "$svc" ]]; then
      info "  Błąd: $(systemctl is-active "$svc" 2>/dev/null || echo '?')"
      info "  Log:  journalctl -u $svc -n 15 --no-pager"
    fi
    case "$name" in
      n8n*)    fix_msg="docker ps -a | grep n8n; docker logs n8n --tail 25"; svc="";;
      Ollama)  fix_msg="OLLAMA_HOST=0.0.0.0 w /etc/systemd/system/ollama.service.d/override.conf";;
      MinIO)   fix_msg="--console-address :9001 w ExecStart minio; UFW/Firewall?";;
      PostgreSQL) fix_msg="pg_lsclusters; sudo pg_createcluster 16 main --start";;
      Redis)   fix_msg="bind 127.0.0.1 – Redis tylko lokalnie (bezpieczeństwo)";;
      *)       fix_msg="sprawdź firewall: ufw status";;
    esac
    info "  Napraw: $fix_msg"
    echo ""
    return 1
  }
  test_port "n8n (HTTP)"        5678 "http://${HOST_IP}:5678" "" "http"
  test_port "MinIO API"         9000 "http://${HOST_IP}:9000" "minio" "http"
  test_port "MinIO Console"     9001 "http://${HOST_IP}:9001" "minio" "http"
  test_port "Ollama API"       11434 "http://${HOST_IP}:11434" "ollama" "http"
  test_port "PostgreSQL"        5432 "${HOST_IP}:5432 (klient psql)" "postgresql"
  test_port "Redis"             6379 "${HOST_IP}:6379 (klient redis-cli)" "redis-server"
  test_port "K3s API"           6443 "https://${HOST_IP}:6443" "k3s"

  echo "=============================================="
  echo " Adresy (tylko HTTP w przeglądarce: n8n, MinIO, Ollama)"
  echo "=============================================="
  echo ""
  echo "  n8n:          http://${HOST_IP}:5678"
  echo "  MinIO API:    http://${HOST_IP}:9000"
  echo "  MinIO Console: http://${HOST_IP}:9001  (minioadmin/minioadmin)"
  echo "  Ollama:       http://${HOST_IP}:11434"
  echo ""
  echo "  PostgreSQL, Redis, K3s – dostęp przez dedykowane klienty (psql, redis-cli, kubectl)"
  echo "  Katalog: ${BASE_DIR}/"
  echo "=============================================="
}

main "$@"
