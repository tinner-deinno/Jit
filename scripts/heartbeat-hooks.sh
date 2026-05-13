#!/usr/bin/env bash
# scripts/heartbeat-hooks.sh — ❤️ Heartbeat event hooks (trace, logging, agents)
#
# Purpose: Define hooks that run on each heartbeat pulse
# Called by: heartbeat.sh after each IN/OUT pulse
#
# Hooks:
#   - trace: update git trace logs
#   - log: append to heartbeat log
#   - notify: signal agents via bus
#   - oracle: persist to Oracle (if needed)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
[ -f "$JIT_ROOT/.env" ] && set -a && source "$JIT_ROOT/.env" && set +a
[ -f "$JIT_ROOT/limbs/lib.sh" ] && source "$JIT_ROOT/limbs/lib.sh"

BUS_ROOT="${BUS_ROOT:-/tmp/manusat-bus}"
HEARTBEAT_LOG="${HEARTBEAT_LOG:-/tmp/innova-heartbeat.log}"

# ─────────────────────────────────────────────────────────────────
# Hook: Trace
# ─────────────────────────────────────────────────────────────────
hook_trace() {
  local pulse_number="$1"
  local pulse_type="$2"  # IN or OUT
  
  # Only run trace every N pulses (to avoid overhead)
  # IN = odd numbers, OUT = even numbers
  # Run full trace on every 6th heartbeat (every ~90 min)
  
  if [ $((pulse_number % 6)) -eq 0 ]; then
    bash "$SCRIPT_DIR/trace-commits.sh" --auto > /dev/null 2>&1 &
  fi
  
  # Always update heartbeat trace (lightweight)
  bash "$SCRIPT_DIR/heartbeat-trace.sh" --auto "$pulse_number" > /dev/null 2>&1 &
}

# ─────────────────────────────────────────────────────────────────
# Hook: Log
# ─────────────────────────────────────────────────────────────────
hook_log() {
  local pulse_number="$1"
  local pulse_type="$2"
  local timestamp="$(date -Iseconds)"
  
  {
    echo "[$timestamp] Pulse #$pulse_number ($pulse_type)"
    echo "  Host: $(hostname)"
    echo "  User: $(whoami)"
    echo "  Pid: $$"
  } >> "$HEARTBEAT_LOG"
}

# ─────────────────────────────────────────────────────────────────
# Hook: Notify agents via bus
# ─────────────────────────────────────────────────────────────────
hook_notify() {
  local pulse_number="$1"
  local pulse_type="$2"
  
  # Create heartbeat event message on bus
  if [ -d "$BUS_ROOT" ]; then
    local event_dir="$BUS_ROOT/pran"
    mkdir -p "$event_dir"
    
    # ON OUT pulses, broadcast status to all agents
    if [ "$pulse_type" = "OUT" ]; then
      local subject="heartbeat:out"
      local body="pulse #$pulse_number @ $(date)"
      
      # This is optional — only if agent bus is ready
      [ -f "$SCRIPT_DIR/../organs/mouth.sh" ] && \
        bash "$SCRIPT_DIR/../organs/mouth.sh" broadcast "$subject" "$body" 2>/dev/null || true
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────
# Main: Route to specific hook
# ─────────────────────────────────────────────────────────────────
case "$1" in
  trace)
    hook_trace "$2" "$3"
    ;;
  log)
    hook_log "$2" "$3"
    ;;
  notify)
    hook_notify "$2" "$3"
    ;;
  *)
    # Run all hooks
    hook_trace "$2" "$3"
    hook_log "$2" "$3"
    hook_notify "$2" "$3"
    ;;
esac
