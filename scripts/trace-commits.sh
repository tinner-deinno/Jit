#!/usr/bin/env bash
# scripts/trace-commits.sh — 🔍 Git Commit Trace System (integrated with heartbeat)
#
# Purpose:
#   - Trace all git commits across time periods
#   - Organize by date and time window
#   - Generate structured summaries (tables, lists, flows)
#   - Auto-update on heartbeat pulses
#   - Create friction analysis and development insights
#
# Usage:
#   bash scripts/trace-commits.sh [--interval=15m] [--auto]
#   bash scripts/trace-commits.sh --daily          # daily summary
#   bash scripts/trace-commits.sh --hourly         # hourly summary
#   bash scripts/trace-commits.sh --stat           # quick stats

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration
[ -f "$JIT_ROOT/.env" ] && set -a && source "$JIT_ROOT/.env" && set +a

# Configuration
TRACE_MODE="${1:-hourly}"
TRACE_ROOT="$JIT_ROOT/ψ/memory/traces"
TODAY=$(date +%Y-%m-%d)
NOW=$(date +%s)
TRACE_DIR="$TRACE_ROOT/$TODAY"
COMMIT_INDEX="$TRACE_DIR/commits.index.json"
SUMMARY_FILE="$TRACE_DIR/summary.md"
STATS_FILE="$TRACE_DIR/stats.json"

# Ensure trace directory exists
mkdir -p "$TRACE_DIR"

# ─────────────────────────────────────────────────────────────────
# Helper: Extract all commits from git history
# ─────────────────────────────────────────────────────────────────
extract_commits() {
  cd "$JIT_ROOT" || return 1
  
  git log --all --pretty=format:'%H|%ai|%an|%ae|%s|%b' --no-merges 2>/dev/null | while IFS='|' read -r hash timestamp author email subject body; do
    # Parse timestamp (YYYY-MM-DD HH:MM:SS +ZZZZ)
    commit_date=$(echo "$timestamp" | cut -d' ' -f1)
    commit_time=$(echo "$timestamp" | cut -d' ' -f2)
    commit_tz=$(echo "$timestamp" | cut -d' ' -f3-)
    
    echo "$(date -d "$timestamp" +%s)|$commit_date|$commit_time|$hash|$author|$subject"
  done | sort -t'|' -k1 -rn
}

# ─────────────────────────────────────────────────────────────────
# Organize commits by time period
# ─────────────────────────────────────────────────────────────────
organize_commits() {
  local mode="$1"
  declare -A buckets
  
  extract_commits | while IFS='|' read -r timestamp date time hash author subject; do
    case "$mode" in
      hourly)
        bucket="${date} $(echo $time | cut -d':' -f1):00"
        ;;
      daily)
        bucket="$date"
        ;;
      weekly)
        bucket=$(date -d "$date" +%Y-W%V)
        ;;
      *)
        bucket="$date"
        ;;
    esac
    
    echo "$bucket|$hash|$author|$subject"
  done
}

# ─────────────────────────────────────────────────────────────────
# Generate markdown table
# ─────────────────────────────────────────────────────────────────
generate_table() {
  local mode="$1"
  
  echo "| Time | Author | Subject | Hash |"
  echo "|------|--------|---------|------|"
  
  organize_commits "$mode" | awk -F'|' '{
    print "| " $1 " | " $3 " | " substr($4, 1, 50) " | `" substr($2, 1, 7) "` |"
  }' | head -50
}

# ─────────────────────────────────────────────────────────────────
# Generate JSON index
# ─────────────────────────────────────────────────────────────────
generate_json_index() {
  local mode="$1"
  
  echo "{"
  echo '  "timestamp": "'$(date -Iseconds)'",'
  echo '  "mode": "'$mode'",'
  echo '  "commits": ['
  
  organize_commits "$mode" | awk -F'|' 'NR>1 {print ","} NR>=1 {
    printf "    {\"time\": \"%s\", \"hash\": \"%s\", \"author\": \"%s\", \"subject\": \"%s\"}", $1, $2, $3, $4
  }'
  
  echo ""
  echo "  ]"
  echo "}"
}

# ─────────────────────────────────────────────────────────────────
# Analyze commit patterns
# ─────────────────────────────────────────────────────────────────
analyze_patterns() {
  local mode="$1"
  
  echo "## Commit Analysis"
  echo ""
  
  # Total commits
  local total=$(cd "$JIT_ROOT" && git log --all --oneline --no-merges 2>/dev/null | wc -l)
  echo "- **Total commits**: $total"
  
  # Today's commits
  local today_commits=$(cd "$JIT_ROOT" && git log --all --oneline --since="midnight" --no-merges 2>/dev/null | wc -l)
  echo "- **Today**: $today_commits commits"
  
  # Top authors
  echo "- **Top authors**:"
  cd "$JIT_ROOT" && git log --all --pretty=format:'%an' --no-merges 2>/dev/null | sort | uniq -c | sort -rn | head -5 | awk '{print "  - " $2 ": " $1 " commits"}'
  
  echo ""
  echo "## Development Activity"
  echo ""
  
  # Commits by type (infer from subject prefix)
  echo "| Type | Count |"
  echo "|------|-------|"
  cd "$JIT_ROOT" && git log --all --pretty=format:'%s' --no-merges 2>/dev/null | awk -F':' '{
    type = ($1 ~ /^feat|^fix|^docs|^style|^refactor|^perf|^test|^chore/) ? substr($1, 1, 4) : "other"
    count[type]++
  } END {
    for (t in count) print "| " t " | " count[t] " |"
  }' | sort
}

# ─────────────────────────────────────────────────────────────────
# Generate friction score
# ─────────────────────────────────────────────────────────────────
calculate_friction() {
  # Friction factors:
  # - How scattered are commits (1.0 = daily, 0.0 = sporadic)
  # - How complete are messages (1.0 = detailed, 0.0 = vague)
  # - How organized are they (1.0 = structured, 0.0 = messy)
  
  local commits=$(cd "$JIT_ROOT" && git log --all --oneline --no-merges 2>/dev/null | wc -l)
  local days_span=$(cd "$JIT_ROOT" && git log --all --pretty=format:'%ai' --no-merges 2>/dev/null | awk '{print $1}' | sort -u | wc -l)
  
  # Frequency score (commits per day, normalized)
  local freq=$(echo "scale=2; $commits / ($days_span + 1)" | bc)
  local freq_score=$(echo "scale=2; if ($freq > 5) 1.0 else if ($freq > 2) 0.7 else if ($freq > 1) 0.5 else 0.3" | bc)
  
  # Message quality (check for conventional commits)
  local quality_commits=$(cd "$JIT_ROOT" && git log --all --pretty=format:'%s' --no-merges 2>/dev/null | grep -E '^(feat|fix|docs|style|refactor|perf|test|chore):' | wc -l)
  local quality_score=$(echo "scale=2; $quality_commits / ($commits + 1)" | bc)
  
  # Overall friction (higher = better visibility)
  local friction=$(echo "scale=2; ($freq_score + $quality_score) / 2" | bc)
  
  # Clamp to [0.0, 1.0]
  if (( $(echo "$friction > 1" | bc -l) )); then
    friction="1.0"
  fi
  
  echo "scale=2; $friction" | bc
}

# ─────────────────────────────────────────────────────────────────
# Generate comprehensive summary
# ─────────────────────────────────────────────────────────────────
generate_summary() {
  local mode="${1:-hourly}"
  
  {
    echo "---"
    echo "timestamp: $(date -Iseconds)"
    echo "mode: $mode"
    echo "friction_score: $(calculate_friction)"
    echo "---"
    echo ""
    echo "# Git Trace Summary — $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "**Repository**: $(basename "$JIT_ROOT")"
    echo "**Mode**: $mode"
    echo ""
    
    echo "## Commit History"
    echo ""
    generate_table "$mode"
    echo ""
    
    analyze_patterns "$mode"
    
    echo ""
    echo "## Next Steps"
    echo ""
    echo "- Run \`git log --oneline -20\` for latest commits"
    echo "- Use \`/trace --deep\` for cross-repo analysis"
    echo "- Check \`ψ/memory/traces/\` for historical traces"
    
  } > "$SUMMARY_FILE"
  
  echo "✅ Trace generated: $SUMMARY_FILE"
}

# ─────────────────────────────────────────────────────────────────
# Main entry point
# ─────────────────────────────────────────────────────────────────
case "$TRACE_MODE" in
  --daily)
    generate_summary "daily"
    ;;
  --hourly)
    generate_summary "hourly"
    ;;
  --stat|--stats)
    analyze_patterns "hourly"
    ;;
  --auto)
    # Called from heartbeat — generate both summaries
    generate_summary "hourly"
    generate_summary "daily"
    ;;
  *)
    generate_summary "hourly"
    ;;
esac

# ─────────────────────────────────────────────────────────────────
# Display result
# ─────────────────────────────────────────────────────────────────
if [ -f "$SUMMARY_FILE" ]; then
  cat "$SUMMARY_FILE"
fi
