#!/usr/bin/env bash
# oracle-e2e-test.sh — SA → bus → PA message roundtrip
set -uo pipefail
CORR="e2e-$(date +%s)-$$"
FROM="sa-infra"
TO="pa-inbox"
SUBJECT="task:e2e-verify"
BODY="corr-id=$CORR timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "[E2E] sending $FROM → $TO (corr=$CORR)"
bash "$(dirname "$0")/../network/bus.sh" send "$TO" med "$SUBJECT" "$BODY" "$FROM" "$CORR" 2>&1 | tail -3

sleep 1
echo "[E2E] checking pa-inbox/med for $CORR"
RECV=$(ls /tmp/manusat-bus/pa-inbox/med/ 2>/dev/null | xargs -I{} grep -l "$CORR" /tmp/manusat-bus/pa-inbox/med/{} 2>/dev/null | head -1)

if [ -n "$RECV" ]; then
  echo "[E2E] ✅ PASS — message at $RECV"
  cat "$RECV"
  exit 0
else
  echo "[E2E] ❌ FAIL — corr-id $CORR not found in pa-inbox/med/"
  echo "--- pa-inbox/med contents ---"
  ls -la /tmp/manusat-bus/pa-inbox/med/ 2>/dev/null
  exit 1
fi
