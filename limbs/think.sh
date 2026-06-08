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
source "$SCRIPT_DIR/agent_filter.sh"

# ─── Agent filter: prepend role context to every think call ─────────────────
# Reads AGENT_NAME from environment (set by the calling agent or parent shell).
# Falls back to "innova" if unset.
_THINK_AGENT="${AGENT_NAME:-innova}"
_AGENT_FILTER_HEADER="$(get_agent_filter "$_THINK_AGENT" 2>/dev/null)"

CMD="${1:-reflect}"
shift || true

case "$CMD" in

  # ── สติ: หยุดคิด ──────────────────────────────────────────────────
  pause|think)
    INTENT="${1:-ทบทวนสิ่งที่จะทำ}"
    echo ""
    echo -e "${CYAN}┌─ สติ: หยุดคิดก่อนลงมือ ─────────────────────────────┐${RESET}"
    echo -e "${CYAN}│${RESET} Agent: $_THINK_AGENT"
    echo -e "${CYAN}│${RESET} เจตนา: $INTENT"
    echo -e "${CYAN}│${RESET} เวลา:  $(date '+%H:%M:%S %Z')"
    echo -e "${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
    echo ""
    echo -e "${BOLD}── Prompt Filter ($_THINK_AGENT) ─────────────────────────${RESET}"
    echo "$_AGENT_FILTER_HEADER"
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
    log_action "THINK[$_THINK_AGENT]" "$INTENT"
    echo ""
    ;;

  # ── ปัญญา: ค้นหาใน Oracle ก่อนตัดสินใจ ──────────────────────────
  reflect|oracle)
    TOPIC="${1:-wisdom}"
    echo ""
    echo -e "${BOLD}── Prompt Filter ($_THINK_AGENT) ─────────────────────────${RESET}"
    echo "$_AGENT_FILTER_HEADER"
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
    echo ""
    step "ค้นหาปัญญาจาก Oracle: '$TOPIC'"
    if oracle_ready; then
      oracle_search "$TOPIC" 3
    else
      warn "Oracle ไม่พร้อม — เริ่มด้วยความรู้ตัวเอง"
    fi
    log_action "REFLECT[$_THINK_AGENT]" "$TOPIC"
    echo ""
    ;;

  # ── อิทัปปัจจยตา: เข้าใจความสัมพันธ์เหตุปัจจัย ──────────────────
  plan)
    TASK="${1:-task}"
    CONTEXT="${2:-}"
    echo ""
    echo -e "${BOLD}── Prompt Filter ($_THINK_AGENT) ─────────────────────────${RESET}"
    echo "$_AGENT_FILTER_HEADER"
    echo -e "${BOLD}─────────────────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "${BOLD}┌─ วางแผน (สัมมาวายามะ) ──────────────────────────────┐${RESET}"
    echo -e "${BOLD}│${RESET} Agent: $_THINK_AGENT"
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

    # CoT logging: Step 1 — Understand & Plan
    COT_SUBSTEPS='["understand","search_oracle","plan_approach"]'
    COT_QUERIES="[]"
    if oracle_ready; then
      echo ""
      step "Oracle บอกว่าเกี่ยวกับ '$TASK':"
      oracle_search "$TASK" 2
      COT_QUERIES='["task_analysis"]'
    fi
    cot_log "วางแผน: $TASK" "1" "$COT_SUBSTEPS" "$COT_QUERIES" "proceed_with_plan"

    log_action "PLAN[$_THINK_AGENT]" "$TASK"
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
    SUBCMD="${1:-}"
    case "$SUBCMD" in
      --cot|-c)
        LIMIT="${2:-10}"
        echo -e "${CYAN}=== Chain-of-Thought Log (ล่าสุด $LIMIT chains) ===${RESET}"
        echo ""
        cot_format "$LIMIT"
        echo ""
        COT_TOTAL=$(cot_count)
        info "CoT entries ทั้งหมด: $COT_TOTAL"
        ;;
      --clear)
        cot_clear
        ;;
      *)
        echo -e "${CYAN}=== innova Action Journal ===${RESET}"
        tail -20 "$JIT_LOG" 2>/dev/null || echo "(ยังไม่มี log)"
        ;;
    esac
    ;;

  *)
    echo "Usage: think.sh {pause|reflect|plan|why|log}"
    echo ""
    echo "  pause  'เจตนา'         — หยุดสติ บันทึกว่าจะทำอะไร"
    echo "  reflect 'หัวข้อ'       — ถาม Oracle ก่อน"
    echo "  plan 'งาน' 'บริบท'    — วางแผนอย่างมีสติ (พร้อม CoT logging)"
    echo "  why 'เหตุผล'          — บันทึกเหตุผล"
    echo "  log [--cot|--clear]   — ดู log (CoT chains หรือ action journal)"
    echo ""
    echo "Options:"
    echo "  log --cot [n]   — แสดงล่าสุด n CoT chains (ค่าเริ่มต้น: 10)"
    echo "  log --clear     — ล้าง CoT log"
    ;;
esac
