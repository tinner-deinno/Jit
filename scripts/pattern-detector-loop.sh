#!/usr/bin/env bash
# pattern-detector-loop.sh — Every 15m, look for good patterns in agent output
# If a pattern is found 3+ times in usage.jsonl, save as skill to Oracle
set -uo pipefail
JIT_ROOT="/workspaces/Jit"
LOG="/tmp/cmdteam/pattern-detector.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LEARNINGS_DIR="$JIT_ROOT/ψ/memory/learnings"
USAGE_FILE="/tmp/cmdteam/usage.jsonl"
SKILLS_DIR="$JIT_ROOT/ψ/memory/learnings/skills"

mkdir -p "$LEARNINGS_DIR" "$SKILLS_DIR"

echo "[$TS] pattern-detector start" >> "$LOG"

# 1. Count calls per model in last 1hr
if [[ -f "$USAGE_FILE" ]]; then
  last_hr_count=$(awk -F'\t' -v cutoff="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S)" '$1 > cutoff' "$USAGE_FILE" 2>/dev/null | wc -l)
  echo "[$TS] last_hour_calls=$last_hr_count" >> "$LOG"
fi

# 2. Find most-used model
if [[ -f "$USAGE_FILE" ]]; then
  top_model=$(awk -F'\t' '{print $2}' "$USAGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -3)
  echo "[$TS] top_models:" >> "$LOG"
  echo "$top_model" >> "$LOG"
fi

# 3. Detect pattern: same agent + same model used 3+ times
if [[ -f "$USAGE_FILE" ]]; then
  pattern_count=$(awk -F'\t' '{print $2"|"$3}' "$USAGE_FILE" 2>/dev/null | sort | uniq -c | awk '$1 >= 3 {print}' | head -5)
  if [[ -n "$pattern_count" ]]; then
    echo "[$TS] pattern_detected (>=3 uses):" >> "$LOG"
    echo "$pattern_count" >> "$LOG"
  fi
fi

# 4. Check for new learnings today
today=$(date -u +%Y-%m-%d)
new_learnings=$(find "$LEARNINGS_DIR" -name "*${today}*.md" 2>/dev/null | wc -l)
echo "[$TS] new_learnings_today=$new_learnings" >> "$LOG"

# 5. Auto-save: if a model is used 50+ times, suggest it as "trusted"
if [[ -f "$USAGE_FILE" ]]; then
  high_use=$(awk -F'\t' '{print $2}' "$USAGE_FILE" 2>/dev/null | sort | uniq -c | awk '$1 >= 50 {print $0}')
  if [[ -n "$high_use" ]]; then
    echo "[$TS] high_use_models (>=50 calls):" >> "$LOG"
    echo "$high_use" >> "$LOG"
  fi
fi

echo "[$TS] pattern-detector done" >> "$LOG"
