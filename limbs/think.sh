#!/usr/bin/env bash
# limbs/think.sh — สติ (Mindfulness): หยุดคิดก่อนลงมือ
#
# หลักพุทธ: สัมมาสังกัปปะ (Right Intention)
# "ก่อนจะพูดหรือทำสิ่งใด จงหยุดคิดสักครู่ว่ามีประโยชน์หรือไม่"
#
# Usage:
#   ./think.sh "สิ่งที่จะทำ"
#   ./think.sh reflect "หัวข้อ"        — ถาม Oracle ก่อน
#   ./think.sh plan "งาน" "context"    — วางแผนทีละขั้น
#   ./think.sh why "เหตุผล"            — บันทึกเหตุผลการกระทำ

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CMD="${1:-reflect}"
shift || true

case "$CMD" in

  # ── สติ: หยุดคิด ──────────────────────────────────────────────────
  pause|think)
    INTENT="${1:-ทบทวนสิ่งที่จะทำ}"
    echo ""
    echo -e "${CYAN}┌─ สติ: หยุดคิดก่อนลงมือ ─────────────────────────────┐${RESET}"
    echo -e "${CYAN}│${RESET} เจตนา: $INTENT"
    echo -e "${CYAN}│${RESET} เวลา:  $(date '+%H:%M:%S %Z')"
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
    log_action "THINK" "$INTENT"
    echo ""
    ;;

  # ── ปัญญา: ค้นหาใน Oracle ก่อนตัดสินใจ ──────────────────────────
  reflect|oracle)
    TOPIC="${1:-wisdom}"
    echo ""
    step "ค้นหาปัญญาจาก Oracle: '$TOPIC'"
    if oracle_ready; then
      oracle_search "$TOPIC" 3
    else
      warn "Oracle ไม่พร้อม — เริ่มด้วยความรู้ตัวเอง"
    fi
    log_action "REFLECT" "$TOPIC"
    echo ""
    ;;

  # ── อิทัปปัจจยตา: เข้าใจความสัมพันธ์เหตุปัจจัย ──────────────────
  plan)
    TASK="${1:-task}"
    CONTEXT="${2:-}"
    echo ""
    echo -e "${BOLD}┌─ วางแผน (สัมมาวายามะ) ──────────────────────────────┐${RESET}"
    echo -e "${BOLD}│${RESET} งาน: $TASK"
    [ -n "$CONTEXT" ] && echo -e "${BOLD}│${RESET} บริบท: $CONTEXT"
    echo -e "${BOLD}│${RESET}"
    echo -e "${BOLD}│${RESET} ขั้นตอนการคิด:"
    echo -e "${BOLD}│${RESET}   1. เข้าใจงานให้ครบ (understand)"
    echo -e "${BOLD}│${RESET}   2. ค้นหาใน Oracle ว่ามีความรู้เกี่ยวข้องไหม"
    echo -e "${BOLD}│${RESET}   3. ทำแบบ reversible ก่อน destructive"
    echo -e "${BOLD}│${RESET}   4. แสดง progress ทุก step"
    echo -e "${BOLD}│${RESET}   5. บันทึกสิ่งที่เรียนรู้กลับ Oracle"
    echo -e "${BOLD}└──────────────────────────────────────────────────────┘${RESET}"

    if oracle_ready; then
      echo ""
      step "Oracle บอกว่าเกี่ยวกับ '$TASK':"
      oracle_search "$TASK" 2
    fi
    log_action "PLAN" "$TASK"
    echo ""
    ;;

  # ── บันทึกเจตนา ───────────────────────────────────────────────────
  why)
    REASON="${1:-เพื่อประโยชน์สาธารณะ}"
    log_action "INTENT" "$REASON"
    ok "บันทึกเจตนา: $REASON"
    ;;

  # ── ดู log สติ ────────────────────────────────────────────────────
  log)
    echo -e "${CYAN}=== innova Action Journal ===${RESET}"
    tail -20 "$JIT_LOG" 2>/dev/null || echo "(ยังไม่มี log)"
    ;;

  *)
    echo "Usage: think.sh {pause|reflect|plan|why|log}"
    echo ""
    echo "  pause  'เจตนา'         — หยุดสติ บันทึกว่าจะทำอะไร"
    echo "  reflect 'หัวข้อ'       — ถาม Oracle ก่อน"
    echo "  plan 'งาน' 'บริบท'    — วางแผนอย่างมีสติ"
    echo "  why 'เหตุผล'          — บันทึกเหตุผล"
    echo "  log                    — ดูประวัติการกระทำ"
    ;;
esac
