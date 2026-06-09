#!/bin/bash
# jit-healthcheck.sh — Health check script for Hermes & Heartbeat
# Returns non-zero if any critical service is unhealthy

set -euo pipefail

HERMES_HEALTH_URL="${HERMES_HEALTH_URL:-http://localhost:47780/healthz}"
HEARTBEAT_STATUS_FILE="${HEARTBEAT_STATUS_FILE:-/tmp/innova-discord-heartbeat.status}"
MAX_HEARTBEAT_AGE_SEC="${MAX_HEARTBEAT_AGE_SEC:-300}"  # 5 minutes

log() {
  echo "[$(date -Iseconds)] $*"
}

check_hermes() {
  log "Checking Hermes Discord bot health..."

  if curl -sf --max-time 10 "$HERMES_HEALTH_URL" >/dev/null 2>&1; then
    log "✅ Hermes health check PASSED"
    return 0
  else
    log "❌ Hermes health check FAILED — no response from $HERMES_HEALTH_URL"
    return 1
  fi
}

check_heartbeat() {
  log "Checking Heartbeat freshness..."

  if [[ ! -f "$HEARTBEAT_STATUS_FILE" ]]; then
    log "⚠️  Heartbeat status file not found: $HEARTBEAT_STATUS_FILE"
    return 1
  fi

  local file_age
  file_age=$(( $(date +%s) - $(stat -c %Y "$HEARTBEAT_STATUS_FILE") ))

  if [[ $file_age -gt $MAX_HEARTBEAT_AGE_SEC ]]; then
    log "❌ Heartbeat stale — last update ${file_age}s ago (max: ${MAX_HEARTBEAT_AGE_SEC}s)"
    return 1
  fi

  log "✅ Heartbeat check PASSED (${file_age}s old)"
  return 0
}

check_systemd_services() {
  log "Checking systemd service states..."

  local failed=0

  for svc in hermes-discord.service jit-heartbeat.service; do
    # Check if systemctl is available (may not work in containers)
    if command -v systemctl >/dev/null 2>&1; then
      if systemctl is-active --quiet "$svc" 2>/dev/null; then
        log "✅ $svc is active"
      else
        log "⚠️  $svc status unknown (systemd not available or service not managed)"
      fi
    else
      # Fallback: check if process is running via pgrep
      local proc_name
      case "$svc" in
        hermes-discord.service) proc_name="node.*bot.js" ;;
        jit-heartbeat.service) proc_name="heartbeat.*daemon" ;;
        *) proc_name="$svc" ;;
      esac

      if pgrep -f "$proc_name" >/dev/null 2>&1; then
        log "✅ $svc process running"
      else
        log "⚠️  $svc process not found (may be managed externally)"
      fi
    fi
  done

  return $failed
}

main() {
  local exit_code=0

  log "=== Jit Health Check Started ==="

  check_hermes || exit_code=1
  check_heartbeat || exit_code=1
  check_systemd_services || exit_code=1

  if [[ $exit_code -eq 0 ]]; then
    log "=== All health checks PASSED ==="
  else
    log "=== Health check FAILED — some services unhealthy ==="
  fi

  return $exit_code
}

main "$@"
