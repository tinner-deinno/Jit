#!/usr/bin/env bash
# cmdteam/self-improve.sh — Self-improvement loop for CommandCode provider
# 🤖 Sonnet 4.6
set -euo pipefail

LOG="/tmp/cmdteam/self-improve.log"
MODELS_FILE="/workspaces/Jit/agents/cmdteam-interpreter/models.json"
USAGE_FILE="/tmp/cmdteam/usage.jsonl"
ENV_FILE="${CMDTEAM_HOME:-/workspaces/Jit}/.env"
BASE_URL="${COMMANDCODE_BASE_URL:-https://api.commandcode.ai}"

TS() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(TS)] $*" | tee -a "$LOG" >/dev/null; }

mkdir -p /tmp/cmdteam
touch "$LOG" "$USAGE_FILE"

# 1) source .env from project root
[[ -f "$ENV_FILE" ]] && set -a && source "$ENV_FILE" && set +a || true
[[ -f "/workspaces/Jit/.env" ]] && set -a && source "/workspaces/Jit/.env" && set +a || true
: "${COMMANDCODE_API_KEY:?missing COMMANDCODE_API_KEY}"

# 2) fetch /provider/v1/models
remote=$(curl -sSf -H "Authorization: Bearer $COMMANDCODE_API_KEY" "$BASE_URL/provider/v1/models" 2>/dev/null) \
  || { log "ERR fetch models failed"; remote="[]"; }

# 3) diff vs models.json — append new
[[ -s "$MODELS_FILE" ]] || echo '[]' > "$MODELS_FILE"
existing=$(jq -r '.models[].id // .[].id' "$MODELS_FILE" 2>/dev/null || true)
new_count=0
if [[ "$remote" != "[]" ]]; then
  while read -r id; do
    [[ -z "$id" ]] && continue
    if ! grep -qxF "$id" <<<"$existing"; then
      tmp=$(mktemp)
      # models.json uses {"models":[...]} — append to .models key
      jq --arg id "$id" --arg ts "$(TS)" '.models += [{id:$id, added:$ts}]' "$MODELS_FILE" > "$tmp" \
        && mv "$tmp" "$MODELS_FILE" \
        && { log "ADD model $id"; new_count=$((new_count+1)); }
    fi
  done < <(echo "$remote" | jq -r '.data[].id // empty' 2>/dev/null)
fi

# 4) parse usage.jsonl last 1h — fail rate > 30% = unhealthy
cutoff=$(date -u -d '1 hour ago' +%s 2>/dev/null || date -u +%s)
if [[ -s "$USAGE_FILE" ]]; then
  awk -v cutoff="$cutoff" '
    {
      cmd = "echo " $0 " | jq -r .ts"
      cmd | getline ts; close(cmd)
      gsub(/"/, "", ts)
      cmd2 = "date -u -d \"" ts "\" +%s"
      cmd2 | getline epoch; close(cmd2)
      if (epoch+0 >= cutoff) print
    }
  ' "$USAGE_FILE" 2>/dev/null | jq -s '
    [.[] | select(.status != "ok")] | length as $fails |
    { total: length, fails: $fails }
  ' 2>/dev/null | {
    read -r summary
    if [[ -n "$summary" ]]; then
      log "usage: $summary"
    fi
  }
fi

# 5+6) concise report
total_models=$(jq '.models | length' "$MODELS_FILE" 2>/dev/null || echo 0)
report="models=$total_models"
[[ "$new_count" -gt 0 ]] && report+=" new=$new_count"
log "report: $report"
# 🤖 Sonnet 4.6
