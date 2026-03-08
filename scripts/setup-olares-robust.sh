#!/usr/bin/env bash
#
# setup-olares-robust.sh – Weryfikuje stan każdego komponentu, instaluje tylko gdy brak.
# Pokazuje postęp (etap X/Y) i pasek postępu. Wymaga potwierdzenia sukcesu przed kolejnym krokiem.
#
# Uruchom: sudo bash setup-olares-robust.sh
# Konfiguracja: config.env (source przed uruchomieniem)
#
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

# Zmienne (jak w setup-olares.sh)
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
WG_INTERFACE="${WG_INTERFACE:-wg0}"
WG_PORT="${WG_PORT:-51820}"
WG_NETWORK="${WG_NETWORK:-10.100.0.0}"
WG_CIDR="${WG_CIDR:-24}"
WG_EXT_IF="${WG_EXT_IF:-$(command -v ip >/dev/null 2>&1 && ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -1)}"
WG_EXT_IF="${WG_EXT_IF:-eth0}"

URL_OLARES="https://olares.sh"
URL_DOCKER="https://get.docker.com"
URL_K3S="https://get.k3s.io"
URL_OLLAMA="https://ollama.com/install.sh"
URL_MINIO="https://dl.min.io/server/minio/release/linux-amd64/minio"
URL_HELM="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"

LOG_FILE="/var/log/setup-olares-robust-$(date +%Y%m%d-%H%M%S).log"
CURRENT_STEP=0
TOTAL_STEPS=0
declare -a STEP_NAMES

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Pasek postępu: [=======>    ] 45%
progress_bar() {
  local current=$1
  local total=$2
  local width=40
  local pct=0
  [[ $total -gt 0 ]] && pct=$((current * 100 / total))
  local filled=$((width * current / total))
  local empty=$((width - filled))
  printf "\r  ${CYAN}["
  printf "%${filled}s" | tr ' ' '='
  [[ $filled -gt 0 ]] && printf ">"
  printf "%${empty}s" | tr ' ' '-'
  printf "]${NC} %3d%%  " "$pct"
}

# Spinner dla długich operacji
spinner_pid=""
spinner_start() {
  local msg="$1"
  (
    local spin='/-\|'
    local i=0
    while true; do
      printf "\r  ${CYAN}%s ${spin:i++%4:1}${NC} " "$msg"
      sleep 0.15
    done
  ) &
  spinner_pid=$!
}
spinner_stop() {
  [[ -n "$spinner_pid" ]] && kill "$spinner_pid" 2>/dev/null
  spinner_pid=""
  printf "\r%-50s\r" " "
}

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
log_ok() { log "${GREEN}[OK]${NC} $*"; }
log_fail() { log "${RED}[FAIL]${NC} $*"; }
log_skip() { log "${YELLOW}[SKIP]${NC} $*"; }
log_warn() { log "${YELLOW}[WARN]${NC} $*"; }

check_root() {
  [[ $EUID -ne 0 ]] && { echo -e "${RED}Uruchom jako root: sudo bash $0${NC}"; exit 1; }
}

# === Weryfikatory stanu (zwracają 0 = OK, 1 = brak/do instalacji) ===
verify_apt_basics()    { command -v curl &>/dev/null && command -v jq &>/dev/null; }
verify_docker()        { command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; }
verify_k3s()           { [[ -f /etc/rancher/k3s/k3s.yaml ]] && systemctl is-active --quiet k3s 2>/dev/null; }
verify_ollama()        { command -v ollama &>/dev/null && systemctl is-active --quiet ollama 2>/dev/null; }
verify_postgres()      { (systemctl is-active --quiet postgresql 2>/dev/null) || (systemctl is-active --quiet postgresql@* 2>/dev/null); }
verify_redis()        { systemctl is-active --quiet redis-server 2>/dev/null; }
verify_minio_binary() { [[ -x /usr/local/bin/minio ]]; }
verify_minio()        { verify_minio_binary && systemctl is-active --quiet minio 2>/dev/null; }
verify_n8n()           { docker ps 2>/dev/null | grep -q n8n; }
verify_wireguard()     { [[ -f /etc/wireguard/${WG_INTERFACE}.conf ]] && ip link show "$WG_INTERFACE" &>/dev/null; }

# === Wykonaj krok z weryfikacją przed i po ===
# run_robust_step "nazwa" "weryfikator" "polecenie_instalacyjne" "dep1" "dep2"
run_robust_step() {
  local name="$1"
  local verifier="$2"
  local install_cmd="$3"
  shift 3
  local deps=("$@")

  for d in "${deps[@]}"; do
    if ! "$d"; then
      log_skip "$name – zależność nie spełniona"
      return 1
    fi
  done

  CURRENT_STEP=$((CURRENT_STEP + 1))
  progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
  echo -ne "\n  ${CYAN}[$CURRENT_STEP/$TOTAL_STEPS]${NC} $name ... "

  if $verifier; then
    log_ok "$name – już zainstalowany i działa"
    echo -e "${GREEN}OK (już jest)${NC}"
    return 0
  fi

  log "Instaluję: $name"
  spinner_start "Instalacja..."
  if eval "$install_cmd" >> "$LOG_FILE" 2>&1; then
    spinner_stop
    if $verifier; then
      log_ok "$name – zainstalowano i zweryfikowano"
      echo -e "${GREEN}OK${NC}"
      return 0
    else
      log_fail "$name – instalacja wykonana, ale weryfikacja nie przeszła"
      echo -e "${RED}FAIL (weryfikacja)${NC}"
      return 1
    fi
  else
    spinner_stop
    log_fail "$name – błąd instalacji"
    echo -e "${RED}FAIL${NC}"
    return 1
  fi
}

# === Instalacje pojedyncze (bez zależności) ===
run_standalone() {
  local name="$1"
  local verifier="$2"
  local install_cmd="$3"

  CURRENT_STEP=$((CURRENT_STEP + 1))
  progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
  echo -ne "\n  ${CYAN}[$CURRENT_STEP/$TOTAL_STEPS]${NC} $name ... "

  if $verifier; then
    log_ok "$name – już OK"
    echo -e "${GREEN}OK (już jest)${NC}"
    return 0
  fi

  log "Wykonuję: $name"
  spinner_start "Instalacja..."
  if eval "$install_cmd" >> "$LOG_FILE" 2>&1; then
    spinner_stop
    if $verifier; then
      log_ok "$name – OK"
      echo -e "${GREEN}OK${NC}"
      return 0
    else
      spinner_stop
      log_fail "$name – weryfikacja nie przeszła"
      echo -e "${RED}FAIL${NC}"
      return 1
    fi
  else
    spinner_stop
    log_fail "$name – błąd"
    echo -e "${RED}FAIL${NC}"
    return 1
  fi
}

# === FAZY (uproszczone) ===
phase_base() {
  run_standalone "apt_update" "true" "apt-get update -qq"
  run_standalone "apt_upgrade" "true" "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq"
  run_standalone "apt_basics" "verify_apt_basics" "apt-get install -y -qq curl wget gnupg2 ca-certificates lsb-release apt-transport-https software-properties-common jq iproute2 locales pciutils iptables"
  run_standalone "hostname" "true" "hostnamectl set-hostname $HOSTNAME"
  run_standalone "timezone" "true" "timedatectl set-timezone $TIMEZONE"
  run_standalone "dirs" "true" "mkdir -p $BASE_DIR/{logs,models,backups} && chmod 755 $BASE_DIR"
}

verify_docker_installed() { command -v docker &>/dev/null; }
phase_docker() {
  [[ "$INSTALL_DOCKER" != "true" ]] && return 0
  run_robust_step "Docker" "verify_docker" "curl -fsSL $URL_DOCKER | sh && systemctl enable docker && systemctl start docker" "verify_apt_basics"
}

phase_k3s() {
  [[ "$INSTALL_K3S" != "true" ]] && return 0
  local k3s_cmd='curl -sfL '"$URL_K3S"' | sh -'
  if verify_docker; then
    k3s_cmd='INSTALL_K3S_EXEC="--docker" '"$k3s_cmd"
  fi
  run_robust_step "K3s" "verify_k3s" "$k3s_cmd" "verify_apt_basics"
  run_standalone "K3s wait" "verify_k3s" "sleep 15 && export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get nodes 2>/dev/null || true"
}

phase_ollama() {
  [[ "$INSTALL_OLLAMA" != "true" ]] && return 0
  run_robust_step "Ollama" "verify_ollama" "
    curl -fsSL $URL_OLLAMA | sh &&
    mkdir -p /etc/systemd/system/ollama.service.d &&
    echo '[Service]
Environment=OLLAMA_HOST=0.0.0.0' > /etc/systemd/system/ollama.service.d/override.conf
    systemctl daemon-reload && systemctl enable ollama 2>/dev/null && systemctl start ollama 2>/dev/null
  " "verify_apt_basics"
}

phase_postgres() {
  [[ "$INSTALL_POSTGRES" != "true" ]] && return 0
  run_robust_step "PostgreSQL" "verify_postgres" "apt-get install -y -qq postgresql postgresql-contrib && systemctl enable postgresql && systemctl start postgresql" "verify_apt_basics"
}

phase_redis() {
  [[ "$INSTALL_REDIS" != "true" ]] && return 0
  run_robust_step "Redis" "verify_redis" "apt-get install -y -qq redis-server && systemctl enable redis-server && systemctl start redis-server" "verify_apt_basics"
}

phase_minio() {
  [[ "$INSTALL_MINIO" != "true" ]] && return 0
  run_robust_step "MinIO" "verify_minio" "
    (cd /tmp && curl -fsSL -o minio $URL_MINIO) &&
    chmod +x /tmp/minio && mv /tmp/minio /usr/local/bin/ &&
    mkdir -p $BASE_DIR/minio-data &&
    useradd -r -s /bin/false minio 2>/dev/null || true &&
    chown -R minio:minio $BASE_DIR/minio-data 2>/dev/null || true &&
    cat > /etc/systemd/system/minio.service << EOF
[Unit]
Description=MinIO
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/minio server --console-address :9001 $BASE_DIR/minio-data
User=minio
Environment=MINIO_ROOT_USER=$MINIO_ROOT_USER
Environment=MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable minio && systemctl start minio
  " "verify_apt_basics"
}

phase_wireguard() {
  [[ "$INSTALL_WIREGUARD" != "true" ]] && return 0
  run_robust_step "WireGuard" "verify_wireguard" "
    apt-get install -y -qq wireguard iptables
    mkdir -p /etc/wireguard
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    chmod 600 /etc/wireguard/server_private.key
    PRIV=\$(cat /etc/wireguard/server_private.key)
    grep -q 'net.ipv4.ip_forward' /etc/sysctl.d/99-wireguard.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-wireguard.conf
    cat > /etc/wireguard/${WG_INTERFACE}.conf << WGF
[Interface]
PrivateKey = \$PRIV
Address = ${WG_NETWORK}.1/${WG_CIDR}
ListenPort = ${WG_PORT}
PreUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WG_EXT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WG_EXT_IF} -j MASQUERADE
WGF
  " "verify_apt_basics"
}

phase_n8n() {
  [[ "$INSTALL_N8N" != "true" ]] && return 0
  if verify_docker; then
    run_robust_step "n8n" "verify_n8n" "
      mkdir -p $BASE_DIR/n8n-data
      docker rm -f n8n 2>/dev/null || true
      docker run -d --name n8n --restart unless-stopped -p 5678:5678 -v $BASE_DIR/n8n-data:/home/node/.n8n n8nio/n8n
    " "verify_docker"
  else
    log_skip "n8n – wymaga Dockera"
  fi
}

phase_helm() {
  if verify_k3s; then
    run_standalone "Helm" "command -v helm" "curl -fsSL $URL_HELM | bash"
  fi
}

phase_olares() {
  [[ "$INSTALL_OLARES" != "true" ]] && return 0
  run_standalone "Olares" "false" "curl -fsSL $URL_OLARES | bash -"
}

# === Liczenie kroków ===
count_steps() {
  TOTAL_STEPS=0
  TOTAL_STEPS=$((TOTAL_STEPS + 6))   # base: apt_update, upgrade, basics, hostname, timezone, dirs
  [[ "$INSTALL_DOCKER" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$INSTALL_K3S" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 2))
  [[ "$INSTALL_OLLAMA" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$INSTALL_POSTGRES" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$INSTALL_REDIS" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$INSTALL_MINIO" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$INSTALL_WIREGUARD" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$INSTALL_N8N" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$INSTALL_K3S" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))   # helm
  [[ "$INSTALL_OLARES" == "true" ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
}

# === MAIN ===
main() {
  check_root
  mkdir -p /var/log
  touch "$LOG_FILE"

  echo ""
  echo "=============================================="
  echo " setup-olares-robust.sh"
  echo " Weryfikacja -> Instalacja -> Potwierdzenie"
  echo "=============================================="
  echo ""
  count_steps
  echo "  Łącznie etapów: $TOTAL_STEPS"
  echo ""

  phase_base
  phase_docker
  phase_k3s
  phase_ollama
  phase_postgres
  phase_redis
  phase_minio
  phase_wireguard
  phase_n8n
  phase_helm
  phase_olares

  echo ""
  echo "=============================================="
  echo -e " ${GREEN}ZAKOŃCZONO${NC}"
  echo " Log: $LOG_FILE"
  echo "=============================================="
  echo ""
  echo "Uruchom weryfikację: sudo bash scripts/verify-and-start-olares.sh"
  echo ""
}

main "$@"
