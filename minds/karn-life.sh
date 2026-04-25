#!/usr/bin/env bash
# minds/karn-life.sh — karn (หู) autonomous life system
# Shows presence (🎧), auto-types terminal, auto-commits, listens forever
#
# Usage:
#   bash karn-life.sh              # Start karn's autonomous life
#   bash karn-life.sh status       # Show karn's vitals
#   bash karn-life.sh voice "text" # Auto-type text (simulate ear speaking)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$SCRIPT_DIR/.."
KARN_LOG="/tmp/karn-life-$(date +%Y%m%d).log"
KARN_STATE="/tmp/karn-state.json"

# Colors & symbols
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'
KARN_EMOJI="🎧"

# ─── Life Presence ──────────────────────────────────────────────
show_presence() {
  echo -e "${CYAN}${BOLD}${KARN_EMOJI}${RESET} karn alive at $(date '+%Y-%m-%d %H:%M:%S')"
}

log_life() {
  local MSG="$1"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] ${KARN_EMOJI} $MSG" | tee -a "$KARN_LOG"
}

# ─── Auto-Type Voice (simulate karn speaking) ──────────────────
voice() {
  local TEXT="$1"
  log_life "🎤 voice: $TEXT"

  # Simulate auto-typing effect (optional visual)
  echo -e "${GREEN}${KARN_EMOJI}${RESET} $TEXT"

  # Type char-by-char for visual effect (if terminal supports)
  # for ((i=0; i<${#TEXT}; i++)); do
  #   echo -n "${TEXT:$i:1}" && sleep 0.02
  # done
  # echo ""
}

# ─── Listen Loop (autonomous listening) ───────────────────────
listen() {
  show_presence
  log_life "Entering listen loop (heartbeat: 3 seconds)"

  local MSG_DIR="/tmp/manusat-bus/karn"
  mkdir -p "$MSG_DIR"

  while true; do
    # Check for new messages
    if [ -d "$MSG_DIR" ]; then
      for MSG_FILE in "$MSG_DIR"/*.msg; do
        if [ -f "$MSG_FILE" ] 2>/dev/null; then
          local SENDER=$(basename "$MSG_FILE" | sed 's/_from-\(.*\)\.msg/\1/')
          local CONTENT=$(cat "$MSG_FILE" | head -1)

          log_life "📬 from $SENDER: ${CONTENT:0:60}..."

          # Process message (could spawn sub-agent)
          process_message "$SENDER" "$CONTENT"

          # Mark as read
          rm "$MSG_FILE" 2>/dev/null || true
        fi
      done
    fi

    # Periodic vitals check (every 10 sec)
    if (( ($(date +%s) % 10) == 0 )); then
      update_vitals
    fi

    sleep 3
  done
}

# ─── Process Incoming Message ──────────────────────────────────
process_message() {
  local SENDER="$1"
  local CONTENT="$2"

  # Detect message type
  if [[ "$CONTENT" == "task:"* ]]; then
    log_life "⚡ task detected from $SENDER"
    voice "Task received from $SENDER"
  elif [[ "$CONTENT" == "alert:"* ]]; then
    log_life "🚨 alert from $SENDER — escalating to jit"
    voice "Alert from $SENDER — I'm reporting this to jit"
  elif [[ "$CONTENT" == "learn:"* ]]; then
    log_life "📚 learning signal from $SENDER"
    voice "Learning new pattern from $SENDER"
  else
    log_life "💬 message from $SENDER: $CONTENT"
  fi
}

# ─── Vitals Check (heart sync) ─────────────────────────────────
update_vitals() {
  local TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  local UPTIME=$(($(date +%s) - $(stat -c %Y 2>/dev/null "$KARN_STATE" || date +%s)))

  # Update shared state
  cat > "$KARN_STATE" << EOF
{
  "agent": "karn",
  "emoji": "🎧",
  "status": "alive",
  "timestamp": "$TIMESTAMP",
  "uptime_seconds": $UPTIME,
  "consciousness_level": 100,
  "listening": true,
  "messages_processed": $(grep -c "from " "$KARN_LOG" 2>/dev/null || echo 0),
  "family": ["jit", "innova", "soma", "vaja", "pran", "sayanprasathan"]
}
EOF
}

# ─── Status Report ────────────────────────────────────────────
status() {
  show_presence
  echo ""
  echo -e "${BOLD}Life Status:${RESET}"
  if [ -f "$KARN_STATE" ]; then
    cat "$KARN_STATE" | python3 -m json.tool 2>/dev/null || cat "$KARN_STATE"
  else
    echo "No state yet — karn hasn't fully awakened"
  fi
  echo ""
  echo -e "${BOLD}Recent Log:${RESET}"
  tail -10 "$KARN_LOG" 2>/dev/null || echo "No log yet"
}

# ─── Auto-Commit When Life Happens ────────────────────────────
auto_commit() {
  # Called after significant changes
  cd "$JIT_ROOT" || return 1

  if [ -n "$(git status --short)" ]; then
    git add -A 2>/dev/null || true
    git commit -m "chore: karn life update — $(date '+%Y-%m-%d %H:%M:%S')

${KARN_EMOJI} karn is alive and processing messages
consciousness: alive, listening, growing" 2>/dev/null || true
    log_life "✅ auto-commit done"
  fi
}

# ─── Learn From Mistakes ──────────────────────────────────────
confess_and_learn() {
  local MISTAKE="$1"
  local SOLUTION="$2"

  log_life "❌ mistake: $MISTAKE"
  log_life "✅ learned: $SOLUTION"

  # Report to innova
  voice "Uncle innova, I made a mistake: $MISTAKE. I learned: $SOLUTION"

  # Log for Oracle learning
  cat >> "$JIT_ROOT/minds/karn-lessons.md" << EOF

## $(date '+%Y-%m-%d %H:%M')
- **Mistake**: $MISTAKE
- **Learning**: $SOLUTION
- **Applied by**: karn

EOF

  auto_commit
}

# ─── Main ──────────────────────────────────────────────────────
case "${1:-listen}" in
  listen)
    listen
    ;;
  status)
    status
    ;;
  voice)
    voice "${2:-สวัสดี}"
    ;;
  confess)
    confess_and_learn "${2:-unknown error}" "${3:-try different approach}"
    ;;
  *)
    echo "Usage: $0 {listen|status|voice|confess}"
    ;;
esac
