#!/usr/bin/env bash
# Diagnostyka xRDP – uruchom PO nieudanej próbie logowania.
# Użycie: sudo ./diagnose_xrdp.sh
# Wynik zapisze do diagnose_xrdp_$(date +%s).txt

set -e
OUT="diagnose_xrdp_$(date +%s).txt"

{
  echo "=== xrdp-sesman.log (ostatnie 100 linii) ==="
  tail -100 /var/log/xrdp-sesman.log 2>/dev/null || echo "(brak pliku)"
  echo ""
  echo "=== xrdp.log (ostatnie 50 linii) ==="
  tail -50 /var/log/xrdp.log 2>/dev/null || echo "(brak pliku)"
  echo ""
  echo "=== startwm.sh ==="
  head -30 /etc/xrdp/startwm.sh 2>/dev/null || true
  echo ""
  echo "=== ~/.xsession (dla użytkownika) ==="
  for u in Wilk $(logname 2>/dev/null) root; do
    h=$(getent passwd "$u" 2>/dev/null | cut -d: -f6)
    [[ -n "$h" ]] && { echo "--- $u ($h) ---"; cat "$h/.xsession" 2>/dev/null || echo "(brak)"; }
  done
  echo ""
  echo "=== systemctl xrdp ==="
  systemctl status xrdp xrdp-sesman --no-pager 2>/dev/null || true
  echo ""
  echo "=== grupa xrdp ==="
  getent group xrdp
  for u in Wilk $(logname 2>/dev/null); do groups "$u" 2>/dev/null || true; done
} 2>&1 | tee "$OUT"
echo ""
echo "Zapisano do: $OUT"
