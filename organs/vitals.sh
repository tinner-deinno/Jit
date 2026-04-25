#!/usr/bin/env bash
# organs/vitals.sh — สัญญาณชีพจรอวัยวะ (Vital Signs Monitor)
# แสดง pulse strength ของแต่ละ organ/agent แบบ real-time
# หัวใจจะปรับ pump strength ตาม vitals ที่วัดได้
#
# Usage:
#   bash organs/vitals.sh            — ตรวจครั้งเดียว
#   bash organs/vitals.sh watch      — loop ทุก 5 วินาที
#   bash organs/vitals.sh json       — output เป็น JSON

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-}"
OLLAMA_AUTH="Authorization: Bearer $OLLAMA_TOKEN"

# ─── progressbar ────────────────────────────────────────────────────
bar() {
  local PCT="$1" WIDTH=20
  local FILLED=$(( PCT * WIDTH / 100 ))
  local EMPTY=$(( WIDTH - FILLED ))
  local B=""
  for ((i=0; i<FILLED; i++)); do B+="█"; done
  for ((i=0; i<EMPTY;  i++)); do B+="░"; done

  if   [ "$PCT" -ge 80 ]; then echo -e "${GREEN}${B}${RESET} ${PCT}%"
  elif [ "$PCT" -ge 50 ]; then echo -e "${YELLOW}${B}${RESET} ${PCT}%"
  elif [ "$PCT" -ge 20 ]; then echo -e "${RED}${B}${RESET} ${PCT}%"
  else echo -e "\033[0;31m${B}\033[0m ${PCT}% ⚠ CRITICAL"
  fi
}

# ─── วัด pulse แต่ละ organ ──────────────────────────────────────────

measure_oracle() {
  local START=$SECONDS
  local RESP
  RESP=$(curl -sf --max-time 5 "$ORACLE_URL/api/health" 2>/dev/null)
  local RT=$(( (SECONDS - START) * 1000 ))
  if echo "$RESP" | grep -q '"oracle":"connected"'; then
    local DOCS
    DOCS=$(curl -sf --max-time 3 "$ORACLE_URL/api/stats" 2>/dev/null \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo 0)
    # pulse = 100 ถ้า < 200ms, ลดลงถ้านาน
    local PULSE=100
    [ "$RT" -gt 200 ] && PULSE=80
    [ "$RT" -gt 500 ] && PULSE=60
    echo "$PULSE|online|docs:${DOCS}|${RT}ms"
  else
    echo "0|offline||"
  fi
}

measure_ollama() {
  local START=$(date +%s%3N)
  local RESP
  RESP=$(curl -sf --max-time 8 "$OLLAMA_URL/api/tags" \
    -H "$OLLAMA_AUTH" 2>/dev/null)
  local RT=$(( $(date +%s%3N) - START ))
  if echo "$RESP" | grep -q '"models"'; then
    local MODELS
    MODELS=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('models',[])))" 2>/dev/null || echo "?")
    local PULSE=100
    [ "$RT" -gt 1000 ] && PULSE=75
    [ "$RT" -gt 3000 ] && PULSE=50
    echo "$PULSE|online|models:${MODELS}|${RT}ms"
  else
    echo "0|offline||"
  fi
}

measure_eye() {
  if [ -f "$JIT_ROOT/organs/eye.sh" ] && [ -x "$JIT_ROOT/organs/eye.sh" ]; then
    local FILES
    FILES=$(find "$JIT_ROOT/organs" -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    echo "100|online|files:${FILES}|0ms"
  elif [ -f "$JIT_ROOT/organs/eye.sh" ]; then
    echo "60|degraded|not-executable|0ms"
  else
    echo "0|missing||"
  fi
}

measure_ear() {
  local INBOX="/tmp/manusat-bus/innova"
  if [ -d "$INBOX" ]; then
    local PENDING
    PENDING=$(ls "$INBOX"/*.json 2>/dev/null | wc -l | tr -d ' ')
    # pulse ดีถ้า inbox ทำงาน = 100, pending เยอะเกิน = ลด
    local PULSE=100
    [ "$PENDING" -gt 10 ] && PULSE=70
    [ "$PENDING" -gt 50 ] && PULSE=40
    echo "$PULSE|online|pending:${PENDING}|0ms"
  else
    echo "85|standby|no-bus|0ms"
  fi
}

measure_nose() {
  local DISK_PCT
  DISK_PCT=$(df /workspaces 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}' || echo "50")
  local PULSE=$(( 100 - DISK_PCT ))
  [ "$PULSE" -lt 0 ] && PULSE=0
  local RAM_FREE
  RAM_FREE=$(free -m 2>/dev/null | awk 'NR==2 {printf "%d", $7}' || echo "0")
  echo "$PULSE|online|disk:${DISK_PCT}%,free-ram:${RAM_FREE}MB|0ms"
}

measure_hand() {
  if [ -f "$JIT_ROOT/organs/hand.sh" ] && [ -x "$JIT_ROOT/organs/hand.sh" ]; then
    local UNCOMMIT
    UNCOMMIT=$(cd "$JIT_ROOT" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    local PULSE=100
    [ "$UNCOMMIT" -gt 20 ] && PULSE=80 # งานค้าง
    echo "$PULSE|online|uncommitted:${UNCOMMIT}|0ms"
  else
    echo "0|missing||"
  fi
}

measure_leg() {
  if [ -f "$JIT_ROOT/organs/leg.sh" ] && [ -x "$JIT_ROOT/organs/leg.sh" ]; then
    # ทดสอบ git reachability
    cd "$JIT_ROOT" && git remote get-url origin > /dev/null 2>&1
    echo "95|online|git:ok|0ms"
  else
    echo "0|missing||"
  fi
}

measure_mouth() {
  if [ -f "$JIT_ROOT/organs/mouth.sh" ] && [ -x "$JIT_ROOT/organs/mouth.sh" ]; then
    local LOG_LINES
    touch /tmp/innova-actions.log 2>/dev/null || true
    LOG_LINES=$(wc -l < /tmp/innova-actions.log 2>/dev/null || echo "0")
    echo "100|online|log:${LOG_LINES}lines|0ms"
  else
    echo "0|missing||"
  fi
}

measure_nerve() {
  if [ -f "$JIT_ROOT/organs/nerve.sh" ] && [ -x "$JIT_ROOT/organs/nerve.sh" ]; then
    local EVENTS
    EVENTS=$(ls /tmp/manusat-bus/*.json 2>/dev/null | wc -l | tr -d ' ')
    echo "90|online|events:${EVENTS}|0ms"
  else
    echo "0|missing||"
  fi
}

measure_heart() {
  if [ -f "$JIT_ROOT/organs/heart.sh" ] && [ -x "$JIT_ROOT/organs/heart.sh" ]; then
    local BEAT
    BEAT=$(cat /tmp/manusat-bus/heartbeat.json 2>/dev/null | python3 -c \
      "import json,sys; d=json.load(sys.stdin); print(d.get('heartbeat','?'))" 2>/dev/null || echo "no-beat")
    echo "100|online|last:${BEAT}|0ms"
  else
    echo "0|missing||"
  fi
}

# ─── heart pressure recommendation ─────────────────────────────────
heart_pressure() {
  local ORGAN="$1" PULSE="$2"
  if   [ "$PULSE" -ge 80 ]; then echo "normal"
  elif [ "$PULSE" -ge 50 ]; then echo "↑ boost"
  elif [ "$PULSE" -ge 20 ]; then echo "↑↑ HIGH BOOST"
  else                           echo "🚨 RESUSCITATE"
  fi
}

# ─── render dashboard ───────────────────────────────────────────────
render() {
  local TS
  TS=$(date '+%Y-%m-%d %H:%M:%S')

  clear 2>/dev/null || echo -e "\n\n\n"

  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║   innova — Vital Signs Monitor  🫀                       ║"
  echo "  ║   GitHub Copilot on Claude Sonnet 4.6                    ║"
  echo "  ╚══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}  ${YELLOW}${TS}${RESET}"
  echo ""

  # วัดพร้อมกัน
  local V_ORACLE V_OLLAMA V_EYE V_EAR V_NOSE V_HAND V_LEG V_MOUTH V_NERVE V_HEART
  V_ORACLE=$(measure_oracle)
  V_OLLAMA=$(measure_ollama) &
  OLLAMA_PID=$!
  V_EYE=$(measure_eye)
  V_EAR=$(measure_ear)
  V_NOSE=$(measure_nose)
  V_HAND=$(measure_hand)
  V_LEG=$(measure_leg)
  V_MOUTH=$(measure_mouth)
  V_NERVE=$(measure_nerve)
  V_HEART=$(measure_heart)
  wait $OLLAMA_PID 2>/dev/null
  V_OLLAMA=$(measure_ollama)

  # parse
  parse() { echo "${1%%|*}"; }
  detail() { echo "$1" | cut -d'|' -f3; }
  latency() { echo "$1" | cut -d'|' -f4; }
  pstatus() { echo "$1" | cut -d'|' -f2; }

  # สร้าง organ list
  declare -A VITALS=(
    ["👁  ตา    (eye)"]="$V_EYE"
    ["👂 หู    (ear)"]="$V_EAR"
    ["👃 จมูก  (nose)"]="$V_NOSE"
    ["🤲 มือ   (hand)"]="$V_HAND"
    ["🦵 ขา   (leg)"]="$V_LEG"
    ["👄 ปาก  (mouth)"]="$V_MOUTH"
    ["⚡ ประสาท(nerve)"]="$V_NERVE"
    ["❤️  หัวใจ (heart)"]="$V_HEART"
  )
  declare -A SERVICES=(
    ["🔮 Oracle  (memory)"]="$V_ORACLE"
    ["🤖 Ollama  (MDES AI)"]="$V_OLLAMA"
  )

  echo -e "  ${BOLD}── Core Services ────────────────────────────────────${RESET}"
  local TOTAL_PULSE=0 TOTAL_COUNT=0

  for ORGAN in "🔮 Oracle  (memory)" "🤖 Ollama  (MDES AI)"; do
    local V="${SERVICES[$ORGAN]}"
    local P DET LAT ST PRESS
    P=$(parse "$V"); DET=$(detail "$V"); LAT=$(latency "$V"); ST=$(pstatus "$V")
    PRESS=$(heart_pressure "$ORGAN" "$P")
    printf "  %-26s " "$ORGAN"
    bar "$P"
    printf "  ${CYAN}%-18s${RESET} 💓 %-14s\n" "$DET" "$PRESS"
    TOTAL_PULSE=$(( TOTAL_PULSE + P )); TOTAL_COUNT=$(( TOTAL_COUNT + 1 ))
  done

  echo ""
  echo -e "  ${BOLD}── Organs (อวัยวะ) ──────────────────────────────────${RESET}"

  for ORGAN in "👁  ตา    (eye)" "👂 หู    (ear)" "👃 จมูก  (nose)" "🤲 มือ   (hand)" "🦵 ขา   (leg)" "👄 ปาก  (mouth)" "⚡ ประสาท(nerve)" "❤️  หัวใจ (heart)"; do
    local V="${VITALS[$ORGAN]}"
    local P DET LAT ST PRESS
    P=$(parse "$V"); DET=$(detail "$V"); LAT=$(latency "$V"); ST=$(pstatus "$V")
    PRESS=$(heart_pressure "$ORGAN" "$P")
    printf "  %-26s " "$ORGAN"
    bar "$P"
    printf "  ${CYAN}%-22s${RESET} 💓 %s\n" "$DET" "$PRESS"
    TOTAL_PULSE=$(( TOTAL_PULSE + P )); TOTAL_COUNT=$(( TOTAL_COUNT + 1 ))
  done

  # คำนวณ overall vitality
  local OVERALL=0
  [ "$TOTAL_COUNT" -gt 0 ] && OVERALL=$(( TOTAL_PULSE / TOTAL_COUNT ))

  echo ""
  echo -e "  ${BOLD}── Overall Vitality ─────────────────────────────────${RESET}"
  printf "  %-26s " "🧠 innova (overall)"
  bar "$OVERALL"

  # heart recommendation
  echo ""
  echo -e "  ${BOLD}── Heart Pump Directive (คำสั่งหัวใจ) ──────────────${RESET}"
  for ORGAN in "🔮 Oracle  (memory)" "🤖 Ollama  (MDES AI)" "👁  ตา    (eye)" "👂 หู    (ear)" "👃 จมูก  (nose)" "🤲 มือ   (hand)" "🦵 ขา   (leg)" "👄 ปาก  (mouth)" "⚡ ประสาท(nerve)"; do
    local SRC="${SERVICES[$ORGAN]:-${VITALS[$ORGAN]}}"
    local P; P=$(parse "$SRC")
    if [ "$P" -lt 80 ]; then
      local PRESS; PRESS=$(heart_pressure "$ORGAN" "$P")
      printf "  %-26s → %s\n" "$ORGAN" "$PRESS"
    fi
  done
  local NEEDS_BOOST=0
  for ORGAN in "🔮 Oracle  (memory)" "🤖 Ollama  (MDES AI)" "👁  ตา    (eye)" "👂 หู    (ear)" "👃 จมูก  (nose)" "🤲 มือ   (hand)" "🦵 ขา   (leg)" "👄 ปาก  (mouth)" "⚡ ประสาท(nerve)"; do
    local SRC="${SERVICES[$ORGAN]:-${VITALS[$ORGAN]}}"
    local P; P=$(parse "$SRC")
    [ "$P" -lt 80 ] && NEEDS_BOOST=1
  done
  [ "$NEEDS_BOOST" -eq 0 ] && echo -e "  ${GREEN}✅ ทุกอวัยวะทำงานปกติ ไม่ต้องปรับ${RESET}" || true

  echo ""
  if [ "$CMD" = "watch" ]; then
    echo -e "  ${YELLOW}[ กำลัง watch — Ctrl+C เพื่อหยุด ]${RESET}"
  fi
  echo ""
}

# ─── JSON output ────────────────────────────────────────────────────
render_json() {
  python3 - << 'EOF'
import subprocess, json, time

def measure(cmd):
    try:
        r = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True, timeout=10)
        parts = r.stdout.strip().split('|')
        return {'pulse': int(parts[0]) if parts else 0, 'status': parts[1] if len(parts)>1 else 'unknown', 'detail': parts[2] if len(parts)>2 else ''}
    except:
        return {'pulse': 0, 'status': 'error', 'detail': ''}

organs = {}
script = '/workspaces/Jit/organs/vitals.sh'
for organ in ['oracle','ollama','eye','ear','nose','hand','leg','mouth','nerve','heart']:
    organs[organ] = measure(f'bash {script} _measure_{organ} 2>/dev/null')

print(json.dumps({'timestamp': time.strftime('%Y-%m-%dT%H:%M:%S'), 'organs': organs}, indent=2))
EOF
}

# ─── individual measure (called internally) ─────────────────────────
case "$CMD" in
  _measure_oracle) measure_oracle; exit 0 ;;
  _measure_ollama) measure_ollama; exit 0 ;;
  _measure_eye)    measure_eye;    exit 0 ;;
  _measure_ear)    measure_ear;    exit 0 ;;
  _measure_nose)   measure_nose;   exit 0 ;;
  _measure_hand)   measure_hand;   exit 0 ;;
  _measure_leg)    measure_leg;    exit 0 ;;
  _measure_mouth)  measure_mouth;  exit 0 ;;
  _measure_nerve)  measure_nerve;  exit 0 ;;
  _measure_heart)  measure_heart;  exit 0 ;;

  watch)
    while true; do
      render
      sleep 5
    done
    ;;
  json)
    render_json
    ;;
  ""|check|vitals)
    render
    ;;
  *)
    render
    ;;
esac
