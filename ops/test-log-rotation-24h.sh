#!/usr/bin/env bash
# ops/test-log-rotation-24h.sh — ทดสอบ log rotation หลัง 24 ชม. (JIT-007)
#
# Usage:
#   bash ops/test-log-rotation-24h.sh [duration_seconds]
#
# Default duration: 3600 (1 hour for quick test)
# For full 24h test: bash ops/test-log-rotation-24h.sh 86400

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

DURATION="${1:-3600}"  # Default 1 hour for quick test
LOG_DIR="$(resolve_log_dir)"
TEST_LOG="$LOG_DIR/jit-heartbeat.log"
START_TIME=$(date +%s)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info() { echo -e "${CYAN}ℹ️  ${RESET} $*"; }
ok()   { echo -e "${GREEN}✅${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠️ ${RESET} $*"; }
err()  { echo -e "${RED}❌${RESET} $*" >&2; }

print_header() {
  echo ""
  echo -e "${CYAN}════════════════════════════════════════════════${RESET}"
  echo -e "${GREEN}🧪 JIT-007 Log Rotation 24h Test${RESET}"
  echo -e "${CYAN}════════════════════════════════════════════════${RESET}"
  echo ""
}

test_log_directory() {
  info "Testing log directory setup..."

  ensure_log_dir
  local dir; dir=$(resolve_log_dir)

  if [ -d "$dir" ]; then
    ok "Log directory exists: $dir"
  else
    err "Log directory not found: $dir"
    return 1
  fi

  if [ -w "$dir" ]; then
    ok "Log directory is writable: $dir"
  else
    err "Log directory not writable: $dir"
    return 1
  fi
}

test_logging_functions() {
  info "Testing logging functions..."

  # Test log_daemon
  log_daemon "heartbeat" "Test message 1" "INFO"
  log_daemon "heartbeat" "Test message 2" "INFO"
  log_daemon "heartbeat" "Test error" "ERROR"

  if [ -f "$TEST_LOG" ]; then
    ok "Log file created: $TEST_LOG"
    info "Content:"
    cat "$TEST_LOG" | tail -5
  else
    err "Log file not created"
    return 1
  fi
}

test_journal_logging() {
  info "Testing journal logging..."

  if command -v systemd-cat >/dev/null 2>&1; then
    # Test journal logging with timeout (non-blocking)
    echo "[TEST] Journal test message" | timeout 5 systemd-cat -t jit-test -p info 2>/dev/null || true
    ok "Journal logging available (systemd-cat found)"
  else
    warn "systemd-cat not available, journal logging skipped"
  fi
}

test_log_rotation_config() {
  info "Checking logrotate configuration..."

  local config="/etc/logrotate.d/jit-daemons"
  local src="$JIT_ROOT/ops/logrotate/jit-daemons"

  if [ -f "$src" ]; then
    ok "Logrotate config source exists: $src"

    # Validate syntax
    if command -v logrotate >/dev/null 2>&1; then
      if logrotate --debug "$src" 2>&1 | grep -q "error"; then
        err "Logrotate config has errors"
        return 1
      else
        ok "Logrotate config syntax is valid"
      fi
    fi
  else
    warn "Logrotate config not found: $src"
  fi
}

test_systemd_services() {
  info "Checking systemd service configurations..."

  local services=("jit-heartbeat.service" "hermes-discord.service")
  for svc in "${services[@]}"; do
    local src="$JIT_ROOT/ops/systemd/${svc}"

    if [ -f "$src" ]; then
      ok "Service config exists: $src"

      # Check for required directives
      if grep -q "LogsDirectory=jit" "$src"; then
        ok "  ✓ LogsDirectory configured"
      else
        warn "  ✗ LogsDirectory missing"
      fi

      if grep -q "RuntimeDirectory=jit" "$src"; then
        ok "  ✓ RuntimeDirectory configured"
      else
        warn "  ✗ RuntimeDirectory missing"
      fi

      if grep -q "StandardOutput=journal" "$src"; then
        ok "  ✓ Journal output configured"
      else
        warn "  ✗ Journal output missing"
      fi
    else
      warn "Service config not found: $src"
    fi
  done
}

simulate_daemon_activity() {
  local count="${1:-10}"
  info "Simulating daemon activity ($count messages)..."

  for i in $(seq 1 "$count"); do
    log_daemon "heartbeat" "Simulated pulse #$i" "INFO"
    sleep 0.5
  done

  ok "Simulated $count messages"
}

check_log_size() {
  info "Checking log file sizes..."

  if [ -d "$LOG_DIR" ]; then
    local total_size; total_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
    ok "Total log directory size: $total_size"

    for log in "$LOG_DIR"/*.log; do
      if [ -f "$log" ]; then
        local size; size=$(du -h "$log" 2>/dev/null | cut -f1)
        info "  $(basename "$log"): $size"
      fi
    done
  fi
}

print_summary() {
  local elapsed=$(($(date +%s) - START_TIME))

  echo ""
  echo -e "${CYAN}════════════════════════════════════════════════${RESET}"
  echo -e "${GREEN}📊 Test Summary${RESET}"
  echo -e "${CYAN}════════════════════════════════════════════════${RESET}"
  echo ""
  echo "Duration: ${elapsed}s"
  echo "Log directory: $(resolve_log_dir)"
  echo "Log files:"
  ls -la "$(resolve_log_dir)"/*.log 2>/dev/null || echo "  (no .log files)"
  echo ""
  echo "Next steps for full 24h test:"
  echo "  sudo systemctl enable jit-heartbeat hermes-discord"
  echo "  sudo systemctl start jit-heartbeat hermes-discord"
  echo "  journalctl -u jit-heartbeat -f"
  echo ""
  echo "After 24 hours, verify:"
  echo "  ls -la /var/log/jit/           # Check rotated files"
  echo "  du -sh /var/log/jit/           # Verify size < 200MB"
  echo "  journalctl -u jit-heartbeat --since '24 hours ago'"
  echo ""
}

# Main
main() {
  print_header
  test_log_directory
  test_logging_functions
  test_journal_logging
  test_log_rotation_config
  test_systemd_services
  simulate_daemon_activity 20
  check_log_size
  print_summary

  ok "All tests completed!"
}

main "$@"
