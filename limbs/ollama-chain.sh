#!/usr/bin/env bash
# limbs/ollama-chain.sh — Ollama Multi-Agent Chain Pipeline
#
# ส่งงานเป็นทอดๆ ผ่าน MDES Ollama models หลายตัว
# Pattern: Discuss → Plan → Execute → Verify
#
# Usage:
#   ollama-chain.sh call <model> "<prompt>"
#   ollama-chain.sh chain "<task>" [model1] [model2] [model3] [model4]
#   ollama-chain.sh web-read "<url>" "<question>"
#   ollama-chain.sh pipe "<prompt>" <model1> <model2>
#   ollama-chain.sh parallel "<prompt>" <model1> <model2> [model3]
#   ollama-chain.sh list-models

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="${SCRIPT_DIR}/.."

# Load .env
if [ -f "$JIT_ROOT/.env" ]; then
  set -a; source "$JIT_ROOT/.env"; set +a
fi

OLLAMA_BASE="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}"
TOKEN="${OLLAMA_TOKEN:-}"
ORACLE_URL="http://localhost:${ORACLE_PORT:-47778}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CHAIN_LOG="/tmp/ollama-chain-${TIMESTAMP}.log"

# ─── Defaults ────────────────────────────────────────────────────────────────
DEFAULT_DISCUSS_MODEL="qwen3.5:9b"
DEFAULT_PLAN_MODEL="gemma4:26b"
DEFAULT_EXECUTE_MODEL="qwen2.5-coder:32b"
DEFAULT_VERIFY_MODEL="qwen3.5:27b"

# ─── Helpers ─────────────────────────────────────────────────────────────────
_log() { echo "[chain:$(date +%H:%M:%S)] $*" | tee -a "$CHAIN_LOG" >&2; }
_ok()  { echo "✅ $*" | tee -a "$CHAIN_LOG"; }
_err() { echo "❌ ERROR: $*" | tee -a "$CHAIN_LOG" >&2; exit 1; }
_sep() { echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" | tee -a "$CHAIN_LOG"; }

# ─── Core: Call single Ollama model ──────────────────────────────────────────
_call_model() {
  local MODEL="$1"
  local PROMPT="$2"
  local TIMEOUT="${3:-90}"

  _log "→ Calling model: $MODEL (timeout: ${TIMEOUT}s)"

  local BODY
  BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'model': '$MODEL',
    'prompt': sys.stdin.read(),
    'stream': False
}))
" <<< "$PROMPT")

  local HEADERS=(-H "Content-Type: application/json")
  if [ -n "$TOKEN" ]; then
    HEADERS+=(-H "Authorization: Bearer $TOKEN")
  fi

  local RESPONSE
  RESPONSE=$(curl -s --max-time "$TIMEOUT" \
    "${HEADERS[@]}" \
    --data "$BODY" \
    "${OLLAMA_BASE}/api/generate" 2>/dev/null) || { _log "⚠ Model $MODEL timeout/error"; echo ""; return 1; }

  if [ -z "$RESPONSE" ]; then
    _log "⚠ Empty response from $MODEL"
    echo ""
    return 1
  fi

  local RESULT
  RESULT=$(echo "$RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('response', ''))
except Exception as e:
    print('', end='')
" 2>/dev/null)

  echo "$RESULT"
}

# ─── Oracle learn helper ──────────────────────────────────────────────────────
_oracle_learn() {
  local PATTERN="$1"
  local CONTENT="$2"
  local CONCEPTS="${3:-ollama-chain,multiagent}"

  curl -s -X POST "${ORACLE_URL}/api/learn" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json, sys
print(json.dumps({
    'pattern': '$PATTERN',
    'content': sys.stdin.read(),
    'concepts': '$CONCEPTS'.split(','),
    'agent': 'ollama-chain'
}))
" <<< "$CONTENT")" > /dev/null 2>&1 || true
}

# ─── CMD: list-models ────────────────────────────────────────────────────────
cmd_list_models() {
  echo "📋 MDES Ollama Models:"
  curl -s --max-time 10 "${OLLAMA_BASE}/api/tags" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(f\"  • {m['name']}\")
" 2>/dev/null || echo "  ⚠ Cannot reach Ollama"
}

# ─── CMD: call — single model ─────────────────────────────────────────────────
cmd_call() {
  local MODEL="${1:?Model required}"
  local PROMPT="${2:?Prompt required}"

  _log "Single call: $MODEL"
  _sep
  local RESULT
  RESULT=$(_call_model "$MODEL" "$PROMPT" 90)
  echo "$RESULT"
  _sep
  echo "$RESULT"
}

# ─── CMD: chain — Discuss→Plan→Execute→Verify ─────────────────────────────────
cmd_chain() {
  local TASK="${1:?Task required}"
  local MODEL_DISCUSS="${2:-$DEFAULT_DISCUSS_MODEL}"
  local MODEL_PLAN="${3:-$DEFAULT_PLAN_MODEL}"
  local MODEL_EXECUTE="${4:-$DEFAULT_EXECUTE_MODEL}"
  local MODEL_VERIFY="${5:-$DEFAULT_VERIFY_MODEL}"

  echo "" | tee -a "$CHAIN_LOG"
  echo "🔗 OLLAMA MULTI-AGENT CHAIN" | tee -a "$CHAIN_LOG"
  echo "📋 Task: ${TASK:0:100}..." | tee -a "$CHAIN_LOG"
  echo "🤖 Models: $MODEL_DISCUSS → $MODEL_PLAN → $MODEL_EXECUTE → $MODEL_VERIFY" | tee -a "$CHAIN_LOG"
  _sep

  # ── STEP 1: DISCUSS ──────────────────────────────────────────────────────
  echo "" | tee -a "$CHAIN_LOG"
  echo "💬 [STEP 1/4: DISCUSS] Model: $MODEL_DISCUSS" | tee -a "$CHAIN_LOG"
  _sep

  local DISCUSS_PROMPT="You are Sub-Agent 1 (Discuss). Your role: clarify the task, identify ambiguities, and outline key requirements.

TASK: $TASK

Discuss:
1. What exactly is being asked?
2. What are the key requirements or constraints?
3. What information or approach is needed?
4. Any risks or edge cases?

Be concise. Output structured discussion points."

  local DISCUSS_OUT
  DISCUSS_OUT=$(_call_model "$MODEL_DISCUSS" "$DISCUSS_PROMPT" 90)
  echo "$DISCUSS_OUT" | tee -a "$CHAIN_LOG"
  _ok "Discuss complete"

  # ── STEP 2: PLAN ─────────────────────────────────────────────────────────
  echo "" | tee -a "$CHAIN_LOG"
  echo "📐 [STEP 2/4: PLAN] Model: $MODEL_PLAN" | tee -a "$CHAIN_LOG"
  _sep

  local PLAN_PROMPT="You are Sub-Agent 2 (Plan). Your role: create a detailed, actionable plan.

ORIGINAL TASK: $TASK

DISCUSSION FROM SUB-AGENT 1:
$DISCUSS_OUT

Create a numbered step-by-step plan to accomplish this task. Be specific and actionable."

  local PLAN_OUT
  PLAN_OUT=$(_call_model "$MODEL_PLAN" "$PLAN_PROMPT" 90)
  echo "$PLAN_OUT" | tee -a "$CHAIN_LOG"
  _ok "Plan complete"

  # ── STEP 3: EXECUTE ──────────────────────────────────────────────────────
  echo "" | tee -a "$CHAIN_LOG"
  echo "⚡ [STEP 3/4: EXECUTE] Model: $MODEL_EXECUTE" | tee -a "$CHAIN_LOG"
  _sep

  local EXECUTE_PROMPT="You are Sub-Agent 3 (Execute). Your role: produce the actual output.

ORIGINAL TASK: $TASK

PLAN FROM SUB-AGENT 2:
$PLAN_OUT

Execute the plan and produce the final output. Be thorough and complete."

  local EXECUTE_OUT
  EXECUTE_OUT=$(_call_model "$MODEL_EXECUTE" "$EXECUTE_PROMPT" 120)
  echo "$EXECUTE_OUT" | tee -a "$CHAIN_LOG"
  _ok "Execute complete"

  # ── STEP 4: VERIFY ───────────────────────────────────────────────────────
  echo "" | tee -a "$CHAIN_LOG"
  echo "🔍 [STEP 4/4: VERIFY] Model: $MODEL_VERIFY" | tee -a "$CHAIN_LOG"
  _sep

  local VERIFY_PROMPT="You are Sub-Agent 4 (Verify). Your role: review and validate the output.

ORIGINAL TASK: $TASK

OUTPUT FROM SUB-AGENT 3:
$EXECUTE_OUT

Verify:
1. Is the output complete and correct?
2. Does it fully address the original task?
3. Quality score (1-10) with reasoning
4. Any suggested improvements or issues?

Be honest and constructive."

  local VERIFY_OUT
  VERIFY_OUT=$(_call_model "$MODEL_VERIFY" "$VERIFY_PROMPT" 90)
  echo "$VERIFY_OUT" | tee -a "$CHAIN_LOG"
  _ok "Verify complete"

  # ── SUMMARY ──────────────────────────────────────────────────────────────
  _sep
  echo "" | tee -a "$CHAIN_LOG"
  echo "✅ CHAIN COMPLETE" | tee -a "$CHAIN_LOG"
  echo "📝 Log: $CHAIN_LOG" | tee -a "$CHAIN_LOG"

  # Save to Oracle if running
  local CHAIN_SUMMARY="Chain task: ${TASK:0:200}
Models: $MODEL_DISCUSS → $MODEL_PLAN → $MODEL_EXECUTE → $MODEL_VERIFY
Result excerpt: ${EXECUTE_OUT:0:500}"
  _oracle_learn "chain-${TIMESTAMP}" "$CHAIN_SUMMARY" "ollama-chain,multiagent,$(echo $MODEL_EXECUTE | tr ':' '-')"

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "FINAL OUTPUT (from Execute step):"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$EXECUTE_OUT"
}

# ─── CMD: web-read — Fetch URL then chain ────────────────────────────────────
cmd_web_read() {
  local URL="${1:?URL required}"
  local QUESTION="${2:-สรุปสาระสำคัญของหน้าเว็บนี้}"

  echo "🌐 WEB-READ CHAIN" | tee -a "$CHAIN_LOG"
  echo "URL: $URL" | tee -a "$CHAIN_LOG"
  echo "Question: $QUESTION" | tee -a "$CHAIN_LOG"
  _sep

  # Fetch page content using curl (text only)
  _log "Fetching URL: $URL"
  local PAGE_CONTENT
  PAGE_CONTENT=$(curl -s --max-time 30 \
    -H "User-Agent: Mozilla/5.0 (compatible; JitAgent/1.0)" \
    "$URL" 2>/dev/null | \
    python3 -c "
import sys, re
html = sys.stdin.read()
# Remove scripts, styles, tags
html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL|re.IGNORECASE)
html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL|re.IGNORECASE)
html = re.sub(r'<[^>]+>', ' ', html)
html = re.sub(r'&[a-zA-Z]+;', ' ', html)
html = re.sub(r'\s+', ' ', html).strip()
# Limit to first 4000 chars to avoid token overflow
print(html[:4000])
" 2>/dev/null) || PAGE_CONTENT="Cannot fetch page"

  if [ -z "$PAGE_CONTENT" ] || [ "$PAGE_CONTENT" = "Cannot fetch page" ]; then
    _log "⚠ Could not fetch page content, proceeding with URL only"
    PAGE_CONTENT="URL: $URL (content unavailable - analyze based on URL)"
  fi

  _log "Page content fetched: ${#PAGE_CONTENT} chars"

  local TASK="Read and analyze this web page content.
URL: $URL
QUESTION: $QUESTION

PAGE CONTENT:
$PAGE_CONTENT"

  cmd_chain "$TASK" \
    "${DEFAULT_DISCUSS_MODEL}" \
    "${DEFAULT_PLAN_MODEL}" \
    "qwen3.5:27b" \
    "${DEFAULT_VERIFY_MODEL}"
}

# ─── CMD: pipe — 2-model quick pipeline ──────────────────────────────────────
cmd_pipe() {
  local PROMPT="${1:?Prompt required}"
  local MODEL1="${2:-$DEFAULT_PLAN_MODEL}"
  local MODEL2="${3:-$DEFAULT_VERIFY_MODEL}"

  echo "⚡ PIPE: $MODEL1 → $MODEL2" | tee -a "$CHAIN_LOG"
  _sep

  _log "Step 1: $MODEL1"
  local OUT1
  OUT1=$(_call_model "$MODEL1" "$PROMPT" 90)
  echo "$OUT1" | tee -a "$CHAIN_LOG"

  _sep
  _log "Step 2: $MODEL2 (reviewing above)"
  local PROMPT2="Review and improve this output:

ORIGINAL PROMPT: $PROMPT

OUTPUT TO REVIEW:
$OUT1

Provide final improved version."
  local OUT2
  OUT2=$(_call_model "$MODEL2" "$PROMPT2" 90)
  echo "$OUT2" | tee -a "$CHAIN_LOG"

  _sep
  echo "✅ Pipe complete. Log: $CHAIN_LOG"
  echo "$OUT2"
}

# ─── CMD: parallel — run multiple models at once ─────────────────────────────
cmd_parallel() {
  local PROMPT="${1:?Prompt required}"
  shift
  local MODELS=("$@")
  [ ${#MODELS[@]} -eq 0 ] && MODELS=("$DEFAULT_DISCUSS_MODEL" "$DEFAULT_PLAN_MODEL" "$DEFAULT_EXECUTE_MODEL")

  echo "🔀 PARALLEL: ${MODELS[*]}" | tee -a "$CHAIN_LOG"
  _sep

  local PIDS=()
  local TMPFILES=()

  for MODEL in "${MODELS[@]}"; do
    local TMP
    TMP=$(mktemp /tmp/ollama-parallel-XXXXXX)
    TMPFILES+=("$TMP")
    (
      _log "Starting $MODEL..."
      local OUT
      OUT=$(_call_model "$MODEL" "$PROMPT" 90)
      echo "=== $MODEL ===" > "$TMP"
      echo "$OUT" >> "$TMP"
    ) &
    PIDS+=($!)
  done

  # Wait for all
  for PID in "${PIDS[@]}"; do
    wait "$PID" 2>/dev/null || true
  done

  echo "" | tee -a "$CHAIN_LOG"
  echo "📊 PARALLEL RESULTS:" | tee -a "$CHAIN_LOG"
  for TMP in "${TMPFILES[@]}"; do
    cat "$TMP" | tee -a "$CHAIN_LOG"
    echo ""
    rm -f "$TMP"
  done

  echo "✅ Parallel complete. Log: $CHAIN_LOG"
}

# ─── Main dispatcher ──────────────────────────────────────────────────────────
CMD="${1:-help}"
shift || true

case "$CMD" in
  call)         cmd_call "$@" ;;
  chain)        cmd_chain "$@" ;;
  web-read)     cmd_web_read "$@" ;;
  pipe)         cmd_pipe "$@" ;;
  parallel)     cmd_parallel "$@" ;;
  list-models)  cmd_list_models ;;
  help|*)
    cat << 'EOF'
🔗 ollama-chain.sh — Ollama Multi-Agent Chain Pipeline

Usage:
  ollama-chain.sh call <model> "<prompt>"
    Single model call

  ollama-chain.sh chain "<task>" [discuss_model] [plan_model] [execute_model] [verify_model]
    Full Discuss→Plan→Execute→Verify chain (defaults to qwen3.5:9b→gemma4:26b→qwen2.5-coder:32b→qwen3.5:27b)

  ollama-chain.sh web-read "<url>" "<question>"
    Fetch web page then analyze through 4-model chain

  ollama-chain.sh pipe "<prompt>" [model1] [model2]
    Quick 2-model pipeline: generate → review

  ollama-chain.sh parallel "<prompt>" <model1> <model2> [model3]
    Run multiple models in parallel, compare results

  ollama-chain.sh list-models
    Show all available MDES Ollama models

Examples:
  bash limbs/ollama-chain.sh chain "อธิบาย multiagent AI system"
  bash limbs/ollama-chain.sh web-read "https://github.com/Soul-Brews-Studio/arra-oracle-v3" "สรุป MCP tools"
  bash limbs/ollama-chain.sh call gemma4:26b "สวัสดี คุณเป็นใคร?"
  bash limbs/ollama-chain.sh list-models
EOF
    ;;
esac
