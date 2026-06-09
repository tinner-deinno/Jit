#!/usr/bin/env bash
# auto-cleanup-stale-tickets.sh — Implement the SOP
set -uo pipefail
TICKETS_DIR="${TICKETS_DIR:-/workspaces/Jit/mirror/aoengaoey/.tickets}"
LOG="/tmp/cmdteam/auto-cleanup.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
STALE_DAYS="${STALE_DAYS:-7}"

[[ -d "$TICKETS_DIR" ]] || { echo "[$TS] tickets dir missing: $TICKETS_DIR" >> "$LOG"; exit 0; }

stale=0
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  if grep -qE "status:[[:space:]]*[\"']?in-progress[\"']?" "$f"; then
    if [[ -n "$(find "$f" -mtime +${STALE_DAYS} 2>/dev/null)" ]]; then
      id=$(grep -m1 "^id:" "$f" | awk '{print $2}')
      assignee=$(grep -m1 "^assignee:" "$f" | awk '{print $2}')
      echo "[$TS] STALE: $id ($f) assignee=$assignee" >> "$LOG"
      stale=$((stale+1))
    fi
  fi
done < <(find "$TICKETS_DIR" -name '*.md' 2>/dev/null)

echo "[$TS] auto-cleanup done (stale=$stale)" >> "$LOG"
