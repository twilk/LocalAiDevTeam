# Ewaluacja skryptu setup-olares.sh

Pełna weryfikacja fragmentów względem dokumentacji oraz mitygacje zidentyfikowanych problemów.

---

## 1. Inicjalizacja i baza

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| apt-get update/upgrade | Ubuntu/Debian standard | OK | |
| apt_basics (curl, wget, jq, iproute2, locales) | Wszystkie w main/universe Ubuntu | OK | pciutils dodany dla lspci |
| hostnamectl, timedatectl | systemd, [freedesktop.org](https://www.freedesktop.org/) | OK | |
| locale-gen | locales package, [Ubuntu](https://packages.ubuntu.com/locales) | OK | |
| /etc/os-release | [freedesktop.org](https://www.freedesktop.org/software/systemd/man/os-release.html) | OK | |

---

## 2. Docker

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| curl -fsSL get.docker.com \| sh | [docs.docker.com](https://docs.docker.com/engine/install/ubuntu/) | OK | Identyczne polecenie |
| systemctl enable/start docker | docs.docker.com | OK | |
| Konflikt z K3s | K3s i Docker używają containerd | MITIGOWANE | K3s z INSTALL_K3S_EXEC="--docker" gdy Docker zainstalowany |

---

## 3. K3s

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| curl -sfL get.k3s.io \| sh - | [docs.k3s.io](https://docs.k3s.io/installation), [get.k3s.io](https://get.k3s.io) | OK | |
| KUBECONFIG=/etc/rancher/k3s/k3s.yaml | docs.k3s.io | OK | |
| kubectl get nodes | K3s instaluje kubectl | OK | |
| K3s + Docker | [docs.k3s.io reference](https://docs.k3s.io/reference/env-variables): INSTALL_K3S_EXEC="--docker" | MITIGOWANE | Używany gdy docker_install=1 |

---

## 4. WireGuard

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| apt install wireguard iptables | [wireguard.com](https://wireguard.com/install), [Ubuntu](https://packages.ubuntu.com/wireguard) | OK | |
| wg genkey, wg pubkey | wireguard-tools | OK | |
| PreUp sysctl ip_forward | [Ubuntu WireGuard](https://ubuntu.com/server/docs/using-the-vpn-as-the-default-gateway) | OK | |
| PostUp iptables MASQUERADE | Standardowa konfiguracja WireGuard VPN | OK | |
| sysctl.d duplicate | - | MITIGOWANE | grep -q przed append |

---

## 5. NVIDIA

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| ubuntu-drivers install | ubuntu-drivers-common, [Ubuntu](https://ubuntu.com/server/docs/nvidia-drivers-installation) | OK | |
| lspci \| grep nvidia | [docs.olares.com](https://docs.olares.com), pciutils | OK | pciutils w apt_basics |
| nvidia-driver-535 | Ubuntu repos | OK | Fallback dla Debian |

---

## 6. Ollama

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| curl -fsSL ollama.com/install.sh \| sh | [docs.ollama.com](https://docs.ollama.com/linux), [GitHub](https://github.com/ollama/ollama/blob/main/scripts/install.sh) | OK | Nieinteraktywne z -fsSL |
| systemctl ollama | Instalator tworzy usługę | OK | |

---

## 7. PostgreSQL

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| postgresql postgresql-contrib | [Ubuntu](https://packages.ubuntu.com/postgresql) | OK | |
| systemctl postgresql | Domyślna usługa Ubuntu | OK | |

---

## 8. Redis

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| redis-server | [Ubuntu](https://packages.ubuntu.com/redis-server) | OK | |
| systemctl redis-server | [Redis docs](https://redis.io/docs/latest/operate/oss_and_stack/install/archive/install-redis/install-redis-on-linux/) | OK | |

---

## 9. MinIO

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| URL dl.min.io/.../minio | [dl.min.io](https://dl.min.io/server/minio/release/linux-amd64) | OK | |
| curl -sLO (L=redirect) | curl docs | OK | -L dla przekierowań |
| useradd minio, chown | [MinIO docs](https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-single-node-single-drive.html) | OK | |
| MINIO_ROOT_USER/PASSWORD | [MinIO root credentials](https://docs.min.io/minio/baremetal/reference/minio-server/settings.html#root-credentials) | MITIGOWANE | Ustawiane w systemd, domyślne dla dev |
| CWD przy curl -O | - | MITIGOWANE | cd /tmp przed pobraniem |

---

## 10. n8n

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| docker run n8nio/n8n | [hub.docker.com](https://hub.docker.com/r/n8nio/n8n), [docs.n8n.io](https://docs.n8n.io/hosting/installation/docker) | OK | |
| -p 5678, -v /home/node/.n8n | docs.n8n.io | OK | |
| Idempotencja | - | MITIGOWANE | docker rm -f n8n przed run |
| NodeSource setup_20.x | [NodeSource](https://github.com/nodesource/distributions), Ubuntu 24.04 supported | OK | |
| n8n start & (npm path) | - | OSTRZEŻENIE | Nie przetrwa rebootu; preferowany Docker |

---

## 11. Helm

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| get-helm-3 script | [helm/helm](https://github.com/helm/helm/blob/main/scripts/get-helm-3) | OK | branch main |

---

## 12. Olares

| Fragment | Dokumentacja | Status | Uwagi |
|----------|--------------|--------|-------|
| curl -fsSL olares.sh \| bash - | [docs.olares.com](https://docs.olares.com/manual/get-started/install-linux-script.html) | OK | Identyczne |
| Interaktywność | docs.olares.com: "prompted to enter Olares ID and domain" | OSTRZEŻENIE | Wymaga interakcji; log_warn w skrypcie |

---

## Zastosowane mitygacje

1. **K3s + Docker**: INSTALL_K3S_EXEC="--docker" gdy Docker zainstalowany
2. **MinIO**: cd /tmp przed curl; MINIO_ROOT_USER/PASSWORD w systemd (domyślne minioadmin dla dev)
3. **WireGuard sysctl**: grep -q przed append do 99-wireguard.conf
4. **n8n Docker**: docker rm -f n8n 2>/dev/null przed docker run (idempotencja)
5. **pciutils**: Dodane do apt_basics dla lspci na minimalnym Ubuntu
6. **MinIO curl**: Pełna ścieżka /tmp/minio, curl -fsSL z -L
