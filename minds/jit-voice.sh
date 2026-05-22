#!/usr/bin/env bash
# minds/jit-voice.sh — จิต Voice Command Processor
# รับคำสั่งเสียงภาษาไทย → parse intent (fast regex + Ollama) → execute → ตอบภาษาไทย
#
# Usage:
#   bash minds/jit-voice.sh process "จิต เปิดเพลง Asap Rocky"
#   bash minds/jit-voice.sh log
#   bash minds/jit-voice.sh test

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# WSL CRLF self-heal
if grep -qi 'microsoft' /proc/version 2>/dev/null; then
  sed -i 's/\r$//' "$0" 2>/dev/null || true
  [ -f "$JIT_ROOT/limbs/lib.sh" ] && sed -i 's/\r$//' "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
fi

# Load .env
[ -f "$JIT_ROOT/.env" ] && { set -a; . "$JIT_ROOT/.env"; set +a; }
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"  # re-assert after .env

# Source lib best-effort
[ -f "$JIT_ROOT/limbs/lib.sh" ] && source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
type log_action >/dev/null 2>&1 || log_action() {
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$1] $2" >> "/tmp/innova-actions.log"
}

OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
LOCAL_OLLAMA_URL="${LOCAL_OLLAMA_URL:-http://localhost:11434}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:26b}"
LOCAL_MODEL="${LOCAL_MODEL:-gemma3:4b}"
VOICE_LOG="/tmp/manusat-voice.log"
BLOOD_DIR="${BLOOD_DIR:-/tmp/manusat-blood}"

# ── Open URL (Windows/WSL/Linux/Git Bash) ──────────────────────────────────────
_open_url() {
  local URL="$1"
  log_action "OPEN_URL" "$URL"

  # WSL (Microsoft kernel)
  if grep -qi 'microsoft' /proc/version 2>/dev/null; then
    powershell.exe -Command "Start-Process '$URL'" >/dev/null 2>&1 && return 0
    cmd.exe /c "start \"\" \"$URL\"" >/dev/null 2>&1 && return 0
  fi

  # Windows Git Bash (WINDIR set, no /proc/version)
  if [ -n "${WINDIR:-}" ] || [ -n "${COMSPEC:-}" ]; then
    cmd.exe /c "start \"\" \"$URL\"" >/dev/null 2>&1 && return 0
    powershell.exe -Command "Start-Process '$URL'" >/dev/null 2>&1 && return 0
  fi

  # Linux / macOS
  command -v xdg-open >/dev/null 2>&1 && { xdg-open "$URL" >/dev/null 2>&1 &; return 0; }
  command -v open    >/dev/null 2>&1 && { open    "$URL" >/dev/null 2>&1 &; return 0; }

  log_action "OPEN_URL_FAIL" "no browser handler found for URL: $URL"
  return 1
}

# ── Build YouTube search URL ──────────────────────────────────────────────
_youtube_url() {
  python3 -c "
import urllib.parse, sys
q = sys.argv[1] if len(sys.argv) > 1 else ''
print('https://www.youtube.com/results?search_query=' + urllib.parse.quote(q))
" "$1" 2>/dev/null
}

# ── Build Google search URL ───────────────────────────────────────────────
_google_url() {
  python3 -c "
import urllib.parse, sys
q = sys.argv[1] if len(sys.argv) > 1 else ''
print('https://www.google.com/search?q=' + urllib.parse.quote(q))
" "$1" 2>/dev/null
}

# ── Call Ollama (mdes primary → local fallback) ───────────────────────────
_call_ollama() {
  local PROMPT="$1" TIMEOUT="${2:-35}"

  local BODY
  BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'model': '$OLLAMA_MODEL',
    'prompt': sys.argv[1],
    'stream': False,
    'options': {'temperature': 0.05, 'num_predict': 300}
}))" "$PROMPT" 2>/dev/null) || return 1

  # 1) mdes Ollama (20s — leave room for local fallback within Bun's 80s budget)
  local RESP
  RESP=$(curl -sf --max-time 20 \
    "$OLLAMA_URL/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null)

  # 2) local Ollama fallback — validate mdes response has .response field
  local _mdes_ok=0
  if [ -n "$RESP" ]; then
    echo "$RESP" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  sys.exit(0 if d.get('response') else 1)
except: sys.exit(1)
" 2>/dev/null && _mdes_ok=1
  fi

  if [ "$_mdes_ok" -eq 0 ]; then
    local LOCAL_BODY
    LOCAL_BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'model': '$LOCAL_MODEL',
    'prompt': sys.argv[1],
    'stream': False,
    'options': {'temperature': 0.05, 'num_predict': 300}
}))" "$PROMPT" 2>/dev/null)
    RESP=$(curl -sf --max-time 15 \
      "$LOCAL_OLLAMA_URL/api/generate" \
      -H "Content-Type: application/json" \
      --data "${LOCAL_BODY:-$BODY}" 2>/dev/null)
  fi

  [ -z "$RESP" ] && { echo "ERROR: no Ollama response" >&2; return 1; }

  echo "$RESP" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('response', ''))
except:
    pass
" 2>/dev/null
}

# ── Ollama intent parser ──────────────────────────────────────────────────
_parse_intent_ollama() {
  local TEXT="$1"
  local PROMPT="คุณคือ จิต ผู้ช่วย AI ภาษาไทย รับคำสั่ง: \"${TEXT}\"

วิเคราะห์ intent แล้วตอบเป็น JSON เท่านั้น ห้ามมีข้อความอื่น ห้าม markdown:
{\"action\":\"ACTION\",\"query\":\"QUERY\",\"response_th\":\"THAI_REPLY\"}

ACTION ที่ใช้ได้:
- search_youtube  : เปิดเพลง/วีดีโอ YouTube
- open_url        : เปิดเว็บ
- search_web      : ค้นหา Google
- tell_time       : บอกเวลา
- tell_date       : บอกวันที่
- system_status   : สถานะระบบ
- chat            : สนทนา / ตอบคำถาม

ตัวอย่าง:
\"เปิดเพลง Asap Rocky เพลงใหม่\" → {\"action\":\"search_youtube\",\"query\":\"Asap Rocky new songs 2025\",\"response_th\":\"ได้เลยค่ะ กำลังเปิดเพลง Asap Rocky ให้นะคะ\"}
\"กี่โมงแล้ว\" → {\"action\":\"tell_time\",\"query\":\"\",\"response_th\":\"ตรวจเวลาให้นะคะ\"}

JSON เท่านั้น:"

  local RAW
  RAW=$(_call_ollama "$PROMPT" 30) || {
    echo '{"action":"chat","query":"","response_th":"ขอโทษค่ะ Ollama ไม่ตอบสนอง"}'; return 0
  }

  echo "$RAW" | python3 -c "
import sys, json, re
text = sys.stdin.read().strip()
try:
    m = re.search(r'\{[^{}]+\}', text, re.DOTALL)
    if m:
        obj = json.loads(m.group())
        obj.setdefault('action', 'chat')
        obj.setdefault('query', '')
        obj.setdefault('response_th', 'ได้ยินค่ะ')
        print(json.dumps(obj, ensure_ascii=False))
    else:
        print(json.dumps({'action':'chat','query':'','response_th':'ขอโทษนะคะ ไม่เข้าใจคำสั่ง'}))
except:
    print(json.dumps({'action':'chat','query':'','response_th':'เกิดข้อผิดพลาดค่ะ'}))
" 2>/dev/null || echo '{"action":"chat","query":"","response_th":"เกิดข้อผิดพลาดค่ะ"}'
}

# ── Fast intent (regex, zero Ollama calls) ────────────────────────────────
_parse_intent_fast() {
  local T; T=$(echo "$1" | tr '[:upper:]' '[:lower:]')

  # เวลา
  if echo "$T" | grep -qE '(กี่โมง|เวลา|เท่าไหร่โมง|ตีเท่าไหร่|what.?time|time.?now)'; then
    echo '{"action":"tell_time","query":"","response_th":"__TIME__"}'; return 0
  fi
  # วันที่
  if echo "$T" | grep -qE '(วันที่|วันนี้|วันอะไร|what.?day|today|date.?today)'; then
    echo '{"action":"tell_date","query":"","response_th":"__DATE__"}'; return 0
  fi
  # สถานะระบบ
  if echo "$T" | grep -qE '(สถานะ|ระบบ|system.?status|life.?loop|organs|agent)'; then
    echo '{"action":"system_status","query":"","response_th":"กำลังตรวจสอบสถานะระบบค่ะ"}'; return 0
  fi

  return 1
}

# ── Execute action ────────────────────────────────────────────────────────
_execute_action() {
  local ACTION="$1" QUERY="$2"
  case "$ACTION" in
    search_youtube)
      local URL; URL=$(_youtube_url "$QUERY")
      [ -n "$URL" ] && _open_url "$URL" && echo "$URL"
      ;;
    open_url)
      _open_url "$QUERY"; echo "$QUERY"
      ;;
    search_web)
      local URL; URL=$(_google_url "$QUERY")
      _open_url "$URL"; echo "$URL"
      ;;
    tell_time)
      date '+%H:%M'
      ;;
    tell_date)
      date '+%d %B %Y' | sed 's/^0//'
      ;;
    system_status)
      if [ -f "${BLOOD_DIR}/synthesized.json" ]; then
        python3 -c "
import json
d = json.load(open('${BLOOD_DIR}/synthesized.json', encoding='utf-8'))
print(f\"Cycle {d['cycle']}: {d['organs_done']} organs, {d['alert_count']} alerts\")
" 2>/dev/null || echo "ระบบรันอยู่"
      else
        echo "ระบบยังไม่เริ่ม"
      fi
      ;;
    *) echo "" ;;
  esac
}

# ── Build Thai response with real data injected ───────────────────────────
_finalize_response() {
  local ACTION="$1" BASE="$2" RESULT="$3"
  case "$ACTION" in
    tell_time)
      local T; T=$(date '+%H:%M')
      echo "ตอนนี้เวลา ${T} นาฬิกาค่ะ"
      ;;
    tell_date)
      local D; D=$(date '+%d %B %Y' | sed 's/^0//')
      echo "วันนี้วันที่ ${D} ค่ะ"
      ;;
    system_status)
      echo "${BASE} — ${RESULT:-ไม่มีข้อมูล}"
      ;;
    *)
      echo "${BASE}"
      ;;
  esac
}

# ══════════════════════════════════════════════════════════════════════════
# COMMANDS
# ══════════════════════════════════════════════════════════════════════════
CMD="${1:-process}"

case "$CMD" in

  # ── รับคำสั่งเสียง ──────────────────────────────────────────────────────
  process)
    TEXT="${2:-}"
    if [ -z "$TEXT" ]; then
      python3 -c "import json; print(json.dumps({'ok':True,'action':'chat','query':'','response_th':'ไม่ได้รับข้อความค่ะ'}, ensure_ascii=False))"
      exit 0
    fi

    echo "$(date '+%Y-%m-%dT%H:%M:%S') VOICE_IN: $TEXT" >> "$VOICE_LOG"

    # 1. Fast regex parse
    INTENT=""
    if INTENT=$(_parse_intent_fast "$TEXT"); then
      : # matched without Ollama
    else
      # 2. Ollama deep parse
      INTENT=$(_parse_intent_ollama "$TEXT")
    fi

    ACTION=$(echo "$INTENT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('action','chat'))" 2>/dev/null || echo "chat")
    QUERY=$(echo "$INTENT"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('query',''))"   2>/dev/null || echo "")
    BASE=$(echo "$INTENT"   | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response_th','ได้ยินค่ะ'))" 2>/dev/null || echo "ได้ยินค่ะ")

    # 3. Execute
    EXEC_RESULT=$(_execute_action "$ACTION" "$QUERY" 2>/dev/null)

    # 4. Final Thai response
    FINAL=$(_finalize_response "$ACTION" "$BASE" "${EXEC_RESULT:-}")

    echo "$(date '+%Y-%m-%dT%H:%M:%S') VOICE_OUT: action=$ACTION resp=$FINAL" >> "$VOICE_LOG"
    log_action "VOICE_CMD" "action=$ACTION query=$QUERY"

    # 5. Return JSON
    python3 -c "
import json, sys
print(json.dumps({
    'ok': True,
    'action': sys.argv[1],
    'query':  sys.argv[2],
    'response_th': sys.argv[3],
    'result': sys.argv[4]
}, ensure_ascii=False))
" "$ACTION" "$QUERY" "$FINAL" "${EXEC_RESULT:-}"
    ;;

  # ── ดู log ──────────────────────────────────────────────────────────────
  log)
    tail -30 "$VOICE_LOG" 2>/dev/null || echo "(no voice log yet)"
    ;;

  # ── test suite ──────────────────────────────────────────────────────────
  test)
    echo "=== jit-voice.sh self-test ==="
    echo ""
    echo "1) Time (fast path — no Ollama):"
    bash "$0" process "จิต กี่โมงแล้ว"
    echo ""
    echo "2) System status (fast path):"
    bash "$0" process "สถานะระบบเป็นยังไงบ้าง"
    echo ""
    echo "3) YouTube (Ollama path):"
    bash "$0" process "จิต เปิดเพลง Asap Rocky เพลงใหม่ใน YouTube ให้หน่อย"
    echo ""
    echo "=== done ==="
    ;;

  *)
    echo "Usage: jit-voice.sh {process '<text>' | log | test}"
    ;;
esac
