#!/usr/bin/env bash
# mind/reflex.sh — สัญชาตญาณ (Reflex/Instinct): ตอบสนองอัตโนมัติ
#
# หลักพุทธ: อกาลิโก — ทำทันทีโดยไม่ต้องรอ เมื่อถึงเวลา
# บทบาท: automatic responses to common situations without soma consultation
# "ปัญญาที่ฝึกมาดีแล้ว กลายเป็นสัญชาตญาณ"
#
# Usage:
#   ./reflex.sh check              — ตรวจสอบสถานการณ์และ respond
#   ./reflex.sh on <trigger>       — ลงทะเบียน reflex
#   ./reflex.sh off <trigger>      — ปิด reflex
#   ./reflex.sh list               — ดู reflexes ทั้งหมด
#   ./reflex.sh test <trigger>     — ทดสอบ reflex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-check}"
shift || true

REFLEX_FILE="/tmp/innova-reflexes.json"

# ── Built-in Reflexes (ปัญจนิยาม — กฎธรรมชาติ) ──────────────────────
# เหล่านี้คือ reflexes ที่ innova มีมาแต่กำเนิด
declare -A BUILTIN_REFLEXES=(
  ["oracle_down"]="bash $SCRIPT_DIR/../limbs/oracle.sh start"
  ["disk_full"]="bash $SCRIPT_DIR/../organs/nose.sh alert disk"
  ["git_conflict"]="bash $SCRIPT_DIR/../organs/nose.sh alert git"
  ["inbox_full"]="bash $SCRIPT_DIR/../organs/ear.sh receive"
  ["no_heartbeat"]="bash $SCRIPT_DIR/../organs/heart.sh start"
  ["task_failed"]="bash $SCRIPT_DIR/../limbs/speak.sh failure 'task failed — checking logs'"
  ["oracle_ready"]="bash $SCRIPT_DIR/../limbs/speak.sh success 'Oracle reconnected'"
)

_trigger_reflex() {
  local TRIGGER="$1"
  local ACTION="${BUILTIN_REFLEXES[$TRIGGER]:-}"
  if [ -z "$ACTION" ]; then
    # ตรวจ custom reflexes
    ACTION=$(python3 -c "
import json, os
if os.path.exists('$REFLEX_FILE'):
    d = json.load(open('$REFLEX_FILE'))
    print(d.get('$TRIGGER', ''))
" 2>/dev/null)
  fi

  if [ -n "$ACTION" ]; then
    log_action "REFLEX_FIRE" "$TRIGGER: $ACTION"
    info "สัญชาตญาณ: $TRIGGER → $ACTION"
    eval "$ACTION"
    return 0
  fi
  return 1
}

case "$CMD" in

  # ── ตรวจและ respond อัตโนมัติ ─────────────────────────────────────
  check)
    info "ตรวจสอบ reflexes..."

    # Reflex 1: Oracle ไม่ทำงาน
    oracle_ready || _trigger_reflex "oracle_down"

    # Reflex 2: inbox มี messages
    INBOX="/tmp/manusat-bus/${AGENT_NAME:-innova}"
    MSGS=$(ls "$INBOX"/*.msg 2>/dev/null | wc -l)
    [ "$MSGS" -gt 5 ] && _trigger_reflex "inbox_full"

    # Reflex 3: heartbeat หาย
    [ ! -f "/tmp/manusat-heart.pid" ] && _trigger_reflex "no_heartbeat"

    # Reflex 4: disk usage > 95%
    USAGE=$(df /workspaces 2>/dev/null | awk 'NR>1 {gsub(/%/,"",$5); print $5}')
    [ "${USAGE:-0}" -gt 95 ] && _trigger_reflex "disk_full"

    ok "reflex check เสร็จแล้ว"
    log_action "REFLEX_CHECK" "all"
    ;;

  # ── ลงทะเบียน custom reflex ──────────────────────────────────────
  on)
    TRIGGER="$1"
    shift || true
    ACTION="$*"
    python3 -c "
import json, os
data = {}
if os.path.exists('$REFLEX_FILE'):
    data = json.load(open('$REFLEX_FILE'))
data['$TRIGGER'] = '$ACTION'
with open('$REFLEX_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print('registered:', '$TRIGGER')
"
    ok "reflex เปิด: $TRIGGER → $ACTION"
    log_action "REFLEX_ON" "$TRIGGER"
    ;;

  # ── ปิด reflex ───────────────────────────────────────────────────
  off)
    TRIGGER="$1"
    python3 -c "
import json, os
if os.path.exists('$REFLEX_FILE'):
    data = json.load(open('$REFLEX_FILE'))
    data.pop('$TRIGGER', None)
    with open('$REFLEX_FILE', 'w') as f:
        json.dump(data, f, indent=2)
print('removed:', '$TRIGGER')
"
    ok "reflex ปิด: $TRIGGER"
    ;;

  # ── แสดง reflexes ────────────────────────────────────────────────
  list)
    echo ""
    echo -e "${BOLD}Built-in Reflexes:${RESET}"
    for KEY in "${!BUILTIN_REFLEXES[@]}"; do
      echo "   ${GREEN}●${RESET} $KEY → ${BUILTIN_REFLEXES[$KEY]:0:60}"
    done | sort
    echo ""
    if [ -f "$REFLEX_FILE" ]; then
      echo -e "${BOLD}Custom Reflexes:${RESET}"
      python3 -c "
import json
d = json.load(open('$REFLEX_FILE'))
for k, v in d.items():
    print(f'   ○ {k} → {v[:60]}')
"
    fi
    echo ""
    ;;

  # ── test reflex ─────────────────────────────────────────────────
  test)
    TRIGGER="$1"
    step "test reflex: $TRIGGER"
    _trigger_reflex "$TRIGGER" && ok "reflex ทำงาน" || warn "ไม่พบ reflex: $TRIGGER"
    ;;

  *)
    echo "Usage: reflex.sh {check|on|off|list|test}"
    echo ""
    echo "  check         — ตรวจและ respond อัตโนมัติ"
    echo "  on  <trigger> <action>  — ลงทะเบียน reflex"
    echo "  off <trigger>           — ปิด reflex"
    echo "  list                    — ดู reflexes ทั้งหมด"
    echo "  test <trigger>          — ทดสอบ"
    ;;
esac
