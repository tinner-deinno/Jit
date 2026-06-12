#!/usr/bin/env bash
# limbs/ollama.sh — วิริยะ (Right Effort): ความพยายามชอบผ่าน MDES Ollama
#
# หลักพุทธ: สัมมาวายามะ (Right Effort) — ใช้ปัญญาสร้างสรรค์
# "ความพยายามที่ดีคือใช้ให้ถูกทาง ไม่มากเกิน ไม่น้อยเกิน"
#
# Usage:
#   ./ollama.sh ask "prompt"              — ถาม Ollama ตรงๆ (lane auto)
#   ./ollama.sh think "prompt" "context" — ถามพร้อม context จาก Oracle
#   ./ollama.sh create "งาน" "กรอบ"      — สร้างสรรค์ใหม่
#   ./ollama.sh translate "ข้อความ"      — แปล/อธิบาย
#   ./ollama.sh status                   — ทดสอบ connection ทั้งสอง lane
#
# Lanes (OLLAMA_LANE=auto|local|mdes, default auto):
#   local — daemon ที่ http://localhost:11434 (model: OLLAMA_CLOUD_MODEL,
#           default gemma4:31b-cloud) — เร็วกว่า ไม่ต้อง token
#   mdes  — https://ollama.mdes-innova.online (gemma4:26b) — fallback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="${SCRIPT_DIR}/.."
source "$SCRIPT_DIR/lib.sh"

# Load .env if it exists (for OLLAMA_TOKEN and other config)
if [ -f "$JIT_ROOT/.env" ]; then
  set -a; source "$JIT_ROOT/.env"; set +a
fi

OLLAMA_LANE="${OLLAMA_LANE:-auto}"
OLLAMA_LOCAL_URL="${OLLAMA_LOCAL_URL:-http://localhost:11434}"
OLLAMA_LOCAL_MODEL="${OLLAMA_LOCAL_MODEL:-${OLLAMA_CLOUD_MODEL:-gemma4:31b-cloud}}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-${OLLAMA_URL:-https://ollama.mdes-innova.online}}"
OLLAMA_MODEL="${OLLAMA_MODEL:-${JIT_OLLAMA_MODEL:-gemma4:26b}}"
OLLAMA_API_PATH="${OLLAMA_API_PATH:-/api/generate}"

CMD="${1:-ask}"
shift || true

# lane resolution: auto = local daemon ถ้ามีชีวิต, ไม่งั้น mdes
_resolve_lane() {
  case "$OLLAMA_LANE" in
    local) echo "local" ;;
    mdes)  echo "mdes" ;;
    *)
      if curl -s --max-time 2 "${OLLAMA_LOCAL_URL}/api/version" >/dev/null 2>&1; then
        echo "local"
      else
        echo "mdes"
      fi
      ;;
  esac
}

# Entire HTTP call lives in node: Thai/UTF-8 survives stdin->fetch->stdout,
# unlike curl --data "$VAR" whose argv gets codepage-mangled on Windows.
_call_ollama() {
  local PROMPT="$1"
  local TIMEOUT="${2:-45}"
  local LANE
  LANE="$(_resolve_lane)"
  log_action "OLLAMA_CALL" "[$LANE] ${PROMPT:0:80}..."

  local URL MODEL TOKEN
  if [ "$LANE" = "local" ]; then
    URL="${OLLAMA_LOCAL_URL%/}${OLLAMA_API_PATH}"
    MODEL="$OLLAMA_LOCAL_MODEL"
    TOKEN=""
    # cloud-backed models ผ่าน daemon local อาจช้ากว่า 45s default
    [ "$TIMEOUT" -lt 90 ] && TIMEOUT=90
  else
    URL="${OLLAMA_BASE_URL%/}${OLLAMA_API_PATH}"
    MODEL="$OLLAMA_MODEL"
    TOKEN="$OLLAMA_TOKEN"
  fi

  printf '%s' "$PROMPT" | OLLAMA_CALL_URL="$URL" OLLAMA_CALL_MODEL="$MODEL" \
    OLLAMA_CALL_TOKEN="$TOKEN" OLLAMA_CALL_TIMEOUT="$TIMEOUT" node --no-warnings -e "
    const prompt = require('fs').readFileSync(0, 'utf8');
    const { OLLAMA_CALL_URL, OLLAMA_CALL_MODEL, OLLAMA_CALL_TOKEN, OLLAMA_CALL_TIMEOUT } = process.env;
    const headers = { 'Content-Type': 'application/json' };
    if (OLLAMA_CALL_TOKEN) headers.Authorization = 'Bearer ' + OLLAMA_CALL_TOKEN;
    fetch(OLLAMA_CALL_URL, {
      method: 'POST', headers,
      body: JSON.stringify({ model: OLLAMA_CALL_MODEL, prompt, stream: false }),
      signal: AbortSignal.timeout(parseInt(OLLAMA_CALL_TIMEOUT, 10) * 1000),
    })
      .then(r => { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
      .then(d => process.stdout.write(d.response || ''))
      .catch(e => { console.error('ERROR: Ollama ' + e.message); process.exit(1); });
  "
}

case "$CMD" in

  # ── ถามตรงๆ ─────────────────────────────────────────────────────
  ask)
    PROMPT="$*"
    if [ -z "$PROMPT" ]; then err "ต้องระบุ prompt"; exit 1; fi
    LANE="$(_resolve_lane)"
    if [ "$LANE" = "local" ]; then
      step "Ask Ollama [local ${OLLAMA_LOCAL_MODEL}]..."
    else
      step "Ask Ollama [mdes ${OLLAMA_MODEL}]..."
    fi
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
    step "ทดสอบ Ollama ทั้งสอง lane..."
    if curl -s --max-time 2 "${OLLAMA_LOCAL_URL}/api/version" >/dev/null 2>&1; then
      RESULT=$(OLLAMA_LANE=local _call_ollama "สวัสดี ตอบสั้นๆ ว่าพร้อมทำงาน" 60 2>/dev/null)
      if [ -n "$RESULT" ]; then
        ok "local  [${OLLAMA_LOCAL_MODEL}]: ${RESULT:0:80}"
      else
        err "local  daemon มีชีวิตแต่ model ไม่ตอบ (${OLLAMA_LOCAL_MODEL})"
      fi
    else
      err "local  daemon ไม่ทำงาน (${OLLAMA_LOCAL_URL})"
    fi
    RESULT=$(OLLAMA_LANE=mdes _call_ollama "สวัสดี ตอบสั้นๆ ว่าพร้อมทำงาน" 30 2>/dev/null)
    if [ -n "$RESULT" ]; then
      ok "mdes   [${OLLAMA_MODEL}]: ${RESULT:0:80}"
    else
      err "mdes   ไม่ตอบสนอง (timeout หรือ network error)"
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
