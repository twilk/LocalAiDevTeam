# Weryfikacja pokrycia planu w dokumentacji i realiach

## Zakres

Weryfikacja: czy wszystkie elementy planu (URL, polecenia, wymagania) mają potwierdzenie w oficjalnej dokumentacji i działających instalacjach.

## Zgodność z Ubuntu

Olares działa na Ubuntu (docs.olares.com). Skrypt `setup-olares.sh` używa wyłącznie komend dostępnych na Ubuntu 22.04/24.04:

| Komenda/Narzędzie | Źródło na Ubuntu | Uwagi |
|-------------------|------------------|-------|
| apt-get, apt | Bazowe | |
| systemctl, hostnamectl, timedatectl | systemd | |
| ip | iproute2 (apt_basics) | |
| locale-gen, update-locale | locales (apt_basics) | |
| wg, wg genkey | wireguard (apt) | |
| iptables | iptables (kernela) | |
| curl, wget | apt_basics | |
| lspci | pciutils | Zazwyczaj preinstalowane |
| ubuntu-drivers | ubuntu-drivers-common | Tylko Ubuntu |
| docker, kubectl | Instalatory curl | |
| node, npm | NodeSource lub Ubuntu repos | Fallback gdy NodeSource nie wspiera wersji |

---

## 1. Olares

| Element        | Plan                                         | Dokumentacja                                                                                                  | Status |
| -------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------ |
| URL instalacji | `curl -fsSL https://olares.sh | bash -`      | [docs.olares.com](https://docs.olares.com/manual/get-started/install-linux-script.html): identyczne polecenie | OK     |
| Wymagania      | Ubuntu 22.04-25.04, Debian 12/13, 150 GB SSD | docs.olares.com: "Debian 12 or 13", "Ubuntu 22.04-25.04 LTS", "At least 150 GB of available SSD storage"     | OK     |
| Aktywacja      | Wizard URL, LarePass, QR                     | docs.olares.com: "Activate Olares using LarePass app", "Scan QR code"                                         | OK     |

---

## 2. Docker

| Element   | Plan                                     | Dokumentacja                                                                                                                                                                                                                                                              | Status                 |
| --------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| URL       | `curl -fsSL https://get.docker.com | sh` | [docs.docker.com](https://docs.docker.com/engine/install/ubuntu/): "Docker provides a convenience script at https://get.docker.com/", "curl -fsSL https://get.docker.com -o get-docker.sh" + "sudo sh get-docker.sh" | OK (pipe = równoważne) |
| Wymagania | Ubuntu 22.04/24.04                       | docs.docker.com: "Ubuntu Jammy 22.04 (LTS)", "Ubuntu Noble 24.04 (LTS)"                                                                                                                                     | OK                     |

---

## 3. K3s

| Element    | Plan                                  | Dokumentacja                                                                                                                           | Status |
| ---------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| URL        | `curl -sfL https://get.k3s.io | sh -` | [get.k3s.io](https://get.k3s.io/), [docs.k3s.io](https://docs.k3s.io/quick-start): "curl -sfL https://get.k3s.io | sh -"  | OK     |
| kubeconfig | `/etc/rancher/k3s/k3s.yaml`           | docs.k3s.io: "Kubeconfig is written to /etc/rancher/k3s/k3s.yaml"                                                                      | OK     |

---

## 4. Ollama

| Element | Plan                                            | Dokumentacja                                                                                                                                    | Status |
| ------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| URL     | `curl -fsSL https://ollama.com/install.sh | sh` | [docs.ollama.com](https://docs.ollama.com/linux), [GitHub](https://github.com/ollama/ollama/blob/main/scripts/install.sh): identyczne polecenie | OK     |
| API     | localhost:11434                                 | docs.ollama.com: "Makes the Ollama API available at 127.0.0.1:11434"                                                                            | OK     |

---

## 5. MinIO

| Element | Plan                                                       | Dokumentacja                                                                                             | Status                                                                |
| ------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| URL     | `https://dl.min.io/server/minio/release/linux-amd64/minio` | [dl.min.io](https://dl.min.io/server/minio/release/linux-amd64): binary dostępny, struktura URL poprawna | OK                                                                    |
| Uwaga   | Pobieranie binary bez wersji                               | Dokumentacja MinIO rekomenduje DEB/RPM dla produkcji; binary działa                                      | Częściowo (zalecana aktualizacja do wersjonowanego URL w przyszłości) |

---

## 6. WireGuard

| Element    | Plan                    | Dokumentacja                                                                                                                               | Status |
| ---------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| Instalacja | `apt install wireguard` | [wireguard.com/install](https://wireguard.com/install), [wiki.debian.org](https://wiki.debian.org/WireGuard): "sudo apt install wireguard" | OK     |

---

## 7. n8n

| Element | Plan                              | Dokumentacja                                                                                                                          | Status |
| ------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Obraz   | `n8nio/n8n`                       | [hub.docker.com](https://hub.docker.com/r/n8nio/n8n), [docs.n8n.io](https://docs.n8n.io/hosting/installation/docker): oficjalny obraz | OK     |
| Port    | 5678                              | docs.n8n.io: "Access n8n at http://localhost:5678"                                                                                    | OK     |
| Volume  | `/home/node/.n8n`                 | docs.n8n.io: "Volume mount at /home/node/.n8n"                                                                                        | OK     |
| Uwaga   | Możliwy `docker.n8n.io/n8nio/n8n` | n8n używa też własnego registry; Docker Hub nadal poprawny                                                                            | OK     |

---

## 8. Helm

| Element | Plan                                                                              | Dokumentacja                                                                                                   | Status                      |
| ------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------- |
| URL     | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash` | [helm/helm](https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3): skrypt w repo, branch `main` | OK                          |
| Uwaga   | Część dokumentacji używa `master`                                                 | Obecnie domyślny branch to `main`                                                                              | OK (użycie `main` poprawne) |

---

## 9. PostgreSQL, Redis

| Element    | Plan                                        | Dokumentacja                      | Status |
| ---------- | ------------------------------------------- | --------------------------------- | ------ |
| PostgreSQL | `apt install postgresql postgresql-contrib` | Standardowe pakiety Ubuntu/Debian | OK     |
| Redis      | `apt install redis-server`                  | Standardowe pakiety Ubuntu/Debian | OK     |

---

## 10. NVIDIA

| Element       | Plan                                           | Dokumentacja                                                                                         | Status |
| ------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ------ |
| Instalacja    | `ubuntu-drivers install` / `nvidia-driver-535` | Narzędzie `ubuntu-drivers` w pakiecie `ubuntu-drivers-common`                                        | OK     |
| Wymagania GPU | Turing+ (GTX 16, RTX 20+)                      | docs.olares.com, [NVIDIA open-gpu-kernel-modules](https://github.com/NVIDIA/open-gpu-kernel-modules) | OK     |

---

## 11. Ubuntu ISO (INSTRUKCJA_MANUALNA)

| Element       | Plan                                                                     | Dokumentacja                                                                                | Status                                                   |
| ------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| URL           | `https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso` | [releases.ubuntu.com/24.04](https://releases.ubuntu.com/24.04/): dostępne są wersje 24.04.x | Rozbieżność wersji                                       |
| Obecna wersja | -                                                                        | `ubuntu-24.04.4-live-server-amd64.iso` (2025)                                               | Zalecenie: użyć generycznego linku lub najnowszej wersji |

---

## 12. BIOS/UEFI (INSTRUKCJA_MANUALNA)

| Element                  | Plan              | Uwagi                                                                                                        | Status                                           |
| ------------------------ | ----------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| Restore on AC Power Loss | Power Management  | Nazwa opcji różni się w BIOS (ASUS: "Restore AC Power Loss", Gigabyte: "AC Back", Dell: "AC Power Recovery") | Ogólna koncepcja OK; nazwy zależne od producenta |
| VT-x/AMD-V               | CPU Configuration | Standardowe nazwy w większości płyt                                                                          | OK                                               |
| IOMMU/VT-d/SVM           | Advanced          | Intel: VT-d, AMD: SVM Mode                                                                                   | OK                                               |

---

## 13. Propozycje ulepszeń (sekcja F – planowana)

| Propozycja                  | Pokrycie w realiach                                                                | Uwagi                               |
| --------------------------- | ---------------------------------------------------------------------------------- | ----------------------------------- |
| Dry-run / resume            | Docker ma `--dry-run`; K3s nie oferuje natywnie – wymaga własnej implementacji     | Częściowe                           |
| Healthcheck                 | `curl`, `redis-cli ping`, `systemctl is-active` – standardowe narzędzia            | OK                                  |
| SHA256 dla instalatorów     | Olares, Ollama, MinIO – dokumentacja nie podaje checksumów; Docker, Helm – możliwe | Częściowe (wymaga utrzymania listy) |
| UFW/firewall                | `ufw` domyślnie w Ubuntu                                                           | OK                                  |
| Idempotencja                | `docker start` vs `docker run` – sprawdzone wzorce                                  | OK                                  |
| Pre-flight (150GB, 8GB RAM) | Zgodne z docs.olares.com                                                           | OK                                  |
| Retry z backoff             | Brak oficjalnych wymagań; dobra praktyka                                           | OK                                  |
| Lock plikowy                | `flock` w util-linux                                                               | OK                                  |
| Structured logging (JSON)   | Własna implementacja                                                               | OK                                  |
| Smoke test                  | Zestaw curl/systemctl/redis-cli                                                    | OK                                  |

---

## Podsumowanie

- Większość elementów planu ma pokrycie w dokumentacji i realiach.
- Drobne rozbieżności:
  1. **Ubuntu ISO** – w planie `ubuntu-24.04.1`; aktualna to `ubuntu-24.04.4`. Zalecenie: odwołanie do `releases.ubuntu.com/24.04/` lub dynamiczne pobranie najnowszej wersji.
  2. **MinIO** – binary bez wersji; dla produkcji dokumentacja zaleca pakiety DEB/RPM z wersją.
  3. **BIOS** – nazwy opcji zależą od producenta; instrukcja powinna to uwzględniać.
- Propozycje ulepszeń: większość oparta na standardowych narzędziach i dobrych praktykach; część (np. checksumy) wymaga własnej definicji i utrzymania.
