#!/usr/bin/env bash
# memory/shared.sh — ความทรงจำร่วม: shared memory ของทุก agent
#
# หลักพุทธ: สัมมาสติ — ระลึกถึงสิ่งที่รู้ร่วมกัน
# บทบาท multiagent: cross-agent shared state, consensus, collective knowledge
#
# ทุก agent อ่าน/เขียน Oracle ร่วมกัน — นั่นคือ "ความทรงจำร่วม"
# ไฟล์นี้เพิ่ม layer สำหรับ real-time shared state
#
# Usage:
#   ./shared.sh set <key> <value>    — บันทึก shared state
#   ./shared.sh get <key>            — อ่าน shared state
#   ./shared.sh all                  — ดูทั้งหมด
#   ./shared.sh clear <key>          — ลบ key
#   ./shared.sh sync                 — sync กับ Oracle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-all}"
shift || true

SHARED_FILE="/tmp/manusat-shared.json"
AGENT="${AGENT_NAME:-innova}"

_load() {
  if [ -f "$SHARED_FILE" ]; then
    cat "$SHARED_FILE"
  else
    echo "{}"
  fi
}

_save() {
  echo "$1" > "$SHARED_FILE"
}

case "$CMD" in

  # ── บันทึก shared state ──────────────────────────────────────────
  set)
    KEY="$1" VALUE="$2"
    if [ -z "$KEY" ]; then err "ต้องระบุ key"; exit 1; fi
    CURRENT=$(_load)
    UPDATED=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
d['$KEY'] = {
  'value': '$VALUE',
  'set_by': '$AGENT',
  'timestamp': '$(date +%Y-%m-%dT%H:%M:%S)'
}
print(json.dumps(d, ensure_ascii=False, indent=2))
" "$CURRENT")
    _save "$UPDATED"
    log_action "SHARED_SET" "$KEY=$VALUE by $AGENT"
    ok "shared: $KEY = $VALUE"
    ;;

  # ── อ่าน shared state ────────────────────────────────────────────
  get)
    KEY="$1"
    if [ -z "$KEY" ]; then err "ต้องระบุ key"; exit 1; fi
    python3 -c "
import json, os
if os.path.exists('$SHARED_FILE'):
    d = json.load(open('$SHARED_FILE'))
    entry = d.get('$KEY', None)
    if entry:
        print(entry['value'])
    else:
        print('')
else:
    print('')
" 2>/dev/null
    ;;

  # ── ดูทั้งหมด ─────────────────────────────────────────────────────
  all)
    echo ""
    echo -e "${BOLD}=== Shared Memory ===${RESET}"
    if [ -f "$SHARED_FILE" ]; then
      python3 -c "
import json
d = json.load(open('$SHARED_FILE'))
if not d:
    print('  (ว่าง)')
else:
    for k, v in d.items():
        val = v['value'] if isinstance(v, dict) else str(v)
        by  = v.get('set_by','?') if isinstance(v, dict) else '?'
        ts  = v.get('timestamp','?') if isinstance(v, dict) else ''
        print(f'  {k}: {val[:50]} [{by}@{ts[:16]}]')
"
    else
      info "ยังไม่มี shared state"
    fi
    echo ""
    ;;

  # ── ลบ key ──────────────────────────────────────────────────────
  clear)
    KEY="$1"
    if [ -f "$SHARED_FILE" ]; then
      python3 -c "
import json
d = json.load(open('$SHARED_FILE'))
if '$KEY' in d:
    del d['$KEY']
    with open('$SHARED_FILE', 'w') as f:
        json.dump(d, f, indent=2)
    print('cleared:', '$KEY')
else:
    print('not found:', '$KEY')
"
    fi
    log_action "SHARED_CLEAR" "$KEY"
    ;;

  # ── sync กับ Oracle ──────────────────────────────────────────────
  sync)
    step "sync shared memory ↔ Oracle..."
    if ! oracle_ready; then
      warn "Oracle ไม่พร้อม — skip sync"
      exit 1
    fi
    if [ -f "$SHARED_FILE" ]; then
      python3 -c "
import json
d = json.load(open('$SHARED_FILE'))
print(json.dumps(d, ensure_ascii=False))
" | while read -r STATE_JSON; do
        oracle_learn "shared-state-snapshot" "$STATE_JSON" "shared,state,$(date +%Y-%m-%d)" > /dev/null
      done
      ok "sync → Oracle เสร็จแล้ว"
      log_action "SHARED_SYNC" "$(date '+%Y-%m-%dT%H:%M:%S')"
    else
      info "ไม่มี shared state ที่ต้อง sync"
    fi
    ;;

  # ── announce state ไปยัง nerve ────────────────────────────────────
  announce)
    KEY="$1" VALUE="$2"
    bash "$SCRIPT_DIR/../memory/shared.sh" set "$KEY" "$VALUE"
    # ส่ง nerve signal
    NERVE="$SCRIPT_DIR/../organs/nerve.sh"
    [ -x "$NERVE" ] && bash "$NERVE" signal "shared_update" "$KEY=$VALUE" "$AGENT"
    ;;

  *)
    echo "Usage: shared.sh {set|get|all|clear|sync|announce}"
    echo ""
    echo "  set      <key> <value>  — บันทึก shared state"
    echo "  get      <key>          — อ่าน shared state"
    echo "  all                     — ดูทั้งหมด"
    echo "  clear    <key>          — ลบ key"
    echo "  sync                    — sync กับ Oracle"
    echo "  announce <key> <value>  — set + nerve signal"
    ;;
esac
