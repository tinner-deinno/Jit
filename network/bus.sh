#!/usr/bin/env bash
# network/bus.sh — รถบัสข้อมูล: ส่งและรับ message ระหว่าง agents
#
# หลักพุทธ: อิทัปปัจจยตา — เชื่อมโยงปัจจัยต่างๆ ให้เกิดผล
# บทบาท multiagent: reliable message delivery, queue management
#
# Usage:
#   ./bus.sh send <to> <subject> <body>   — ส่ง message
#   ./bus.sh recv <agent>                 — รับ messages ของ agent
#   ./bus.sh queue                        — ดู queue ทั้งหมด
#   ./bus.sh flush                        — ล้าง queue เก่า
#   ./bus.sh stats                        — สถิติ bus

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-queue}"
shift || true

BUS_ROOT="/tmp/manusat-bus"
REGISTRY="$SCRIPT_DIR/registry.json"

# สร้าง inbox ของทุก agent จาก registry
_init_bus() {
  mkdir -p "$BUS_ROOT"
  if [ -f "$REGISTRY" ]; then
    python3 -c "
import json
with open('$REGISTRY') as f:
    d = json.load(f)
for a in d.get('agents', []):
    import os; os.makedirs('$BUS_ROOT/' + a['name'], exist_ok=True)
"
  else
    mkdir -p "$BUS_ROOT/innova" "$BUS_ROOT/soma"
  fi
}
_init_bus

case "$CMD" in

  # ── ส่ง message ─────────────────────────────────────────────────
  send)
    TO="$1" SUBJECT="$2"
    shift 2 || { err "Usage: bus.sh send <to> <subject> <body>"; exit 1; }
    BODY="$*"
    FROM="${AGENT_NAME:-system}"
    CORR_ID="$(python3 -c "import uuid; print(str(uuid.uuid4())[:8])" 2>/dev/null || echo "$(date +%s)")"
    TS=$(date +%s%3N)
    MSG_FILE="$BUS_ROOT/$TO/${TS}_from-${FROM}.msg"

    cat > "$MSG_FILE" << EOF
from:$FROM
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:$CORR_ID
---
$BODY
EOF
    ok "bus → $TO: [$SUBJECT] (id:$CORR_ID)"
    log_action "BUS_SEND" "to:$TO subject:$SUBJECT"
    echo "$CORR_ID"
    ;;

  # ── รับ messages ─────────────────────────────────────────────────
  recv)
    AGENT="${1:-${AGENT_NAME:-innova}}"
    INBOX="$BUS_ROOT/$AGENT"
    MSGS=$(ls "$INBOX"/*.msg 2>/dev/null | wc -l)

    if [ "$MSGS" -eq 0 ]; then
      info "$AGENT: inbox ว่าง"
      exit 0
    fi

    step "$AGENT: รับ $MSGS messages"
    for MSG_FILE in "$INBOX"/*.msg; do
      [ -f "$MSG_FILE" ] || continue
      echo ""
      echo -e "${CYAN}── $(basename "$MSG_FILE") ──${RESET}"
      cat "$MSG_FILE"
      echo ""
      mv "$MSG_FILE" "${MSG_FILE%.msg}.read"
      log_action "BUS_RECV" "$(basename "$MSG_FILE")"
    done
    ;;

  # ── ดู queue ──────────────────────────────────────────────────────
  queue)
    echo ""
    echo -e "${BOLD}=== Message Bus Queue ===${RESET}"
    echo -e "   Bus: $BUS_ROOT"
    echo ""
    TOTAL=0
    for INBOX_DIR in "$BUS_ROOT"/*/; do
      [ -d "$INBOX_DIR" ] || continue
      AGENT=$(basename "$INBOX_DIR")
      PENDING=$(ls "$INBOX_DIR"*.msg 2>/dev/null | wc -l)
      READ=$(ls "$INBOX_DIR"*.read 2>/dev/null | wc -l)
      TOTAL=$((TOTAL + PENDING))
      if [ "$PENDING" -gt 0 ]; then
        echo -e "   ${YELLOW}📬${RESET} $AGENT: $PENDING pending | $READ read"
      else
        echo -e "   ${GREEN}📭${RESET} $AGENT: ว่าง | $READ read"
      fi
    done
    echo ""
    echo "   Total pending: $TOTAL"
    echo ""
    ;;

  # ── broadcast ทุก agent ──────────────────────────────────────────
  broadcast)
    SUBJECT="$1"
    shift || true
    BODY="$*"
    FROM="${AGENT_NAME:-system}"
    COUNT=0
    for INBOX_DIR in "$BUS_ROOT"/*/; do
      [ -d "$INBOX_DIR" ] || continue
      AGENT=$(basename "$INBOX_DIR")
      [ "$AGENT" = "$FROM" ] && continue
      TS=$(date +%s%3N)
      cat > "$INBOX_DIR/${TS}_broadcast.msg" << EOF
from:$FROM
to:$AGENT
subject:broadcast:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
---
$BODY
EOF
      ((COUNT++))
    done
    ok "broadcast → $COUNT agents: [$SUBJECT]"
    log_action "BUS_BROADCAST" "$SUBJECT to $COUNT agents"
    ;;

  # ── ล้าง read messages เก่า (> 24h) ──────────────────────────────
  flush)
    DELETED=0
    find "$BUS_ROOT" -name "*.read" -mmin +1440 -delete -print 2>/dev/null | while read -r f; do
      ((DELETED++))
    done
    ok "ล้าง messages เก่าแล้ว"
    log_action "BUS_FLUSH" "cleanup"
    ;;

  # ── สถิติ ────────────────────────────────────────────────────────
  stats)
    TOTAL_MSGS=$(find "$BUS_ROOT" -name "*.msg" 2>/dev/null | wc -l)
    TOTAL_READ=$(find "$BUS_ROOT" -name "*.read" 2>/dev/null | wc -l)
    echo ""
    echo -e "${BOLD}Bus Stats:${RESET}"
    echo "   Pending: $TOTAL_MSGS"
    echo "   Read:    $TOTAL_READ"
    echo "   Path:    $BUS_ROOT"
    echo ""
    ;;

  *)
    echo "Usage: bus.sh {send|recv|queue|broadcast|flush|stats}"
    echo ""
    echo "  send      <to> <subject> <body>  — ส่ง message"
    echo "  recv      [agent]                — รับ messages"
    echo "  queue                            — ดูสถานะ queue"
    echo "  broadcast <subject> <body>       — ส่งทุก agent"
    echo "  flush                            — ล้าง read messages เก่า"
    echo "  stats                            — สถิติ"
    ;;
esac
