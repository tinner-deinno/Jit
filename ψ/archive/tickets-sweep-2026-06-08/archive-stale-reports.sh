#!/usr/bin/env bash
# archive-stale-reports.sh — Move 13 stale reports to ψ/archive
# Phase 3 of "Ticket Sweep Storm" — mechanical archive (no LLM needed for this group)
# Rule: Nothing is Deleted — git mv preserves history

set -uo pipefail

JIT_ROOT="/workspaces/Jit"
REPORTS="$JIT_ROOT/reports"
ARCHIVE="$JIT_ROOT/ψ/archive/tickets-sweep-2026-06-08/reports"
mkdir -p "$ARCHIVE"

# Files to KEEP (operational + latest evidence)
KEEP=(
  "code-review-004-quick.json"
  "integration-test-5-codex.json"
)

# Files to ARCHIVE (everything else)
ARCHIVED=0
SKIPPED=0
for f in "$REPORTS"/*.json; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  keep=false
  for k in "${KEEP[@]}"; do
    if [ "$fname" = "$k" ]; then keep=true; break; fi
  done
  if $keep; then
    echo "KEEP: $fname"
    SKIPPED=$((SKIPPED+1))
  else
    git -C "$JIT_ROOT" mv "$f" "$ARCHIVE/$fname" 2>/dev/null || mv "$f" "$ARCHIVE/$fname"
    echo "ARCHIVED: $fname"
    ARCHIVED=$((ARCHIVED+1))
  fi
done

echo ""
echo "═══════════════════════════════════════"
echo "Archive complete: $ARCHIVED moved, $SKIPPED kept"
echo "═══════════════════════════════════════"
ls "$ARCHIVE" | head -20
