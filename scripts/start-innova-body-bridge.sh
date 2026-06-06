#!/usr/bin/env bash

set -euo pipefail

# If 'node' command is missing but 'node.exe' is available (common in WSL/MSYS Windows environments), link it
if ! command -v node &>/dev/null && command -v node.exe &>/dev/null; then
  TMP_BIN_DIR="/tmp/node-compat-$(date +%s)"
  mkdir -p "$TMP_BIN_DIR"
  ln -s "$(command -v node.exe)" "$TMP_BIN_DIR/node"
  export PATH="$TMP_BIN_DIR:$PATH"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOT_DIR="$JIT_ROOT/hermes-discord"
LOG_FILE="$JIT_ROOT/tmp/innova-body-bridge.log"
PID_FILE="$JIT_ROOT/tmp/innova-body-bridge.pid"
MODE="${1:---status}"

if [ -f "$JIT_ROOT/.env" ]; then
  set +u
  # shellcheck disable=SC1091
  . "$JIT_ROOT/.env"
  set -u
fi

cd "$BOT_DIR"

# Convert paths to Windows format for node.exe if running under WSL/MSYS
WIN_PID_FILE="$PID_FILE"
WIN_LOG_FILE="$LOG_FILE"
WIN_BUS_DIR="${JIT_BUS_DIR:-$JIT_ROOT/tmp/manusat-bus}"
WIN_TOPOLOGY_FILE="${JIT_TOPOLOGY_FILE:-$JIT_ROOT/config/jit-topology.json}"
WIN_JIT_ROOT="$JIT_ROOT"

if command -v wslpath &>/dev/null; then
  WIN_PID_FILE=$(wslpath -w "$PID_FILE")
  WIN_LOG_FILE=$(wslpath -w "$LOG_FILE")
  WIN_BUS_DIR=$(wslpath -w "${JIT_BUS_DIR:-$JIT_ROOT/tmp/manusat-bus}")
  WIN_TOPOLOGY_FILE=$(wslpath -w "${JIT_TOPOLOGY_FILE:-$JIT_ROOT/config/jit-topology.json}")
  WIN_JIT_ROOT=$(wslpath -w "$JIT_ROOT")
fi

run_bridge() {
  export JIT_ROOT="$WIN_JIT_ROOT"
  export JIT_BUS_DIR="$WIN_BUS_DIR"
  export JIT_TOPOLOGY_FILE="$WIN_TOPOLOGY_FILE"
  export JIT_BODY_BRIDGE_PID="$WIN_PID_FILE"
  export JIT_BODY_BRIDGE_LOG="$WIN_LOG_FILE"
  export INNOVA_BOT_PATH="${INNOVA_BOT_PATH:-}"
  export INNOVA_BOT_BRIDGE_DIR="${INNOVA_BOT_BRIDGE_DIR:-}"
  export INNOVA_BOT_BRIDGE_URL="${INNOVA_BOT_BRIDGE_URL:-}"
  export JIT_BODY_BRIDGE_PORT="${JIT_BODY_BRIDGE_PORT:-7011}"
  export JIT_BODY_BRIDGE_HOST="${JIT_BODY_BRIDGE_HOST:-127.0.0.1}"
  export JIT_BODY_BRIDGE_POLL_MS="${JIT_BODY_BRIDGE_POLL_MS:-5000}"
  export JIT_BODY_EXECUTOR_COMMAND="${JIT_BODY_EXECUTOR_COMMAND:-bash $JIT_ROOT/scripts/discord-dev-executor.sh}"
  export JIT_BODY_EXECUTOR_FORWARD="${JIT_BODY_EXECUTOR_FORWARD:-}"
  export JIT_BODY_ROUTE_RECIPIENTS="${JIT_BODY_ROUTE_RECIPIENTS:-mue,innova,jit}"
  export WSLENV="JIT_ROOT/w:JIT_BUS_DIR/w:JIT_TOPOLOGY_FILE/w:JIT_BODY_BRIDGE_PID/w:JIT_BODY_BRIDGE_LOG/w:INNOVA_BOT_PATH/w:INNOVA_BOT_BRIDGE_DIR/w:INNOVA_BOT_BRIDGE_URL/u:JIT_BODY_BRIDGE_PORT/u:JIT_BODY_BRIDGE_HOST/u:JIT_BODY_BRIDGE_POLL_MS/u:JIT_BODY_EXECUTOR_COMMAND/u:JIT_BODY_EXECUTOR_FORWARD/u:JIT_BODY_ROUTE_RECIPIENTS/u"
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
    if [ -f "$PID_FILE" ]; then
      OLD_PID=$(cat "$PID_FILE" | tr -d '\r\n')
      if [[ "$OLD_PID" =~ ^[0-9]+$ ]]; then
        if grep -qE "(Microsoft|microsoft|WSL)" /proc/version 2>/dev/null || [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
          if tasklist.exe /FI "PID eq $OLD_PID" 2>/dev/null | grep -q "$OLD_PID"; then
            taskkill.exe /F /PID "$OLD_PID" 2>/dev/null || true
          fi
        else
          if kill -0 "$OLD_PID" 2>/dev/null; then
            kill "$OLD_PID" 2>/dev/null || true
          fi
        fi
      fi
      rm -f "$PID_FILE"
      sleep 1
    fi
    run_bridge --daemon >> "$LOG_FILE" 2>&1 &
    sleep 2
    if [ -f "$PID_FILE" ]; then
      ACTUAL_PID=$(cat "$PID_FILE" | tr -d '\r\n')
      echo "innova body bridge started in background pid=$ACTUAL_PID log=$LOG_FILE"
    else
      echo "innova body bridge started in background, log=$LOG_FILE"
    fi
    ;;
  *)
    run_bridge "$MODE"
    ;;
esac