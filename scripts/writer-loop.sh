#!/usr/bin/env bash
# writer-loop.sh — Doc improvement agent
# Every 1hr: scan recent ψ/ files, look for gaps, propose doc updates
set -uo pipefail
JIT_ROOT="/workspaces/Jit"
LOG="/tmp/cmdteam/writer-actions.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[$TS] writer start" >> "$LOG"

# 1. Count files needing review
todo_count=$(find "$JIT_ROOT/ψ" -name '*.md' -mmin -60 2>/dev/null | wc -l)
new_learnings=$(find "$JIT_ROOT/ψ/memory/learnings" -name '*.md' -mtime -1 2>/dev/null | wc -l)
echo "[$TS] stats: recent_md=$todo_count new_learnings=$new_learnings" >> "$LOG"

# 2. Find docs that haven't been updated in >30d
stale=$(find "$JIT_ROOT/ψ" -name '*.md' -mtime +30 2>/dev/null | head -5)
stale_count=$(echo "$stale" | grep -c . 2>/dev/null || echo 0)
echo "[$TS] stale_docs=$stale_count" >> "$LOG"
[[ -n "$stale" ]] && echo "$stale" >> "$LOG"

# 3. Check that key docs exist
for required in CLAUDE.md README.md; do
  for path in "$JIT_ROOT/$required" "$JIT_ROOT/ψ/$required"; do
    if [[ -f "$path" ]]; then
      size=$(wc -l < "$path" 2>/dev/null)
      echo "[$TS] doc_ok: $path ($size lines)" >> "$LOG"
    fi
  done
done

echo "[$TS] writer done" >> "$LOG"
