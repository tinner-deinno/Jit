#!/usr/bin/env bash
# limbs/trace-query.sh — 📊 Query interface for git trace data
#
# Purpose: Allow agents (Jit, innova, etc) to query trace summaries
#
# Usage:
#   bash limbs/trace-query.sh today              # today's summary
#   bash limbs/trace-query.sh latest             # latest commits
#   bash limbs/trace-query.sh stats              # quick stats
#   bash limbs/trace-query.sh activity           # current activity level
#   bash limbs/trace-query.sh friction           # friction score

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
[ -f "$JIT_ROOT/.env" ] && set -a && source "$JIT_ROOT/.env" && set +a

TRACE_ROOT="$JIT_ROOT/ψ/memory/traces"
TODAY=$(date +%Y-%m-%d)
TRACE_DIR="$TRACE_ROOT/$TODAY"
REGISTRY="$TRACE_ROOT/trace-registry.json"

# ─────────────────────────────────────────────────────────────────
# Query: today's summary
# ─────────────────────────────────────────────────────────────────
query_today() {
  if [ ! -f "$TRACE_DIR/summary.md" ]; then
    echo "❌ No trace for today. Run: bash scripts/trace-commits.sh --daily"
    return 1
  fi
  
  cat "$TRACE_DIR/summary.md"
}

# ─────────────────────────────────────────────────────────────────
# Query: latest commits
# ─────────────────────────────────────────────────────────────────
query_latest() {
  local count="${1:-10}"
  
  cd "$JIT_ROOT" || return 1
  
  echo "## Latest $count Commits"
  echo ""
  echo "| Hash | Author | Subject | Date |"
  echo "|------|--------|---------|------|"
  
  git log --all --pretty=format:'%h|%an|%s|%ai' --no-merges -$count 2>/dev/null | while IFS='|' read -r hash author subject date; do
    # Extract just the date part
    dateonly=$(echo "$date" | cut -d' ' -f1)
    echo "| \`$hash\` | $author | $subject | $dateonly |"
  done
}

# ─────────────────────────────────────────────────────────────────
# Query: quick stats
# ─────────────────────────────────────────────────────────────────
query_stats() {
  cd "$JIT_ROOT" || return 1
  
  local total=$(git log --all --oneline --no-merges 2>/dev/null | wc -l)
  local today=$(git log --all --oneline --since="midnight" --no-merges 2>/dev/null | wc -l)
  local week=$(git log --all --oneline --since="1 week ago" --no-merges 2>/dev/null | wc -l)
  local month=$(git log --all --oneline --since="1 month ago" --no-merges 2>/dev/null | wc -l)
  
  echo "## Development Stats"
  echo ""
  echo "| Period | Commits |"
  echo "|--------|---------|"
  echo "| Total | $total |"
  echo "| Month | $month |"
  echo "| Week | $week |"
  echo "| Today | $today |"
  echo ""
  
  # Activity level
  local avg_week=$(echo "scale=1; $week / 7" | bc)
  local activity_level="📊 Moderate"
  
  if (( $(echo "$today >= 10" | bc -l) )); then
    activity_level="🔥 High"
  elif (( $(echo "$today >= 5" | bc -l) )); then
    activity_level="⚡ Active"
  elif (( $(echo "$today == 0" | bc -l) )); then
    activity_level="😴 Quiet"
  fi
  
  echo "**Activity Level**: $activity_level"
  echo "**Avg/Week**: $avg_week commits/day"
}

# ─────────────────────────────────────────────────────────────────
# Query: activity level
# ─────────────────────────────────────────────────────────────────
query_activity() {
  cd "$JIT_ROOT" || return 1
  
  local last_hour=$(git log --all --oneline --since="1 hour ago" --no-merges 2>/dev/null | wc -l)
  local last_day=$(git log --all --oneline --since="24 hours ago" --no-merges 2>/dev/null | wc -l)
  local last_30min=$(git log --all --oneline --since="30 minutes ago" --no-merges 2>/dev/null | wc -l)
  
  echo "## Activity Level"
  echo ""
  echo "| Window | Commits | Status |"
  echo "|--------|---------|--------|"
  
  local status_30min="✓ Yes"
  [ "$last_30min" -eq 0 ] && status_30min="— No"
  
  local status_hour="✓ Yes"
  [ "$last_hour" -eq 0 ] && status_hour="— No"
  
  echo "| Last 30min | $last_30min | $status_30min |"
  echo "| Last hour | $last_hour | $status_hour |"
  echo "| Last 24h | $last_day | ✓ Yes |"
  echo ""
  
  if [ "$last_hour" -gt 0 ]; then
    echo "**Status**: 🟢 Active — commits in last hour"
  elif [ "$last_day" -gt 0 ]; then
    echo "**Status**: 🟡 Busy — commits today"
  else
    echo "**Status**: 🔴 Idle — no recent commits"
  fi
}

# ─────────────────────────────────────────────────────────────────
# Query: friction score
# ─────────────────────────────────────────────────────────────────
query_friction() {
  if [ ! -f "$TRACE_DIR/summary.md" ]; then
    echo "❌ No friction data. Run: bash scripts/trace-commits.sh"
    return 1
  fi
  
  # Extract friction score from YAML front matter
  friction=$(grep "^friction_score:" "$TRACE_DIR/summary.md" | cut -d':' -f2 | xargs)
  
  echo "## Friction Analysis"
  echo ""
  echo "**Friction Score**: $friction"
  echo ""
  
  # Interpret score
  if (( $(echo "$friction >= 0.9" | bc -l) )); then
    echo "🟢 **Excellent** — Very easy to find, well-indexed"
  elif (( $(echo "$friction >= 0.7" | bc -l) )); then
    echo "🟢 **Good** — Visible, organized commits"
  elif (( $(echo "$friction >= 0.5" | bc -l) )); then
    echo "🟡 **Fair** — Could be better indexed"
  elif (( $(echo "$friction >= 0.3" | bc -l) )); then
    echo "🟠 **Low** — Hidden, hard to find"
  else
    echo "🔴 **Poor** — Very hard to discover"
  fi
  
  echo ""
  echo "**Action**: Consider running \`bash scripts/trace-commits.sh --daily\` to re-index"
}

# ─────────────────────────────────────────────────────────────────
# Query: registry (machine-readable)
# ─────────────────────────────────────────────────────────────────
query_registry() {
  if [ ! -f "$REGISTRY" ]; then
    echo "{\"error\": \"trace registry not found\"}"
    return 1
  fi
  
  cat "$REGISTRY"
}

# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────
case "${1:-today}" in
  today|summary)
    query_today
    ;;
  latest)
    query_latest "${2:-10}"
    ;;
  stats)
    query_stats
    ;;
  activity)
    query_activity
    ;;
  friction)
    query_friction
    ;;
  registry|json)
    query_registry
    ;;
  help|--help)
    cat << EOF
Usage: bash limbs/trace-query.sh [command]

Commands:
  today       — today's trace summary
  latest [n]  — latest n commits (default: 10)
  stats       — quick statistics
  activity    — activity level (last 24h)
  friction    — friction score analysis
  registry    — machine-readable registry (JSON)
  help        — this message

Examples:
  bash limbs/trace-query.sh stats
  bash limbs/trace-query.sh latest 20
  bash limbs/trace-query.sh activity

EOF
    ;;
  *)
    echo "❓ Unknown command: $1"
    echo "Run 'bash limbs/trace-query.sh help' for usage"
    exit 1
    ;;
esac
