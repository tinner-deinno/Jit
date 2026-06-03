#!/usr/bin/env bash
# scripts/deploy-bridge.sh — Deploy and initialize the Innova Body Bridge
# This script ensures the environment is ready and the bridge is running as a daemon.

set -euo pipefail

# 1. Environment Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOT_DIR="$JIT_ROOT/hermes-discord"
LOG_FILE="/tmp/innova-body-bridge.log"
PID_FILE="/tmp/innova-body-bridge.pid"

# Load env
if [ -f "$JIT_ROOT/.env" ]; then
  set +u
  . "$JIT_ROOT/.env"
  set -u
fi

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

_info() { echo -e "${GREEN}INFO:${RESET} $1"; }
_warn() { echo -e "${YELLOW}WARN:${RESET} $1"; }
_err() { echo -e "${RED}ERROR:${RESET} $1"; exit 1; }

echo ""
echo -e "${BOLD}🚀 Deploying Innova Body Bridge...${RESET}"
echo ""

# 2. Dependency Validation
echo -e "Checking dependencies..."
if ! command -v node >/dev/null 2>&1; then
  _err "Node.js is not installed. Please install Node.js to run the bridge."
fi

if [ ! -f "$BOT_DIR/body-bridge.js" ]; then
  _err "Bridge source not found at $BOT_DIR/body-bridge.js"
fi

# 3. Directory Initialization
# Use the same logic as the JS bridge to ensure directories exist
# Default: .jit-bridge/inbox
BRIDGE_INBOX="${INNOVA_BOT_BRIDGE_DIR:-$JIT_ROOT/.jit-bridge/inbox}"
BRIDGE_ROOT=$(dirname "$BRIDGE_INBOX")

echo "Initializing bridge directories in $BRIDGE_ROOT..."
mkdir -p "$BRIDGE_INBOX"
mkdir -p "$BRIDGE_ROOT/processed"
mkdir -p "$BRIDGE_ROOT/failed"
mkdir -p "$BRIDGE_ROOT/acks"
mkdir -p "$BRIDGE_ROOT/tmp"

# 4. Configuration Validation
echo "Validating configuration..."
if [ -z "${JIT_ROOT}" ]; then
  _err "JIT_ROOT is not set."
fi

# 5. Deployment (Daemon Start)
echo "Starting bridge as daemon..."

# Stop existing instance if running
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    _info "Stopping existing bridge process (PID: $OLD_PID)..."
    kill "$OLD_PID" || true
    sleep 2
  fi
fi

# Launch the bridge using the existing start script's daemon mode
# We use the start script to keep the runtime flags consistent
bash "$SCRIPT_DIR/start-innova-body-bridge.sh" --daemon

if [ -f "$PID_FILE" ]; then
  NEW_PID=$(cat "$PID_FILE")
  _info "Bridge deployed successfully! PID: $NEW_PID"
  _info "Logs: $LOG_FILE"
  _info "Health Check: http://localhost:7011/health"
else
  _err "Bridge failed to start. Please check $LOG_FILE"
fi

echo ""
echo -e "${BOLD}✅ Deployment complete.${RESET}"
echo ""
