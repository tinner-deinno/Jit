#!/usr/bin/env bash
# housekeeping-loop.sh — Smart folder organizer
# Every 1hr: scan for misplaced files, organize into proper directories
set -uo pipefail
JIT_ROOT="/workspaces/Jit"
LOG="/tmp/cmdteam/housekeeping.log"
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "[$TS] housekeeping start" >> "$LOG"

moved=0
rejected=0

# 1. Move orphaned .md files from Jit root → ψ/inbox/drafts/ (if not CLAUDE.md/README.md)
for f in "$JIT_ROOT"/*.md; do
  [[ -f "$f" ]] || continue
  bn=$(basename "$f")
  case "$bn" in
    CLAUDE.md|README.md) continue ;;
  esac
  mkdir -p "$JIT_ROOT/ψ/inbox/drafts"
  if mv "$f" "$JIT_ROOT/ψ/inbox/drafts/$bn" 2>/dev/null; then
    echo "[$TS] organized $bn → ψ/inbox/drafts/" >> "$LOG"
    moved=$((moved+1))
  else
    rejected=$((rejected+1))
  fi
done

# 2. Move orphan .log/.jsonl files in ψ/ root → /tmp/cmdteam/
for f in "$JIT_ROOT/ψ"/*.log "$JIT_ROOT/ψ"/*.jsonl; do
  [[ -f "$f" ]] || continue
  bn=$(basename "$f")
  mv "$f" "/tmp/cmdteam/$bn" 2>/dev/null && {
    echo "[$TS] moved ψ/$bn → /tmp/cmdteam/" >> "$LOG"
    moved=$((moved+1))
  }
done

# 3. Compress old ψ/ files (>90d) — leave pointer
for f in $(find "$JIT_ROOT/ψ" -name '*.md' -mtime +90 2>/dev/null | head -10); do
  rel=${f#$JIT_ROOT/}
  echo "[$TS] old_file: $rel" >> "$LOG"
done

# 4. Disk usage report
du -sh "$JIT_ROOT" 2>/dev/null | head -1 >> "$LOG"
df -h / | head -2 | tail -1 >> "$LOG"

echo "[$TS] housekeeping done (moved=$moved rejected=$rejected)" >> "$LOG"

# 5. Run auto-cleanup-stale-tickets skill (Opus-developed)
bash /workspaces/Jit/ψ/memory/skills/auto-cleanup-stale-tickets.sh >> /tmp/cmdteam/auto-cleanup.log 2>&1
