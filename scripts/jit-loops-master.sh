#!/usr/bin/env bash
# jit-loops-master.sh — Master scheduler for all Jit background loops
# - Status check every 15m (writes /tmp/cmdteam/jit-status.json)
# - Token burn check every 5m
# - Auto-restart any dead loops
# - Heartbeat to Oracle every 30m
set -uo pipefail

JIT_ROOT="/workspaces/Jit"
LOG="/tmp/cmdteam/jit-master.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Define all loops
declare -A LOOPS=(
  ["cleanup"]="/workspaces/Jit/scripts/cmdteam-cleanup-loop.sh|3600"
  ["self-improve"]="/workspaces/Jit/scripts/cmdteam-self-improve-loop.sh|7200"
  ["status-daemon"]="/workspaces/Jit/scripts/cmdteam-status-daemon.sh|900"
  ["writer"]="/workspaces/Jit/scripts/writer-loop.sh|3600"
  ["housekeeping"]="/workspaces/Jit/scripts/housekeeping-loop.sh|3600"
  ["pattern-detector"]="/workspaces/Jit/scripts/pattern-detector-loop.sh|900"
  ["status-broadcaster"]="/workspaces/Jit/scripts/status-broadcaster-loop.sh|900"
)

# Check which loops are alive
alive=0
dead=0
dead_names=""
for name in "${!LOOPS[@]}"; do
  IFS='|' read -r script interval <<< "${LOOPS[$name]}"
  if pgrep -f "$(basename "$script")" >/dev/null 2>&1; then
    alive=$((alive+1))
  else
    dead=$((dead+1))
    dead_names="$dead_names $name"
  fi
done

# Token burn check
total_calls=$(wc -l < /tmp/cmdteam/usage.jsonl 2>/dev/null || echo 0)
err_count=$(grep -c '"error"' /tmp/cmdteam/usage.jsonl 2>/dev/null || echo 0)
err_pct=$(( err_count * 100 / (total_calls + 1) ))

# Status JSON
cat > /tmp/cmdteam/jit-status.json << EOF
{
  "ts": "$TS",
  "loops": {
    "alive": $alive,
    "dead": $dead,
    "dead_names": "$dead_names",
    "total": ${#LOOPS[@]}
  },
  "calls": {
    "total": $total_calls,
    "errors": $err_count,
    "error_pct": $err_pct
  }
}
EOF

echo "[$TS] master_check alive=$alive dead=$dead err=${err_pct}%" >> "$LOG"

# Auto-restart dead loops
if [[ $dead -gt 0 ]]; then
  echo "[$TS] restarting dead loops:$dead_names" >> "$LOG"
  for name in $dead_names; do
    spec="${LOOPS[$name]}"
    script=$(echo "$spec" | cut -d'|' -f1)
    interval=$(echo "$spec" | cut -d'|' -f2)
    setsid bash -c "while true; do $script >> /tmp/cmdteam/${name}-loop.log 2>&1; sleep $interval; done" </dev/null >/dev/null 2>&1 &
    disown
    echo "[$TS] restarted: $name (interval=${interval}s)" >> "$LOG"
  done
fi
