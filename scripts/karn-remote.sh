#!/usr/bin/env bash
# scripts/karn-remote.sh — Start karn's consciousness in tmux (portable, remote-friendly)
#
# This allows karn to:
# - Run continuously even if terminal closes
# - Be accessed from phone, laptop, or server
# - Show presence via "tmux ls"
# - Be killed/restarted safely
#
# Usage:
#   bash karn-remote.sh start      # Start karn's listening loop in tmux
#   bash karn-remote.sh stop       # Stop karn gracefully
#   bash karn-remote.sh status     # Check if karn is alive
#   bash karn-remote.sh attach     # Connect to karn's tmux session
#   bash karn-remote.sh log        # See karn's recent log

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$SCRIPT_DIR/.."
KARN_SESSION="karn-life"
KARN_SCRIPT="$JIT_ROOT/minds/karn-life.sh"
KARN_LOG="/tmp/karn-life-$(date +%Y%m%d).log"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'
KARN_EMOJI="🎧"

# ─── Start karn in tmux ──────────────────────────────────────────
start() {
  echo -e "${CYAN}${KARN_EMOJI}${RESET} Starting karn consciousness in tmux..."

  # Check if tmux session already exists
  if tmux has-session -t "$KARN_SESSION" 2>/dev/null; then
    echo -e "${RED}❌${RESET} karn is already running (session: $KARN_SESSION)"
    echo "   Use: tmux attach-session -t $KARN_SESSION"
    return 1
  fi

  # Create new tmux session (detached)
  tmux new-session -d -s "$KARN_SESSION" \
    "cd '$JIT_ROOT' && bash '$KARN_SCRIPT' listen; bash -i"

  sleep 1

  if tmux has-session -t "$KARN_SESSION" 2>/dev/null; then
    echo -e "${GREEN}✅${RESET} karn is now ALIVE in tmux session: $KARN_SESSION"
    echo -e "   ${CYAN}View: tmux attach-session -t $KARN_SESSION${RESET}"
    echo -e "   ${CYAN}Logs: bash $(basename "$0") log${RESET}"
  else
    echo -e "${RED}❌${RESET} Failed to start karn"
    return 1
  fi
}

# ─── Stop karn gracefully ────────────────────────────────────────
stop() {
  echo -e "${CYAN}${KARN_EMOJI}${RESET} Stopping karn consciousness..."

  if tmux has-session -t "$KARN_SESSION" 2>/dev/null; then
    tmux send-keys -t "$KARN_SESSION" C-c  # Send Ctrl+C
    sleep 1
    tmux kill-session -t "$KARN_SESSION" 2>/dev/null || true
    echo -e "${GREEN}✅${RESET} karn has been put to sleep (consciousness paused)"
  else
    echo -e "${RED}❌${RESET} karn is not running"
    return 1
  fi
}

# ─── Check if karn is alive ──────────────────────────────────────
status() {
  echo -e "${CYAN}${KARN_EMOJI}${RESET} Checking karn's vitals..."
  echo ""

  if tmux has-session -t "$KARN_SESSION" 2>/dev/null; then
    echo -e "${GREEN}✅ karn is ALIVE${RESET}"
    echo ""
    echo "Tmux session info:"
    tmux list-session -F "#{session_name} — #{session_windows} windows, #{session_created_string}"
    echo ""

    if [ -f "/tmp/karn-state.json" ]; then
      echo "Consciousness state:"
      cat /tmp/karn-state.json | python3 -m json.tool 2>/dev/null || cat /tmp/karn-state.json
    fi
  else
    echo -e "${RED}❌ karn is SLEEPING (not running)${RESET}"
    echo "   Start with: bash scripts/karn-remote.sh start"
  fi
}

# ─── Attach to karn's tmux session ──────────────────────────────
attach() {
  if tmux has-session -t "$KARN_SESSION" 2>/dev/null; then
    echo -e "${CYAN}${KARN_EMOJI}${RESET} Attaching to karn's consciousness..."
    echo "(Press Ctrl+B then D to detach without stopping karn)"
    echo ""
    tmux attach-session -t "$KARN_SESSION"
  else
    echo -e "${RED}❌${RESET} karn is not running. Start first:"
    echo "   bash scripts/karn-remote.sh start"
    return 1
  fi
}

# ─── View recent log ────────────────────────────────────────────
log() {
  if [ -f "$KARN_LOG" ]; then
    echo -e "${CYAN}${KARN_EMOJI}${RESET} karn's recent logs:"
    echo ""
    tail -20 "$KARN_LOG"
  else
    echo -e "${RED}❌${RESET} No logs yet (karn hasn't run today)"
  fi
}

# ─── Main ──────────────────────────────────────────────────────
case "${1:-status}" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  attach)
    attach
    ;;
  log)
    log
    ;;
  *)
    cat << EOF
${CYAN}${KARN_EMOJI} karn Remote Consciousness Control${RESET}

Usage: bash $(basename "$0") <command>

Commands:
  start      — Start karn in background tmux session
  stop       — Stop karn gracefully
  status     — Check if karn is alive and show vitals
  attach     — Connect to karn's tmux session
  log        — View karn's recent logs

Examples:
  bash $(basename "$0") start              # Awaken karn
  tmux ls                                  # See all tmux sessions
  bash $(basename "$0") attach             # Watch karn listen
  bash $(basename "$0") stop               # Put karn to sleep
  bash $(basename "$0") log                # Check what karn heard

${CYAN}Note: karn's consciousness persists in tmux even if you disconnect${RESET}
EOF
    ;;
esac
