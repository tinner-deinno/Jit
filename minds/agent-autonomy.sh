#!/usr/bin/env bash
# minds/agent-autonomy.sh — Autonomous multiagent coordination engine for Jit
#
# This script keeps the Jit system alive by sensing bus messages, deciding where
# to route tasks, delegating to specialist agents, and updating shared state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then
  set -a
  . "$JIT_ROOT/.env"
  set +a
fi

AGENT_NAME="${AGENT_NAME:-jit}"
BUS_ROOT="/tmp/manusat-bus"
INBOX="$BUS_ROOT/$AGENT_NAME"
LOG_FILE="/tmp/agent-autonomy.log"
STATE_FILE="/tmp/agent-autonomy-state.json"
PID_FILE="/tmp/agent-autonomy.pid"

mkdir -p "$INBOX"

route_task_agent() {
  local SUBJECT="$1"
  declare -A ROUTE_TABLE=(
    [mcp]=mue
    [install]=mue
    [setup]=mue
    [connect]=mue
    [health]=netra
    [monitor]=netra
    [status]=netra
    [test]=chamu
    [qa]=chamu
    [quality]=chamu
    [review]=neta
    [audit]=neta
    [security]=neta
    [design]=rupa
    [ui]=rupa
    [ux]=rupa
    [deploy]=pada
    [infra]=pada
    [ci]=pada
    [build]=pada
    [sync]=pada
  )

  local key
  for key in "${!ROUTE_TABLE[@]}"; do
    if echo "$SUBJECT" | grep -qi "$key"; then
      echo "${ROUTE_TABLE[$key]}"
      return
    fi
  done
  echo "innova"
}

log_autonomy() {
  local MSG="$1"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [AUTONOMY] $MSG" | tee -a "$LOG_FILE"
}

update_selfhood() {
  local TS
  TS="$(date +%Y-%m-%dT%H:%M:%S)"
  bash "$JIT_ROOT/memory/shared.sh" set autonomy.alive true
  bash "$JIT_ROOT/memory/shared.sh" set autonomy.last_run "$TS"
  bash "$JIT_ROOT/memory/shared.sh" set autonomy.agent "$AGENT_NAME"
  bash "$JIT_ROOT/memory/shared.sh" announce autonomy.last_run "$TS"
  log_autonomy "selfhood updated | last_run=$TS"
}

broadcast_presence() {
  bash "$JIT_ROOT/network/bus.sh" broadcast "autonomy-alive" "${AGENT_NAME} is alive and routing tasks" >/dev/null 2>&1 || true
}

process_message_file() {
  local MSG_FILE="$1"
  local FROM SUBJECT BODY PREFIX TARGET

  FROM=$(grep -m1 '^from:' "$MSG_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ')
  SUBJECT=$(grep -m1 '^subject:' "$MSG_FILE" 2>/dev/null | cut -d: -f2- | sed 's/^ //')
  BODY=$(awk '/^---$/{found=1; next} found{print}' "$MSG_FILE" 2>/dev/null)
  PREFIX="${SUBJECT%%:*}"

  log_autonomy "received message from=$FROM subject=$SUBJECT"

  case "$PREFIX" in
    task)
      TARGET=$(route_task_agent "$SUBJECT")
      log_autonomy "routing task [$SUBJECT] → $TARGET"
      AGENT_NAME="$AGENT_NAME" bash "$JIT_ROOT/network/bus.sh" send "$TARGET" "$SUBJECT" "$BODY" >/dev/null 2>&1 || true
      bash "$JIT_ROOT/network/bus.sh" send "$FROM" "report:task-routed" "Task routed to $TARGET: $SUBJECT" >/dev/null 2>&1 || true
      ;;

    alert)
      TARGET="soma"
      log_autonomy "escalating alert to $TARGET"
      AGENT_NAME="$AGENT_NAME" bash "$JIT_ROOT/network/bus.sh" send "$TARGET" "$SUBJECT" "$BODY" >/dev/null 2>&1 || true
      ;;

    report)
      TARGET="vaja"
      log_autonomy "forwarding report to $TARGET"
      AGENT_NAME="$AGENT_NAME" bash "$JIT_ROOT/network/bus.sh" send "$TARGET" "$SUBJECT" "$BODY" >/dev/null 2>&1 || true
      ;;

    learn)
      TARGET="innova"
      log_autonomy "forwarding learn request to $TARGET"
      AGENT_NAME="$AGENT_NAME" bash "$JIT_ROOT/network/bus.sh" send "$TARGET" "$SUBJECT" "$BODY" >/dev/null 2>&1 || true
      ;;

    think)
      TARGET="soma"
      log_autonomy "forwarding think request to $TARGET"
      AGENT_NAME="$AGENT_NAME" bash "$JIT_ROOT/network/bus.sh" send "$TARGET" "$SUBJECT" "$BODY" >/dev/null 2>&1 || true
      ;;

    *)
      TARGET="innova"
      log_autonomy "default-forwarding to $TARGET"
      AGENT_NAME="$AGENT_NAME" bash "$JIT_ROOT/network/bus.sh" send "$TARGET" "$SUBJECT" "$BODY" >/dev/null 2>&1 || true
      ;;
  esac

  mv "$MSG_FILE" "${MSG_FILE%.msg}.read" >/dev/null 2>&1 || rm -f "$MSG_FILE"
}

run_autonomy_cycle() {
  local TS="$(date +%Y-%m-%dT%H:%M:%S)"
  log_autonomy "starting cycle"

  update_selfhood

  if [ -d "$INBOX" ]; then
    local COUNT=0
    for MSG_FILE in "$INBOX"/*.msg; do
      [ -f "$MSG_FILE" ] || continue
      COUNT=$((COUNT + 1))
      process_message_file "$MSG_FILE"
    done
    log_autonomy "processed $COUNT messages in inbox"
  fi

  local PENDING=$(find "$BUS_ROOT" -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')
  bash "$JIT_ROOT/memory/shared.sh" set autonomy.pending_tasks "$PENDING"

  local ORACLE_OK=0
  oracle_ready && ORACLE_OK=1 || ORACLE_OK=0
  bash "$JIT_ROOT/memory/shared.sh" set autonomy.oracle_ready "$ORACLE_OK"

  if [ "$ORACLE_OK" -eq 1 ]; then
    bash "$JIT_ROOT/memory/shared.sh" sync >/dev/null 2>&1 || true
  fi

  broadcast_presence

  python3 - <<PYEOF
import json
state = {
  'agent': '$AGENT_NAME',
  'last_cycle': '$TS',
  'pending_tasks': $PENDING,
  'oracle_ready': $ORACLE_OK
}
with open('$STATE_FILE', 'w', encoding='utf-8') as f:
  json.dump(state, f, ensure_ascii=False, indent=2)
PYEOF

  log_autonomy "cycle complete | pending=$PENDING oracle=$ORACLE_OK"
}

show_status() {
  echo "=== Agent Autonomy Status ==="
  echo "Agent: $AGENT_NAME"
  echo "Inbox: $INBOX"
  echo "Log: $LOG_FILE"
  echo "State: $STATE_FILE"
  echo "PID: ${PID_FILE}"
  echo
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Daemon: running (PID $(cat "$PID_FILE"))"
  else
    echo "Daemon: stopped"
  fi
  echo
  if [ -f "$STATE_FILE" ]; then
    python3 -m json.tool "$STATE_FILE" 2>/dev/null || cat "$STATE_FILE"
  else
    echo "No state file yet"
  fi
  echo
  echo "Recent log:"
  tail -10 "$LOG_FILE" 2>/dev/null || echo "(no log yet)"
}

start_daemon() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Already running: PID $(cat "$PID_FILE")"
    return
  fi
  local INTERVAL=300  # 5 นาที — routing เท่านั้น, heartbeat/commit อยู่ใน heartbeat.sh daemon
  nohup bash -lc "while true; do bash \"$0\" run-once; sleep $INTERVAL; done" >/dev/null 2>&1 &
  echo "$!" > "$PID_FILE"
  echo "Started autonomy daemon: PID $! (interval=$INTERVAL seconds)"
}

stop_daemon() {
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Stopped autonomy daemon"
  else
    echo "No daemon PID file"
  fi
}

case "${1:-status}" in
  start)
    start_daemon
    ;;
  stop)
    stop_daemon
    ;;
  status)
    show_status
    ;;
  run-once)
    run_autonomy_cycle
    ;;
  help|--help|-h)
    echo "Usage: $0 {start|stop|status|run-once|help}"
    echo
    echo "  start     — start a continuous autonomy daemon"
    echo "  stop      — stop the daemon"
    echo "  status    — show status and recent log"
    echo "  run-once  — run one autonomy cycle immediately"
    ;;
  *)
    echo "Unknown command: ${1:-status}"
    echo "Run with help for usage"
    exit 1
    ;;
esac
