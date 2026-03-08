# Instrukcja wykonania kroków manualnych

Kroki oznaczone jako **NO** lub **PARTIAL** w planie nie da się wykonać wyłącznie z konsoli. Poniżej instrukcje krok po kroku.

---

## A2. Sprzęt i przygotowanie fizyczne (NO)

**Uwaga:** Nazwy opcji w BIOS różnią się w zależności od producenta płyty (ASUS, Gigabyte, Dell, MSI itd.); szukaj odpowiedników wymienionych funkcji.

| ID | Krok | Instrukcja |
|----|------|------------|
| HW-001 do HW-010 | Montaż i pierwszy boot | Zmontuj serwer według instrukcji producenta. Podłącz UPS. Wykonaj pierwszy boot. Przed instalacją OS potwierdź specyfikację: CPU, GPU, RAM, SSD/NVMe. |
| HW-011 | Aktualizacja BIOS/UEFI | Pobierz najnowszą stabilną wersję BIOS z witryny producenta płyty (ASUS, Gigabyte, MSI itd.). Zapis na pendrive i uruchom z poziomu BIOS lub z Windows (jeśli dostępny). |
| HW-012 | Restore on AC Power Loss | W BIOS: **Power Management** → **Restore on AC Power Loss** → ustaw **Power On** (serwer ma się włączyć po powrocie zasilania). |
| HW-013 | Wirtualizacja CPU | W BIOS: **CPU Configuration** → **Virtualization Technology** → **Enabled** (Intel VT-x / AMD-V). |
| HW-014 | IOMMU/VT-d/SVM | W BIOS: **Advanced** → **IOMMU** (Intel VT-d) lub **SVM Mode** (AMD) → **Enabled**. |
| HW-015 | Kolejność bootowania | W BIOS: **Boot** → **Boot Option #1** = dysk z Ubuntu/Olares. |

---

## A4. Instalacja systemów operacyjnych (PARTIAL)

| ID | Krok | Instrukcja |
|----|------|------------|
| OS-001 | Nośnik Olares/Ubuntu | Pobierz Ubuntu 24.04 LTS ze strony [releases.ubuntu.com/24.04](https://releases.ubuntu.com/24.04/) – wybierz aktualną wersję ISO (np. `ubuntu-24.04.4-live-server-amd64.iso`). Olares ISO: `https://github.com/beclab/Olares/releases`. Zapis na pendrive: Balena Etcher lub `dd if=ubuntu.iso of=/dev/sdX bs=4M status=progress` (zamień sdX na właściwe urządzenie). |
| OS-002 | Nośnik Windows | Pobierz Media Creation Tool z microsoft.com i utwórz nośnik instalacyjny Windows. |
| OS-003 | Instalacja Olares/Ubuntu | Boot z pendrive → instalator Ubuntu. Wybierz partycję Olares (1 TB). Zaznacz OpenSSH server, jeśli dostępne. Ustaw hasło root/admin. |
| OS-004 | Weryfikacja bootu Olares | Po instalacji: reboot. Sprawdź, czy system uruchamia się poprawnie. |
| OS-005 | Instalacja Windows | Boot z pendrive Windows → zainstaluj na partycji Windows (400 GB). Nie formatuj partycji Olares. |
| OS-006 | Weryfikacja bootu Windows | Reboot. Sprawdź, czy Windows uruchamia się. |
| OS-012, OS-013 | Test bootloadera | Ręcznie przetestuj boot Olares i Windows z GRUB. Upewnij się, że można wybrać oba systemy. |

---

## A6. Sieć (PARTIAL)

| ID | Krok | Instrukcja |
|----|------|------------|
| NET-001 | Decyzja o adresacji | Zdecyduj: **statyczny IP** (np. 192.168.1.100) czy **rezerwacja DHCP** w routerze. Zanotuj: IP, gateway (np. 192.168.1.1), DNS (np. 8.8.8.8). Te wartości będą potrzebne w skrypcie `config.env`. |

---

## Olares – aktywacja (jeśli używasz Olares)

| Krok | Instrukcja |
|------|------------|
| Aktywacja | Po wykonaniu `curl -fsSL https://olares.sh | bash -` skrypt poprosi o: (1) Olares ID (prefix, np. alice123), (2) domenę. Na końcu wyświetli **Wizard URL** i **hasło jednorazowe**. Otwórz Wizard URL w przeglądarce, wprowadź hasło, zeskanuj QR kod w aplikacji LarePass. Telefon i serwer muszą być w tej samej sieci. |

---

## FIN. Walidacja końcowa (PARTIAL)

| ID | Krok | Instrukcja |
|----|------|------------|
| FIN-001 | Pełny boot | Ręcznie: wyłącz serwer, włącz. Sprawdź pełny boot flow od zimnego startu. |
| FIN-002 | Powrót zasilania | Symuluj przerwę zasilania (odłącz zasilacz, odczekaj, podłącz). Serwer powinien się sam włączyć (HW-012). |
| FIN-004 | Wybór Windows | Przy starcie wybierz Windows z menu GRUB. Sprawdź, czy boot działa. |

---

## Uwagi

- Pełna weryfikacja pokrycia planu w dokumentacji: [VERIFIKACJA_POKRYCIA.md](VERIFIKACJA_POKRYCIA.md).
- Kroki **YES** są wykonywane przez skrypt `scripts/setup-olares.sh`.
- Po instalacji: `sudo bash scripts/verify-and-start-olares.sh` – weryfikacja, uruchomienie i podsumowanie serwisów.
- Dostęp sieciowy (IP:port, docker bez sudo): `sudo bash scripts/apply-network-access.sh` – raz po instalacji.
- Przed uruchomieniem skryptu upewnij się, że wykonano wszystkie kroki manualne z sekcji A2, A4 (instalacja OS) i A6 (decyzja sieciowa).
- Skrypt nie wykonuje partycjonowania dysku – zakłada, że partycje są już utworzone.
