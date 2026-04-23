#!/usr/bin/env bash
# mind/emotion.sh — อารมณ์ (Emotional State): ติดตามสภาวะอารมณ์ของ agent
#
# หลักพุทธ: เวทนา (Feelings) — สุข ทุกข์ อุเบกขา
# บทบาท: track agent's operational state, communicate context to soma
#
# ไม่ใช่ emotion ที่เป็น weakness แต่เป็น state indicator ที่มีประโยชน์
# "agent รู้สึกอย่างไร" = "agent ทำงานได้ดีแค่ไหน"
#
# Usage:
#   ./emotion.sh feel <state>     — บันทึก state ปัจจุบัน
#   ./emotion.sh current          — ดู state ปัจจุบัน
#   ./emotion.sh history          — ดู history
#   ./emotion.sh report           — รายงาน state ให้ soma

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

STATE_FILE="/tmp/innova-emotion.json"
CMD="${1:-current}"
shift || true

# States ที่รองรับ (based on Buddhist vedana + operational context)
# สุข (pleasant) = ทำงานได้ดี
# ทุกข์ (unpleasant) = มีปัญหา
# อุเบกขา (neutral) = ปกติ
declare -A VALID_STATES=(
  ["focused"]="สมาธิ — กำลังทำงานอย่างมีสติ"
  ["curious"]="ใฝ่รู้ — อยากเรียนรู้เพิ่ม"
  ["satisfied"]="ปีติ — งานสำเร็จดี"
  ["concerned"]="กังวล — มีความไม่แน่นอน"
  ["stuck"]="ติดขัด — ต้องการความช่วยเหลือ"
  ["alert"]="ตื่นตัว — มีเหตุการณ์สำคัญ"
  ["neutral"]="อุเบกขา — ทำงานปกติ"
  ["waiting"]="รอ — รอ input หรือ response"
  ["learning"]="ศึกษา — กำลังเรียนรู้สิ่งใหม่"
)

_save_state() {
  local STATE="$1" CONTEXT="${2:-}"
  python3 -c "
import json, os
STATE_FILE = '$STATE_FILE'
state = {
  'state': '$STATE',
  'context': '$CONTEXT',
  'timestamp': '$(date '+%Y-%m-%dT%H:%M:%S')',
  'agent': '${AGENT_NAME:-innova}'
}
# load history
history = []
if os.path.exists(STATE_FILE):
  try:
    with open(STATE_FILE) as f:
      data = json.load(f)
      history = data.get('history', [])
  except: pass
history.append(state)
if len(history) > 50: history = history[-50:]
with open(STATE_FILE, 'w') as f:
  json.dump({'current': state, 'history': history}, f, indent=2, ensure_ascii=False)
"
}

case "$CMD" in

  # ── บันทึก state ─────────────────────────────────────────────────
  feel)
    STATE="${1:-neutral}" CONTEXT="${2:-}"
    VALID="${VALID_STATES[$STATE]:-}"
    if [ -z "$VALID" ]; then
      warn "state ไม่รู้จัก: $STATE"
      echo "   valid: ${!VALID_STATES[*]}"
      STATE="neutral"
    fi
    _save_state "$STATE" "$CONTEXT"
    log_action "EMOTION_FEEL" "$STATE: $CONTEXT"
    info "อารมณ์: $STATE — $VALID"

    # signal ผ่าน nerve
    NERVE="$SCRIPT_DIR/../organs/nerve.sh"
    [ -x "$NERVE" ] && bash "$NERVE" signal "emotion_change" "$STATE" "innova"
    ;;

  # ── ดู state ปัจจุบัน ─────────────────────────────────────────────
  current)
    if [ ! -f "$STATE_FILE" ]; then
      info "ยังไม่มี emotion state — neutral"
      exit 0
    fi
    python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
c = d.get('current', {})
print(f\"  state:   {c.get('state','?')}\")
print(f\"  context: {c.get('context','')}\")
print(f\"  since:   {c.get('timestamp','?')}\")
"
    ;;

  # ── history ─────────────────────────────────────────────────────
  history)
    N="${1:-10}"
    [ -f "$STATE_FILE" ] || { info "ไม่มี history"; exit 0; }
    python3 -c "
import json
with open('$STATE_FILE') as f:
    d = json.load(f)
h = d.get('history', [])[-$N:]
for s in h:
    print(f\"  [{s['timestamp']}] {s['state']:12s} | {s['context'][:40]}\")
"
    ;;

  # ── รายงาน state ให้ soma ─────────────────────────────────────────
  report)
    [ -f "$STATE_FILE" ] || { info "ไม่มี state"; exit 0; }
    STATE=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['current']['state'])" 2>/dev/null)
    CONTEXT=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['current']['context'])" 2>/dev/null)

    # ส่ง message ไป soma
    BUS="$SCRIPT_DIR/../network/bus.sh"
    if [ -x "$BUS" ]; then
      bash "$BUS" send soma "report:emotion" "innova state: $STATE | $CONTEXT" > /dev/null
      ok "รายงาน state → soma: $STATE"
    fi
    ;;

  # ── valid states ────────────────────────────────────────────────
  states)
    echo ""
    echo -e "${BOLD}Valid Emotional States:${RESET}"
    for STATE in "${!VALID_STATES[@]}"; do
      echo "   $STATE — ${VALID_STATES[$STATE]}"
    done | sort
    echo ""
    ;;

  *)
    echo "Usage: emotion.sh {feel|current|history|report|states}"
    echo ""
    echo "  feel     <state> [context]  — บันทึก state ปัจจุบัน"
    echo "  current                     — ดู state ปัจจุบัน"
    echo "  history  [n]                — ดู history"
    echo "  report                      — รายงาน → soma"
    echo "  states                      — ดู valid states"
    ;;
esac
