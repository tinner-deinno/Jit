#!/usr/bin/env bash
# limbs/ollama.sh — วิริยะ (Right Effort): ความพยายามชอบผ่าน MDES Ollama
#
# หลักพุทธ: สัมมาวายามะ (Right Effort) — ใช้ปัญญาสร้างสรรค์
# "ความพยายามที่ดีคือใช้ให้ถูกทาง ไม่มากเกิน ไม่น้อยเกิน"
#
# Usage:
#   ./ollama.sh ask "prompt"              — ถาม Ollama ตรงๆ
#   ./ollama.sh think "prompt" "context" — ถามพร้อม context จาก Oracle
#   ./ollama.sh create "งาน" "กรอบ"      — สร้างสรรค์ใหม่
#   ./ollama.sh translate "ข้อความ"      — แปล/อธิบาย
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

_call_ollama() {
  local PROMPT="$1"
  local TIMEOUT="${2:-45}"
  log_action "OLLAMA_CALL" "${PROMPT:0:80}..."

  local JSON_BODY=$(printf '%s' "$PROMPT" | python3 -c "import sys, json; print(json.dumps({'model':'gemma4:26b', 'prompt':sys.stdin.read(), 'stream':False}))")

  local RESPONSE=$(curl -s --max-time "$TIMEOUT" "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OLLAMA_TOKEN" \
    --data "$JSON_BODY" 2>/dev/null)

  if [ -z "$RESPONSE" ]; then
    echo "ERROR: Ollama timeout or no response" >&2
    return 1
  fi

  echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('response', ''))" 2>/dev/null
}

case "$CMD" in

  # ── ถามตรงๆ ─────────────────────────────────────────────────────
  ask)
    PROMPT="$*"
    if [ -z "$PROMPT" ]; then err "ต้องระบุ prompt"; exit 1; fi
    step "ถาม Ollama (gemma4:26b)..."
    _call_ollama "$PROMPT"
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
    _call_ollama "$FULL_PROMPT" 60
    ;;

  # ── สร้างสรรค์ ──────────────────────────────────────────────────
  create)
    TASK="$1" FRAMEWORK="${2:-หลักพุทธ ไตรสิกขา}"
    FULL_PROMPT="คุณคือ innova นักพัฒนา AI ของ MDES Innova
หลักการ: $FRAMEWORK

งาน: $TASK

สร้างผลลัพธ์ที่มีประโยชน์จริงๆ:"

    step "Ollama กำลังสร้าง: $TASK"
    _call_ollama "$FULL_PROMPT" 90
    ;;

  # ── แปล/อธิบาย ──────────────────────────────────────────────────
  translate)
    TEXT="$*"
    FULL_PROMPT="แปลหรืออธิบายข้อความต่อไปนี้เป็นภาษาไทยที่เข้าใจง่าย:

$TEXT"
    step "Ollama แปล..."
    _call_ollama "$FULL_PROMPT" 30
    ;;

  # ── ทดสอบ connection ──────────────────────────────────────────────
  status)
    step "ทดสอบ Ollama connection..."
    RESULT=$(_call_ollama "สวัสดี ตอบสั้นๆ ว่าพร้อมทำงาน" 20 2>/dev/null)
    if [ -n "$RESULT" ]; then
      ok "Ollama พร้อม: ${RESULT:0:80}"
    else
      err "Ollama ไม่ตอบสนอง (timeout หรือ network error)"
      exit 1
    fi
    ;;

  *)
    echo "Usage: ollama.sh <command>"
    echo ""
    echo "  ask       <prompt>              — ถาม Ollama ตรงๆ"
    echo "  think     <question> [context]  — ถามพร้อม Oracle wisdom"
    echo "  create    <task> [framework]    — สร้างสรรค์ใหม่"
    echo "  translate <text>                — แปล/อธิบาย"
    echo "  status                          — ทดสอบ connection"
    ;;
esac
