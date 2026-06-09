#!/usr/bin/env bash
# Auto-organize: move loose files in /tmp, /workspaces/Jit root, into proper dirs
set -uo pipefail
JIT_ROOT="/workspaces/Jit"
LOG="/tmp/cmdteam/cleanup-actions.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "[$TS] cleanup start" >> "$LOG"

# 1. Move orphan .log files in Jit root to /tmp/cmdteam/
moved=0
for f in "$JIT_ROOT"/*.log "$JIT_ROOT"/*.tmp; do
  [[ -f "$f" ]] || continue
  bn=$(basename "$f")
  mv "$f" "/tmp/cmdteam/$bn" 2>/dev/null && { echo "[$TS] moved $bn → /tmp/cmdteam/" >> "$LOG"; moved=$((moved+1)); }
done

# 2. Remove old >7d log files
for f in /tmp/cmdteam/*.log /tmp/cmdteam/*.jsonl; do
  [[ -f "$f" ]] || continue
  age=$(find "$f" -mtime +7 2>/dev/null | head -1)
  [[ -n "$age" ]] && rm "$f" && echo "[$TS] removed old $f" >> "$LOG"
done

# 3. Disk usage
du -sh "$JIT_ROOT" /tmp/cmdteam 2>/dev/null | head -3 >> "$LOG"
echo "[$TS] cleanup done (moved=$moved)" >> "$LOG"
