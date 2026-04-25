#!/usr/bin/env bash
# organs/ear.sh — หู (Hearing): ฟัง รับข้อมูล รับคำสั่ง
#
# หลักพุทธ: โสตาปัตติมรรค — เกิดปัญญาจากการฟัง (สุตมยปัญญา)
# บทบาท multiagent: รับ message จาก agent อื่น, ฟัง queue, รับ webhook
#
# Usage:
#   ./ear.sh listen               — รอรับ message (blocking)
#   ./ear.sh receive              — รับ message ที่รอ (non-blocking)
#   ./ear.sh inbox                — ดู inbox ของ agent นี้
#   ./ear.sh from <agent>         — รับเฉพาะจาก agent นั้น
#   ./ear.sh clear                — ล้าง inbox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

# inbox directory: แต่ละ agent มี inbox ของตัวเอง
AGENT_NAME="${AGENT_NAME:-innova}"
INBOX_DIR="${INBOX_DIR:-/tmp/manusat-bus}"
MY_INBOX="$INBOX_DIR/$AGENT_NAME"

mkdir -p "$MY_INBOX"

CMD="${1:-inbox}"
shift || true

case "$CMD" in

  # ── รอรับ message (blocking poll) ───────────────────────────────
  listen)
    TIMEOUT="${1:-60}"
    step "หู ฟัง inbox: $MY_INBOX (timeout ${TIMEOUT}s)"
    log_action "EAR_LISTEN" "waiting..."
    ELAPSED=0
    while [ $ELAPSED -lt "$TIMEOUT" ]; do
      MSG_FILE=$(ls "$MY_INBOX"/*.msg 2>/dev/null | head -1)
      if [ -n "$MSG_FILE" ]; then
        CONTENT=$(cat "$MSG_FILE")
        BASENAME=$(basename "$MSG_FILE")
        ok "หู ได้ยิน: $BASENAME"
        echo "$CONTENT"
        mv "$MSG_FILE" "$MY_INBOX/read_${BASENAME}"
        log_action "EAR_RECEIVED" "$BASENAME"
        break
      fi
      sleep 2
      ELAPSED=$((ELAPSED + 2))
    done
    [ $ELAPSED -ge "$TIMEOUT" ] && warn "timeout — ไม่มี message"
    ;;

  # ── รับ message ที่รอ (non-blocking) ────────────────────────────
  receive)
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    if [ "$MSGS" -eq 0 ]; then
      info "inbox ว่าง"
      exit 0
    fi
    step "หู รับ $MSGS messages:"
    for MSG_FILE in "$MY_INBOX"/*.msg; do
      [ -f "$MSG_FILE" ] || continue
      BASENAME=$(basename "$MSG_FILE")
      CONTENT=$(cat "$MSG_FILE")
      echo ""
      echo -e "${CYAN}── $BASENAME ──${RESET}"
      echo "$CONTENT"
      mv "$MSG_FILE" "$MY_INBOX/read_${BASENAME}"
      log_action "EAR_RECEIVED" "$BASENAME"
    done
    ;;

  # ── ดู inbox ─────────────────────────────────────────────────────
  inbox)
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    READ=$(ls "$MY_INBOX"/read_*.msg 2>/dev/null | wc -l)
    echo ""
    echo -e "${BOLD}📬 Inbox ของ $AGENT_NAME${RESET}"
    echo "   รอ: $MSGS | อ่านแล้ว: $READ"
    echo ""
    if [ "$MSGS" -gt 0 ]; then
      for MSG_FILE in "$MY_INBOX"/*.msg; do
        [ -f "$MSG_FILE" ] || continue
        BASENAME=$(basename "$MSG_FILE")
        # อ่าน metadata จาก header ของ message
        FROM=$(head -1 "$MSG_FILE" | grep -o 'from:[^ ]*' | cut -d: -f2)
        SUBJECT=$(head -2 "$MSG_FILE" | tail -1 | grep -o 'subject:.*' | cut -d: -f2-)
        echo "   📩 $BASENAME | from:${FROM:-?} | ${SUBJECT:-no subject}"
      done
    else
      info "ไม่มี message รอ"
    fi
    echo ""
    ;;

  # ── รับเฉพาะจาก agent ─────────────────────────────────────────────
  from)
    SENDER="$1"
    if [ -z "$SENDER" ]; then err "ต้องระบุ sender"; exit 1; fi
    step "หู ฟัง message จาก: $SENDER"
    for MSG_FILE in "$MY_INBOX"/*.msg; do
      [ -f "$MSG_FILE" ] || continue
      if grep -q "from:$SENDER" "$MSG_FILE" 2>/dev/null; then
        cat "$MSG_FILE"
        mv "$MSG_FILE" "$MY_INBOX/read_$(basename "$MSG_FILE")"
      fi
    done
    ;;

  # ── ล้าง inbox ───────────────────────────────────────────────────
  clear)
    rm -f "$MY_INBOX"/*.msg "$MY_INBOX"/read_*.msg 2>/dev/null
    ok "ล้าง inbox แล้ว"
    log_action "EAR_CLEAR" "$MY_INBOX"
    ;;

  # ── ให้พลังงาน (pulse) ─────────────────────────────────────────────────
  pulse)
    CONTEXT="$*"
    log_action "EAR_PULSE" "$CONTEXT"
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    echo "Ear receives clean energy and listens for new signals"
    echo "  inbox pending: ${MSGS:-0}"
    ;;

  # ── สถานะ ────────────────────────────────────────────────────────
  status)
    MSGS=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
    ok "หู (ear) พร้อม | inbox: $MY_INBOX | รอ: $MSGS messages"
    ;;

  *)
    echo "Usage: ear.sh {listen|receive|inbox|from|clear|status}"
    echo ""
    echo "  listen  [timeout]   — รอรับ message (default 60s)"
    echo "  receive             — รับทุก message ที่รอ"
    echo "  inbox               — ดูสถานะ inbox"
    echo "  from <agent>        — รับเฉพาะจาก agent"
    echo "  clear               — ล้าง inbox"
    ;;
esac
