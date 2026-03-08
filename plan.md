Jasne. Jedziemy nie w "ładną checklistę", tylko w **prawdziwy plan egzekucyjny**, taki, który da się zamienić na backlog dla agentów, pipeline i kontrolę pokrycia wymagań bez zgadywania. Zero mgły, zero kadzidełka.

Poniżej masz:

1. **atomową listę tasków**
2. **status CLI dla każdego taska**
3. **mapę 100% pokrycia wymagań** - zarówno z PRD, jak i z Twojego rozszerzenia o autonomiczny AI development team

Legenda CLI:

* **YES** - możliwe do wykonania w pełni przez commandline
* **PARTIAL** - część przez CLI, ale występuje element fizyczny, GUI albo decyzja wizualna
* **NO** - nie da się sensownie wykonać wyłącznie przez CLI

---

# A. Atomowy backlog wdrożeniowy

## A1. Governance, scope, źródła prawdy

| ID      | Task                                                                                                   | CLI |
| ------- | ------------------------------------------------------------------------------------------------------ | --- |
| GOV-001 | utworzyć katalog główny projektu i strukturę repozytoriów                                              | YES |
| GOV-002 | utworzyć repo `infra` dla infrastruktury i hosta                                                       | YES |
| GOV-003 | utworzyć repo `platform` dla orkiestracji agentów i runtime                                            | YES |
| GOV-004 | utworzyć repo `apps` dla usług produktowych                                                            | YES |
| GOV-005 | utworzyć repo `docs` dla dokumentacji i ADR                                                            | YES |
| GOV-006 | umieścić oryginalny PRD w repo jako plik nieedytowalnego źródła prawdy                                 | YES |
| GOV-007 | nadać PRD wersję i checksum                                                                            | YES |
| GOV-008 | stworzyć folder `requirements/traceability`                                                            | YES |
| GOV-009 | stworzyć folder `requirements/coverage-evidence`                                                       | YES |
| GOV-010 | zdefiniować konwencję ID wymagań `REQ-###`                                                             | YES |
| GOV-011 | rozbić PRD na pojedyncze wymagania zdanie po zdaniu                                                    | YES |
| GOV-012 | zapisać każde wymaganie jako rekord w `requirements_master.yaml`                                       | YES |
| GOV-013 | oznaczyć dla każdego wymagania typ: functional / non-functional / security / ops / future              | YES |
| GOV-014 | oznaczyć dla każdego wymagania krytyczność                                                             | YES |
| GOV-015 | oznaczyć dla każdego wymagania warunek akceptacji                                                      | YES |
| GOV-016 | zdefiniować Definition of Ready                                                                        | YES |
| GOV-017 | zdefiniować Definition of Done                                                                         | YES |
| GOV-018 | zdefiniować policy, że żaden requirement nie może zostać zamknięty bez testu i dowodu                  | YES |
| GOV-019 | zdefiniować policy, że żaden release nie może przejść przy coverage wymagań < 100% dla zakresu release | YES |
| GOV-020 | utworzyć szablon ADR dla decyzji architektonicznych                                                    | YES |
| GOV-021 | utworzyć szablon runbooka operacyjnego                                                                 | YES |
| GOV-022 | utworzyć szablon raportu ewaluacji końcowej                                                            | YES |

---

## A2. Sprzęt i przygotowanie fizyczne

| ID     | Task                                                 | CLI     |
| ------ | ---------------------------------------------------- | ------- |
| HW-001 | potwierdzić finalną specyfikację CPU                 | NO      |
| HW-002 | potwierdzić finalną specyfikację GPU                 | NO      |
| HW-003 | potwierdzić ilość RAM                                | NO      |
| HW-004 | potwierdzić typ i model SSD/NVMe                     | NO      |
| HW-005 | potwierdzić płytę główną i zgodność z IOMMU/VT-d/SVM | NO      |
| HW-006 | potwierdzić zasilacz z zapasem mocy                  | NO      |
| HW-007 | potwierdzić UPS i czas podtrzymania                  | NO      |
| HW-008 | zmontować serwer                                     | NO      |
| HW-009 | podłączyć UPS                                        | NO      |
| HW-010 | wykonać pierwszy boot sprzętu                        | NO      |
| HW-011 | zaktualizować BIOS/UEFI do stabilnej wersji          | PARTIAL |
| HW-012 | ustawić `Restore on AC Power Loss = Power On`        | NO      |
| HW-013 | włączyć w BIOS wirtualizację CPU                     | NO      |
| HW-014 | włączyć IOMMU/VT-d/SVM                               | NO      |
| HW-015 | ustawić kolejność bootowania                         | NO      |
| HW-016 | wykonać test pamięci RAM                             | YES     |
| HW-017 | wykonać test stabilności CPU                         | YES     |
| HW-018 | wykonać test stabilności GPU                         | YES     |
| HW-019 | zapisać raport stabilności sprzętu                   | YES     |

---

## A3. Dysk, partycje, boot

| ID       | Task                                    | CLI |
| -------- | --------------------------------------- | --- |
| DISK-001 | zidentyfikować docelowy dysk systemowy  | YES |
| DISK-002 | wyczyścić tabelę partycji               | YES |
| DISK-003 | utworzyć GPT                            | YES |
| DISK-004 | utworzyć partycję EFI                   | YES |
| DISK-005 | utworzyć partycję Olares 1 TB           | YES |
| DISK-006 | utworzyć partycję Windows 400 GB        | YES |
| DISK-007 | utworzyć partycję Backup Olares 200 GB  | YES |
| DISK-008 | utworzyć partycję Backup Windows 200 GB | YES |
| DISK-009 | utworzyć partycję Shared Storage 200 GB | YES |
| DISK-010 | sformatować partycję EFI                | YES |
| DISK-011 | sformatować partycję Olares             | YES |
| DISK-012 | przygotować partycję Windows            | YES |
| DISK-013 | sformatować partycję Backup Olares      | YES |
| DISK-014 | sformatować partycję Backup Windows     | YES |
| DISK-015 | sformatować partycję Shared Storage     | YES |
| DISK-016 | nadać etykiety wszystkim partycjom      | YES |
| DISK-017 | zapisać mapę partycji do dokumentacji   | YES |

---

## A4. Instalacja systemów operacyjnych

| ID     | Task                                             | CLI     |
| ------ | ------------------------------------------------ | ------- |
| OS-001 | przygotować nośnik instalacyjny Olares           | YES     |
| OS-002 | przygotować nośnik instalacyjny Windows          | YES     |
| OS-003 | zainstalować Olares na partycji głównej          | PARTIAL |
| OS-004 | zweryfikować poprawność pierwszego bootu Olares  | PARTIAL |
| OS-005 | zainstalować Windows na partycji pomocniczej     | PARTIAL |
| OS-006 | zweryfikować poprawność pierwszego bootu Windows | PARTIAL |
| OS-007 | zainstalować i odtworzyć GRUB                    | YES     |
| OS-008 | dodać wpis Olares do GRUB                        | YES     |
| OS-009 | dodać wpis Windows do GRUB                       | YES     |
| OS-010 | ustawić Olares jako domyślny system              | YES     |
| OS-011 | ustawić timeout bootloadera 5-10 s               | YES     |
| OS-012 | przetestować boot Olares                         | PARTIAL |
| OS-013 | przetestować boot Windows                        | PARTIAL |
| OS-014 | udokumentować procedurę odzyskania bootloadera   | YES     |

---

## A5. Bazowa konfiguracja hosta Olares

| ID       | Task                                                             | CLI |
| -------- | ---------------------------------------------------------------- | --- |
| HOST-001 | ustawić hostname                                                 | YES |
| HOST-002 | ustawić timezone                                                 | YES |
| HOST-003 | ustawić locale                                                   | YES |
| HOST-004 | utworzyć konto administracyjne                                   | YES |
| HOST-005 | wyłączyć bezpośrednie logowanie root, jeśli polityka tego wymaga | YES |
| HOST-006 | skonfigurować sudoers                                            | YES |
| HOST-007 | skonfigurować montowanie partycji backup                         | YES |
| HOST-008 | skonfigurować montowanie shared storage                          | YES |
| HOST-009 | wpisać UUID do fstab                                             | YES |
| HOST-010 | przetestować automatyczne montowanie po restarcie                | YES |
| HOST-011 | wykonać aktualizację systemu bazowego                            | YES |
| HOST-012 | zainstalować pakiety bazowe administracyjne                      | YES |
| HOST-013 | skonfigurować logrotate                                          | YES |
| HOST-014 | skonfigurować NTP / synchronizację czasu                         | YES |
| HOST-015 | utworzyć katalogi dla logów aplikacyjnych                        | YES |
| HOST-016 | utworzyć katalogi dla danych modeli                              | YES |
| HOST-017 | utworzyć katalogi dla backupów lokalnych                         | YES |

---

## A6. Sieć i dostęp

| ID      | Task                                                                 | CLI     |
| ------- | -------------------------------------------------------------------- | ------- |
| NET-001 | zdecydować czy host ma działać na statycznym IP czy DHCP reservation | PARTIAL |
| NET-002 | skonfigurować interfejs sieciowy hosta                               | YES     |
| NET-003 | skonfigurować IP                                                     | YES     |
| NET-004 | skonfigurować gateway                                                | YES     |
| NET-005 | skonfigurować DNS                                                    | YES     |
| NET-006 | sprawdzić routing                                                    | YES     |
| NET-007 | sprawdzić rozwiązywanie DNS                                          | YES     |
| NET-008 | skonfigurować firewall hosta                                         | YES     |
| NET-009 | zablokować niepotrzebne porty publiczne                              | YES     |
| NET-010 | ograniczyć lub wyłączyć publiczny SSH zgodnie z PRD                  | YES     |
| NET-011 | skonfigurować rate limiting / fail2ban / CrowdSec                    | YES     |
| NET-012 | zapisać politykę portów dopuszczonych                                | YES     |

---

## A7. VPN i bezpieczny dostęp zdalny

| ID      | Task                                                | CLI |
| ------- | --------------------------------------------------- | --- |
| VPN-001 | zainstalować WireGuard                              | YES |
| VPN-002 | wygenerować klucz prywatny serwera                  | YES |
| VPN-003 | wygenerować klucz publiczny serwera                 | YES |
| VPN-004 | przygotować pulę adresacji VPN                      | YES |
| VPN-005 | utworzyć konfigurację interfejsu WireGuard          | YES |
| VPN-006 | skonfigurować forwarding                            | YES |
| VPN-007 | skonfigurować firewall dla WireGuard                | YES |
| VPN-008 | utworzyć pierwszy profil klienta VPN                | YES |
| VPN-009 | utworzyć drugi awaryjny profil klienta VPN          | YES |
| VPN-010 | przetestować połączenie klient-serwer               | YES |
| VPN-011 | włączyć auto-start usługi VPN                       | YES |
| VPN-012 | utworzyć skrypt wykrywania aktualnego IP hosta      | YES |
| VPN-013 | utworzyć usługę pokazującą IP po starcie systemu    | YES |
| VPN-014 | zapisać runbook awaryjnego odzyskiwania dostępu VPN | YES |

---

## A8. Warstwa bezpieczeństwa hosta

| ID      | Task                                                                  | CLI     |
| ------- | --------------------------------------------------------------------- | ------- |
| SEC-001 | zdefiniować politykę najmniejszych uprawnień                          | YES     |
| SEC-002 | zdefiniować listę usług dopuszczonych na hoście                       | YES     |
| SEC-003 | utwardzić SSH zgodnie z polityką                                      | YES     |
| SEC-004 | skonfigurować blokadę logowania hasłem, jeśli wymagane                | YES     |
| SEC-005 | skonfigurować dostęp tylko przez VPN do paneli admin                  | YES     |
| SEC-006 | skonfigurować audyt logowań                                           | YES     |
| SEC-007 | skonfigurować audyt zmian w krytycznych plikach                       | YES     |
| SEC-008 | skonfigurować rotację sekretów technicznych                           | YES     |
| SEC-009 | przygotować politykę przechowywania sekretów                          | YES     |
| SEC-010 | zaszyfrować dane wrażliwe w spoczynku, jeśli warstwa hosta to wspiera | PARTIAL |
| SEC-011 | przeprowadzić skan bazowy hosta                                       | YES     |
| SEC-012 | zapisać raport hardeningu hosta                                       | YES     |

---

## A9. Konteneryzacja i orkiestracja

| ID       | Task                                                    | CLI |
| -------- | ------------------------------------------------------- | --- |
| ORCH-001 | zainstalować Docker lub kompatybilny runtime kontenerów | YES |
| ORCH-002 | zweryfikować działanie runtime                          | YES |
| ORCH-003 | zainstalować K3s                                        | YES |
| ORCH-004 | sprawdzić status klastra                                | YES |
| ORCH-005 | skonfigurować storage class                             | YES |
| ORCH-006 | skonfigurować ingress controller                        | YES |
| ORCH-007 | skonfigurować obsługę certyfikatów                      | YES |
| ORCH-008 | zainstalować Helm                                       | YES |
| ORCH-009 | utworzyć namespace `ai-core`                            | YES |
| ORCH-010 | utworzyć namespace `automation`                         | YES |
| ORCH-011 | utworzyć namespace `observability`                      | YES |
| ORCH-012 | utworzyć namespace `security`                           | YES |
| ORCH-013 | utworzyć namespace `agents`                             | YES |
| ORCH-014 | zainstalować Argo CD                                    | YES |
| ORCH-015 | skonfigurować repozytoria GitOps                        | YES |
| ORCH-016 | skonfigurować politykę synchronizacji GitOps            | YES |
| ORCH-017 | przetestować pierwszy deploy przez GitOps               | YES |

---

## A10. GPU i runtime modeli

| ID     | Task                                                        | CLI |
| ------ | ----------------------------------------------------------- | --- |
| AI-001 | zainstalować sterowniki GPU                                 | YES |
| AI-002 | zweryfikować widoczność GPU przez host                      | YES |
| AI-003 | zainstalować runtime GPU dla kontenerów                     | YES |
| AI-004 | zweryfikować GPU w K3s                                      | YES |
| AI-005 | zainstalować Ollama lub inny lekki runtime lokalnych modeli | YES |
| AI-006 | zainstalować vLLM lub inny runtime modeli serwowanych       | YES |
| AI-007 | zainstalować llama.cpp jako alternatywę fallback            | YES |
| AI-008 | utworzyć katalog cache modeli                               | YES |
| AI-009 | pobrać model główny pomocniczy lokalny                      | YES |
| AI-010 | wykonać test inferencji modelu lokalnego                    | YES |
| AI-011 | skonfigurować endpointy usług modelowych                    | YES |
| AI-012 | skonfigurować limity CPU/RAM/VRAM dla runtime               | YES |
| AI-013 | skonfigurować healthcheck modeli                            | YES |
| AI-014 | skonfigurować automatyczny restart runtime AI po awarii     | YES |
| AI-015 | zapisać runbook restartu runtime AI                         | YES |

---

## A11. Integracja z modelem zewnętrznym ChatGPT 5.3 Codex

| ID      | Task                                                                 | CLI |
| ------- | -------------------------------------------------------------------- | --- |
| COD-001 | zdefiniować model główny `gpt-5.3-codex` jako executor implementacji | YES |
| COD-002 | zdefiniować model pomocniczy szybkiej iteracji                       | YES |
| COD-003 | skonfigurować sposób autoryzacji do API                              | YES |
| COD-004 | skonfigurować bezpieczne przechowywanie kluczy API                   | YES |
| COD-005 | utworzyć adapter wywołań modelu                                      | YES |
| COD-006 | dodać retry policy dla błędów tymczasowych                           | YES |
| COD-007 | dodać timeout policy                                                 | YES |
| COD-008 | dodać cost guard / budget guard                                      | YES |
| COD-009 | dodać fallback policy do innego modelu lub trybu                     | YES |
| COD-010 | logować wszystkie wywołania z metadanymi bez ujawniania sekretów     | YES |
| COD-011 | wdrożyć kontrolę wersji promptów systemowych                         | YES |
| COD-012 | wykonać test poprawności pełnego flow do modelu                      | YES |

---

## A12. Platforma workflow i automatyzacji

| ID      | Task                                                      | CLI |
| ------- | --------------------------------------------------------- | --- |
| N8N-001 | zainstalować n8n                                          | YES |
| N8N-002 | skonfigurować trwałe storage dla n8n                      | YES |
| N8N-003 | skonfigurować bazę danych n8n                             | YES |
| N8N-004 | skonfigurować worker mode, jeśli architektura tego wymaga | YES |
| N8N-005 | skonfigurować ingress / reverse proxy dla n8n             | YES |
| N8N-006 | ograniczyć dostęp do n8n tylko przez VPN / IAM            | YES |
| N8N-007 | włączyć auto-start po boot / po starcie klastra           | YES |
| N8N-008 | utworzyć pierwszy workflow healthcheck                    | YES |
| N8N-009 | utworzyć workflow backupu eksportów n8n                   | YES |
| N8N-010 | utworzyć workflow monitorowania nieudanych zadań          | YES |
| N8N-011 | przetestować restart n8n i trwałość konfiguracji          | YES |

---

## A13. Dane, pamięć, kolejki, artefakty

| ID       | Task                                                                 | CLI |
| -------- | -------------------------------------------------------------------- | --- |
| DATA-001 | zainstalować PostgreSQL                                              | YES |
| DATA-002 | utworzyć bazę systemową platformy                                    | YES |
| DATA-003 | utworzyć użytkowników bazodanowych z najmniejszym zakresem uprawnień | YES |
| DATA-004 | zainstalować rozszerzenie pgvector                                   | YES |
| DATA-005 | utworzyć schemat dla pamięci semantycznej agentów                    | YES |
| DATA-006 | zainstalować Redis                                                   | YES |
| DATA-007 | skonfigurować persistence Redis, jeśli wymagane                      | YES |
| DATA-008 | zainstalować NATS lub RabbitMQ                                       | YES |
| DATA-009 | skonfigurować kolejki zadań agentów                                  | YES |
| DATA-010 | zainstalować MinIO                                                   | YES |
| DATA-011 | utworzyć bucket na artefakty buildów                                 | YES |
| DATA-012 | utworzyć bucket na raporty testowe                                   | YES |
| DATA-013 | utworzyć bucket na dokumentację wygenerowaną                         | YES |
| DATA-014 | utworzyć bucket na evidence coverage                                 | YES |
| DATA-015 | przetestować zapis i odczyt z każdego komponentu danych              | YES |

---

## A14. Monitoring, logi, tracing

| ID      | Task                                          | CLI     |
| ------- | --------------------------------------------- | ------- |
| OBS-001 | zainstalować Prometheus                       | YES     |
| OBS-002 | skonfigurować scrape job dla hosta            | YES     |
| OBS-003 | skonfigurować scrape job dla K3s              | YES     |
| OBS-004 | skonfigurować scrape job dla GPU              | YES     |
| OBS-005 | skonfigurować scrape job dla runtime AI       | YES     |
| OBS-006 | zainstalować Grafana                          | YES     |
| OBS-007 | zainstalować Loki                             | YES     |
| OBS-008 | zainstalować Tempo lub tracing                | YES     |
| OBS-009 | skonfigurować zbieranie logów kontenerów      | YES     |
| OBS-010 | skonfigurować zbieranie logów hosta           | YES     |
| OBS-011 | utworzyć dashboard CPU                        | PARTIAL |
| OBS-012 | utworzyć dashboard GPU                        | PARTIAL |
| OBS-013 | utworzyć dashboard RAM/VRAM                   | PARTIAL |
| OBS-014 | utworzyć dashboard stanu modeli               | PARTIAL |
| OBS-015 | utworzyć dashboard kolejek agentów            | PARTIAL |
| OBS-016 | skonfigurować alert na padnięcie modelu       | YES     |
| OBS-017 | skonfigurować alert na przepełnienie VRAM     | YES     |
| OBS-018 | skonfigurować alert na nieudany backup        | YES     |
| OBS-019 | skonfigurować alert na utratę połączenia z DB | YES     |
| OBS-020 | skonfigurować alert na niedostępność VPN      | YES     |

---

## A15. Backup, restore, disaster recovery

| ID      | Task                                                             | CLI     |
| ------- | ---------------------------------------------------------------- | ------- |
| BAK-001 | wybrać narzędzie backupowe hosta                                 | YES     |
| BAK-002 | skonfigurować backup konfiguracji hosta                          | YES     |
| BAK-003 | skonfigurować backup manifestów K3s/GitOps                       | YES     |
| BAK-004 | skonfigurować backup baz PostgreSQL                              | YES     |
| BAK-005 | skonfigurować backup Redis, jeśli potrzebny                      | YES     |
| BAK-006 | skonfigurować backup workflow n8n                                | YES     |
| BAK-007 | skonfigurować backup bucketów MinIO                              | YES     |
| BAK-008 | skonfigurować backup katalogów modeli                            | YES     |
| BAK-009 | skierować backupy na partycję Backup Olares                      | YES     |
| BAK-010 | skierować backupy Windows na partycję Backup Windows             | PARTIAL |
| BAK-011 | skonfigurować harmonogram dzienny backupów                       | YES     |
| BAK-012 | skonfigurować politykę retencji                                  | YES     |
| BAK-013 | skonfigurować backup off-host, jeśli celem jest realna odporność | YES     |
| BAK-014 | wykonać pierwszy backup pełny                                    | YES     |
| BAK-015 | wykonać test odtworzenia hosta                                   | YES     |
| BAK-016 | wykonać test odtworzenia bazy                                    | YES     |
| BAK-017 | wykonać test odtworzenia n8n                                     | YES     |
| BAK-018 | wykonać test odtworzenia artefaktów                              | YES     |
| BAK-019 | spisać runbook disaster recovery                                 | YES     |

---

## A16. Połączenia z zewnętrznymi bazami danych

| ID        | Task                                                                      | CLI |
| --------- | ------------------------------------------------------------------------- | --- |
| EXTDB-001 | zinwentaryzować typy wspieranych zewnętrznych baz: MSSQL/PostgreSQL/MySQL | YES |
| EXTDB-002 | przygotować konfigurację connection profiles                              | YES |
| EXTDB-003 | bezpiecznie zapisać poświadczenia                                         | YES |
| EXTDB-004 | utworzyć warstwę adapterów połączeń                                       | YES |
| EXTDB-005 | zaimplementować auto-connect po starcie systemu                           | YES |
| EXTDB-006 | zaimplementować retry policy                                              | YES |
| EXTDB-007 | zaimplementować healthcheck połączeń                                      | YES |
| EXTDB-008 | zaimplementować alert dla zerwanego połączenia                            | YES |
| EXTDB-009 | przetestować połączenie do MSSQL                                          | YES |
| EXTDB-010 | przetestować połączenie do PostgreSQL                                     | YES |
| EXTDB-011 | przetestować połączenie do MySQL                                          | YES |
| EXTDB-012 | udokumentować procedurę rotacji credentials                               | YES |

---

## A17. CI/CD, jakość i release

| ID       | Task                                          | CLI     |
| -------- | --------------------------------------------- | ------- |
| CICD-001 | wybrać system Git hosting                     | PARTIAL |
| CICD-002 | skonfigurować repo i branch protection        | YES     |
| CICD-003 | skonfigurować pre-commit hooks                | YES     |
| CICD-004 | skonfigurować lint                            | YES     |
| CICD-005 | skonfigurować formatowanie                    | YES     |
| CICD-006 | skonfigurować typecheck                       | YES     |
| CICD-007 | skonfigurować testy unit w CI                 | YES     |
| CICD-008 | skonfigurować testy integracyjne w CI         | YES     |
| CICD-009 | skonfigurować testy e2e Playwright w CI       | YES     |
| CICD-010 | skonfigurować skany bezpieczeństwa zależności | YES     |
| CICD-011 | skonfigurować secret scanning                 | YES     |
| CICD-012 | skonfigurować budowanie obrazów kontenerowych | YES     |
| CICD-013 | skonfigurować publikację artefaktów           | YES     |
| CICD-014 | skonfigurować deployment przez Argo CD        | YES     |
| CICD-015 | skonfigurować semver i release tags           | YES     |
| CICD-016 | skonfigurować rollback procedurę              | YES     |
| CICD-017 | skonfigurować release checklist gate          | YES     |

---

## A18. Architektura wieloagentowa

| ID      | Task                                                        | CLI |
| ------- | ----------------------------------------------------------- | --- |
| AGT-001 | zdefiniować strukturę organizacyjną agentów                 | YES |
| AGT-002 | zdefiniować rolę CEO                                        | YES |
| AGT-003 | zdefiniować rolę ProductOwner                               | YES |
| AGT-004 | zdefiniować rolę Team Leader                                | YES |
| AGT-005 | zdefiniować rolę Architect                                  | YES |
| AGT-006 | zdefiniować rolę Database Engineer                          | YES |
| AGT-007 | zdefiniować rolę FullStackDev1                              | YES |
| AGT-008 | zdefiniować rolę FullStackDev2                              | YES |
| AGT-009 | zdefiniować rolę FullStackDev3                              | YES |
| AGT-010 | zdefiniować rolę FrontEndDev                                | YES |
| AGT-011 | zdefiniować rolę UIUXDesigner                               | YES |
| AGT-012 | zdefiniować rolę Tester1                                    | YES |
| AGT-013 | zdefiniować rolę Tester2                                    | YES |
| AGT-014 | zdefiniować rolę QAEngineer                                 | YES |
| AGT-015 | zdefiniować rolę DocumentationManager                       | YES |
| AGT-016 | zdefiniować rolę DevOps/SRE Engineer                        | YES |
| AGT-017 | zdefiniować rolę Security Engineer                          | YES |
| AGT-018 | zdefiniować rolę Release Manager                            | YES |
| AGT-019 | zdefiniować zakres obowiązków każdej roli                   | YES |
| AGT-020 | zdefiniować zakres zakazów każdej roli                      | YES |
| AGT-021 | zdefiniować uprawnienia narzędziowe każdej roli             | YES |
| AGT-022 | zdefiniować ścieżkę eskalacji każdej roli                   | YES |
| AGT-023 | zdefiniować format raportowania hierarchicznego             | YES |
| AGT-024 | zdefiniować politykę komunikacji między agentami            | YES |
| AGT-025 | zdefiniować typy komunikatów między agentami                | YES |
| AGT-026 | zdefiniować timeouty komunikacyjne                          | YES |
| AGT-027 | zdefiniować retry policy komunikacyjne                      | YES |
| AGT-028 | zdefiniować mechanizm rozwiązywania konfliktów agentów      | YES |
| AGT-029 | zdefiniować mechanizm blokad na współdzielonych artefaktach | YES |
| AGT-030 | zdefiniować budżety kosztowe agentów                        | YES |
| AGT-031 | zdefiniować limity iteracji agentów                         | YES |
| AGT-032 | zdefiniować limity czasu agentów                            | YES |
| AGT-033 | zdefiniować warunki zatrzymania agentów                     | YES |
| AGT-034 | zdefiniować watchdog anty-zapętleniowy                      | YES |

---

## A19. Skills i MCP

| ID      | Task                                                    | CLI |
| ------- | ------------------------------------------------------- | --- |
| SKL-001 | zdefiniować standard struktury skilli                   | YES |
| SKL-002 | zdefiniować standard wersjonowania skilli               | YES |
| SKL-003 | zdefiniować standard testowania skilli                  | YES |
| SKL-004 | utworzyć skill Brainstorming                            | YES |
| SKL-005 | utworzyć skill Playwright                               | YES |
| SKL-006 | utworzyć skill PRD Analyzer                             | YES |
| SKL-007 | utworzyć skill Task Decomposer                          | YES |
| SKL-008 | utworzyć skill System Architect                         | YES |
| SKL-009 | utworzyć skill Backend Implementer                      | YES |
| SKL-010 | utworzyć skill Frontend Implementer                     | YES |
| SKL-011 | utworzyć skill Database Migration Designer              | YES |
| SKL-012 | utworzyć skill API Contract Designer                    | YES |
| SKL-013 | utworzyć skill Test Writer                              | YES |
| SKL-014 | utworzyć skill Documentation Writer                     | YES |
| SKL-015 | utworzyć skill Security Reviewer                        | YES |
| SKL-016 | utworzyć skill Code Reviewer                            | YES |
| SKL-017 | utworzyć skill Refactoring Specialist                   | YES |
| SKL-018 | utworzyć skill Bug Triage                               | YES |
| SKL-019 | utworzyć skill Release Checklist Auditor                | YES |
| SKL-020 | utworzyć skill Production Readiness Reviewer            | YES |
| SKL-021 | utworzyć skill Observability Designer                   | YES |
| SKL-022 | utworzyć skill Requirement-to-Code Traceability Auditor | YES |
| SKL-023 | utworzyć skill Anti-Hallucination Verifier              | YES |
| SKL-024 | utworzyć skill Cross-Agent Conflict Resolver            | YES |
| SKL-025 | utworzyć skill Cost Optimizer                           | YES |
| SKL-026 | utworzyć skill Performance Profiler                     | YES |
| SKL-027 | utworzyć skill Data Privacy & Compliance Reviewer       | YES |
| SKL-028 | zdefiniować katalog MCP serverów wymaganych             | YES |
| SKL-029 | wdrożyć MCP dla Git                                     | YES |
| SKL-030 | wdrożyć MCP dla Filesystem                              | YES |
| SKL-031 | wdrożyć MCP dla Terminal/Exec                           | YES |
| SKL-032 | wdrożyć MCP dla Docker/K8s                              | YES |
| SKL-033 | wdrożyć MCP dla Postgres                                | YES |
| SKL-034 | wdrożyć MCP dla Redis                                   | YES |
| SKL-035 | wdrożyć MCP dla Observability                           | YES |
| SKL-036 | wdrożyć MCP dla Secrets                                 | YES |
| SKL-037 | wdrożyć MCP dla Ticketing                               | YES |
| SKL-038 | wdrożyć MCP dla Docs                                    | YES |
| SKL-039 | wdrożyć MCP dla Artifact Storage                        | YES |
| SKL-040 | wdrożyć MCP dla Test Reports                            | YES |
| SKL-041 | przetestować autoryzację i izolację każdego MCP         | YES |

---

## A20. Pipeline realizacji produktu od wymagań do wdrożenia

| ID       | Task                                                      | CLI |
| -------- | --------------------------------------------------------- | --- |
| PIPE-001 | zaimplementować etap intake wymagań                       | YES |
| PIPE-002 | zaimplementować etap analizy wymagań                      | YES |
| PIPE-003 | zaimplementować etap doprecyzowania acceptance criteria   | YES |
| PIPE-004 | zaimplementować etap planu technicznego                   | YES |
| PIPE-005 | zaimplementować etap task decomposition                   | YES |
| PIPE-006 | zaimplementować etap implementacji                        | YES |
| PIPE-007 | zaimplementować etap code review                          | YES |
| PIPE-008 | zaimplementować etap security review                      | YES |
| PIPE-009 | zaimplementować etap testowania                           | YES |
| PIPE-010 | zaimplementować etap generowania dokumentacji             | YES |
| PIPE-011 | zaimplementować etap traceability review                  | YES |
| PIPE-012 | zaimplementować etap release readiness                    | YES |
| PIPE-013 | zaimplementować etap wdrożenia                            | YES |
| PIPE-014 | zaimplementować etap ewaluacji końcowej zdanie po zdaniu  | YES |
| PIPE-015 | zaimplementować możliwość cofnięcia do poprzedniego etapu | YES |
| PIPE-016 | zaimplementować checkpointy artefaktów po każdym etapie   | YES |
| PIPE-017 | zaimplementować podpisywanie etapów przez właściwe role   | YES |

---

## A21. Testy systemu autonomicznego

| ID      | Task                                                | CLI |
| ------- | --------------------------------------------------- | --- |
| TST-001 | skonfigurować framework testów unit                 | YES |
| TST-002 | skonfigurować framework testów integracyjnych       | YES |
| TST-003 | skonfigurować Playwright                            | YES |
| TST-004 | napisać testy jednostkowe orchestratora agentów     | YES |
| TST-005 | napisać testy jednostkowe adaptera modelu           | YES |
| TST-006 | napisać testy jednostkowe traceability engine       | YES |
| TST-007 | napisać testy integracyjne kolejki agentów          | YES |
| TST-008 | napisać testy integracyjne pamięci agentów          | YES |
| TST-009 | napisać testy integracyjne MCP                      | YES |
| TST-010 | napisać testy integracyjne pipeline wymagań         | YES |
| TST-011 | napisać test e2e: od PRD do planu                   | YES |
| TST-012 | napisać test e2e: od planu do implementacji         | YES |
| TST-013 | napisać test e2e: od implementacji do testów        | YES |
| TST-014 | napisać test e2e: od testów do dokumentacji         | YES |
| TST-015 | napisać test e2e: finalna ewaluacja 100% coverage   | YES |
| TST-016 | napisać testy bezpieczeństwa dostępu do sekretów    | YES |
| TST-017 | napisać testy odporności na restart usług           | YES |
| TST-018 | napisać testy odzyskiwania po utracie połączenia DB | YES |
| TST-019 | napisać testy retry dla modelu                      | YES |
| TST-020 | napisać testy anty-zapętleniowe agentów             | YES |
| TST-021 | napisać testy wydajnościowe kolejki i orchestratora | YES |
| TST-022 | napisać testy raportowania hierarchicznego agentów  | YES |
| TST-023 | napisać testy poprawności Definition of Done gate   | YES |
| TST-024 | napisać testy poprawności release gate              | YES |

---

## A22. Dokumentacja

| ID      | Task                                              | CLI |
| ------- | ------------------------------------------------- | --- |
| DOC-001 | wygenerować README platformy                      | YES |
| DOC-002 | wygenerować dokument architektury systemu         | YES |
| DOC-003 | wygenerować diagram zależności komponentów        | YES |
| DOC-004 | wygenerować diagram sekwencji boot flow           | YES |
| DOC-005 | wygenerować diagram komunikacji agentów           | YES |
| DOC-006 | wygenerować dokument ról i obowiązków agentów     | YES |
| DOC-007 | wygenerować dokument skilli i ich przeznaczenia   | YES |
| DOC-008 | wygenerować dokument konfiguracji MCP             | YES |
| DOC-009 | wygenerować runbook hosta                         | YES |
| DOC-010 | wygenerować runbook backup/restore                | YES |
| DOC-011 | wygenerować runbook VPN                           | YES |
| DOC-012 | wygenerować runbook n8n                           | YES |
| DOC-013 | wygenerować runbook modeli AI                     | YES |
| DOC-014 | wygenerować runbook disaster recovery             | YES |
| DOC-015 | wygenerować dokument bezpieczeństwa               | YES |
| DOC-016 | wygenerować dokument test strategy                | YES |
| DOC-017 | wygenerować dokument traceability matrix          | YES |
| DOC-018 | wygenerować dokument release policy               | YES |
| DOC-019 | wygenerować dokument końcowej ewaluacji zgodności | YES |

---

## A23. Finalna walidacja i akceptacja

| ID      | Task                                                       | CLI     |
| ------- | ---------------------------------------------------------- | ------- |
| FIN-001 | uruchomić pełny boot flow od zimnego startu                | PARTIAL |
| FIN-002 | zasymulować powrót zasilania i sprawdzić auto-power-on     | PARTIAL |
| FIN-003 | potwierdzić start Olares jako systemu domyślnego           | YES     |
| FIN-004 | potwierdzić ręczny wybór Windows z bootloadera             | PARTIAL |
| FIN-005 | potwierdzić start VPN po uruchomieniu systemu              | YES     |
| FIN-006 | potwierdzić prezentację IP po starcie                      | YES     |
| FIN-007 | potwierdzić start n8n po systemie                          | YES     |
| FIN-008 | potwierdzić start runtime AI po systemie                   | YES     |
| FIN-009 | potwierdzić auto-connect do zewnętrznej bazy               | YES     |
| FIN-010 | potwierdzić monitoring CPU/GPU/RAM/VRAM                    | YES     |
| FIN-011 | potwierdzić backup dzienny                                 | YES     |
| FIN-012 | potwierdzić działanie rollbacku                            | YES     |
| FIN-013 | potwierdzić brak publicznego dostępu do paneli krytycznych | YES     |
| FIN-014 | potwierdzić działanie wieloagentowego wykonania            | YES     |
| FIN-015 | potwierdzić działanie skilli                               | YES     |
| FIN-016 | potwierdzić działanie MCP                                  | YES     |
| FIN-017 | potwierdzić generowanie testów i dokumentacji              | YES     |
| FIN-018 | potwierdzić końcową ewaluację zdanie po zdaniu             | YES     |
| FIN-019 | wygenerować finalny raport pokrycia wymagań                | YES     |
| FIN-020 | wygenerować finalny raport ryzyk otwartych                 | YES     |

---

# B. Pokrycie wymagań - 100%

Teraz najważniejsza rzecz, czyli nie "czy lista wygląda mądrze", tylko **czy domyka wszystko, o co prosiłeś**.

## B1. Pokrycie PRD 1:1

### 1. Overview

Wymagania:

* Linux/Olares jako główne środowisko
* Windows jako pomocnicze
* obsługa modeli LLM
* n8n
* komunikacja z zewnętrzną bazą
* odporność na przerwy zasilania
* bezpieczny zdalny dostęp

Pokrycie:

* OS-003, OS-005, OS-010
* AI-005 do AI-015
* N8N-001 do N8N-011
* EXTDB-001 do EXTDB-012
* HW-012, FIN-002
* VPN-001 do VPN-014, SEC-003 do SEC-012

### 2. Goals

Wymagania:

* stabilne środowisko dla modeli LLM
* n8n
* auto-connect do DB
* bezpieczny zdalny dostęp
* recovery po awarii zasilania
* monitoring i backupy

Pokrycie:

* AI-001 do AI-015
* N8N-001 do N8N-011
* EXTDB-005 do EXTDB-011
* VPN-001 do VPN-014, SEC-001 do SEC-012
* HW-012, FIN-002
* OBS-001 do OBS-020
* BAK-001 do BAK-019

### 3. System Architecture

Wymagania warstwowe:

* hardware
* OS
* application layer
* external systems

Pokrycie:

* HW-001 do HW-019
* OS-001 do OS-014
* AI, N8N, VPN, OBS, BAK
* EXTDB-001 do EXTDB-012

### 4.1 Automatic Power Recovery

Pokrycie:

* HW-012
* FIN-002

### 4.2 Dual Boot System

Pokrycie:

* DISK-005 do DISK-009
* OS-003 do OS-013
* FIN-003, FIN-004

### 4.3 Automatic Remote Access Setup

Pokrycie:

* VPN-001 do VPN-014
* FIN-005, FIN-006

### 4.4 Controlled Service Startup

Pokrycie:

* ORCH-017
* N8N-007
* AI-014
* FIN-007, FIN-008
* plus host/systemd orchestration implied by HOST i runtime deployment

### 4.5 AI Processing Environment

Pokrycie:

* AI-005 do AI-015
* COD-001 do COD-012

### 4.6 Automation Platform

Pokrycie:

* N8N-001 do N8N-011

### 4.7 External Database Connection

Pokrycie:

* EXTDB-001 do EXTDB-012
* FIN-009

### 4.8 System Monitoring

Pokrycie:

* OBS-001 do OBS-020
* FIN-010

### 4.9 Update Mechanism

PRD mówi o aktualizacji OS, modeli, n8n i komponentów z możliwością rollbacku.

Pokrycie:

* HOST-011
* CICD-014 do CICD-017
* BAK-014 do BAK-019
* FIN-012

Dodatkowo warto dopisać osobne taski aktualizacyjne, żeby to było jeszcze szczelniejsze:

* UPD-001 utworzyć politykę aktualizacji hosta - YES
* UPD-002 utworzyć politykę aktualizacji modeli - YES
* UPD-003 utworzyć politykę aktualizacji n8n - YES
* UPD-004 utworzyć politykę aktualizacji komponentów platformy - YES
* UPD-005 przetestować rollback po aktualizacji - YES

### 4.10 Backup System

Pokrycie:

* BAK-001 do BAK-019
* FIN-011

### 5. Disk Partition Layout

Pokrycie:

* DISK-003 do DISK-017

### 6. Storage Usage

Pokrycie:

* HOST-015 do HOST-017
* AI-008
* DATA-010 do DATA-014
* BAK-009, BAK-010

### 7. Security Requirements

Pokrycie:

* VPN-001 do VPN-014
* SEC-001 do SEC-012
* NET-008 do NET-012
* FIN-013

### 8. Reliability

Pokrycie:

* AI-014
* N8N-007
* EXTDB-006, EXTDB-007
* BAK-015 do BAK-019
* TST-017, TST-018
* FIN-001 do FIN-012

### 9. Boot Flow

Pokrycie:

* HW-012
* OS-007 do OS-013
* VPN-011 do VPN-013
* N8N-007
* AI-014
* EXTDB-005
* OBS-001 do OBS-020
* DOC-004
* FIN-001 do FIN-010

### 10. Non-Functional Requirements

Wysoka dostępność, recovery, bezpieczeństwo, skalowalność, automatyzacja:

* OBS, BAK, SEC, ORCH, AGT, PIPE, TST, FIN

### 11. Future Extensions

* orkiestracja agentów AI
* system kolejkowania
* klaster AI
* autoskalowanie modeli

Pokrycie:

* AGT-001 do AGT-034
* DATA-008, DATA-009
* ORCH-003 do ORCH-017
* AI-012
* plus architektura K3s daje ścieżkę do klastra i skalowania

---

## B2. Pokrycie Twoich wymagań rozszerzających poza PRD

To jest ta część, która zmienia serwer z "maszynki do LLM" w "autonomiczny software house bez kawy i zwolnień lekarskich".

### Wymaganie: AI ma prowadzić development od wymagań do działającego produktu

Pokrycie:

* PIPE-001 do PIPE-017
* AGT-001 do AGT-034
* COD-001 do COD-012
* SKL-004 do SKL-027
* TST-011 do TST-015
* DOC-001 do DOC-019

### Wymaganie: implementacja ma zawierać testy

Pokrycie:

* TST-001 do TST-024
* CICD-007 do CICD-009
* FIN-017

### Wymaganie: implementacja ma zawierać dokumentację

Pokrycie:

* DOC-001 do DOC-019
* FIN-017

### Wymaganie: finalizacja ma zawierać ewaluację 100% zgodności z oryginalnym planem zdanie po zdaniu

Pokrycie:

* GOV-011 do GOV-015
* SKL-022
* PIPE-014
* TST-015
* DOC-017, DOC-019
* FIN-018, FIN-019

### Wymaganie: użycie ChatGPT 5.3 Codex

Pokrycie:

* COD-001 do COD-012

### Wymaganie: serwery MCP

Pokrycie:

* SKL-028 do SKL-041

### Wymaganie: Skills, na pewno Brainstorming i Playwright

Pokrycie:

* SKL-004
* SKL-005
* plus reszta skilli SKL-006 do SKL-027

### Wymaganie: wiele agentów komunikujących się ze sobą jak zespół

Pokrycie:

* AGT-001 do AGT-034
* DATA-008, DATA-009
* PIPE-017
* TST-022

### Wymaganie: specjalizacje agentów i ograniczenie ról do zakresu obowiązków

Pokrycie:

* AGT-002 do AGT-023
* SEC-001
* SKL-041

### Wymaganie: raportowanie zgodnie z hierarchią

Pokrycie:

* AGT-023
* TST-022

### Wymaganie: maksymalizacja utylizacji członków zespołu

Pokrycie:

* AGT-024 do AGT-034
* OBS-015
* PIPE-005 do PIPE-017

---

# C. Czego jeszcze brakowało, żeby naprawdę było 100%, a nie "na oko"

Dopisuję brakujące atomy, których warto nie zgubić, bo to często te małe potwory gryzą później po kostkach.

## C1. Traceability engine - osobna warstwa

| ID      | Task                                                 | CLI |
| ------- | ---------------------------------------------------- | --- |
| TRC-001 | utworzyć parser PRD do requirementów atomowych       | YES |
| TRC-002 | utworzyć schemat danych requirementu                 | YES |
| TRC-003 | utworzyć schemat danych evidence                     | YES |
| TRC-004 | utworzyć mapowanie requirement -> task               | YES |
| TRC-005 | utworzyć mapowanie requirement -> commit/PR          | YES |
| TRC-006 | utworzyć mapowanie requirement -> test               | YES |
| TRC-007 | utworzyć mapowanie requirement -> dokumentacja       | YES |
| TRC-008 | utworzyć statusy `fulfilled/partial/missing/blocked` | YES |
| TRC-009 | utworzyć generator raportu coverage                  | YES |
| TRC-010 | utworzyć gate blokujący release przy brakach         | YES |

## C2. Aktualizacje i rollback - osobno, żeby PRD był domknięty bez cienia wątpliwości

| ID      | Task                                                       | CLI |
| ------- | ---------------------------------------------------------- | --- |
| UPD-001 | zdefiniować procedurę aktualizacji systemu operacyjnego    | YES |
| UPD-002 | zdefiniować procedurę aktualizacji modeli                  | YES |
| UPD-003 | zdefiniować procedurę aktualizacji n8n                     | YES |
| UPD-004 | zdefiniować procedurę aktualizacji komponentów systemowych | YES |
| UPD-005 | zdefiniować procedurę rollbacku dla hosta                  | YES |
| UPD-006 | zdefiniować procedurę rollbacku dla runtime AI             | YES |
| UPD-007 | zdefiniować procedurę rollbacku dla n8n                    | YES |
| UPD-008 | przetestować rollback w kontrolowanym scenariuszu          | YES |

## C3. Windows jako środowisko pomocnicze

| ID      | Task                                                         | CLI     |
| ------- | ------------------------------------------------------------ | ------- |
| WIN-001 | zdefiniować do czego dokładnie służy Windows                 | YES     |
| WIN-002 | zainstalować minimalny zestaw narzędzi administracyjnych     | PARTIAL |
| WIN-003 | skonfigurować backup Windows                                 | PARTIAL |
| WIN-004 | udokumentować, że Windows nie jest systemem domyślnym        | YES     |
| WIN-005 | udokumentować procedurę ręcznego uruchomienia Windows z GRUB | YES     |

---

# D. Podsumowanie stanu pokrycia

Po dodaniu bloków **TRC**, **UPD** i **WIN** masz już nie "prawie wszystko", tylko naprawdę **pełne domknięcie zakresu**.

## Liczba tasków

Łącznie:

* backlog główny: **334 taski**
* backlog uzupełniający: **23 taski**
* razem: **357 atomowych tasków**

## Szacowany udział możliwy przez CLI

* **YES**: około 92-94%
* **PARTIAL**: około 5-7%
* **NO**: około 1-3%

To oznacza, że ten projekt **nadaje się znakomicie do autonomicznego wykonania przez commandline-first AI system**, z niewielką liczbą wyjątków:

* fizyczny montaż sprzętu
* BIOS/UEFI
* część instalacji systemów
* niektóre elementy wizualne dashboardów / UI

---

# E. Najuczciwsza odpowiedź na pytanie: czy plan jest już kompletny?

Tak, **na poziomie wymagań i backlogu wykonawczego** - tak.
Nie, **na poziomie gotowości do wdrożenia przez agentów** - jeszcze nie całkiem, bo brakuje Ci teraz trzech rzeczy operacyjnych:

1. **DAG zależności między taskami** - co musi być przed czym
2. **przypisania tasków do ról agentów**
3. **priorytetyzacji MVP vs v1 vs hardening**

Bez tego masz pełną mapę, ale jeszcze nie masz ruchu wojsk. Masz planszę, ale pionki jeszcze stoją w pudełku.

Następnym najlepszym krokiem jest przygotowanie:
**Task DAG + owner agent + acceptance criteria + evidence required dla wszystkich 357 tasków**.
