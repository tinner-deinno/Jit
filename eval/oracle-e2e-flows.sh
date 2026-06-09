#!/usr/bin/env bash
# oracle-e2e-flows.sh — 3 production E2E flows
set -uo pipefail
PASS=0; FAIL=0
RESULTS=()

run_flow() {
  local name="$1" from="$2" to="$3" subject="$4" body="$5"
  local CORR="flow-$(date +%s)-$$-$RANDOM"
  echo ""
  echo "=== Flow: $name ($from → $to) corr=$CORR ==="
  bash "$(dirname "$0")/../network/bus.sh" send "$to" med "$subject" "$body" "$from" "$CORR" 2>&1 | tail -1
  sleep 1
  local recv
  recv=$(ls "/tmp/manusat-bus/${to}/med/" 2>/dev/null | xargs -I{} grep -l "$CORR" "/tmp/manusat-bus/${to}/med/{}" 2>/dev/null | head -1)
  if [ -n "$recv" ]; then
    echo "  PASS — $recv"
    PASS=$((PASS+1))
    RESULTS+=("PASS $name corr=$CORR")
  else
    echo "  FAIL — corr-id $CORR not in /tmp/manusat-bus/${to}/med/"
    FAIL=$((FAIL+1))
    RESULTS+=("FAIL $name corr=$CORR")
  fi
}

run_flow "security-alert" "sa-security" "jit" "alert:security-anomaly" "intrusion detected at 2026-06-10T01:45Z"
run_flow "schedule-reminder" "pa-schedule" "vaja" "task:schedule-reminder" "standup at 09:00 BKK"
run_flow "metrics-broadcast" "sa-observability" "sayanprasathan" "broadcast:metrics" "p99=450ms req/s=1200"

echo ""
echo "================================"
echo "PASS: $PASS  FAIL: $FAIL"
printf '%s\n' "${RESULTS[@]}"
echo "================================"
[ $FAIL -eq 0 ] && exit 0 || exit 1
