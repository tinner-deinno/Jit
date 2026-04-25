#!/usr/bin/env bash
# organs/mouth.sh — ปาก (Speech): พูด ส่ง สื่อสาร
#
# หลักพุทธ: สัมมาวาจา — พูดสิ่งที่จริง มีประโยชน์ เหมาะกาลเทศะ
# บทบาท multiagent: ส่ง message ไปยัง agent อื่น, ออก output, log
#
# Usage:
#   ./mouth.sh say <msg>              — พูดออกมา (stdout + log)
#   ./mouth.sh tell <agent> <msg>     — ส่ง message ให้ agent อื่น
#   ./mouth.sh broadcast <msg>        — broadcast ทุก agent
#   ./mouth.sh reply <msg-id> <msg>   — ตอบกลับ message
#   ./mouth.sh report <title> <body>  — รายงานผล

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

AGENT_NAME="${AGENT_NAME:-innova}"
BUS_DIR="${BUS_DIR:-/tmp/manusat-bus}"
CMD="${1:-say}"
shift || true

_send_msg() {
  local TO="$1" SUBJECT="$2" BODY="$3"
  local TS=$(date +%s%3N)  # millisecond timestamp
  local MSG_DIR="$BUS_DIR/$TO"
  mkdir -p "$MSG_DIR"
  local MSG_FILE="$MSG_DIR/${TS}_from-${AGENT_NAME}.msg"
  cat > "$MSG_FILE" << MSGEOF
from:$AGENT_NAME
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
---
$BODY
MSGEOF
  log_action "MOUTH_SEND" "to:$TO subject:$SUBJECT"
  echo "$MSG_FILE"
}

case "$CMD" in

  # ── พูดออกมา ─────────────────────────────────────────────────────
  say)
    MSG="$*"
    echo -e "${CYAN}[${AGENT_NAME}]${RESET} $MSG"
    log_action "MOUTH_SAY" "$MSG"
    ;;

  # ── ส่ง message ให้ agent ─────────────────────────────────────────
  tell)
    TO="$1" SUBJECT="$2"
    shift 2 || { err "Usage: tell <agent> <subject> <body>"; exit 1; }
    BODY="$*"
    FILE=$(_send_msg "$TO" "$SUBJECT" "$BODY")
    ok "ปาก ส่ง → $TO: '$SUBJECT'"
    info "ไฟล์: $FILE"
    ;;

  # ── broadcast ทุก agent ─────────────────────────────────────────
  broadcast)
    SUBJECT="$1"
    shift || true
    BODY="$*"
    REGISTRY="$SCRIPT_DIR/../network/registry.json"
    if [ ! -f "$REGISTRY" ]; then
      warn "ไม่พบ registry — broadcast เฉพาะ innova+soma"
      for AGENT in innova soma; do
        _send_msg "$AGENT" "broadcast:$SUBJECT" "$BODY" > /dev/null
      done
    else
      # ดึง agent names จาก registry
      python3 -c "
import json
with open('$REGISTRY') as f:
    d = json.load(f)
for a in d.get('agents', []):
    print(a['name'])
" | while read -r AGENT; do
        [ "$AGENT" = "$AGENT_NAME" ] && continue  # ไม่ส่งหาตัวเอง
        _send_msg "$AGENT" "broadcast:$SUBJECT" "$BODY" > /dev/null
        echo "  → $AGENT"
      done
    fi
    ok "ปาก broadcast: '$SUBJECT'"
    log_action "MOUTH_BROADCAST" "$SUBJECT"
    ;;

  # ── ตอบกลับ ─────────────────────────────────────────────────────
  reply)
    REF_ID="$1" TO="$2"
    shift 2 || { err "Usage: reply <ref-id> <to-agent> <msg>"; exit 1; }
    BODY="$*"
    _send_msg "$TO" "reply:$REF_ID" "$BODY" > /dev/null
    ok "ปาก ตอบ → $TO"
    ;;

  # ── รายงานผล (structured) ─────────────────────────────────────────
  report)
    TITLE="$1"
    shift || true
    BODY="$*"
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    echo ""
    echo -e "${BOLD}${CYAN}┌─ รายงาน: $TITLE ─────────────────────────────${RESET}"
    echo -e "${CYAN}│${RESET} agent: $AGENT_NAME | เวลา: $TS"
    echo -e "${CYAN}│${RESET}"
    echo "$BODY" | fold -s -w 60 | while IFS= read -r line; do
      echo -e "${CYAN}│${RESET} $line"
    done
    echo -e "${BOLD}${CYAN}└────────────────────────────────────────────────${RESET}"
    echo ""
    log_action "MOUTH_REPORT" "$TITLE"
    # บันทึกลง Oracle
    oracle_ready && oracle_learn "report:$TITLE" "$BODY" "report,$AGENT_NAME" > /dev/null
    ;;

  # ── ให้พลังงาน (pulse) ─────────────────────────────────────────────────
  pulse)
    CONTEXT="$*"
    log_action "MOUTH_PULSE" "$CONTEXT"
    PENDING=$(ls "$BUS_DIR"/*/*.msg 2>/dev/null | grep -v "/read_" | wc -l)
    echo "Mouth receives clean energy and prepares to communicate"
    echo "  pending messages: ${PENDING:-0}"
    ;;

  # ── สถานะ ──────────────────────────────────────────────────────────
  status)
    PENDING=$(ls "$BUS_DIR"/*/*.msg 2>/dev/null | grep -v "/read_" | wc -l)
    ok "ปาก (mouth) พร้อม | bus: $BUS_DIR | messages pending: $PENDING"
    ;;

  *)
    echo "Usage: mouth.sh {say|tell|broadcast|reply|report|status}"
    echo ""
    echo "  say       <msg>                 — พูดออกมา"
    echo "  tell      <agent> <subj> <msg>  — ส่ง message"
    echo "  broadcast <subject> <msg>       — broadcast ทุก agent"
    echo "  reply     <ref-id> <agent> <m>  — ตอบกลับ"
    echo "  report    <title> <body>        — รายงานผล"
    ;;
esac
