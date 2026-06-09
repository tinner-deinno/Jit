#!/usr/bin/env bash
# limbs/ollama.sh — วิริยะ (Right Effort): ความพยายามชอบผ่าน MDES Ollama
#
# หลักพุทธ: สัมมาวายามะ (Right Effort) — ใช้ปัญญาสร้างสรรค์
# "ความพยายามที่ดีคือใช้ให้ถูกทาง ไม่มากเกิน ไม่น้อยเกิน"
#
# JIT-015: Multi-Model Fallback Chain
#   - MODEL_CHAIN env var: comma-separated model list
#   - Auto-retry on timeout/5xx with next model
#   - Log each attempt: timestamp, model, latency, success/fail
#   - Emit fallback events to bus for Oracle tracking
#   - OLLAMA_TIMEOUT_SEC configurable per attempt
#
# Usage:
#   ./ollama.sh ask "prompt"              — ถาม Ollama ตรงๆ
#   ./ollama.sh think "prompt" "context" — ถามพร้อม context จาก Oracle
#   ./ollama.sh create "งาน" "กรอบ"      — สร้างสรรค์ใหม่
#   ./ollama.sh translate "ข้ความ"      — แปล/อธิบาย
#   ./ollama.sh status                   — ทดสอบ connection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="${SCRIPT_DIR}/.."
source "$SCRIPT_DIR/lib.sh"

# Load .env if it exists (for OLLAMA_TOKEN and other config)
if [ -f "$JIT_ROOT/.env" ]; then
  set -a; source "$JIT_ROOT/.env"; set +a
fi

CMD="${1:-ask}"
shift || true

# ── JIT-015: Multi-Model Fallback Configuration ─────────────────────
MODEL_CHAIN="${MODEL_CHAIN:-${OLLAMA_MODEL:-gemma4:26b}}"
OLLAMA_TIMEOUT_SEC="${OLLAMA_TIMEOUT_SEC:-30}"
IFS=',' read -ra MODELS <<< "$MODEL_CHAIN"

# Log file for model attempts
MODEL_ATTEMPTS_LOG="$(resolve_log_dir)/ollama-model-attempts.log"
ensure_log_dir

# Log model attempt with timestamp, model, latency, result
log_model_attempt() {
  local MODEL="$1" LATENCY="$2" RESULT="$3" DETAILS="${4:-}"
  local TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S.%3N')
  ensure_log_dir
  echo "[$TIMESTAMP] model=$MODEL latency=${LATENCY}s result=$RESULT $DETAILS" >> "$MODEL_ATTEMPTS_LOG"
}

# Emit fallback event to bus for Oracle tracking
# Subject: learn:model-fallback
emit_fallback_event() {
  local MODEL="$1" LATENCY="$2" RESULT="$3" ATTEMPT_NUM="$4" TOTAL_MODELS="$5"
  local EVENT_BODY="model_fallback_event|timestamp:$(date '+%Y-%m-%dT%H:%M:%S')|model:$MODEL|latency:${LATENCY}s|result:$RESULT|attempt:$ATTEMPT_NUM/$TOTAL_MODELS"

  # Send to bus if available
  if [ -x "$SCRIPT_DIR/../network/bus.sh" ]; then
    bash "$SCRIPT_DIR/../network/bus.sh" send innova "learn:model-fallback" "$EVENT_BODY" >/dev/null 2>&1 || true
  fi

  # Also log to action log
  log_action "MODEL_FALLBACK" "model:$MODEL latency:${LATENCY}s result:$RESULT attempt:$ATTEMPT_NUM/$TOTAL_MODELS"
}

# Call Ollama with fallback chain support
# Returns: response on success, exits 1 on all models failed
_call_ollama_with_fallback() {
  local PROMPT="$1"
  local TIMEOUT="${2:-$OLLAMA_TIMEOUT_SEC}"
  local ATTEMPT_NUM=0
  local TOTAL_MODELS=${#MODELS[@]}

  log_action "OLLAMA_CHAIN_START" "models:${MODELS[*]} prompt:${PROMPT:0:50}..."

  for MODEL in "${MODELS[@]}"; do
    ATTEMPT_NUM=$((ATTEMPT_NUM + 1))
    local START_TIME=$(date +%s.%N)
    local ATTEMPT_TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S.%3N')

    step "Trying model[$ATTEMPT_NUM/$TOTAL_MODELS]: $MODEL (timeout:${TIMEOUT}s)..."

    # Build JSON body
    local JSON_BODY
    JSON_BODY=$(printf '%s' "$PROMPT" | python3 -c "import sys, json; print(json.dumps({'model':'$MODEL', 'prompt':sys.stdin.read(), 'stream':False}))")

    # Call Ollama API
    # JIT-021: Pass headers via stdin (not cmdline, not temp file) to hide token from ps aux + temp filesystem
    local RESPONSE HTTP_CODE CURL_STATUS
    RESPONSE=$(printf '%s\n' "Authorization: Bearer ${OLLAMA_TOKEN}" | curl -s --max-time "$TIMEOUT" \
      -w "\n%{http_code}" \
      "https://ollama.mdes-innova.online/api/generate" \
      -H "Content-Type: application/json" \
      -H @- \
      --data "$JSON_BODY" 2>/dev/null)

    CURL_STATUS=$?
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE=$(echo "$RESPONSE" | sed '$d')

    local END_TIME=$(date +%s.%N)
    local LATENCY
    LATENCY=$(echo "$END_TIME - $START_TIME" | bc 2>/dev/null || echo "N/A")

    # Check for success: curl status 0 AND non-empty response AND HTTP 2xx
    if [ $CURL_STATUS -eq 0 ] && [ -n "$RESPONSE" ] && [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
      log_model_attempt "$MODEL" "$LATENCY" "success" "attempt:$ATTEMPT_NUM/$TOTAL_MODELS http_code:$HTTP_CODE"
      emit_fallback_event "$MODEL" "$LATENCY" "success" "$ATTEMPT_NUM" "$TOTAL_MODELS"

      log_action "OLLAMA_CHAIN_SUCCESS" "model:$MODEL latency:${LATENCY}s attempt:$ATTEMPT_NUM/$TOTAL_MODELS"

      # Return response (extract just the text)
      echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('response', ''))" 2>/dev/null
      return 0
    else
      # Failed - log and continue to next model
      local FAIL_REASON="curl_status=$CURL_STATUS"
      if [ -n "$HTTP_CODE" ] && ! [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
        FAIL_REASON="http_code=$HTTP_CODE"
      fi

      log_model_attempt "$MODEL" "$LATENCY" "fail" "$FAIL_REASON attempt:$ATTEMPT_NUM/$TOTAL_MODELS"
      emit_fallback_event "$MODEL" "$LATENCY" "fail:$FAIL_REASON" "$ATTEMPT_NUM" "$TOTAL_MODELS"

      warn "Model $MODEL failed ($FAIL_REASON, latency:${LATENCY}s), trying next..."
    fi
  done

  # All models failed
  log_action "OLLAMA_CHAIN_FAILED" "all ${TOTAL_MODELS} models failed"
  err "All models in chain failed (tried: ${MODELS[*]})"
  return 1
}

case "$CMD" in

  # ── ถามตรงๆ ─────────────────────────────────────────────────────
  ask)
    PROMPT="$*"
    if [ -z "$PROMPT" ]; then err "ต้องระบุ prompt"; exit 1; fi
    step "ถาม Ollama (chain: ${MODELS[*]})..."
    _call_ollama_with_fallback "$PROMPT"
    ;;

  # ── ถามพร้อม context จาก Oracle ─────────────────────────────────
  think)
    QUESTION="$1" EXTRA_CONTEXT="${2:-}"
    ORACLE_WISDOM=""
    if oracle_ready; then
      ORACLE_WISDOM=$(oracle_search "$QUESTION" 2 2>/dev/null | tail -20)
    fi

    FULL_PROMPT="คุณคือ innova ผู้ช่วย AI ของ MDES Innova

Oracle บอกว่า:
$ORACLE_WISDOM

$EXTRA_CONTEXT

คำถาม: $QUESTION

ตอบสั้น กระชับ มีประโยชน์:"

    step "ถาม Ollama พร้อม Oracle context..."
    _call_ollama_with_fallback "$FULL_PROMPT" 60
    ;;

  # ── สร้างสรรค์ ──────────────────────────────────────────────────
  create)
    TASK="$1" FRAMEWORK="${2:-หลักพุทธ ไตรสิกขา}"
    FULL_PROMPT="คุณคือ innova นักพัฒนา AI ของ MDES Innova
หลักการ: $FRAMEWORK

งาน: $TASK

สร้างผลลัพธ์ที่มีประโยชน์จริงๆ:"

    step "Ollama กำลังสร้าง: $TASK"
    _call_ollama_with_fallback "$FULL_PROMPT" 90
    ;;

  # ── แปล/อธิบาย ──────────────────────────────────────────────────
  translate)
    TEXT="$*"
    FULL_PROMPT="แปลหรืออธิบายข้อความต่อไปนี้เป็ภาษาไทยที่เข้าใจง่าย:

$TEXT"
    step "Ollama แปล..."
    _call_ollama_with_fallback "$FULL_PROMPT" 30
    ;;

  # ── ทดสอบ connection ──────────────────────────────────────────────
  status)
    step "ทดสอบ Ollama connection ด้วย fallback chain..."
    info "Model chain: ${MODELS[*]}"
    info "Timeout per attempt: ${OLLAMA_TIMEOUT_SEC}s"
    echo ""
    RESULT=$(_call_ollama_with_fallback "สวัสดี ตอบสั้นๆ ว่าพร้อมทำงาน" 20 2>/dev/null)
    if [ -n "$RESULT" ]; then
      ok "Ollama พร้อม: ${RESULT:0:80}"
    else
      err "Ollama ไม่ตอบสนอง (ทุก model ใน chain ล้มเหลว)"
      exit 1
    fi
    ;;

  *)
    echo "Usage: ollama.sh <command>"
    echo ""
    echo "  ask       <prompt>              — ถาม Ollama ตรงๆ (ใช้ fallback chain)"
    echo "  think     <question> [context]  — ถามพร้อม Oracle wisdom"
    echo "  create    <task> [framework]    — สร้างสรรค์ใหม่"
    echo "  translate <text>                — แปล/อธิบาย"
    echo "  status                          — ทดสอบ connection พร้อม fallback chain"
    echo ""
    echo "Environment Variables:"
    echo "  MODEL_CHAIN         — Comma-separated model list (e.g., 'gemma4:26b,gemma2:9b,gemma2:2b')"
    echo "  OLLAMA_TIMEOUT_SEC  — Timeout per model attempt (default: 30)"
    echo "  OLLAMA_MODEL        — Single model (fallback if MODEL_CHAIN not set)"
    ;;
esac
