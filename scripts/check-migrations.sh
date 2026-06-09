#!/usr/bin/env bash
# scripts/check-migrations.sh — Pre-deploy safety check for destructive migrations
# Usage: bash scripts/check-migrations.sh
#
# JIT-008: Refuses to run db:push if migration is destructive
#
# Returns:
#   0 — Migrations are safe to apply
#   1 — Destructive migration detected (abort!)

set -e

ORACLE_DIR="/workspaces/arra-oracle-v3"
STATE_DIR="/var/lib/jit"
MIGRATION_LOG="$STATE_DIR/migration-check.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Destructive patterns to detect
DESTRUCTIVE_PATTERNS=(
  "DROP TABLE"
  "DROP COLUMN"
  "ALTER COLUMN.*TYPE"
  "ALTER COLUMN.*SET NOT NULL"
  "DELETE FROM"
  "TRUNCATE"
)

echo "🔍 Checking migrations for destructive operations..."
echo ""

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Check if Oracle directory exists
if [ ! -d "$ORACLE_DIR" ]; then
  log_error "Oracle directory not found: $ORACLE_DIR"
  exit 1
fi

cd "$ORACLE_DIR"

# Check if this is a git repo with pending changes
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  log_warn "Not a git repository — skipping migration diff check"
  exit 0
fi

# Get the migration diff (compare current HEAD with last deployed tag or main)
LAST_DEPLOYED=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -n "$LAST_DEPLOYED" ]; then
  log_info "Comparing against last deployed tag: $LAST_DEPLOYED"
  MIGRATION_DIFF=$(git diff "$LAST_DEPLOYED" -- "*.sql" "prisma/*.prisma" "drizzle/*.ts" "migrations/" 2>/dev/null || true)
else
  log_info "No tags found — comparing against origin/main"
  MIGRATION_DIFF=$(git diff origin/main -- "*.sql" "prisma/*.prisma" "drizzle/*.ts" "migrations/" 2>/dev/null || true)
fi

if [ -z "$MIGRATION_DIFF" ]; then
  log_info "No migration changes detected — safe to proceed"
  exit 0
fi

# Save diff for logging
echo "$MIGRATION_DIFF" > "$MIGRATION_LOG"

# Check for destructive patterns
DESTRUCTIVE_FOUND=false
for pattern in "${DESTRUCTIVE_PATTERNS[@]}"; do
  if echo "$MIGRATION_DIFF" | grep -qiE "$pattern"; then
    log_error "Destructive pattern detected: $pattern"
    echo "$MIGRATION_DIFF" | grep -iE "$pattern" | head -5
    DESTRUCTIVE_FOUND=true
  fi
done

if [ "$DESTRUCTIVE_FOUND" = true ]; then
  echo ""
  log_error "Destructive migration detected — aborting deploy!"
  echo ""
  echo "Review the full diff:"
  echo "  cat $MIGRATION_LOG"
  echo ""
  echo "Options:"
  echo "  1. Fix the migration to be non-destructive"
  echo "  2. Manually review and approve with:"
  echo "     bash scripts/check-migrations.sh --force"
  echo ""
  exit 1
fi

log_info "✅ Migrations safe to apply"
exit 0
