#!/usr/bin/env bash
# cmdteam-status-daemon.sh — run every 15 min
set -uo pipefail
STATE="/tmp/cmdteam/status.json"
CMDTEAM_LOG="/tmp/cmdteam/usage.jsonl"
COMMANDCODE_BASE="https://api.commandcode.ai/provider/v1"
OLLAMA_BASE="https://ollama.mdes-innova.online"
mkdir -p "$(dirname "$STATE")"

# 1. Health check via cmdteam (uses correct status semantics)
CMDTEAM_STATUS=$(/workspaces/Jit/cmdteam/cmdteam.sh status 2>/dev/null || echo '{"error":"cmdteam-down"}')

# 2. Quick individual reachability
ollama_code=$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$OLLAMA_BASE" 2>/dev/null || echo 000)
cc_code=$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "$COMMANDCODE_BASE" 2>/dev/null || echo 000)

# 3. Log stats
total=0; errors=0; claude_calls=0; openai_calls=0; ollama_calls=0
if [[ -f "$CMDTEAM_LOG" ]]; then
  total=$(wc -l < "$CMDTEAM_LOG" 2>/dev/null | tr -d ' ' || echo 0)
  errors=$(grep -c '"status":"error"' "$CMDTEAM_LOG" 2>/dev/null || echo 0)
  claude_calls=$(grep -c '"provider":"claude"' "$CMDTEAM_LOG" 2>/dev/null || echo 0)
  openai_calls=$(grep -c '"provider":"openai"' "$CMDTEAM_LOG" 2>/dev/null || echo 0)
  ollama_calls=$(grep -c '"provider":"ollama"' "$CMDTEAM_LOG" 2>/dev/null || echo 0)
fi

# 4. Write status JSON
{
  echo "{"
  echo "  \"ts\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"providers\": {"
  echo "    \"commandcode\": \"$cc_code\","
  echo "    \"ollama_mdes\": \"$ollama_code\""
  echo "  },"
  echo "  \"log_stats\": {"
  echo "    \"total_calls\": $total,"
  echo "    \"errors\": $errors,"
  echo "    \"claude_calls\": $claude_calls,"
  echo "    \"openai_calls\": $openai_calls,"
  echo "    \"ollama_calls\": $ollama_calls"
  echo "  },"
  echo "  \"cmdteam_status\": $(echo "$CMDTEAM_STATUS" | head -c 2000)"
  echo "}"
} > "$STATE"

echo "[status] $(date -u +%H:%M:%S) cc=$cc_code ollama=$ollama_code calls=$total err=$errors"
