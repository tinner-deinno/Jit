#!/usr/bin/env bash
# organs/heart.sh — หัวใจ (Heart / pran)
#
# หลักพุทธ: อิทธิบาท 4 (ฉันทะ วิริยะ จิตตะ วิมังสา)
# บทบาท: สูบฉีดชีวิต — รับเลือดดำ(IN) ฟอก ส่งเลือดแดง(OUT)
#
# จังหวะ: เต้น 2 ครั้งต่อ 1 รอบ
#   beat in  — ดูดเลือดจากทั่วร่าง (รับ signals/stats จากทุก agent)
#   beat out — ฉีดเลือดออกไป (ส่ง energy/commands ให้ทุก agent)
#
# Usage:
#   ./heart.sh beat in    — IN beat: collect blood payload
#   ./heart.sh beat out   — OUT beat: broadcast clean blood
#   ./heart.sh rhythm     — แสดง vital signs dashboard
#   ./heart.sh pump <type> <task> — route task to organ
#   ./heart.sh rate <mode>        — request rate change (sprint/fast/normal/slow/rest)
#   ./heart.sh routes     — แสดง routing table

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

CMD="${1:-rhythm}"
shift || true

# ── state files (git-tracked = living proof of heartbeat) ───────────
HEART_IN_STATE="$JIT_ROOT/memory/state/heart.in.json"
HEART_OUT_STATE="$JIT_ROOT/memory/state/heart.out.json"
HEART_RATE_REQUEST="/tmp/heart-rate-request.txt"
HEART_LOG="/tmp/manusat-heart.log"
BUS_ROOT="/tmp/manusat-bus"
REGISTRY="$JIT_ROOT/network/registry.json"

mkdir -p "$(dirname "$HEART_IN_STATE")" "$BUS_ROOT"

# ── routing table: task type → organ ─────────────────────────────
declare -A ROUTE_TABLE=(
  ["read"]="eye"      ["observe"]="eye"   ["web"]="eye"
  ["listen"]="ear"    ["receive"]="ear"
  ["say"]="mouth"     ["tell"]="mouth"    ["broadcast"]="mouth"
  ["detect"]="nose"   ["monitor"]="nose"  ["health"]="nose"
  ["create"]="hand"   ["edit"]="hand"     ["build"]="hand"
  ["go"]="leg"        ["deploy"]="leg"
  ["think"]="brain"   ["plan"]="brain"
  ["ask"]="ollama"    ["learn"]="oracle"  ["search"]="oracle"
)

# ── collect blood: รวบรวม stats จากทุก agent ──────────────────────
_collect_blood() {
  local ts agents agent pending total_pending=0
  local oracle_ok=0 ollama_ok=0
  ts="$(date '+%Y-%m-%dT%H:%M:%S')"

  # ตรวจ services
  curl -sf --max-time 3 "${ORACLE_URL:-http://localhost:47778}/api/health" \
    2>/dev/null | grep -q '"oracle":"connected"' && oracle_ok=1
  curl -sf --max-time 4 "${OLLAMA_URL:-https://ollama.mdes-innova.online}/api/tags" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" 2>/dev/null \
    | grep -q '"models"' && ollama_ok=1

  # รวบ agent stats จาก registry
  local agent_stats="{}"
  if [ -f "$REGISTRY" ]; then
    agent_stats=$(python3 - << PYEOF 2>/dev/null
import json, os, subprocess

reg = json.load(open('$REGISTRY'))
bus = '$BUS_ROOT'
stats = {}
for a in reg.get('agents', []):
  name = a['name']
  inbox = os.path.join(bus, name)
  pending = 0
  if os.path.isdir(inbox):
    pending = len([f for f in os.listdir(inbox) if f.endswith('.msg')])
  alive_file = f'/tmp/manusat-alive-{name}'
  alive = os.path.exists(alive_file) and (
    (os.stat(alive_file).st_mtime if os.path.exists(alive_file) else 0)
    > (__import__('time').time() - 3600)
  )
  stats[name] = {
    'pending': pending,
    'organ': a.get('organ', '?'),
    'tier': a.get('tier', '?'),
    'alive': alive
  }
print(json.dumps(stats, ensure_ascii=False))
PYEOF
)
  fi

  # git stats
  local git_changes
  git_changes=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  # รวบ total pending (task messages เท่านั้น)
  total_pending=$(find "$BUS_ROOT" -name '*.msg' -mmin -10 2>/dev/null \
                  | grep -v '_broadcast\.msg$' | wc -l | tr -d ' ')

  # สร้าง blood payload
  python3 - << PYEOF 2>/dev/null
import json
payload = {
  "timestamp": "$ts",
  "host": "$(hostname)",
  "oracle_ok": bool($oracle_ok),
  "ollama_ok": bool($ollama_ok),
  "git_changes": $git_changes,
  "total_pending": $total_pending,
  "agents": ${agent_stats:-{}}
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
PYEOF
}

# ── IN beat: ดูดเลือดดำ → ฟอก → บันทึก ─────────────────────────
_beat_in() {
  local ts="$(date '+%Y-%m-%dT%H:%M:%S')"
  local pulse_n="${PULSE_COUNT:-0}"

  # เก็บ blood payload
  local blood
  blood=$(_collect_blood)

  # บันทึก heart.in.json (git-tracked = proof of IN beat)
  python3 - << PYEOF 2>/dev/null
import json, time
blood = json.loads('''$blood''') if '''$blood''' else {}
state = {
  "beat": "IN",
  "pulse": $pulse_n,
  "timestamp": "$ts",
  "host": "$(hostname)",
  "blood": blood,
  "note": "diastole — collecting signals from body"
}
with open('$HEART_IN_STATE', 'w', encoding='utf-8') as f:
  json.dump(state, f, ensure_ascii=False, indent=2)
PYEOF

  # บันทึก bus marker
  echo "{\"heartbeat\":\"$ts\",\"from\":\"heart\",\"phase\":\"IN\",\"pulse\":$pulse_n}" \
    > "$BUS_ROOT/heartbeat-in.json" 2>/dev/null || true

  # ส่งสัญญาณผ่าน nerve (ถ้ามี)
  local NERVE="$SCRIPT_DIR/nerve.sh"
  [ -x "$NERVE" ] && bash "$NERVE" signal "heartbeat:IN" "$ts" "heart" >/dev/null 2>&1 || true

  # ส่งผ่าน bus
  bash "$JIT_ROOT/network/bus.sh" broadcast "heartbeat:IN" \
    "pulse #$pulse_n from $(hostname) @ $ts" >/dev/null 2>&1 || true

  log_action "HEART_IN" "pulse=$pulse_n ts=$ts"
  echo "$blood"
}

# ── OUT beat: ฉีดเลือดแดง → ส่งพลังงานให้ทุกอวัยวะ ─────────────
_beat_out() {
  local ts="$(date '+%Y-%m-%dT%H:%M:%S')"
  local pulse_n="${PULSE_COUNT:-0}"
  local mode="${HEARTBEAT_MODE:-normal}"

  # สร้าง energy payload สำหรับส่งออก
  local energy
  energy=$(python3 - << PYEOF 2>/dev/null
import json, os
# อ่าน IN state เพื่อดูว่าต้อง wake ใคร
in_state = {}
try:
  in_state = json.load(open('$HEART_IN_STATE'))
except:
  pass

blood = in_state.get('blood', {})
agents = blood.get('agents', {})

# ระบุ agents ที่ไม่ active (มี pending > 0 = ยังมีงานค้าง)
wake_list = [name for name, info in agents.items() if info.get('pending', 0) > 0]

energy = {
  "beat": "OUT",
  "pulse": $pulse_n,
  "timestamp": "$ts",
  "host": "$(hostname)",
  "mode": "$mode",
  "wake": wake_list,
  "command": "alive",
  "note": "systole — pumping clean blood to all organs"
}
print(json.dumps(energy, ensure_ascii=False, indent=2))
PYEOF
)

  # บันทึก heart.out.json (git-tracked = proof of OUT beat)
  echo "$energy" > "$HEART_OUT_STATE" 2>/dev/null || true

  # บันทึก bus marker
  echo "{\"heartbeat\":\"$ts\",\"from\":\"heart\",\"phase\":\"OUT\",\"pulse\":$pulse_n}" \
    > "$BUS_ROOT/heartbeat-out.json" 2>/dev/null || true

  # broadcast energy ไปทุก agent
  bash "$JIT_ROOT/network/bus.sh" broadcast "heartbeat:OUT" \
    "pulse #$pulse_n energy out @ $ts | mode=$mode" >/dev/null 2>&1 || true

  # ส่งสัญญาณผ่าน nerve
  local NERVE="$SCRIPT_DIR/nerve.sh"
  [ -x "$NERVE" ] && bash "$NERVE" signal "heartbeat:OUT" "$ts" "heart" >/dev/null 2>&1 || true

  # pulse อวัยวะหลัก (non-blocking)
  local organs=(lung nose eye ear)
  for organ in "${organs[@]}"; do
    local sc="$SCRIPT_DIR/$organ.sh"
    [ -x "$sc" ] && bash "$sc" pulse "$energy" >/dev/null 2>&1 || true &
  done
  wait  # รอ organs ทั้งหมด (non-blocking: timeout ใน organ script เอง)

  log_action "HEART_OUT" "pulse=$pulse_n mode=$mode ts=$ts"
  echo "$energy"
}

case "$CMD" in

  # ── beat: เต้นหัวใจ ─────────────────────────────────────────────
  beat)
    PHASE="${1:-cycle}"
    shift || true
    case "$PHASE" in
      in)    _beat_in  ;;
      out)   _beat_out ;;
      cycle) _beat_in; echo ""; _beat_out ;;
      *)     echo "Usage: heart.sh beat {in|out|cycle}" ;;
    esac
    ;;

  # ── rate: ขอเปลี่ยน heartbeat rate ──────────────────────────────
  rate)
    RATE="${1:-normal}"
    case "$RATE" in
      sprint|fast|normal|slow|rest)
        echo "$RATE" > "$HEART_RATE_REQUEST"
        ok "🫀 Rate request: $RATE → $HEART_RATE_REQUEST"
        log_action "HEART_RATE_REQ" "$RATE"
        ;;
      *) err "Rate ต้องเป็น: sprint fast normal slow rest" ;;
    esac
    ;;

  # ── pump: route task → organ ────────────────────────────────────
  pump)
    TASK_TYPE="${1:-unknown}"; shift || true; TASK_ARGS="$*"
    ORGAN="${ROUTE_TABLE[$TASK_TYPE]:-hand}"
    ORGAN_SCRIPT="$SCRIPT_DIR/$ORGAN.sh"
    step "pump: $TASK_TYPE → $ORGAN"
    log_action "HEART_PUMP" "$TASK_TYPE → $ORGAN"
    if [ -x "$ORGAN_SCRIPT" ]; then
      bash "$ORGAN_SCRIPT" "$TASK_TYPE" $TASK_ARGS
    else
      LIMB="$JIT_ROOT/limbs/$ORGAN.sh"
      [ -x "$LIMB" ] && bash "$LIMB" "$TASK_TYPE" $TASK_ARGS \
        || bash "$SCRIPT_DIR/hand.sh" execute "$TASK_ARGS"
    fi
    ;;

  # ── rhythm: vital signs ──────────────────────────────────────────
  rhythm)
    VITALS="$SCRIPT_DIR/vitals.sh"
    if [ -x "$VITALS" ]; then
      bash "$VITALS"
    else
      echo ""
      echo -e "${BOLD}${RED}❤ มนุษย์ Agent — Vital Signs${RESET}"
      echo -e "   $(date '+%Y-%m-%d %H:%M:%S')"
      echo ""
      ORGANS=(eye ear mouth nose hand leg heart nerve)
      ALIVE=0; TOTAL=${#ORGANS[@]}
      for O in "${ORGANS[@]}"; do
        F="$SCRIPT_DIR/$O.sh"
        if [ -f "$F" ]; then echo -e "   ${GREEN}♥${RESET} $O"; (( ALIVE++ ))
        else echo -e "   ${RED}✗${RESET} $O"; fi
      done
      echo ""
      oracle_ready && echo -e "   ${GREEN}♥${RESET} Oracle" \
                   || echo -e "   ${RED}✗${RESET} Oracle offline"
      PCT=$(( (ALIVE * 100) / TOTAL ))
      echo -e "   Vitality: ${GREEN}$PCT%${RESET} ($ALIVE/$TOTAL)"
      log_action "HEART_RHYTHM" "$ALIVE/$TOTAL"
      echo ""

      # แสดง last heartbeat stats
      if [ -f "$HEART_OUT_STATE" ]; then
        echo -e "   Last OUT: $(python3 -c "import json; d=json.load(open('$HEART_OUT_STATE')); print(d.get('timestamp','?'), '| pulse #' + str(d.get('pulse','?')))")"
      fi
    fi
    ;;

  # ── routes ───────────────────────────────────────────────────────
  routes)
    echo ""; echo -e "${BOLD}Routing Table:${RESET}"
    for K in "${!ROUTE_TABLE[@]}"; do echo "   $K → ${ROUTE_TABLE[$K]}"; done | sort
    echo ""
    ;;

  *)
    echo "Usage: heart.sh {beat|rate|pump|rhythm|routes}"
    echo "  beat {in|out|cycle}   — เต้นหัวใจ IN / OUT / ทั้งคู่"
    echo "  rate {sprint|fast|normal|slow|rest} — ขอเปลี่ยน rate"
    echo "  pump <type> <..>      — route task ไปยัง organ"
    echo "  rhythm                — vital signs dashboard"
    echo "  routes                — routing table"
    ;;
esac
