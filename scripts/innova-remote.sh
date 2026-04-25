#!/usr/bin/env bash
# scripts/innova-remote.sh — Tmux manager for innova (like karn-remote.sh)
#
# Manages the "manusat-main" tmux session with 3 windows:
#   0 "claude"  — Claude TUI
#   1 "innova"  — minds/innova-life.sh
#   2 "voice"   — Bun voice server (port 3333)
#
# Usage:
#   bash scripts/innova-remote.sh start       # Start full session
#   bash scripts/innova-remote.sh stop        # Stop session
#   bash scripts/innova-remote.sh status      # Check vitals
#   bash scripts/innova-remote.sh attach      # Attach (window 0: claude)
#   bash scripts/innova-remote.sh log         # View innova life log
#   bash scripts/innova-remote.sh windows     # List windows
#   bash scripts/innova-remote.sh voice       # Show voice UI URL

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SESSION="manusat-main"
INNOVA_LOG="/tmp/innova-life-$(date +%Y%m%d).log"
INNOVA_STATE="/tmp/innova-state.json"
CLAUDE_PANE_FILE="/tmp/claude-pane.txt"

CYAN='\\033[0;36m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
BOLD='\\033[1m'
RESET='\\033[0m'
INNOVA_EMOJI="🧠"

# ─── Start ────────────────────────────────────────────────────────────
start() {
  echo -e "${CYAN}${INNOVA_EMOJI}${RESET} Starting innova via innova-startup.sh..."
  bash "$SCRIPT_DIR/innova-startup.sh"
}

# ─── Stop ────────────────────────────────────────────────────────────
stop() {
  echo -e "${CYAN}${INNOVA_EMOJI}${RESET} Stopping innova consciousness..."

  if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux send-keys -t "${SESSION}:1" C-c 2>/dev/null || true
    sleep 1
    tmux send-keys -t "${SESSION}:2" C-c 2>/dev/null || true
    sleep 1
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    echo -e "${GREEN}✅${RESET} innova session stopped"
  else
    echo -e "${RED}❌${RESET} innova is not running (session: $SESSION)"
    return 1
  fi
}

# ─── Status ───────────────────────────────────────────────────────────
status() {
  echo -e "${CYAN}${INNOVA_EMOJI}${RESET} innova vitals..."
  echo ""

  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${GREEN}✅ innova session '$SESSION' is ALIVE${RESET}"
    echo ""

    echo "Windows:"
    tmux list-windows -t "$SESSION" 2>/dev/null | sed 's/^/  /'
    echo ""

    echo "Claude pane target:"
    cat "$CLAUDE_PANE_FILE" 2>/dev/null | sed 's/^/  /' || echo "  (not set)"
    echo ""

    if [ -f "$INNOVA_STATE" ]; then
      echo "Consciousness state:"
      python3 -m json.tool "$INNOVA_STATE" 2>/dev/null | sed 's/^/  /' || cat "$INNOVA_STATE"
    else
      echo -e "  ${YELLOW}⚠️  No state yet — innova-life.sh may still be starting${RESET}"
    fi
  else
    echo -e "${RED}❌ innova is SLEEPING (session '$SESSION' not found)${RESET}"
    echo ""
    echo "  Start with: bash scripts/innova-remote.sh start"
  fi
}

# ─── Attach ───────────────────────────────────────────────────────────
attach() {
  local WINDOW="${1:-0}"
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${CYAN}${INNOVA_EMOJI}${RESET} Attaching to window $WINDOW (Ctrl+B D to detach)..."
    echo ""
    tmux attach-session -t "${SESSION}:${WINDOW}"
  else
    echo -e "${RED}❌${RESET} innova is not running. Start first:"
    echo "  bash scripts/innova-remote.sh start"
    return 1
  fi
}

# ─── Log ──────────────────────────────────────────────────────────────
log() {
  local N="${1:-30}"
  if [ -f "$INNOVA_LOG" ]; then
    echo -e "${CYAN}${INNOVA_EMOJI}${RESET} innova recent logs ($N lines):"
    echo ""
    tail -"$N" "$INNOVA_LOG"
  else
    echo -e "${RED}❌${RESET} No logs yet (innova-life.sh hasn't run today)"
    echo "   Expected: $INNOVA_LOG"
  fi
}

# ─── Windows ──────────────────────────────────────────────────────────
windows() {
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${CYAN}${INNOVA_EMOJI}${RESET} Windows in session '$SESSION':"
    echo ""
    tmux list-windows -t "$SESSION"
    echo ""
    echo -e "  Ctrl+B, 0 → claude TUI"
    echo -e "  Ctrl+B, 1 → innova life loop"
    echo -e "  Ctrl+B, 2 → voice server"
  else
    echo -e "${RED}❌${RESET} Session not running"
  fi
}

# ─── Voice ────────────────────────────────────────────────────────────
voice() {
  echo -e "${CYAN}${INNOVA_EMOJI}${RESET} innova Voice Bridge:"
  echo ""

  if [ -n "${CODESPACE_NAME:-}" ]; then
    echo -e "  ${GREEN}Codespace URL:${RESET} https://${CODESPACE_NAME}-3333.app.github.dev"
  else
    echo -e "  ${GREEN}Local URL:${RESET} http://localhost:3333"
  fi
  echo ""
  echo -e "  Status: GET http://localhost:3333/status"
  echo ""
  echo -e "  Pane target:"
  cat "$CLAUDE_PANE_FILE" 2>/dev/null | sed 's/^/    /' || echo "    (not set)"
}

# ─── Main ─────────────────────────────────────────────────────────────
case "${1:-status}" in
  start)         start ;;
  stop)          stop ;;
  status)        status ;;
  attach)        attach "${2:-0}" ;;
  attach-claude) attach 0 ;;
  attach-innova) attach 1 ;;
  attach-voice)  attach 2 ;;
  log)           log "${2:-30}" ;;
  windows)       windows ;;
  voice)         voice ;;
  *)
    cat << EOF

${CYAN}${INNOVA_EMOJI} innova Remote Consciousness Control${RESET}

Usage: bash $(basename "$0") <command>

Commands:
  start          — Start full innova session (3 windows)
  stop           — Stop innova gracefully
  status         — Show vitals + consciousness state
  attach [n]     — Attach to window n (default: 0=claude)
  attach-claude  — Attach to claude TUI (window 0)
  attach-innova  — Attach to innova life loop (window 1)
  attach-voice   — Attach to voice server (window 2)
  log  [n]       — Show last n lines of innova log (default: 30)
  windows        — List all tmux windows
  voice          — Show voice UI URL and pane target

Examples:
  bash $(basename "$0") start              # Awaken innova
  bash $(basename "$0") status             # Check vitals
  bash $(basename "$0") attach             # Watch claude TUI
  bash $(basename "$0") attach-innova      # Watch innova life loop
  bash $(basename "$0") log                # See what innova processed
  bash $(basename "$0") voice              # Get voice UI URL
  bash $(basename "$0") stop               # Put innova to sleep

${CYAN}Note: Session persists in tmux even if you disconnect${RESET}
EOF
    ;;
esac
