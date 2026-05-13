#!/usr/bin/env bash
#
# GSD — Jit Service Daemon
# Global Service Daemon managing all Jit system operations
# 
# Controls: heartbeat, hermes-discord, oracle, tests, git
# Purpose: 24/7 autonomous system with self-healing
#
# Usage:
#   gsd status          — Check all services
#   gsd start           — Start all services
#   gsd stop            — Stop all services
#   gsd restart         — Restart services
#   gsd health          — Full health check
#   gsd log             — View all logs
#   gsd test            — Run test suite
#   gsd deploy          — Deploy to production
#   gsd self-heal       — Detect and fix issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="${SCRIPT_DIR%/*}"
cd "$JIT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Configuration
GSD_VERSION="1.0.0"
GSD_LOG="/tmp/gsd.log"
SERVICES=(
  "jit-heartbeat"
  "hermes-discord"
)
CRITICAL_SERVICES=(
  "jit-heartbeat"
  "hermes-discord"
)

# ═══════════════════════════════════════════════════════════════
# Core Functions
# ═══════════════════════════════════════════════════════════════

log() {
  local level="$1" && shift
  local msg="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${CYAN}[${timestamp}]${RESET} ${level}: ${msg}" | tee -a "$GSD_LOG"
}

log_error() { log "ERROR" "$@"; }
log_warn() { log "WARN" "$@"; }
log_info() { log "INFO" "$@"; }
log_ok() { echo -e "${GREEN}✅${RESET} $@"; }
log_fail() { echo -e "${RED}❌${RESET} $@"; }

# ═══════════════════════════════════════════════════════════════
# Service Management
# ═══════════════════════════════════════════════════════════════

check_service_installed() {
  local service="$1"
  if systemctl list-unit-files | grep -q "^${service}\.service"; then
    return 0
  else
    return 1
  fi
}

service_status() {
  local service="$1"
  
  if ! check_service_installed "$service"; then
    echo "NOT_INSTALLED"
    return 1
  fi
  
  if systemctl is-active --quiet "$service"; then
    echo "RUNNING"
    return 0
  else
    echo "STOPPED"
    return 1
  fi
}

service_start() {
  local service="$1"
  log_info "Starting ${service}..."
  
  if ! check_service_installed "$service"; then
    log_error "${service} not installed"
    return 1
  fi
  
  if sudo systemctl start "$service"; then
    log_ok "${service} started"
    return 0
  else
    log_error "Failed to start ${service}"
    return 1
  fi
}

service_stop() {
  local service="$1"
  log_info "Stopping ${service}..."
  
  if ! check_service_installed "$service"; then
    log_warn "${service} not installed, skipping"
    return 0
  fi
  
  if sudo systemctl stop "$service"; then
    log_ok "${service} stopped"
    return 0
  else
    log_error "Failed to stop ${service}"
    return 1
  fi
}

service_restart() {
  local service="$1"
  log_info "Restarting ${service}..."
  
  service_stop "$service" || true
  sleep 2
  service_start "$service"
}

# ═══════════════════════════════════════════════════════════════
# Status Commands
# ═══════════════════════════════════════════════════════════════

cmd_status() {
  log_info "GSD Status Report (v${GSD_VERSION})"
  echo ""
  
  local all_ok=true
  for service in "${SERVICES[@]}"; do
    local status=$(service_status "$service" 2>/dev/null || echo "UNKNOWN")
    
    if [ "$status" = "RUNNING" ]; then
      log_ok "${service}: ${status}"
    else
      log_fail "${service}: ${status}"
      all_ok=false
    fi
  done
  
  echo ""
  
  # Check critical files
  echo -e "${BLUE}Critical Files:${RESET}"
  for file in \
    "/tmp/innova-heartbeat-daemon.json" \
    "/workspaces/Jit/memory/discord-memory.json" \
    "/tmp/discord-bot-last-active.timestamp"
  do
    if [ -f "$file" ]; then
      log_ok "$(basename $file) exists"
    else
      log_warn "$(basename $file) missing"
    fi
  done
  
  echo ""
  if [ "$all_ok" = true ]; then
    log_ok "All services running"
    return 0
  else
    log_fail "Some services not running"
    return 1
  fi
}

cmd_health() {
  log_info "Full System Health Check"
  echo ""
  
  local failures=0
  
  # 1. Service health
  echo -e "${BLUE}1. Services:${RESET}"
  for service in "${CRITICAL_SERVICES[@]}"; do
    if systemctl is-active --quiet "$service"; then
      log_ok "${service} active"
    else
      log_fail "${service} not active"
      ((failures++))
    fi
  done
  
  # 2. Heartbeat state
  echo ""
  echo -e "${BLUE}2. Heartbeat State:${RESET}"
  if [ -f "/tmp/innova-heartbeat-daemon.json" ]; then
    local beat_num=$(cat /tmp/innova-heartbeat-daemon.json | jq -r '.beat_num // 0')
    local last_success=$(cat /tmp/innova-heartbeat-daemon.json | jq -r '.last_success // "never"')
    log_ok "Beat #${beat_num}, Last success: ${last_success}"
  else
    log_warn "No heartbeat state found"
    ((failures++))
  fi
  
  # 3. Memory persistence
  echo ""
  echo -e "${BLUE}3. Memory:${RESET}"
  if [ -f "/workspaces/Jit/memory/discord-memory.json" ]; then
    local users=$(cat /workspaces/Jit/memory/discord-memory.json | jq '.users | length')
    local channels=$(cat /workspaces/Jit/memory/discord-memory.json | jq '.channels | length')
    log_ok "Memory OK (${users} users, ${channels} channels)"
  else
    log_warn "No memory file found"
  fi
  
  # 4. Git status
  echo ""
  echo -e "${BLUE}4. Git Repository:${RESET}"
  if git status > /dev/null 2>&1; then
    local commits=$(git rev-list --count HEAD)
    local branch=$(git rev-parse --abbrev-ref HEAD)
    log_ok "Git OK (${commits} commits, branch: ${branch})"
  else
    log_fail "Git repository issue"
    ((failures++))
  fi
  
  # 5. Oracle connectivity
  echo ""
  echo -e "${BLUE}5. Oracle (Knowledge Base):${RESET}"
  if curl -s http://localhost:47778/api/health | jq -e '.status == "ok"' > /dev/null 2>&1; then
    log_ok "Oracle online"
  else
    log_warn "Oracle offline or not responding"
  fi
  
  # 6. Ollama connectivity
  echo ""
  echo -e "${BLUE}6. MDES Ollama:${RESET}"
  if curl -s https://ollama.mdes-innova.online/api/health | jq -e '.status == "ok"' > /dev/null 2>&1; then
    log_ok "Ollama accessible"
  else
    log_warn "Ollama not responding (may be expected)"
  fi
  
  echo ""
  if [ $failures -eq 0 ]; then
    log_ok "System health: EXCELLENT"
    return 0
  elif [ $failures -lt 3 ]; then
    log_warn "System health: DEGRADED (${failures} issues)"
    return 1
  else
    log_fail "System health: CRITICAL (${failures} issues)"
    return 2
  fi
}

# ═══════════════════════════════════════════════════════════════
# Control Commands
# ═══════════════════════════════════════════════════════════════

cmd_start() {
  log_info "Starting all GSD services"
  
  for service in "${SERVICES[@]}"; do
    service_start "$service" || true
  done
  
  sleep 2
  cmd_status
}

cmd_stop() {
  log_info "Stopping all GSD services"
  
  for service in "${SERVICES[@]}"; do
    service_stop "$service" || true
  done
  
  log_ok "All services stopped"
}

cmd_restart() {
  log_info "Restarting all GSD services"
  cmd_stop
  sleep 3
  cmd_start
}

cmd_log() {
  echo -e "${BLUE}Hermes Discord Logs:${RESET}"
  journalctl -u hermes-discord -n 20 --no-pager || log_warn "No hermes logs yet"
  
  echo ""
  echo -e "${BLUE}Heartbeat Logs:${RESET}"
  journalctl -u jit-heartbeat -n 20 --no-pager || log_warn "No heartbeat logs yet"
  
  echo ""
  echo -e "${BLUE}GSD Log:${RESET}"
  tail -20 "$GSD_LOG" 2>/dev/null || log_warn "No GSD log yet"
}

# ═══════════════════════════════════════════════════════════════
# Test Commands
# ═══════════════════════════════════════════════════════════════

cmd_test() {
  log_info "Running Jit test suite"
  
  if [ ! -d "tests" ]; then
    log_error "tests/ directory not found"
    return 1
  fi
  
  # Run all Jit tests
  if command -v pytest &> /dev/null; then
    log_info "Running pytest..."
    pytest tests/test_jit_*.py -v --tb=short 2>&1 | tee -a "$GSD_LOG"
  else
    log_warn "pytest not found, trying python -m pytest"
    python3 -m pytest tests/test_jit_*.py -v --tb=short 2>&1 | tee -a "$GSD_LOG" || {
      log_warn "Python tests not available, trying shell tests"
      bash tests/test_integration.sh || true
    }
  fi
}

# ═══════════════════════════════════════════════════════════════
# Self-Healing
# ═══════════════════════════════════════════════════════════════

cmd_self_heal() {
  log_info "Running self-heal checks..."
  
  local fixed=0
  
  # 1. Check and restart dead services
  for service in "${CRITICAL_SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
      log_warn "${service} is down, attempting restart..."
      service_restart "$service" && ((fixed++))
    fi
  done
  
  # 2. Check memory file
  if [ ! -f "/workspaces/Jit/memory/discord-memory.json" ]; then
    log_warn "Memory file missing, creating..."
    mkdir -p /workspaces/Jit/memory
    echo '{"channels":{},"users":{},"lastAutoEngage":{},"timeSyncOffset":0}' \
      > /workspaces/Jit/memory/discord-memory.json
    ((fixed++))
  fi
  
  # 3. Check heartbeat state
  if [ ! -f "/tmp/innova-heartbeat-daemon.json" ]; then
    log_warn "Heartbeat state missing, initializing..."
    cat > /tmp/innova-heartbeat-daemon.json <<EOF
{
  "beat_num": 0,
  "status": "init",
  "last_success": "never",
  "consecutive_failures": 0,
  "initialized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    ((fixed++))
  fi
  
  # 4. Check git
  if ! git status > /dev/null 2>&1; then
    log_error "Git repository damaged"
    return 1
  fi
  
  # 5. Verify Discord token
  if ! grep -q "DISCORD_TOKEN=" .env 2>/dev/null; then
    log_warn "DISCORD_TOKEN not in .env (expected if not deployed)"
  fi
  
  echo ""
  if [ $fixed -gt 0 ]; then
    log_ok "Self-heal: Fixed ${fixed} issues"
    return 0
  else
    log_ok "Self-heal: No issues found"
    return 0
  fi
}

# ═══════════════════════════════════════════════════════════════
# Deploy
# ═══════════════════════════════════════════════════════════════

cmd_deploy() {
  log_info "Deploying Jit system to production"
  
  # 1. Check prerequisites
  echo -e "${BLUE}Checking prerequisites...${RESET}"
  
  if ! grep -q "DISCORD_TOKEN=" .env 2>/dev/null; then
    log_error "DISCORD_TOKEN not set in .env"
    echo "Set it with: echo 'DISCORD_TOKEN=your_token' >> .env"
    return 1
  fi
  log_ok "DISCORD_TOKEN found"
  
  if ! grep -q "OLLAMA_TOKEN=" .env 2>/dev/null; then
    log_warn "OLLAMA_TOKEN not set (may be optional)"
  else
    log_ok "OLLAMA_TOKEN found"
  fi
  
  # 2. Install services
  echo ""
  echo -e "${BLUE}Installing services...${RESET}"
  
  if [ -f "scripts/install-heartbeat-daemon.sh" ]; then
    log_info "Installing heartbeat daemon..."
    sudo bash scripts/install-heartbeat-daemon.sh || log_warn "Heartbeat install failed"
  fi
  
  if [ -f "scripts/install-hermes-discord-daemon.sh" ]; then
    log_info "Installing hermes daemon..."
    sudo bash scripts/install-hermes-discord-daemon.sh || log_warn "Hermes install failed"
  fi
  
  # 3. Run health check
  echo ""
  echo -e "${BLUE}Running health check...${RESET}"
  cmd_health
  
  # 4. Start services
  echo ""
  echo -e "${BLUE}Starting services...${RESET}"
  cmd_start
  
  # 5. Verify
  echo ""
  echo -e "${BLUE}Verifying deployment...${RESET}"
  sleep 3
  
  if cmd_status; then
    log_ok "Deployment successful!"
    echo ""
    echo -e "${CYAN}Next steps:${RESET}"
    echo "1. Watch logs: gsd log"
    echo "2. Check Discord for first auto-engage message in 5 min"
    echo "3. Check for heartbeat report in 15 min"
    return 0
  else
    log_fail "Deployment verification failed"
    return 1
  fi
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════

main() {
  local cmd="${1:-status}"
  
  case "$cmd" in
    status)    cmd_status ;;
    health)    cmd_health ;;
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    restart)   cmd_restart ;;
    log)       cmd_log ;;
    test)      cmd_test ;;
    self-heal) cmd_self_heal ;;
    deploy)    cmd_deploy ;;
    *)
      echo "GSD v${GSD_VERSION} — Jit Service Daemon"
      echo ""
      echo "Usage: gsd <command>"
      echo ""
      echo "Commands:"
      echo "  status          Check service status"
      echo "  health          Full health check"
      echo "  start           Start all services"
      echo "  stop            Stop all services"
      echo "  restart         Restart all services"
      echo "  log             View logs"
      echo "  test            Run test suite"
      echo "  self-heal       Auto-fix detected issues"
      echo "  deploy          Deploy to production"
      return 0
      ;;
  esac
}

main "$@"
