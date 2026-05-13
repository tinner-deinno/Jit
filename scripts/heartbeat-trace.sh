#!/usr/bin/env bash
# scripts/heartbeat-trace.sh — 💓 Trace integration with heartbeat pulses
#
# Runs on each heartbeat IN/OUT pulse to update git trace summaries
# Called by: heartbeat.sh after each pulse commit
#
# Usage: bash scripts/heartbeat-trace.sh [--auto]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
[ -f "$JIT_ROOT/.env" ] && set -a && source "$JIT_ROOT/.env" && set +a

TRACE_ROOT="$JIT_ROOT/ψ/memory/traces"
TODAY=$(date +%Y-%m-%d)
TRACE_DIR="$TRACE_ROOT/$TODAY"

# Ensure trace directory
mkdir -p "$TRACE_DIR"

# ─────────────────────────────────────────────────────────────────
# Get latest git activity
# ─────────────────────────────────────────────────────────────────
get_latest_activity() {
  cd "$JIT_ROOT" || return 1
  
  # Last 3 commits with details
  git log --all --oneline -3 --no-merges 2>/dev/null | while read -r line; do
    hash=$(echo "$line" | awk '{print $1}')
    msg=$(echo "$line" | cut -d' ' -f2-)
    timestamp=$(git log -1 --format=%ai "$hash" 2>/dev/null)
    
    echo "- \`$hash\` — $msg @ $timestamp"
  done
}

# ─────────────────────────────────────────────────────────────────
# Quick stats
# ─────────────────────────────────────────────────────────────────
quick_stats() {
  cd "$JIT_ROOT" || return 1
  
  local total=$(git log --all --oneline --no-merges 2>/dev/null | wc -l)
  local today=$(git log --all --oneline --since="midnight" --no-merges 2>/dev/null | wc -l)
  local week=$(git log --all --oneline --since="1 week ago" --no-merges 2>/dev/null | wc -l)
  
  echo "- Total: $total commits | Today: $today | Week: $week"
}

# ─────────────────────────────────────────────────────────────────
# Generate heartbeat-specific trace update
# ─────────────────────────────────────────────────────────────────
update_heartbeat_trace() {
  local pulse_number="$1"
  local heartbeat_file="$TRACE_DIR/heartbeat-pulses.md"
  
  # Initialize if not exists
  if [ ! -f "$heartbeat_file" ]; then
    cat > "$heartbeat_file" << 'EOF'
# Heartbeat Trace Log

| Pulse | Time | Type | Activity | Commits |
|-------|------|------|----------|---------|
EOF
  fi
  
  # Append new pulse entry
  local pulse_type=$([ $((pulse_number % 2)) -eq 0 ] && echo "OUT (systole)" || echo "IN (diastole)")
  local now=$(date '+%H:%M:%S')
  local activity="Trace auto-update"
  local commits_since_last=$(cd "$JIT_ROOT" && git log --all --oneline --since="10 minutes ago" --no-merges 2>/dev/null | wc -l)
  
  # Only add if there's activity
  if [ "$commits_since_last" -gt 0 ] || [ $((pulse_number % 6)) -eq 0 ]; then
    echo "| #$pulse_number | $now | $pulse_type | $activity | $commits_since_last |" >> "$heartbeat_file"
  fi
}

# ─────────────────────────────────────────────────────────────────
# Append summary to daily trace
# ─────────────────────────────────────────────────────────────────
append_to_daily_summary() {
  local summary_file="$TRACE_DIR/daily-summary.md"
  
  if [ ! -f "$summary_file" ]; then
    cat > "$summary_file" << EOF
# Daily Trace Summary — $TODAY

**Generated**: $(date '+%Y-%m-%d %H:%M:%S')
**Repository**: Jit

---

## Timeline
EOF
  fi
  
  # Append current snapshot
  {
    echo ""
    echo "### $(date '+%H:%M')"
    echo ""
    echo "**Activity**:"
    get_latest_activity
    echo ""
    echo "**Stats**:"
    quick_stats
    echo ""
  } >> "$summary_file"
}

# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────
if [ "$1" = "--auto" ]; then
  # Called from heartbeat
  pulse_num="${2:-1}"
  
  # Update trace files
  update_heartbeat_trace "$pulse_num"
  append_to_daily_summary
  
  echo "✅ Heartbeat trace updated (pulse #$pulse_num)"
else
  # Manual run
  echo "📊 Current Git Activity:"
  echo ""
  echo "Latest commits:"
  get_latest_activity
  echo ""
  echo "Statistics:"
  quick_stats
fi
