#!/usr/bin/env bash
#
# setup-olares-ultimate.sh – Holistyczny workflow z pełną informacją na każdym etapie.
# Weryfikacja → Instalacja → Potwierdzenie. Komunikaty na absolutnie każdym kroku.
#
# Uruchom: sudo bash setup-olares-ultimate.sh
# Konfiguracja: config.env (source przed uruchomieniem)
#
set -uo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/config.env" ]] && source "$SCRIPT_DIR/config.env"

# === Konfiguracja ===
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

LOG_FILE="/var/log/setup-olares-ultimate-$(date +%Y%m%d-%H%M%S).log"
CURRENT_STEP=0
TOTAL_STEPS=0
PHASE_START_TIME=0

# Kolory
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# === Logowanie ===
log()        { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
log_ok()     { echo -e "[$(date '+%H:%M:%S')] ${GREEN}✓${NC} $*" | tee -a "$LOG_FILE"; }
log_fail()   { echo -e "[$(date '+%H:%M:%S')] ${RED}✗${NC} $*" | tee -a "$LOG_FILE"; }
log_skip()   { echo -e "[$(date '+%H:%M:%S')] ${YELLOW}○${NC} $*" | tee -a "$LOG_FILE"; }
log_info()   { echo -e "[$(date '+%H:%M:%S')] ${CYAN}ℹ${NC} $*" | tee -a "$LOG_FILE"; }
log_step()   { echo -e "  ${DIM}→${NC} $*" | tee -a "$LOG_FILE"; }

# === Komunikaty dla użytkownika ===
say()        { echo -e "$*"; echo "$*" >> "$LOG_FILE"; }
say_section() { echo ""; echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"; echo -e "${BOLD}  $*${NC}"; echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"; echo ""; }
say_phase()  { echo ""; echo -e "${CYAN}┌─ FAZA: $*${NC}"; echo -e "${CYAN}└─${NC}"; }
say_step()   { echo -e "  ${BOLD}[$CURRENT_STEP/$TOTAL_STEPS]${NC} $*"; }
say_doing()  { echo -e "     ${DIM}Czynność: $*${NC}"; }
say_done()   { echo -e "     ${GREEN}Wynik: $*${NC}"; }
say_fail()   { echo -e "     ${RED}Wynik: $*${NC}"; }
say_skip()   { echo -e "     ${YELLOW}Wynik: $*${NC}"; }

# Pasek postępu
progress_bar() {
  local cur=$1 tot=$2
  local pct=0; [[ $tot -gt 0 ]] && pct=$((cur * 100 / tot))
  local width=40
  local filled=$((width * cur / (tot || 1)))
  local empty=$((width - filled))
  printf "\r     ${DIM}["
  printf "%${filled}s" | tr ' ' '█'
  printf "%${empty}s" | tr ' ' '░'
  printf "] %3d%%${NC}  " "$pct"
}

spinner_pid=""
spinner_start() {
  ( while true; do for c in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do printf "\r     ${CYAN}%s${NC} %s  " "$c" "$1"; sleep 0.08; done; done ) &
  spinner_pid=$!
}
spinner_stop() { [[ -n "$spinner_pid" ]] && kill "$spinner_pid" 2>/dev/null; spinner_pid=""; printf "\r%-60s\r" " "; }

# === Weryfikatory ===
verify_apt_basics()    { command -v curl &>/dev/null && command -v jq &>/dev/null; }
verify_docker()        { command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; }
verify_k3s()           { [[ -f /etc/rancher/k3s/k3s.yaml ]] && systemctl is-active --quiet k3s 2>/dev/null; }
verify_ollama()        { command -v ollama &>/dev/null && systemctl is-active --quiet ollama 2>/dev/null; }
verify_postgres()      { systemctl is-active --quiet postgresql 2>/dev/null || systemctl is-active --quiet postgresql@* 2>/dev/null; }
verify_redis()         { systemctl is-active --quiet redis-server 2>/dev/null; }
verify_minio_binary()  { [[ -x /usr/local/bin/minio ]]; }
verify_minio()         { verify_minio_binary && systemctl is-active --quiet minio 2>/dev/null; }
verify_n8n()           { docker ps 2>/dev/null | grep -q n8n; }
verify_wireguard()     { [[ -f /etc/wireguard/${WG_INTERFACE}.conf ]] && ip link show "$WG_INTERFACE" &>/dev/null; }
verify_nvidia()        { command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; }
verify_always_run()    { return 1; }  # nigdy nie pomijaj – zawsze wykonuj

# === Pre-flight ===
preflight() {
  say_section "ANALIZA SYSTEMU (pre-flight)"
  say "  Sprawdzanie wymagań przed instalacją..."
  echo ""

  log_step "Weryfikacja uprawnień root..."
  if [[ $EUID -ne 0 ]]; then
    say_fail "Brak uprawnień root. Uruchom: sudo bash $0"
    exit 1
  fi
  say_done "root OK"

  log_step "Sprawdzanie wolnego miejsca na dysku..."
  local free_gb=$(df -BG / 2>/dev/null | tail -1 | awk '{gsub(/G/,""); print $4}')
  if [[ -n "$free_gb" && "$free_gb" -lt 10 ]]; then
    say_fail "Mało miejsca: ${free_gb}GB. Zalecane min. 10GB na /"
  else
    say_done "Wolne miejsce: ~${free_gb:-?}GB"
  fi

  log_step "Sprawdzanie sieci (ping 8.8.8.8)..."
  if ping -c1 -W2 8.8.8.8 &>/dev/null; then
    say_done "Sieć OK"
  else
    say_skip "Brak połączenia – instalacja może się nie powieść"
  fi

  log_step "Wykrywanie systemu..."
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    say_done "$PRETTY_NAME"
  else
    say_done "nieznany"
  fi

  log_step "Interfejs sieciowy (WireGuard)..."
  say_done "${WG_EXT_IF}"

  echo ""
}

# === Główna funkcja kroku – pełna informacja ===
run_ultimate_step() {
  local name="$1" verifier="$2" install_cmd="$3" desc="$4"
  shift 4
  local deps=("$@")

  for d in "${deps[@]}"; do
    if ! "$d"; then
      say_step "$name"
      say_doing "Wymagana zależność nie spełniona"
      say_skip "Pominięto (brak: $d)"
      return 1
    fi
  done

  CURRENT_STEP=$((CURRENT_STEP + 1))
  progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
  say_step "$name"
  say_doing "$desc"

  if $verifier; then
    say_done "Już zainstalowane i działa – pomijam"
    return 0
  fi

  say_doing "Instalacja w toku..."
  spinner_start "pobieranie / konfiguracja"
  if eval "$install_cmd" >> "$LOG_FILE" 2>&1; then
    spinner_stop
    if $verifier; then
      say_done "Zainstalowano i zweryfikowano pomyślnie"
      return 0
    else
      say_fail "Instalacja OK, ale weryfikacja nie przeszła"
      return 1
    fi
  else
    spinner_stop
    say_fail "Błąd instalacji – sprawdź log: $LOG_FILE"
    return 1
  fi
}

run_ultimate_standalone() {
  local name="$1" verifier="$2" install_cmd="$3" desc="$4"
  CURRENT_STEP=$((CURRENT_STEP + 1))
  progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
  say_step "$name"
  say_doing "$desc"

  if $verifier; then
    say_done "Już OK – pomijam"
    return 0
  fi

  spinner_start "wykonywanie"
  if eval "$install_cmd" >> "$LOG_FILE" 2>&1; then
    spinner_stop
    if $verifier; then
      say_done "Wykonano pomyślnie"
      return 0
    else
      spinner_stop
      say_fail "Weryfikacja nie przeszła"
      return 1
    fi
  else
    spinner_stop
    say_fail "Błąd"
    return 1
  fi
}

# === Liczenie kroków ===
count_steps() {
  TOTAL_STEPS=6
  [[ "$INSTALL_DOCKER" == "true" ]] && ((TOTAL_STEPS++))
  [[ "$INSTALL_K3S" == "true" ]] && ((TOTAL_STEPS+=2))
  [[ "$INSTALL_OLLAMA" == "true" ]] && ((TOTAL_STEPS++))
  [[ "$INSTALL_POSTGRES" == "true" ]] && ((TOTAL_STEPS++))
  [[ "$INSTALL_REDIS" == "true" ]] && ((TOTAL_STEPS++))
  [[ "$INSTALL_MINIO" == "true" ]] && ((TOTAL_STEPS++))
  [[ "$INSTALL_WIREGUARD" == "true" ]] && ((TOTAL_STEPS++))
  [[ "$INSTALL_N8N" == "true" ]] && ((TOTAL_STEPS++))
  [[ "$INSTALL_K3S" == "true" ]] && ((TOTAL_STEPS++))
  if [[ "$INSTALL_NVIDIA" == "true" ]]; then ((TOTAL_STEPS++)); fi
  if [[ "$INSTALL_NVIDIA" == "auto" ]] && lspci 2>/dev/null | grep -qi nvidia; then ((TOTAL_STEPS++)); fi
  [[ "$INSTALL_OLARES" == "true" ]] && ((TOTAL_STEPS++))
  ((TOTAL_STEPS++))  # phase_network_access
}

# === FAZY ===
phase_base() {
  say_phase "Baza systemowa"
  say "  Aktualizacja APT, pakiety podstawowe, hostname, strefa czasowa, katalogi."
  echo ""
  run_ultimate_standalone "apt update" "verify_always_run" "apt-get update -qq" "Aktualizacja indeksu pakietów"
  run_ultimate_standalone "apt upgrade" "verify_always_run" "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq" "Aktualizacja pakietów systemowych"
  run_ultimate_step "apt basics" "verify_apt_basics" "apt-get install -y -qq curl wget gnupg2 ca-certificates lsb-release apt-transport-https software-properties-common jq iproute2 locales pciutils iptables" "curl, jq, ip, iptables, locales"
  run_ultimate_standalone "hostname" "verify_always_run" "hostnamectl set-hostname $HOSTNAME" "Ustawienie hostname: $HOSTNAME"
  run_ultimate_standalone "timezone" "verify_always_run" "timedatectl set-timezone $TIMEZONE" "Strefa czasowa: $TIMEZONE"
  run_ultimate_standalone "katalogi" "verify_always_run" "mkdir -p $BASE_DIR/{logs,models,backups} && chmod 755 $BASE_DIR" "Katalog bazowy: $BASE_DIR"
}

phase_docker() {
  [[ "$INSTALL_DOCKER" != "true" ]] && return 0
  say_phase "Docker"
  say "  Silnik kontenerów – wymagany m.in. dla n8n."
  echo ""
  run_ultimate_step "Docker" "verify_docker" "
    curl -fsSL $URL_DOCKER | sh &&
    systemctl enable docker && systemctl start docker &&
    [[ -n \"\${SUDO_USER:-}\" ]] && usermod -aG docker \"\$SUDO_USER\" && echo \"Użytkownik \$SUDO_USER dodany do grupy docker (newgrp docker lub re-login)\"
  " "Instalacja ze skryptu oficjalnego, włączenie usługi, dodanie użytkownika do grupy docker" "verify_apt_basics"
}

phase_k3s() {
  [[ "$INSTALL_K3S" != "true" ]] && return 0
  say_phase "K3s (Kubernetes)"
  say "  Lekki Kubernetes – orkiestracja kontenerów."
  echo ""
  local k3s_cmd='curl -sfL '"$URL_K3S"' | sh -'
  verify_docker && k3s_cmd='INSTALL_K3S_EXEC="--docker" '"$k3s_cmd"
  run_ultimate_step "K3s" "verify_k3s" "$k3s_cmd" "Pobranie i instalacja K3s" "verify_apt_basics"
  run_ultimate_standalone "K3s node" "verify_k3s" "sleep 15 && export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl get nodes 2>/dev/null || true" "Czekam na gotowość węzła"
}

phase_nvidia() {
  if [[ "$INSTALL_NVIDIA" == "no" ]]; then return 0; fi
  if [[ "$INSTALL_NVIDIA" == "auto" ]] && ! lspci 2>/dev/null | grep -qi nvidia; then
    return 0
  fi
  say_phase "NVIDIA (sterowniki GPU)"
  say "  ubuntu-drivers lub nvidia-driver-535 – wymagane dla CUDA/Ollama na GPU."
  echo ""
  run_ultimate_step "NVIDIA" "verify_nvidia" "
    apt-get install -y -qq ubuntu-drivers-common 2>/dev/null || true
    if command -v ubuntu-drivers >/dev/null 2>&1; then
      ubuntu-drivers install --no-interactive 2>/dev/null || apt-get install -y nvidia-driver-535
    else
      apt-get install -y -qq nvidia-driver-535 2>/dev/null || apt-get install -y -qq nvidia-driver
    fi
  " "ubuntu-drivers lub nvidia-driver-535" "verify_apt_basics"
}

phase_ollama() {
  [[ "$INSTALL_OLLAMA" != "true" ]] && return 0
  say_phase "Ollama"
  say "  Lokalne modele LLM – API na porcie 11434, nasłuch 0.0.0.0."
  echo ""
  run_ultimate_step "Ollama" "verify_ollama" "
    curl -fsSL $URL_OLLAMA | sh &&
    mkdir -p /etc/systemd/system/ollama.service.d &&
    echo '[Service]
Environment=OLLAMA_HOST=0.0.0.0' > /etc/systemd/system/ollama.service.d/override.conf &&
    systemctl daemon-reload && systemctl enable ollama 2>/dev/null && systemctl start ollama 2>/dev/null
  " "Instalacja + konfiguracja nasłuchu na wszystkich interfejsach" "verify_apt_basics"
}

phase_postgres() {
  [[ "$INSTALL_POSTGRES" != "true" ]] && return 0
  say_phase "PostgreSQL"
  say "  Baza danych SQL – port 5432."
  echo ""
  run_ultimate_step "PostgreSQL" "verify_postgres" "apt-get install -y -qq postgresql postgresql-contrib && systemctl enable postgresql && systemctl start postgresql" "Pakiet APT + usługa systemd" "verify_apt_basics"
}

phase_redis() {
  [[ "$INSTALL_REDIS" != "true" ]] && return 0
  say_phase "Redis"
  say "  Magazyn klucz–wartość, kolejki – port 6379."
  echo ""
  run_ultimate_step "Redis" "verify_redis" "apt-get install -y -qq redis-server && systemctl enable redis-server && systemctl start redis-server" "Pakiet APT + usługa systemd" "verify_apt_basics"
}

phase_minio() {
  [[ "$INSTALL_MINIO" != "true" ]] && return 0
  say_phase "MinIO"
  say "  Obiektowe magazyny S3 – API 9000, konsola 9001."
  echo ""
  run_ultimate_step "MinIO" "verify_minio" "
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
  " "Binarka, użytkownik minio, usługa systemd" "verify_apt_basics"
}

phase_wireguard() {
  [[ "$INSTALL_WIREGUARD" != "true" ]] && return 0
  say_phase "WireGuard"
  say "  VPN – klucze w /etc/wireguard, port $WG_PORT. Dodaj [Peer] ręcznie."
  echo ""
  run_ultimate_step "WireGuard" "verify_wireguard" "
    apt-get install -y -qq wireguard iptables &&
    mkdir -p /etc/wireguard &&
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key &&
    chmod 600 /etc/wireguard/server_private.key &&
    PRIV=\$(cat /etc/wireguard/server_private.key) &&
    grep -q 'net.ipv4.ip_forward' /etc/sysctl.d/99-wireguard.conf 2>/dev/null || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-wireguard.conf &&
    cat > /etc/wireguard/${WG_INTERFACE}.conf << WGF
[Interface]
PrivateKey = \$PRIV
Address = ${WG_NETWORK}.1/${WG_CIDR}
ListenPort = ${WG_PORT}
PreUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${WG_EXT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${WG_INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${WG_EXT_IF} -j MASQUERADE
WGF
  " "Pakiety, generowanie kluczy, plik konfiguracyjny" "verify_apt_basics"
}

phase_n8n() {
  [[ "$INSTALL_N8N" != "true" ]] && return 0
  say_phase "n8n"
  say "  Automatyzacja workflow – kontener Docker, port 5678."
  echo ""
  if verify_docker; then
    run_ultimate_step "n8n" "verify_n8n" "
      mkdir -p $BASE_DIR/n8n-data &&
      chown -R 1000:1000 $BASE_DIR/n8n-data 2>/dev/null || true &&
      docker rm -f n8n 2>/dev/null || true &&
      docker run -d --name n8n --restart unless-stopped -p 0.0.0.0:5678:5678 -v $BASE_DIR/n8n-data:/home/node/.n8n n8nio/n8n
    " "Kontener Docker z wolumenem danych (chown 1000:1000, bind 0.0.0.0)" "verify_docker"
  else
    say_step "n8n"; say_skip "Pominięto – wymaga Dockera"
  fi
}

phase_helm() {
  if ! verify_k3s; then return 0; fi
  say_phase "Helm"
  say "  Menedżer chartów Kubernetes."
  echo ""
  run_ultimate_standalone "Helm" "command -v helm" "curl -fsSL $URL_HELM | bash" "Pobranie i instalacja Helm 3"
}

phase_olares() {
  [[ "$INSTALL_OLARES" != "true" ]] && return 0
  say_phase "Olares"
  say "  Platforma Olares – wymaga ręcznej aktywacji (Wizard URL)."
  echo ""
  run_ultimate_standalone "Olares" "false" "curl -fsSL $URL_OLARES | bash -" "Uruchomienie instalatora Olares"
}

phase_network_access() {
  say_phase "Dostęp sieciowy (IP:port, bez sudo dla docker)"
  say "  UFW, PostgreSQL listen_addresses, Redis bind – usługi dostępne z sieci."
  echo ""
  run_ultimate_standalone "UFW + bind" "verify_always_run" "
    command -v ufw >/dev/null 2>&1 && {
      ufw allow 5678/tcp 2>/dev/null || true
      ufw allow 9000/tcp 2>/dev/null || true
      ufw allow 9001/tcp 2>/dev/null || true
      ufw allow 11434/tcp 2>/dev/null || true
      ufw allow 5432/tcp 2>/dev/null || true
      ufw allow 6379/tcp 2>/dev/null || true
      ufw --force enable 2>/dev/null || true
      ufw reload 2>/dev/null || true
    }
    for f in /etc/postgresql/*/main/postgresql.conf; do
      [[ -f \"\$f\" ]] && grep -q \"listen_addresses\" \"\$f\" && sed -i \"s/^#*listen_addresses.*/listen_addresses = '*'/\" \"\$f\" && systemctl restart postgresql 2>/dev/null || true
    done
    for f in /etc/postgresql/*/main/pg_hba.conf; do
      [[ -f \"\$f\" ]] || continue
      grep -q \"0.0.0.0/0\" \"\$f\" || echo \"host all all 0.0.0.0/0 scram-sha-256\" >> \"\$f\"
    done 2>/dev/null || true
    systemctl restart postgresql 2>/dev/null || true
    [[ -f /etc/redis/redis.conf ]] && sed -i 's/^bind 127.0.0.1.*/bind 0.0.0.0/' /etc/redis/redis.conf 2>/dev/null || true
    systemctl restart redis-server 2>/dev/null || true
  " "UFW allow porty, PostgreSQL listen_addresses='*', Redis bind 0.0.0.0"
}

# === Raport końcowy ===
print_final_report() {
  local HOST_IP=$(hostname -I | awk '{print $1}')
  say_section "RAPORT KOŃCOWY"
  echo ""
  say "  ${BOLD}Log:${NC} $LOG_FILE"
  say ""
  say "  ${BOLD}Adresy usług (HOST: ${HOST_IP}):${NC}"
  say "  ─────────────────────────────────────────────────────────"
  say "  n8n:          http://${HOST_IP}:5678"
  say "  MinIO API:    http://${HOST_IP}:9000"
  say "  MinIO Console: http://${HOST_IP}:9001  (minioadmin/minioadmin)"
  say "  Ollama:       http://${HOST_IP}:11434"
  say "  PostgreSQL:   ${HOST_IP}:5432  (klient psql)"
  say "  Redis:        ${HOST_IP}:6379  (klient redis-cli)"
  say "  K3s:          KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
  say "  ─────────────────────────────────────────────────────────"
  say ""
  say "  ${BOLD}Następne kroki:${NC}"
  say "  1. Wyloguj i zaloguj ponownie (lub: newgrp docker) – docker bez sudo"
  say "  2. Weryfikacja: sudo bash scripts/verify-and-start-olares.sh"
  say "  3. WireGuard: edytuj /etc/wireguard/${WG_INTERFACE}.conf i dodaj [Peer]"
  say "  4. Olares: jeśli INSTALL_OLARES=true, dokończ aktywację w Wizard"
  say ""
  say_section "KONIEC"
  echo ""
}

# === MAIN ===
main() {
  mkdir -p /var/log
  touch "$LOG_FILE"

  say_section "setup-olares-ultimate.sh"
  say "  Holistyczny workflow instalacji środowiska AI Dev Team."
  say "  Weryfikacja przed każdym krokiem – instalacja tylko gdy brak."
  say ""
  say "  ${BOLD}Konfiguracja:${NC}"
  say "  HOSTNAME=$HOSTNAME  BASE_DIR=$BASE_DIR  TIMEZONE=$TIMEZONE"
  say "  Docker=$INSTALL_DOCKER  K3s=$INSTALL_K3S  NVIDIA=$INSTALL_NVIDIA  Ollama=$INSTALL_OLLAMA"
  say "  Postgres=$INSTALL_POSTGRES  Redis=$INSTALL_REDIS  MinIO=$INSTALL_MINIO"
  say "  n8n=$INSTALL_N8N  WireGuard=$INSTALL_WIREGUARD  Olares=$INSTALL_OLARES"
  say ""

  preflight
  count_steps

  say_phase "Rozpoczęcie instalacji"
  say "  Łącznie etapów: $TOTAL_STEPS"
  echo ""

  phase_base
  phase_docker
  phase_k3s
  phase_nvidia
  phase_ollama
  phase_postgres
  phase_redis
  phase_minio
  phase_wireguard
  phase_n8n
  phase_helm
  phase_olares
  phase_network_access

  printf "\r%-60s\r" " "
  print_final_report
}

main "$@"
