#!/usr/bin/env bash
# scripts/bridge.sh — The Master Bridge Manager for Innova Body Bridge
# provides a unified interface for lifecycle management (up, down, restart, status, logs, check)

set -euo pipefail

# 1. Setup Environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="/tmp/innova-body-bridge.log"
PID_FILE="/tmp/innova-body-bridge.pid"

# Load environment variables
if [ -f "$JIT_ROOT/.env" ]; then
  set +u
  . "$JIT_ROOT/.env"
  set -u
fi

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'
BOLD='\033[1m'

_info() { echo -e "${GREEN}INFO:${RESET} $1"; }
_warn() { echo -e "${YELLOW}WARN:${RESET} $1"; }
_err() { echo -e "${RED}ERROR:${RESET} $1"; exit 1; }
_success() { echo -e "${GREEN}${BOLD}✅ $1${RESET}"; }

usage() {
  echo -e "${BOLD}Innova Body Bridge Manager${RESET}"
  echo ""
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  up        Deploy and start the bridge in daemon mode"
  echo "  down      Stop the bridge process"
  echo "  restart   Stop and start the bridge"
  echo "  status    Quick check if the bridge process is running"
  echo "  check     Run the full health-check suite (eval/bridge-check.sh)"
  echo "  logs      Tail the bridge logs in real-time"
  echo "  help      Show this help message"
  echo ""
}

# --- Lifecycle Commands ---

do_up() {
  _info "Deploying and starting Innova Body Bridge..."
  # We delegate to the existing deploy script to ensure all dirs are created
  bash "$SCRIPT_DIR/deploy-bridge.sh"
  _success "Bridge is up and running."
}

do_down() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    _info "Stopping bridge process (PID: $PID)..."
    kill "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    _success "Bridge stopped."
  else
    _warn "No PID file found. Bridge might not be running."
  fi
}

do_restart() {
  do_down
  sleep 1
  do_up
}

do_status() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      echo -e "Status: ${GREEN}${BOLD}RUNNING${RESET} (PID: $PID)"
      return 0
    fi
  fi
  echo -e "Status: ${RED}${BOLD}STOPPED${RESET}"
  return 1
}

do_check() {
  _info "Running comprehensive health check..."
  bash "$JIT_ROOT/eval/bridge-check.sh"
}

do_logs() {
  if [ -f "$LOG_FILE" ]; then
    _info "Tailing logs from $LOG_FILE..."
    tail -f "$LOG_FILE"
  else
    _err "Log file not found: $LOG_FILE"
  fi
}

# --- Main Execution ---

if [ $# -eq 0 ]; then
  usage
  exit 0
fi

COMMAND="$1"
shift || true

case "$COMMAND" in
  up)      do_up ;;
  down)    do_down ;;
  restart) do_restart ;;
  status)  do_status ;;
  check)   do_check ;;
  logs)    do_logs ;;
  help|--help|-h) usage ;;
  *)
    _err "Unknown command: $COMMAND\nRefer to 'bridge.sh help' for usage."
    ;;
esac
