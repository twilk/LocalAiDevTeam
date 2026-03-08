#!/usr/bin/env bash
#
# apply-network-access.sh – Konfiguracja dostępu sieciowego dla istniejącej instalacji.
# Bez sudo do docker, usługi dostępne na IP:port.
# Uruchom raz: sudo bash apply-network-access.sh
#
set -uo pipefail

BASE_DIR="${BASE_DIR:-/opt/ai-dev-team}"

echo ""
echo "=== apply-network-access.sh ==="
echo ""

# 1. User do grupy docker (bez sudo dla docker)
if [[ -n "${SUDO_USER:-}" ]]; then
  usermod -aG docker "$SUDO_USER"
  echo "[OK] Użytkownik $SUDO_USER dodany do grupy docker"
  echo "     → Wyloguj i zaloguj ponownie (lub: newgrp docker)"
else
  echo "[?] Uruchom przez sudo, by dodać użytkownika do grupy docker"
fi

# 2. n8n-data uprawnienia
if [[ -d "$BASE_DIR/n8n-data" ]]; then
  chown -R 1000:1000 "$BASE_DIR/n8n-data"
  echo "[OK] chown 1000:1000 $BASE_DIR/n8n-data"
fi

# 3. UFW – porty usług
if command -v ufw &>/dev/null; then
  for port in 5678 9000 9001 11434 5432 6379; do
    ufw allow "${port}/tcp" 2>/dev/null || true
  done
  ufw --force enable 2>/dev/null || true
  ufw reload 2>/dev/null || true
  echo "[OK] UFW – porty 5678, 9000, 9001, 11434, 5432, 6379 otwarte"
fi

# 4. PostgreSQL – listen na wszystkich interfejsach
for f in /etc/postgresql/*/main/postgresql.conf; do
  [[ -f "$f" ]] || continue
  if grep -q "listen_addresses" "$f"; then
    sed -i "s/^#*listen_addresses.*/listen_addresses = '*'/" "$f"
    echo "[OK] PostgreSQL listen_addresses='*' w $f"
  fi
done

# pg_hba.conf – zezwól na połączenia z sieci
for f in /etc/postgresql/*/main/pg_hba.conf; do
  [[ -f "$f" ]] || continue
  if ! grep -q "0.0.0.0/0" "$f"; then
    echo "host all all 0.0.0.0/0 scram-sha-256" >> "$f"
    echo "[OK] pg_hba.conf – dodano host 0.0.0.0/0"
  fi
done

# 5. Redis – bind 0.0.0.0
if [[ -f /etc/redis/redis.conf ]]; then
  sed -i 's/^bind 127\.0\.0\.1.*/bind 0.0.0.0/' /etc/redis/redis.conf 2>/dev/null || true
  echo "[OK] Redis bind 0.0.0.0"
fi

# 6. n8n kontener – przebuduj z 0.0.0.0 jeśli potrzeba
if command -v docker &>/dev/null && docker ps -a --format '{{.Names}}' | grep -q ^n8n$; then
  if ! docker port n8n 5678 2>/dev/null | grep -q "0.0.0.0"; then
    echo "[INFO] n8n – restart kontenera z -p 0.0.0.0:5678:5678"
    docker stop n8n 2>/dev/null || true
    docker rm n8n 2>/dev/null || true
    docker run -d --name n8n --restart unless-stopped -p 0.0.0.0:5678:5678 \
      -v "$BASE_DIR/n8n-data:/home/node/.n8n" n8nio/n8n
    echo "[OK] n8n – kontener odtworzony"
  fi
fi

# Restart serwisów
systemctl restart postgresql 2>/dev/null || true
systemctl restart redis-server 2>/dev/null || true

echo ""
echo "=== Gotowe ==="
echo "  newgrp docker  # lub wyloguj/zaloguj"
echo "  Adresy: http://\$(hostname -I | awk '{print \$1}'):5678 (n8n), :9001 (MinIO), :11434 (Ollama)"
echo ""
