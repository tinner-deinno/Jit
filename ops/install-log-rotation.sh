#!/usr/bin/env bash
# ops/install-log-rotation.sh — ติดตั้ง log rotation สำหรับ Jit daemons (JIT-007)
#
# Usage:
#   sudo bash ops/install-log-rotation.sh
#
# What it does:
#   1. Creates /var/log/jit/ directory with proper permissions
#   2. Installs logrotate config to /etc/logrotate.d/jit-daemons
#   3. Installs systemd service units
#   4. Validates configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info() { echo -e "${CYAN}ℹ️  ${RESET} $*"; }
ok()   { echo -e "${GREEN}✅${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠️ ${RESET} $*"; }
err()  { echo -e "${RED}❌${RESET} $*" >&2; }

# Check if running as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    err "ต้องรันด้วย sudo (script นี้ต้องการ root privileges)"
    exit 1
  fi
}

# Create log directory
create_log_dir() {
  info "Creating /var/log/jit/ directory..."
  mkdir -p /var/log/jit
  chmod 0755 /var/log/jit
  chown codespace:codespace /var/log/jit 2>/dev/null || chown "$(whoami):$(whoami)" /var/log/jit || true
  ok "Log directory created: /var/log/jit"
}

# Install logrotate config
install_logrotate() {
  info "Installing logrotate configuration..."
  local src="$JIT_ROOT/ops/logrotate/jit-daemons"
  local dst="/etc/logrotate.d/jit-daemons"

  if [ -f "$src" ]; then
    cp "$src" "$dst"
    chmod 0644 "$dst"
    ok "Logrotate config installed: $dst"
  else
    warn "Source file not found: $src"
    return 1
  fi
}

# Install systemd services
install_systemd_services() {
  info "Installing systemd service units..."

  local services=("jit-heartbeat.service" "hermes-discord.service")
  for svc in "${services[@]}"; do
    local src="$JIT_ROOT/ops/systemd/${svc}"
    local dst="/etc/systemd/system/${svc}"

    if [ -f "$src" ]; then
      cp "$src" "$dst"
      chmod 0644 "$dst"
      ok "Service installed: $dst"
    else
      warn "Service file not found: $src"
    fi
  done
}

# Reload systemd daemon
reload_systemd() {
  info "Reloading systemd daemon..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    ok "Systemd daemon reloaded"
  else
    warn "systemctl not available, skipping daemon-reload"
  fi
}

# Validate logrotate config
validate_logrotate() {
  info "Validating logrotate configuration..."
  if command -v logrotate >/dev/null 2>&1; then
    if logrotate --debug /etc/logrotate.d/jit-daemons 2>&1 | head -20; then
      ok "Logrotate configuration is valid"
    else
      warn "Logrotate configuration may have issues (check output above)"
    fi
  else
    warn "logrotate not installed, skipping validation"
  fi
}

# Test logging functions
test_logging() {
  info "Testing logging functions..."
  local test_log="/var/log/jit/test-$(date +%s).log"

  # Test file logging
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TEST] Log rotation test" >> "$test_log"

  # Test journal logging (if available)
  if command -v systemd-cat >/dev/null 2>&1; then
    echo "[TEST] Journal logging test" | systemd-cat -t jit-test -p info 2>/dev/null || true
    ok "Journal logging test sent"
  else
    warn "systemd-cat not available, journal logging skipped"
  fi

  ok "Test log created: $test_log"
}

# Print summary
print_summary() {
  echo ""
  echo -e "${CYAN}════════════════════════════════════════════════${RESET}"
  echo -e "${GREEN}✅ JIT-007 Log Rotation Installation Complete${RESET}"
  echo -e "${CYAN}════════════════════════════════════════════════${RESET}"
  echo ""
  echo "Installed files:"
  echo "  - /var/log/jit/              (log directory)"
  echo "  - /etc/logrotate.d/jit-daemons (logrotate config)"
  echo "  - /etc/systemd/system/jit-heartbeat.service"
  echo "  - /etc/systemd/system/hermes-discord.service"
  echo ""
  echo "Next steps:"
  echo "  1. Enable services: sudo systemctl enable jit-heartbeat hermes-discord"
  echo "  2. Start services:  sudo systemctl start jit-heartbeat hermes-discord"
  echo "  3. Check status:    systemctl status jit-heartbeat"
  echo "  4. View logs:       journalctl -u jit-heartbeat -f"
  echo "  5. Test rotation:   sudo logrotate -f /etc/logrotate.d/jit-daemons"
  echo ""
}

# Main
main() {
  echo -e "${GREEN}🔄 JIT-007 Log Rotation Installer${RESET}"
  echo ""

  check_root
  create_log_dir
  install_logrotate
  install_systemd_services
  reload_systemd
  validate_logrotate
  test_logging
  print_summary
}

main "$@"
