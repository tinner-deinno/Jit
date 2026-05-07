#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOT_DIR="$JIT_ROOT/hermes-discord"
LOG_FILE="/tmp/innova-body-bridge.log"
PID_FILE="/tmp/innova-body-bridge.pid"
MODE="${1:---status}"

if [ -f "$JIT_ROOT/.env" ]; then
  set +u
  # shellcheck disable=SC1091
  . "$JIT_ROOT/.env"
  set -u
fi

cd "$BOT_DIR"

run_bridge() {
  env \
    JIT_ROOT="$JIT_ROOT" \
    JIT_BUS_DIR="${JIT_BUS_DIR:-/tmp/manusat-bus}" \
    JIT_TOPOLOGY_FILE="${JIT_TOPOLOGY_FILE:-$JIT_ROOT/config/jit-topology.json}" \
    INNOVA_BOT_PATH="${INNOVA_BOT_PATH:-}" \
    INNOVA_BOT_BRIDGE_DIR="${INNOVA_BOT_BRIDGE_DIR:-}" \
    INNOVA_BOT_BRIDGE_URL="${INNOVA_BOT_BRIDGE_URL:-}" \
    JIT_BODY_BRIDGE_PORT="${JIT_BODY_BRIDGE_PORT:-7011}" \
    JIT_BODY_BRIDGE_HOST="${JIT_BODY_BRIDGE_HOST:-127.0.0.1}" \
    JIT_BODY_BRIDGE_POLL_MS="${JIT_BODY_BRIDGE_POLL_MS:-5000}" \
    JIT_BODY_EXECUTOR_COMMAND="${JIT_BODY_EXECUTOR_COMMAND:-bash $JIT_ROOT/scripts/discord-dev-executor.sh}" \
    JIT_BODY_EXECUTOR_FORWARD="${JIT_BODY_EXECUTOR_FORWARD:-}" \
    JIT_BODY_ROUTE_RECIPIENTS="${JIT_BODY_ROUTE_RECIPIENTS:-mue,innova,jit}" \
    node body-bridge.js "$@"
}

case "$MODE" in
  --status|status)
    run_bridge --status
    ;;
  --once|once)
    run_bridge --once
    ;;
  --test|test)
    run_bridge --test-payload
    ;;
  --daemon|daemon)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      sleep 1
    fi
    run_bridge --daemon >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "innova body bridge started pid=$! log=$LOG_FILE"
    ;;
  *)
    run_bridge "$MODE"
    ;;
esac