#!/usr/bin/env bash
# ============================================================
#  mind-loop.sh — MDES Ollama Single-Agent Continuous Loop
#  Usage: bash mind-loop.sh <NAME> <MODEL> <ROLE> [INTERVAL]
# ============================================================
set -uo pipefail

JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
ENV_FILE="$JIT_ROOT/.env"
[[ -f "$ENV_FILE" ]] && while IFS='=' read -r k v; do
  [[ "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]] && [[ -n "$v" ]] && export "$k=${v//\"/}"
done < <(grep -E '^[A-Z_][A-Z0-9_]*=' "$ENV_FILE" 2>/dev/null)

AGENT_NAME="${1:-AGENT}"
MODEL="${2:-gemma4:e4b}"
ROLE="${3:-A helpful AI assistant}"
INTERVAL="${4:-90}"
OLLAMA_URL="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
BUS_DIR="/tmp/manusat-bus"
LOG_FILE="/tmp/agent-${AGENT_NAME,,}.log"

mkdir -p "$BUS_DIR"

# ── ANSI Colors ──────────────────────────────────────────────
declare -A _CLRS
_CLRS[INNOVA]='\033[1;35m'       # Magenta bold (mother)
_CLRS[PLANNER]='\033[1;36m'      # Cyan bold
_CLRS[CODER]='\033[1;32m'        # Green bold
_CLRS[RESEARCHER]='\033[1;34m'   # Blue bold
_CLRS[REVIEWER]='\033[1;33m'     # Yellow bold
_CLRS[EMOTION]='\033[1;31m'      # Red bold
_CLRS[ORACLE]='\033[0;37m'       # White
_CLRS[GSD]='\033[1;96m'          # Bright cyan (GSD node)
CLR="${_CLRS[$AGENT_NAME]:-\033[1;37m}"
DIM='\033[2m'
BLD='\033[1m'
NC='\033[0m'

CYCLE=0
LAST_THOUGHT=""

print_header() {
  local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
  local short_role="${ROLE:0:52}"
  printf '\033[H\033[2J'   # clear
  printf "${CLR}"
  printf '╔══════════════════════════════════════════════════════════════╗\n'
  printf '║  %-62s║\n' "🤖  $AGENT_NAME  ·  MODEL: $MODEL"
  printf '║  %-62s║\n' "📋  $short_role"
  printf '║  %-62s║\n' "🔄  Cycle #$CYCLE  ·  $ts"
  printf '╠══════════════════════════════════════════════════════════════╣\n'
  printf "${NC}"
}

call_ollama() {
  local prompt="$1"
  local payload
  payload=$(python3 - <<PYEOF
import json, sys
print(json.dumps({
  "model": "$MODEL",
  "prompt": """$prompt""",
  "stream": False,
  "options": {"num_predict": 120, "temperature": 0.75, "top_p": 0.9}
}))
PYEOF
)
  local resp
  resp=$(curl -sf -X POST \
    "${OLLAMA_URL}/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN}" \
    --data "$payload" \
    --max-time 45 2>/dev/null)
  if [[ -z "$resp" ]]; then
    echo "[no response — API timeout or unreachable]"
    return
  fi
  echo "$resp" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  print(d.get('response','[empty]').strip())
except Exception as e:
  print(f'[parse error: {e}]')
"
}

read_bus() {
  local ctx=""
  for f in "$BUS_DIR"/*.msg; do
    [[ -f "$f" ]] || continue
    local src; src=$(basename "$f" .msg | tr '[:lower:]' '[:upper:]')
    [[ "$src" == "$AGENT_NAME" ]] && continue
    ctx+="[$src]: $(tail -1 "$f") | "
  done
  echo "${ctx:0:300}"
}

write_bus() {
  echo "$1" > "$BUS_DIR/${AGENT_NAME,,}.msg"
}

# ── Main Loop ────────────────────────────────────────────────
echo -e "${CLR}[${AGENT_NAME}] Starting mind-loop (model=$MODEL interval=${INTERVAL}s)${NC}"

while true; do
  CYCLE=$((CYCLE + 1))
  print_header

  BUS_CTX=$(read_bus)
  [[ -z "$BUS_CTX" ]] && BUS_CTX="System start — no messages yet."

  PROMPT="CYCLE ${CYCLE}: You are ${AGENT_NAME}, ${ROLE}.
Bus context: ${BUS_CTX}
Previous thought: ${LAST_THOUGHT:0:100}
Give a 2-sentence status update: what you are observing and one concrete action you are taking right now.
Be specific, avoid repetition. Keep it under 80 words."

  printf "${CLR}[THINKING]${NC} querying $MODEL...\n"
  RESPONSE=$(call_ollama "$PROMPT")
  LAST_THOUGHT="$RESPONSE"

  printf "\n${CLR}┌─ ${AGENT_NAME} @ $(date '+%H:%M:%S') ──────────────────────────────┐${NC}\n"
  echo "$RESPONSE" | fold -s -w 62 | while IFS= read -r line; do
    printf "${BLD}│${NC} %s\n" "$line"
  done
  printf "${CLR}└──────────────────────────────────────────────────────────┘${NC}\n"

  write_bus "$RESPONSE"
  printf '[%s] CYCLE#%d | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$CYCLE" "$RESPONSE" >> "$LOG_FILE"

  printf "\n${DIM}[Next cycle in ${INTERVAL}s — Ctrl+C to stop]${NC}\n"
  sleep "$INTERVAL"
done
