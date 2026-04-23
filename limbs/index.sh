#!/usr/bin/env bash
# limbs/index.sh — จิต (Mind): ตัวประสาน แขนขาทั้งหมดเข้าด้วยกัน
#
# หลักพุทธ: อริยมรรคมีองค์ 8 — วงจรสมบูรณ์ของการกระทำชอบ
#
# Pipeline: think → act → speak → remember
#
# Usage:
#   ./index.sh do "intent"        — ทำงานแบบ full pipeline
#   ./index.sh wake               — ตื่นตัว ตรวจสอบทุกระบบ
#   ./index.sh remember "insight" — บันทึกสิ่งที่เรียนรู้
#   ./index.sh reflect "topic"    — ถาม Oracle + Ollama
#   ./index.sh status             — แสดงสถานะทุกระบบ

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

THINK="$SCRIPT_DIR/think.sh"
ACT="$SCRIPT_DIR/act.sh"
SPEAK="$SCRIPT_DIR/speak.sh"
OLLAMA="$SCRIPT_DIR/ollama.sh"
ORACLE="$SCRIPT_DIR/oracle.sh"

# chmod ทุก limb ให้ executable
_ensure_exec() {
  for F in "$THINK" "$ACT" "$SPEAK" "$OLLAMA" "$ORACLE"; do
    [ -f "$F" ] && chmod +x "$F"
  done
}
_ensure_exec

CMD="${1:-status}"
shift || true

case "$CMD" in

  # ── ตื่นรู้ (Wake): ตรวจสอบทุกระบบ ──────────────────────────────
  wake|awaken)
    echo ""
    echo -e "${BOLD}${CYAN}"
    cat << 'BANNER'
   ██╗ ██╗███╗   ██╗███╗   ██╗ ██████╗ ██╗   ██╗ █████╗
   ██║ ██║████╗  ██║████╗  ██║██╔═══██╗██║   ██║██╔══██╗
   ██║ ██║██╔██╗ ██║██╔██╗ ██║██║   ██║██║   ██║███████║
   ██║ ██║██║╚██╗██║██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══██║
   ██║ ██║██║ ╚████║██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║
   ╚═╝ ╚═╝╚═╝  ╚═══╝╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝
BANNER
    echo -e "${RESET}"
    echo -e "   ${CYAN}innova — มนุษย์ Agent (จิต)${RESET}"
    echo -e "   $(date '+%A %d %B %Y %H:%M:%S')"
    echo ""

    # ── Oracle ──
    echo -ne "   Oracle: "
    if oracle_ready; then
      STATS=$(curl -sf "$ORACLE_URL/api/stats" 2>/dev/null || curl -sf "$ORACLE_URL/stats" 2>/dev/null)
      TOTAL=$(echo "$STATS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('totalDocuments', d.get('total','?')))" 2>/dev/null || echo "?")
      echo -e "${GREEN}✓ connected ($TOTAL docs)${RESET}"
    else
      echo -e "${RED}✗ offline — รัน: oracle.sh start${RESET}"
    fi

    # ── Limbs ──
    echo ""
    echo -e "   แขนขา (limbs):"
    for LIMB in lib think act speak ollama oracle; do
      F="$SCRIPT_DIR/${LIMB}.sh"
      if [ -f "$F" ]; then
        echo -e "     ${GREEN}✓${RESET} $LIMB.sh"
      else
        echo -e "     ${RED}✗${RESET} $LIMB.sh (ไม่พบ)"
      fi
    done

    # ── Soul check ──
    EVAL_DIR="$(dirname "$SCRIPT_DIR")/eval"
    if [ -f "$EVAL_DIR/soul-check.sh" ]; then
      echo ""
      echo "   soul-check:"
      bash "$EVAL_DIR/soul-check.sh" 2>/dev/null | grep -E "PASS|FAIL|✔|✘" | head -5 | sed 's/^/     /'
    fi

    echo ""
    log_action "WAKE" "$(date '+%Y-%m-%d %H:%M:%S')"
    ;;

  # ── Full pipeline: think → act → speak → remember ────────────────
  do)
    INTENT="$*"
    if [ -z "$INTENT" ]; then err "ต้องระบุ intent"; exit 1; fi

    # 1. สติ: หยุดคิด
    bash "$THINK" pause "$INTENT"

    # 2. ปัญญา: ค้นหาบริบทจาก Oracle
    bash "$THINK" reflect "$INTENT"

    # 3. กาย: log เจตนา
    log_action "DO" "$INTENT"

    # 4. วาจา: รายงาน
    bash "$SPEAK" announce "innova กำลังดำเนินการ: $INTENT"
    ;;

  # ── Reflect: Oracle + Ollama ─────────────────────────────────────
  reflect)
    TOPIC="$*"
    if [ -z "$TOPIC" ]; then err "ต้องระบุ topic"; exit 1; fi

    echo ""
    step "ค้นหา Oracle: $TOPIC"
    bash "$ORACLE" search "$TOPIC" 3

    echo ""
    step "ถาม Ollama พร้อม context..."
    bash "$OLLAMA" think "$TOPIC"
    ;;

  # ── Remember: บันทึกลง Oracle ────────────────────────────────────
  remember)
    PATTERN="$1" CONTENT="${2:-$1}" CONCEPTS="${3:-learning,innova}"
    if [ -z "$PATTERN" ]; then err "ต้องระบุ pattern"; exit 1; fi
    bash "$ACT" learn "$PATTERN" "$CONTENT" "$CONCEPTS"
    ;;

  # ── Status: สถานะทุกระบบ ─────────────────────────────────────────
  status)
    echo ""
    echo -e "${BOLD}=== innova Status ===${RESET}"
    echo -e "   เวลา: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    echo -ne "   Oracle:  "
    oracle_ready && echo -e "${GREEN}✓ online${RESET}" || echo -e "${RED}✗ offline${RESET}"

    echo ""
    echo -e "   Log ล่าสุด:"
    tail -5 "$JIT_LOG" 2>/dev/null | sed 's/^/     /' || echo "     (ไม่มี)"
    echo ""
    ;;

  # ── Help ─────────────────────────────────────────────────────────
  *)
    echo "Usage: index.sh <command>"
    echo ""
    echo "  wake               — ตื่นรู้ ตรวจสอบทุกระบบ"
    echo "  do    <intent>     — full pipeline (think→act→speak)"
    echo "  reflect <topic>    — Oracle + Ollama ร่วมกัน"
    echo "  remember <pattern> <content> <tags>  — บันทึกลง Oracle"
    echo "  status             — สถานะทุกระบบ"
    ;;
esac
