#!/usr/bin/env bash
# scripts/start-24h-heartbeat.sh — Start 24/7 innova heartbeat monitor
#
# Usage:
#   bash scripts/start-24h-heartbeat.sh
#   # Monitor in background, auto-restart if fails

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

HEARTBEAT_SCRIPT="$JIT_ROOT/scripts/heartbeat-enhanced.sh"
HEARTBEAT_PID_FILE="/tmp/innova-heartbeat.pid"
HEARTBEAT_LOG="/tmp/innova-heartbeat-enhanced.log"
HEARTBEAT_MONITOR_LOG="/tmp/innova-heartbeat-monitor.log"
PULSE_INTERVAL="${PULSE_INTERVAL:-900}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function: Log
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$HEARTBEAT_MONITOR_LOG"
}

# Function: Check if heartbeat is running
is_running() {
  if [ -f "$HEARTBEAT_PID_FILE" ]; then
    local pid=$(cat "$HEARTBEAT_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

# Function: Start heartbeat monitor
start_monitor() {
  log "${GREEN}🫀 Starting 24/7 Heartbeat Monitor${NC}"
  
  # Check if already running
  if is_running; then
    log "${YELLOW}⚠️  Heartbeat already running (PID: $(cat $HEARTBEAT_PID_FILE))${NC}"
    return 1
  fi
  
  # Verify OLLAMA_TOKEN
  if [ -z "${OLLAMA_TOKEN:-}" ]; then
    log "${RED}❌ ERROR: OLLAMA_TOKEN not set${NC}"
    return 1
  fi
  
  # Create monitor process
  {
    # Store PID
    echo $$ > "$HEARTBEAT_PID_FILE"
    
    log "${GREEN}✅ Monitor started (PID: $$)${NC}"
    log "📊 Pulse interval: ${PULSE_INTERVAL}s"
    log "📝 Logs: $HEARTBEAT_LOG"
    log ""
    
    # Main loop: run heartbeat with auto-restart
    local restart_count=0
    local max_consecutive_failures=5
    local consecutive_failures=0
    
    while true; do
      log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      log "${BLUE}🫀 Heartbeat cycle (restart count: $restart_count)${NC}"
      log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      
      # Run heartbeat cycle
      if bash "$HEARTBEAT_SCRIPT" once >> "$HEARTBEAT_LOG" 2>&1; then
        log "${GREEN}✅ Heartbeat cycle successful${NC}"
        consecutive_failures=0
        restart_count=$((restart_count + 1))
      else
        log "${RED}❌ Heartbeat cycle failed${NC}"
        consecutive_failures=$((consecutive_failures + 1))
        
        if [ $consecutive_failures -ge $max_consecutive_failures ]; then
          log "${RED}🚨 CRITICAL: $consecutive_failures consecutive failures!${NC}"
          log "${RED}   System may be unresponsive. Check logs:${NC}"
          log "${RED}   tail -f $HEARTBEAT_LOG${NC}"
        fi
      fi
      
      log "${BLUE}💤 Sleeping ${PULSE_INTERVAL}s before next beat...${NC}"
      sleep "$PULSE_INTERVAL"
    done
  } &
  
  # Background process PID
  local bg_pid=$!
  sleep 1
  
  if is_running; then
    log "${GREEN}✅ Monitor is running (PID: $bg_pid)${NC}"
    return 0
  else
    log "${RED}❌ Failed to start monitor${NC}"
    return 1
  fi
}

# Function: Stop heartbeat monitor
stop_monitor() {
  if [ -f "$HEARTBEAT_PID_FILE" ]; then
    local pid=$(cat "$HEARTBEAT_PID_FILE")
    log "${YELLOW}🛑 Stopping heartbeat monitor (PID: $pid)${NC}"
    kill "$pid" 2>/dev/null || true
    rm -f "$HEARTBEAT_PID_FILE"
    log "${GREEN}✅ Monitor stopped${NC}"
  else
    log "${YELLOW}⚠️  Monitor not running${NC}"
  fi
}

# Function: Show status
show_status() {
  echo ""
  echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "${BLUE}📊 Heartbeat Monitor Status${NC}"
  echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if is_running; then
    echo "${GREEN}✅ Status: RUNNING (PID: $(cat $HEARTBEAT_PID_FILE))${NC}"
  else
    echo "${RED}❌ Status: STOPPED${NC}"
  fi
  
  echo ""
  echo "${BLUE}Recent Activity:${NC}"
  tail -15 "$HEARTBEAT_LOG" 2>/dev/null || echo "No activity yet"
  
  echo ""
  echo "${BLUE}Configuration:${NC}"
  echo "  Pulse Interval: ${PULSE_INTERVAL}s"
  echo "  Heartbeat Script: $HEARTBEAT_SCRIPT"
  echo "  Log File: $HEARTBEAT_LOG"
  echo "  Monitor Log: $HEARTBEAT_MONITOR_LOG"
  echo ""
  echo "${BLUE}Commands:${NC}"
  echo "  Start:  bash $JIT_ROOT/scripts/start-24h-heartbeat.sh start"
  echo "  Stop:   bash $JIT_ROOT/scripts/start-24h-heartbeat.sh stop"
  echo "  Status: bash $JIT_ROOT/scripts/start-24h-heartbeat.sh status"
  echo "  Logs:   tail -f $HEARTBEAT_LOG"
  echo ""
  echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main CLI
main() {
  local cmd="${1:-status}"
  
  case "$cmd" in
    start)
      start_monitor
      ;;
    stop)
      stop_monitor
      ;;
    status)
      show_status
      ;;
    restart)
      stop_monitor
      sleep 2
      start_monitor
      ;;
    *)
      echo "Usage: $0 {start|stop|status|restart}"
      exit 1
      ;;
  esac
}

main "$@"
