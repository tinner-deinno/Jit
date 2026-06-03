#!/usr/bin/env bash
# eval/bridge-check.sh — ตรวจสอบสุขภาพของ Innova Body Bridge
# Bridge Health Integrity Check

set -euo pipefail

# 1. Setup Environment
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
JIT_ROOT="$(pwd)"

# Load environment variables
if [ -f "$JIT_ROOT/.env" ]; then
  set +u
  . "$JIT_ROOT/.env"
  set -u
fi

# Defaults for bridge config
BRIDGE_PORT="${JIT_BODY_BRIDGE_PORT:-7011}"
BRIDGE_HOST="${JIT_BODY_BRIDGE_HOST:-127.0.0.1}"
BRIDGE_URL="http://$BRIDGE_HOST:$BRIDGE_PORT/health"
PID_FILE="/tmp/innova-body-bridge.pid"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

_pass() { echo -e "  ${GREEN}✅${RESET} $1"; return 0; }
_fail() { echo -e "  ${RED}❌${RESET} $1"; return 1; }
_warn() { echo -e "  ${YELLOW}⚠️ ${RESET} $1"; return 0; }

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Innova Body Bridge Health Check${RESET}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"

EXIT_CODE=0

# 2. Process Check
echo -e "\n[ Process ]"
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    _pass "Bridge process is running (PID: $PID)"
  else
    _fail "PID file exists but process $PID is NOT running"
    EXIT_CODE=1
  fi
else
  _fail "PID file not found ($PID_FILE)"
  EXIT_CODE=1
fi

# 3. Endpoint Check (The "Heartbeat")
echo -e "\n[ Endpoint ]"
if curl -sf "$BRIDGE_URL" > /dev/null 2>&1; then
  HEALTH_JSON=$(curl -sf "$BRIDGE_URL")
  _pass "Health endpoint is responsive ($BRIDGE_URL)"

  # Analyze health payload
  echo "  Details:"
  echo "$HEALTH_JSON" | python3 -m json.tool | sed 's/^/    /' || true

  # Check for critical failures in the payload
  if echo "$HEALTH_JSON" | grep -q '"ok": false'; then
    _fail "Bridge reports internally: NOT OK"
    EXIT_CODE=1
  fi
else
  _fail "Health endpoint unreachable: $BRIDGE_URL"
  EXIT_CODE=1
fi

# 4. Directory & Permissions Check
echo -e "\n[ Filesystem ]"
# Use the bridge's own logic to find the bridge root if possible, or assume defaults
BRIDGE_DIR="${INNOVA_BOT_BRIDGE_DIR:-$JIT_ROOT/.jit-bridge/inbox}"
if [ -d "$BRIDGE_DIR" ]; then
  _pass "Bridge inbox exists: $BRIDGE_DIR"

  # Check if inbox is clogged
  COUNT=$(find "$BRIDGE_DIR" -maxdepth 1 -name "*.json" | wc -l)
  if [ "$COUNT" -gt 50 ]; then
    _warn "Inbox is potentially clogged: $COUNT pending messages"
  else
    _pass "Inbox load is normal: $COUNT messages"
  fi
else
  _fail "Bridge inbox directory missing: $BRIDGE_DIR"
  EXIT_CODE=1
fi

# 5. Executor Check
echo -e "\n[ Executor ]"
EXECUTOR_CMD="${JIT_BODY_EXECUTOR_COMMAND:-bash $JIT_ROOT/scripts/discord-dev-executor.sh}"
# Remove 'bash ' prefix if present to check for executable
CHECK_CMD=$(echo "$EXECUTOR_CMD" | sed 's/^bash //')
if [ -f "$CHECK_CMD" ]; then
  if [ -x "$CHECK_CMD" ]; then
    _pass "Executor found and executable: $CHECK_CMD"
  else
    _warn "Executor found but NOT executable: $CHECK_CMD"
  fi
else
  _fail "Executor script not found: $CHECK_CMD"
  EXIT_CODE=1
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}🌟 Bridge is healthy and synchronized.${RESET}"
else
  echo -e "  ${RED}${BOLD}❌ Bridge health check failed. Please check logs.${RESET}"
fi
echo ""

exit $EXIT_CODE
