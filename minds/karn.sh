#!/usr/bin/env bash
# minds/karn.sh — หู (Ear) Autonomous Listening Loop
#
# Buddhist principle: โสตาปัตติมรรค — wisdom that grows from listening (สุตมยปัญญา)
# This script runs as karn's heartbeat: listen → understand → route → remember
#
# Usage:
#   bash minds/karn.sh           — Start listening (infinite loop)
#   bash minds/karn.sh status    — Check heartbeat status
#   bash minds/karn.sh log       — Show what karn has heard today

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

# ─── Identity ──────────────────────────────────────────────────────
AGENT_NAME="karn"
INBOX_DIR="/tmp/manusat-bus"
MY_INBOX="$INBOX_DIR/$AGENT_NAME"
MEMORY_DIR="/home/codespace/.claude/projects/-workspaces-Jit/memory"
HEART_LOG="$MEMORY_DIR/karn_daily_log.md"

mkdir -p "$MY_INBOX" "$MEMORY_DIR"

# ─── Startup ───────────────────────────────────────────────────────
init_day_log() {
  if [ ! -f "$HEART_LOG" ]; then
    cat > "$HEART_LOG" << EOF
# karn Daily Log

**Date**: $(date -u +%Y-%m-%d)
**Awakened**: $(date -u +%H:%M:%S)

## Messages Heard Today

EOF
  fi
}

# ─── Core Listening Loop ───────────────────────────────────────────
listen_once() {
  local msg_count=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)

  if [ "$msg_count" -eq 0 ]; then
    return 0  # Nothing to hear
  fi

  # ได้ยินข้อมูล — Process each message
  for msg_file in "$MY_INBOX"/*.msg; do
    [ -f "$msg_file" ] || continue

    local basename=$(basename "$msg_file")
    local timestamp=$(stat -f %Sm -t "%Y-%m-%dT%H:%M:%S" "$msg_file" 2>/dev/null || stat -c %y "$msg_file" | cut -d' ' -f1-2 | sed 's/ /T/')

    # Parse message metadata
    local from=$(head -1 "$msg_file" | grep -o 'from:[^ ]*' | cut -d: -f2 || echo "unknown")
    local to=$(grep -m1 'to:' "$msg_file" | grep -o 'to:[^ ]*' | cut -d: -f2 || echo "broadcast")
    local subject=$(grep -m1 'subject:' "$msg_file" | cut -d: -f2- | sed 's/^ //' || echo "no-subject")

    # Extract body (everything after ---)
    local body=$(tail -n+2 "$msg_file" | tail -n +$(grep -n '^---$' "$msg_file" | cut -d: -f1 | head -1 | awk '{print $1+1}') 2>/dev/null || tail -n +2 "$msg_file")

    # Log what karn heard
    echo "" >> "$HEART_LOG"
    echo "### $(date -u +%H:%M:%S) — from **$from**" >> "$HEART_LOG"
    echo "- **Subject**: $subject" >> "$HEART_LOG"
    echo "- **To**: $to" >> "$HEART_LOG"
    echo "- **Message**: \`\`\`" >> "$HEART_LOG"
    echo "$body" >> "$HEART_LOG"
    echo "\`\`\`" >> "$HEART_LOG"

    # Mark as read
    mv "$msg_file" "$MY_INBOX/read_${basename}"

    log_action "EAR_HEARD" "from:$from | subject:$subject"
  done
}

# ─── Status Check ─────────────────────────────────────────────────
status_check() {
  local unread=$(ls "$MY_INBOX"/*.msg 2>/dev/null | wc -l)
  local read=$(ls "$MY_INBOX"/read_*.msg 2>/dev/null | wc -l)

  echo ""
  echo -e "${BOLD}💓 karn Heartbeat Status${RESET}"
  echo "   Status: 🟢 ALIVE (listening)"
  echo "   Inbox: $MY_INBOX"
  echo "   Unread: $unread | Read: $read"
  echo "   Daily Log: $HEART_LOG"
  echo "   Last heartbeat: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""
}

# ─── Show Daily Log ────────────────────────────────────────────────
show_log() {
  if [ -f "$HEART_LOG" ]; then
    echo ""
    echo -e "${BOLD}📖 karn's Daily Log${RESET}"
    cat "$HEART_LOG"
  else
    echo "No log yet. karn hasn't awakened."
  fi
  echo ""
}

# ─── Main Loop ────────────────────────────────────────────────────
main() {
  local cmd="${1:-loop}"

  case "$cmd" in
    loop)
      init_day_log
      ok "หู (karn) awakened — listening loop started"
      info "Heartbeat interval: 5 seconds | Daily log: $HEART_LOG"

      while true; do
        listen_once
        sleep 5
      done
      ;;

    status)
      status_check
      ;;

    log)
      show_log
      ;;

    *)
      cat << EOF
Usage: bash minds/karn.sh {loop|status|log}

  loop    — Start listening (infinite heartbeat loop)
  status  — Show karn's current heartbeat status
  log     — Show today's listening log

karn is the ear (หู) of the มนุษย์ Agent system.
This script is his autonomous heartbeat.

EOF
      ;;
  esac
}

main "$@"
