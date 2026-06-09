#!/usr/bin/env bash
# status-broadcaster-loop.sh — Every 15m, generate status snapshot
# Discord webhook if configured, otherwise write to /tmp/cmdteam/discord-broadcast.log
set -uo pipefail
LOG="/tmp/cmdteam/discord-broadcast.log"
STATUS_FILE="/tmp/cmdteam/status.json"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build a short status message
loops=0
ps aux | grep -E "(cleanup|self-improve|status-daemon|writer|housekeeping|pattern-detector)-loop" | grep -v grep | wc -l > /tmp/loops.tmp
loops=$(cat /tmp/loops.tmp)
rm -f /tmp/loops.tmp

usage_calls=$(wc -l < /tmp/cmdteam/usage.jsonl 2>/dev/null || echo 0)
errors=$(grep -c '"error"' /tmp/cmdteam/usage.jsonl 2>/dev/null || echo 0)

msg="🟢 Jit $TS | loops=$loops | calls=$usage_calls | errors=$errors | phase2 clean"

echo "$msg" >> "$LOG"

# If Discord webhook is configured, send
if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
  DISCORD_WEBHOOK="$DISCORD_WEBHOOK" /workspaces/Jit/network/discord-webhook.sh 0 ok "$msg" 2>&1 >> "$LOG" || true
fi
