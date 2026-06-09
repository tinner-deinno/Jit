#!/usr/bin/env bash
# eval/monitor.sh — Simple wrapper for monitoring spawns
# Spawns health-monitor.sh in the background for Codex CLI
# Usage:
#   bash eval/monitor.sh start [interval_seconds] — Start background monitor
#   bash eval/monitor.sh status                    — Get latest health status (JSON)
#   bash eval/monitor.sh stop                      — Stop background monitor
#   bash eval/monitor.sh check                     — One-time health check (JSON)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MONITOR_PID_FILE="/tmp/jit-health-monitor.pid"
MONITOR_LOG="/tmp/jit-health-monitor.log"
MONITOR_LATEST="/tmp/jit-health-monitor.latest.json"
INTERVAL="${2:-30}"

action="${1:-status}"

case "$action" in
  start)
    # Start background monitor if not already running
    if [ -f "$MONITOR_PID_FILE" ]; then
      PID=$(cat "$MONITOR_PID_FILE")
      if kill -0 "$PID" 2>/dev/null; then
        echo "Monitor already running (PID $PID)"
        exit 0
      fi
    fi

    # Spawn monitoring loop in background
    (
      while true; do
        bash "$JIT_ROOT/eval/health-monitor.sh" json all > "$MONITOR_LATEST" 2>&1
        sleep "$INTERVAL"
      done
    ) > "$MONITOR_LOG" 2>&1 &

    PID=$!
    echo "$PID" > "$MONITOR_PID_FILE"
    echo "{\"action\": \"start\", \"pid\": $PID, \"interval_seconds\": $INTERVAL, \"status\": \"started\"}"
    ;;

  stop)
    if [ -f "$MONITOR_PID_FILE" ]; then
      PID=$(cat "$MONITOR_PID_FILE")
      if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        rm "$MONITOR_PID_FILE"
        echo "{\"action\": \"stop\", \"status\": \"stopped\"}"
      else
        rm "$MONITOR_PID_FILE"
        echo "{\"action\": \"stop\", \"status\": \"not_running\"}"
      fi
    else
      echo "{\"action\": \"stop\", \"status\": \"not_running\"}"
    fi
    ;;

  status)
    # Return latest health snapshot
    if [ -f "$MONITOR_LATEST" ]; then
      cat "$MONITOR_LATEST"
    else
      echo "{\"status\": \"pending\", \"message\": \"No recent health check. Run 'bash eval/monitor.sh check' or start monitor.\"}"
    fi
    ;;

  check)
    # One-time synchronous check
    bash "$JIT_ROOT/eval/health-monitor.sh" json all
    ;;

  *)
    echo "Usage: bash eval/monitor.sh [start|stop|status|check] [interval_seconds]"
    echo "  start [30]  — Start background monitor (default 30s interval)"
    echo "  stop        — Stop background monitor"
    echo "  status      — Get latest health snapshot (JSON)"
    echo "  check       — Run one-time health check (JSON)"
    exit 1
    ;;
esac
