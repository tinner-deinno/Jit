#!/usr/bin/env bash
# limbs/prompt_proxy.sh — ปัญญาประดิษฐ์: Structured Prompt Proxy via CommandCode
#
# หลักพุทธ: สัมมาวาจา (Right Speech) — พูดให้ตรง ชัด มีโครงสร้าง มีประโยชน์
# "คำพูดที่ดีคือคำที่ชัดเจน ตรงประเด็น และสื่อสารได้ครบถ้วน"
#
# Uses CommandCode as the token provider (burns THEIR tokens, not ours).
# All agent calls go through: ANTHROPIC_API_KEY=$COMMANDCODE_API_KEY claude -p
#
# Usage:
#   ./prompt_proxy.sh call "prompt ใดก็ได้"
#   ./prompt_proxy.sh call "prompt" --model haiku
#   ./prompt_proxy.sh call "prompt" --model sonnet
#   ./prompt_proxy.sh format "raw prompt"        — แสดง structured prompt ที่จะส่ง
#   ./prompt_proxy.sh route  "prompt"            — แสดงว่าจะใช้ model อะไร
#   ./prompt_proxy.sh status                     — ทดสอบ API key + connectivity
#
# Environment:
#   COMMANDCODE_API_KEY  — CommandCode proxy key (user_...)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Load .env if present (may carry COMMANDCODE_API_KEY)
JIT_ROOT="${JIT_ROOT:-$SCRIPT_DIR/..}"
if [ -f "$JIT_ROOT/.env" ]; then
  set -a; source "$JIT_ROOT/.env"; set +a
fi

# ─── Constants ──────────────────────────────────────────────────────────────
DEFAULT_MAX_TOKENS=2048
HAIKU_MODEL="claude-haiku-4-5-20251001"
SONNET_MODEL="claude-sonnet-4-6"

# Complexity thresholds (word count)
COMPLEXITY_THRESHOLD=50

# ─── format_prompt ──────────────────────────────────────────────────────────
# Wrap a raw prompt into the structured [Role]/[Context]/[Task]/[Example]/[Format] template.
# Output goes to stdout (the structured prompt string).
format_prompt() {
  local RAW_PROMPT="$1"

  python3 - "$RAW_PROMPT" <<'PYEOF'
import sys, textwrap

raw = sys.argv[1].strip()

# Heuristic: extract anything the user already named as context (after "context:" label)
role    = "Senior AI assistant specialised in multi-agent systems and software engineering"
context = (
    "You are operating inside the Jit (จิต) multi-agent orchestration system built by MDES-Innova. "
    "The system follows Buddhist principles: ศีล (integrity), สมาธิ (focus), ปัญญา (wisdom). "
    "Agents communicate via a file-based message bus. Oracle knowledge base (Arra V3) stores "
    "persistent learnings. Always prefer reversible actions; signal before destructive ones."
)
task    = raw
example = (
    "If the task involves code: provide working, minimal, well-commented examples. "
    "If the task involves analysis: structure findings as bullet points ranked by importance. "
    "If the task involves decisions: present 2-3 options with trade-offs."
)
fmt = (
    "Respond in a clear, structured format. "
    "Use headers (##) for distinct sections when the response has multiple parts. "
    "Keep the response concise yet complete — avoid unnecessary filler phrases."
)

structured = (
    f"[Role]\n{role}\n\n"
    f"[Context]\n{context}\n\n"
    f"[Task]\n{task}\n\n"
    f"[Example]\n{example}\n\n"
    f"[Format]\n{fmt}"
)

print(structured)
PYEOF
}

# ─── add_thai_summary_instruction ───────────────────────────────────────────
# Append the Thai summary requirement to a system prompt string.
# Prints the augmented system prompt to stdout.
add_thai_summary_instruction() {
  local SYSTEM_PROMPT="$1"
  printf '%s\n\n%s' \
    "$SYSTEM_PROMPT" \
    "เมื่อสรุปผลลัพธ์ให้ผู้ใช้ กรุณาตอบเป็นภาษาไทย (When summarizing results to the user, respond in Thai language.)"
}

# ─── route_model ────────────────────────────────────────────────────────────
# Decide which Claude model to use based on prompt complexity.
# Prints model ID to stdout.
route_model() {
  local PROMPT="$1"
  local HINT="${2:-}"  # optional override: "haiku" | "sonnet"

  # Explicit override wins
  case "$HINT" in
    haiku)  echo "$HAIKU_MODEL";  return ;;
    sonnet) echo "$SONNET_MODEL"; return ;;
  esac

  # Auto-route by word count
  local WORD_COUNT
  WORD_COUNT=$(printf '%s' "$PROMPT" | wc -w | tr -d '[:space:]')

  if [ "$WORD_COUNT" -ge "$COMPLEXITY_THRESHOLD" ]; then
    echo "$SONNET_MODEL"
  else
    echo "$HAIKU_MODEL"
  fi
}

# ─── _check_api_key ─────────────────────────────────────────────────────────
_check_api_key() {
  if [ -z "${COMMANDCODE_API_KEY:-}" ]; then
    err "ไม่พบ COMMANDCODE_API_KEY — กรุณาตั้งค่า environment variable นี้ก่อน"
    err "  export COMMANDCODE_API_KEY='sk-ant-...'"
    return 1
  fi
}

# ─── proxy_call ─────────────────────────────────────────────────────────────
# Main: format prompt → pick model → call Claude API → return result.
# Args: proxy_call <raw_prompt> [model_hint: haiku|sonnet]
proxy_call() {
  local RAW_PROMPT="$1"
  local MODEL_HINT="${2:-}"

  if [ -z "$RAW_PROMPT" ]; then
    err "ต้องระบุ prompt (กรุณาใส่ข้อความที่จะส่ง Claude)"
    return 1
  fi

  _check_api_key || return 1

  # 1. Format the prompt
  local STRUCTURED_PROMPT
  STRUCTURED_PROMPT="$(format_prompt "$RAW_PROMPT")"

  # 2. Build system prompt with Thai instruction
  local BASE_SYSTEM="คุณคือ Jit Oracle (จิต) ผู้ช่วย AI ของระบบ มนุษย์ Agent โดย MDES-Innova."
  local SYSTEM_PROMPT
  SYSTEM_PROMPT="$(add_thai_summary_instruction "$BASE_SYSTEM")"

  # 3. Pick model
  local MODEL
  MODEL="$(route_model "$RAW_PROMPT" "$MODEL_HINT")"

  log_action "PROXY_CALL" "model=$MODEL prompt_words=$(printf '%s' "$RAW_PROMPT" | wc -w | tr -d '[:space:]')"
  step "ส่งผ่าน CommandCode → claude CLI ($MODEL) — burning THEIR tokens..."

  # 4. Build full prompt with system header prepended (claude -p takes single string)
  local FULL_PROMPT
  FULL_PROMPT="$(printf '%s\n\n---\n\n%s' "$SYSTEM_PROMPT" "$STRUCTURED_PROMPT")"

  # 5. Call via claude CLI with COMMANDCODE as the API key — burns CommandCode tokens
  local RESULT
  RESULT=$(ANTHROPIC_API_KEY="$COMMANDCODE_API_KEY" \
    claude -p \
    --model "$MODEL" \
    "$FULL_PROMPT" 2>/dev/null)

  local EXIT_CODE=$?
  if [ $EXIT_CODE -ne 0 ] || [ -z "$RESULT" ]; then
    err "Claude CLI ผ่าน CommandCode ล้มเหลว (model=$MODEL)"
    log_action "PROXY_ERROR" "exit=$EXIT_CODE model=$MODEL"
    return 1
  fi

  echo "$RESULT"
  log_action "PROXY_OK" "model=$MODEL chars=${#RESULT}"
}

# ─── CLI entrypoint ─────────────────────────────────────────────────────────
CMD="${1:-help}"
shift || true

case "$CMD" in

  # ── ส่ง prompt ────────────────────────────────────────────────────────────
  call)
    RAW_PROMPT="$1"; shift || true
    MODEL_HINT=""
    # Parse optional --model flag
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --model|-m) MODEL_HINT="${2:-}"; shift 2 || shift ;;
        *) shift ;;
      esac
    done
    if [ -z "$RAW_PROMPT" ]; then
      err "ต้องระบุ prompt: prompt_proxy.sh call \"ข้อความ\""
      exit 1
    fi
    proxy_call "$RAW_PROMPT" "$MODEL_HINT"
    ;;

  # ── แสดง structured prompt ────────────────────────────────────────────────
  format)
    RAW_PROMPT="$*"
    if [ -z "$RAW_PROMPT" ]; then
      err "ต้องระบุ prompt: prompt_proxy.sh format \"ข้อความ\""
      exit 1
    fi
    echo ""
    echo -e "${CYAN}┌─ Structured Prompt ──────────────────────────────────┐${RESET}"
    format_prompt "$RAW_PROMPT"
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
    echo ""
    ;;

  # ── แสดง model routing ────────────────────────────────────────────────────
  route)
    RAW_PROMPT="$1"; HINT="${2:-}"
    MODEL=$(route_model "$RAW_PROMPT" "$HINT")
    WORDS=$(printf '%s' "$RAW_PROMPT" | wc -w | tr -d '[:space:]')
    info "คำ: $WORDS | threshold: $COMPLEXITY_THRESHOLD | model: $MODEL"
    echo "$MODEL"
    ;;

  # ── ทดสอบ API key และ connectivity ───────────────────────────────────────
  status)
    _check_api_key || exit 1
    step "ทดสอบ Claude API..."
    RESULT=$(proxy_call "Say: API OK" "haiku" 2>&1)
    if echo "$RESULT" | grep -qi "error\|ERROR"; then
      err "Claude API ไม่ตอบสนองถูกต้อง: ${RESULT:0:200}"
      exit 1
    fi
    ok "Claude API พร้อม: ${RESULT:0:80}"
    ;;

  # ── help ──────────────────────────────────────────────────────────────────
  help|--help|-h)
    echo ""
    echo -e "${BOLD}prompt_proxy.sh — Structured Prompt Proxy to Claude API${RESET}"
    echo ""
    echo "Usage:"
    echo "  prompt_proxy.sh call   <prompt> [--model haiku|sonnet]"
    echo "  prompt_proxy.sh format <prompt>"
    echo "  prompt_proxy.sh route  <prompt> [haiku|sonnet]"
    echo "  prompt_proxy.sh status"
    echo ""
    echo "Environment:"
    echo "  COMMANDCODE_API_KEY   — Anthropic API key (ต้องตั้งค่า)"
    echo ""
    echo "Models:"
    echo "  haiku  → $HAIKU_MODEL  (prompt < $COMPLEXITY_THRESHOLD words)"
    echo "  sonnet → $SONNET_MODEL (prompt >= $COMPLEXITY_THRESHOLD words)"
    echo ""
    ;;

  *)
    err "คำสั่งไม่รู้จัก: '$CMD' — ลอง: prompt_proxy.sh help"
    exit 1
    ;;
esac
