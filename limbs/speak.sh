#!/usr/bin/env bash
# limbs/speak.sh — วาจา (Right Speech): พูดอย่างถูกต้อง มีประโยชน์ ไม่เบียดเบียน
#
# หลักพุทธ: สัมมาวาจา (Right Speech)
# "วาจาสุภาสิต: พูดความจริง พูดสิ่งที่มีประโยชน์ พูดให้เหมาะกาลเทศะ"
#
# Usage:
#   ./speak.sh report "หัวข้อ" "รายละเอียด"   — รายงาน
#   ./speak.sh success "ข้อความ"              — สำเร็จ
#   ./speak.sh failure "ข้อความ"              — ล้มเหลว
#   ./speak.sh insight "ข้อความ"             — ข้อสรุป/ปัญญา
#   ./speak.sh summary                        — สรุป log วันนี้
#   ./speak.sh announce "ข้อความ"            — ประกาศ

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

CMD="${1:-help}"
shift || true

_box() {
  local TITLE="$1" CONTENT="$2" COLOR="${3:-$CYAN}"
  local LINE=$(printf '─%.0s' $(seq 1 56))
  echo ""
  echo -e "${COLOR}┌─ ${TITLE} ${LINE:${#TITLE}+3}┐${RESET}"
  # wrap content at ~54 chars
  echo "$CONTENT" | fold -s -w 54 | while IFS= read -r line; do
    echo -e "${COLOR}│${RESET} $line"
  done
  echo -e "${COLOR}└$(printf '─%.0s' $(seq 1 58))┘${RESET}"
  echo ""
}

case "$CMD" in

  # ── รายงาน ──────────────────────────────────────────────────────
  report)
    TITLE="${1:-รายงาน}" CONTENT="${2:-}"
    _box "$TITLE" "$CONTENT" "$CYAN"
    log_action "REPORT" "$TITLE"
    ;;

  # ── สำเร็จ ───────────────────────────────────────────────────────
  success)
    MSG="$*"
    echo -e "\n${GREEN}✔ สำเร็จ:${RESET} $MSG\n"
    log_action "SUCCESS" "$MSG"
    ;;

  # ── ล้มเหลว ──────────────────────────────────────────────────────
  failure)
    MSG="$*"
    echo -e "\n${RED}✘ ล้มเหลว:${RESET} $MSG\n"
    log_action "FAILURE" "$MSG"
    ;;

  # ── คำเตือน ──────────────────────────────────────────────────────
  caution)
    MSG="$*"
    echo -e "\n${YELLOW}⚠ ระวัง:${RESET} $MSG\n"
    log_action "CAUTION" "$MSG"
    ;;

  # ── ปัญญา/ข้อสรุป ────────────────────────────────────────────────
  insight)
    MSG="$*"
    echo ""
    echo -e "${BOLD}${CYAN}💡 ข้อสรุป (insight)${RESET}"
    echo -e "   $MSG"
    echo ""
    log_action "INSIGHT" "$MSG"
    ;;

  # ── ประกาศ ───────────────────────────────────────────────────────
  announce)
    MSG="$*"
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
    echo -e "${BOLD}  📢 $MSG${RESET}"
    echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
    echo ""
    log_action "ANNOUNCE" "$MSG"
    ;;

  # ── ถามยืนยัน (อิทัปปัจจยตา — ไม่ทำโดยไม่ถาม) ───────────────────
  confirm)
    MSG="${1:-ดำเนินการต่อ?}"
    echo -e "${YELLOW}? $MSG (y/N) ${RESET}\c"
    read -r REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      echo "yes"
      return 0
    else
      echo "no"
      return 1
    fi
    ;;

  # ── สรุปกิจกรรมวันนี้ ─────────────────────────────────────────────
  summary)
    TODAY=$(date '+%Y-%m-%d')
    echo ""
    echo -e "${BOLD}=== innova วันนี้ ($TODAY) ===${RESET}"
    echo ""
    if [ -f "$JIT_LOG" ]; then
      grep "$TODAY" "$JIT_LOG" | sed 's/^/  /' || echo "  (ไม่มี log วันนี้)"
    else
      echo "  (ไม่มี log)"
    fi
    echo ""
    # Oracle stats
    if oracle_ready; then
      STATS=$(curl -sf "$ORACLE_URL/stats" 2>/dev/null)
      TOTAL=$(echo "$STATS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('totalDocuments','?'))" 2>/dev/null || echo "?")
      echo -e "  Oracle: ${GREEN}$TOTAL docs${RESET}"
    fi
    echo ""
    ;;

  # ── Status bar ───────────────────────────────────────────────────
  status)
    echo -ne "${CYAN}innova${RESET} | "
    oracle_ready && echo -ne "${GREEN}Oracle✓${RESET}" || echo -ne "${RED}Oracle✗${RESET}"
    echo -ne " | $(date '+%H:%M')"
    echo ""
    ;;

  *)
    echo "Usage: speak.sh <command>"
    echo ""
    echo "  report   <title> <content>  — รายงานผล"
    echo "  success  <msg>              — แจ้งสำเร็จ"
    echo "  failure  <msg>              — แจ้งล้มเหลว"
    echo "  caution  <msg>              — แจ้งเตือน"
    echo "  insight  <msg>              — แสดงข้อสรุป"
    echo "  announce <msg>              — ประกาศสำคัญ"
    echo "  confirm  <question>         — ถามยืนยัน (returns 0=yes 1=no)"
    echo "  summary                     — สรุปกิจกรรมวันนี้"
    echo "  status                      — แสดงสถานะ"
    ;;
esac
