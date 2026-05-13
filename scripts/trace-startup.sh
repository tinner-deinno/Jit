#!/usr/bin/env bash
# scripts/trace-startup.sh — 🚀 Initialize trace system when Jit starts
#
# Purpose: Set up trace infrastructure before Jit agents begin work
# Called by: init-life.sh or bootstrap.sh (before startBot / awaken)
#
# Creates:
#   - ψ/memory/traces/ directory
#   - trace-registry.json for Jit to read
#   - Initial trace index

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
[ -f "$JIT_ROOT/.env" ] && set -a && source "$JIT_ROOT/.env" && set +a

TRACE_ROOT="$JIT_ROOT/ψ/memory/traces"
TODAY=$(date +%Y-%m-%d)
TRACE_DIR="$TRACE_ROOT/$TODAY"
REGISTRY_FILE="$TRACE_ROOT/trace-registry.json"

echo "🔍 Initializing trace system..."

# Create directories
mkdir -p "$TRACE_DIR"
echo "  ✓ Trace directory: $TRACE_DIR"

# Generate initial git snapshot
cd "$JIT_ROOT" || exit 1

TOTAL_COMMITS=$(git log --all --oneline --no-merges 2>/dev/null | wc -l)
LATEST_HASH=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
LATEST_MSG=$(git log -1 --pretty=format:%s 2>/dev/null || echo "unknown")

# Create registry file for Jit to read
cat > "$REGISTRY_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "trace_root": "$TRACE_ROOT",
  "today": "$TODAY",
  "trace_dir": "$TRACE_DIR",
  "git": {
    "total_commits": $TOTAL_COMMITS,
    "latest_hash": "$LATEST_HASH",
    "latest_message": "$LATEST_MSG",
    "repo": "$(basename "$JIT_ROOT")"
  },
  "traces": {
    "hourly": "$TRACE_DIR/trace-hourly.md",
    "daily": "$TRACE_DIR/trace-daily.md",
    "weekly": "$TRACE_DIR/trace-weekly.md",
    "pulses": "$TRACE_DIR/heartbeat-pulses.md",
    "summary": "$TRACE_DIR/summary.md"
  },
  "auto_update": true,
  "update_interval_seconds": 900,
  "next_update": "$(date -d '+15 minutes' -Iseconds)"
}
EOF

echo "  ✓ Registry: $REGISTRY_FILE"
echo "  ✓ Total commits: $TOTAL_COMMITS"
echo "  ✓ Latest: $LATEST_HASH ($LATEST_MSG)"

# Generate initial hourly trace
bash "$SCRIPT_DIR/trace-commits.sh" --hourly > /dev/null 2>&1
echo "  ✓ Initial trace generated"

# Create index for quick access
cat > "$TRACE_DIR/index.md" << EOF
# Trace Index — $TODAY

**Started**: $(date '+%Y-%m-%d %H:%M:%S')
**Repository**: $(basename "$JIT_ROOT")

## Files

- \`trace-hourly.md\` — hourly commits
- \`trace-daily.md\` — daily summary
- \`heartbeat-pulses.md\` — heartbeat log
- \`summary.md\` — full analysis
- \`commits.index.json\` — machine-readable index

## Quick Stats

- **Total commits**: $TOTAL_COMMITS
- **Latest**: \`$(echo $LATEST_HASH | cut -c1-7)\`
- **Auto-update**: Every 15 minutes

See \`trace-registry.json\` for full details.
EOF

echo "  ✓ Index created"
echo ""
echo "✅ Trace system ready"
echo "   Registry: $REGISTRY_FILE"
echo "   Next: heartbeat will auto-update every 15 min"
