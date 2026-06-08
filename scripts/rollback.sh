#!/usr/bin/env bash
# scripts/rollback.sh — Rollback to last known good state
# Usage: bash scripts/rollback.sh [--force] [--dry-run]
#
# JIT-008: Full recovery flow for failed deployments
#
# Flow:
#   1. Stop both units (jit-heartbeat, hermes-discord)
#   2. git checkout $(cat /var/lib/jit/last-known-good.txt)
#   3. Re-run bun install
#   4. Restart units
#   5. Emit Discord webhook on success/failure

set -e

# ==============================
# Configuration
# ==============================
ORACLE_DIR="/workspaces/arra-oracle-v3"
STATE_DIR="/var/lib/jit"
JIT_DIR="/workspaces/Jit"
LAST_KNOWN_GOOD_FILE="$STATE_DIR/last-known-good.txt"
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Flags
FORCE=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: bash scripts/rollback.sh [--force] [--dry-run]"
      exit 1
      ;;
  esac
done

# ==============================
# Helper Functions
# ==============================
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

send_discord_webhook() {
  local status="$1"
  local message="$2"
  local color

  if [ "$status" = "success" ]; then
    color=65280  # Green
  else
    color=16711680  # Red
  fi

  if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    curl -s -X POST "$DISCORD_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{
        \"embeds\": [{
          \"title\": \"🔄 Rollback ${status^}\",
          \"description\": \"$message\",
          \"color\": $color,
          \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
          \"footer\": {\"text\": \"Jit Oracle Rollback System\"}
        }]
      }" > /dev/null || log_warn "Failed to send Discord webhook"
  else
    log_warn "DISCORD_WEBHOOK_URL not set — skipping notification"
  fi
}

# ==============================
# Pre-flight Checks
# ==============================
echo "🔄 Starting rollback procedure..."
echo ""

if [ "$DRY_RUN" = true ]; then
  log_info "DRY RUN MODE — No changes will be made"
  echo ""
fi

# Check if last-known-good snapshot exists
if [ ! -f "$LAST_KNOWN_GOOD_FILE" ]; then
  log_error "No rollback snapshot found at $LAST_KNOWN_GOOD_FILE"
  log_error "Cannot rollback without a known good state"
  send_discord_webhook "failure" "Rollback failed: No snapshot found at $LAST_KNOWN_GOOD_FILE"
  exit 1
fi

LAST_KNOWN_COMMIT=$(cat "$LAST_KNOWN_GOOD_FILE")
if [ -z "$LAST_KNOWN_COMMIT" ] || [ "$LAST_KNOWN_COMMIT" = "unknown" ]; then
  log_error "Invalid snapshot content: '$LAST_KNOWN_COMMIT'"
  send_discord_webhook "failure" "Rollback failed: Invalid snapshot content"
  exit 1
fi

log_info "Found snapshot: $LAST_KNOWN_COMMIT"

# Check if Oracle directory exists
if [ ! -d "$ORACLE_DIR" ]; then
  log_error "Oracle directory not found: $ORACLE_DIR"
  send_discord_webhook "failure" "Rollback failed: Oracle directory not found"
  exit 1
fi

# ==============================
# Step 1: Stop Services
# ==============================
echo "[ Step 1/5 ] Stopping services..."
if [ "$DRY_RUN" = true ]; then
  log_info "Would stop: jit-heartbeat.service"
  log_info "Would stop: hermes-discord.service"
else
  if systemctl is-active --quiet jit-heartbeat 2>/dev/null; then
    sudo systemctl stop jit-heartbeat
    log_info "Stopped jit-heartbeat"
  else
    log_warn "jit-heartbeat not running"
  fi

  if systemctl is-active --quiet hermes-discord 2>/dev/null; then
    sudo systemctl stop hermes-discord
    log_info "Stopped hermes-discord"
  else
    log_warn "hermes-discord not running"
  fi
fi

# ==============================
# Step 2: Checkout Last Known Good
# ==============================
echo ""
echo "[ Step 2/5 ] Checking out last known good commit..."
log_info "Target commit: $LAST_KNOWN_COMMIT"

if [ "$DRY_RUN" = true ]; then
  log_info "Would run: git -C $ORACLE_DIR checkout $LAST_KNOWN_COMMIT"
else
  cd "$ORACLE_DIR"

  # Verify commit exists
  if ! git rev-parse "$LAST_KNOWN_COMMIT" >/dev/null 2>&1; then
    log_error "Commit $LAST_KNOWN_COMMIT not found in repository"
    log_warn "Snapshot may be from a different repository state"
    if [ "$FORCE" != true ]; then
      log_error "Use --force to skip this check"
      send_discord_webhook "failure" "Rollback failed: Commit $LAST_KNOWN_COMMIT not found"
      exit 1
    fi
  fi

  git checkout "$LAST_KNOWN_COMMIT" --quiet
  log_info "Checked out: $(git rev-parse --short HEAD)"
fi

# ==============================
# Step 3: Reinstall Dependencies
# ==============================
echo ""
echo "[ Step 3/5 ] Reinstalling dependencies..."
if [ "$DRY_RUN" = true ]; then
  log_info "Would run: bun install (in $ORACLE_DIR)"
else
  cd "$ORACLE_DIR"
  bun install 2>&1 | tail -3
  log_info "Dependencies reinstalled"
fi

# ==============================
# Step 4: Restart Services
# ==============================
echo ""
echo "[ Step 4/5 ] Restarting services..."
if [ "$DRY_RUN" = true ]; then
  log_info "Would start: jit-heartbeat.service"
  log_info "Would start: hermes-discord.service"
else
  sudo systemctl start jit-heartbeat
  log_info "Started jit-heartbeat"

  sudo systemctl start hermes-discord
  log_info "Started hermes-discord"
fi

# ==============================
# Step 5: Health Check
# ==============================
echo ""
echo "[ Step 5/5 ] Running health check..."
if [ "$DRY_RUN" = true ]; then
  log_info "Would verify Oracle health at http://localhost:47778/api/health"
  log_info "Would run soul-check.sh"
else
  sleep 3

  # Check Oracle
  if curl -sf http://localhost:47778/api/health > /dev/null 2>&1; then
    log_info "Oracle is healthy"
  else
    log_warn "Oracle health check failed — may still be starting"
  fi

  # Run soul check
  cd "$JIT_DIR"
  if bash eval/soul-check.sh > /dev/null 2>&1; then
    log_info "Soul integrity check passed"
  else
    log_warn "Soul check reported issues — review manually"
  fi
fi

# ==============================
# Complete
# ==============================
echo ""
if [ "$DRY_RUN" = true ]; then
  log_info "DRY RUN COMPLETE — No changes were made"
  echo ""
  echo "To perform actual rollback:"
  echo "  bash scripts/rollback.sh"
else
  log_info "✅ Rollback complete!"
  echo ""
  echo "Restored to commit: $LAST_KNOWN_COMMIT"
  echo ""
  echo "Verify with:"
  echo "  git -C $ORACLE_DIR log -1 --oneline"
  echo "  systemctl status jit-heartbeat hermes-discord"
  echo "  curl http://localhost:47778/api/health"

  send_discord_webhook "success" "Rollback complete — restored to commit $LAST_KNOWN_COMMIT"
fi
