#!/bin/bash
# PM+SA Dispatcher — fires claude CLI sub-agents in background
# Main loop token cost: ~0 (orchestration is pure bash, results go to disk)
# Usage: bash scripts/pm-sa-dispatch.sh [--wait]

set -euo pipefail

PROJ="/workspaces/Jit"
PROMPT_DIR="$PROJ/.claude/pm-sa"
REPORT_DIR="$PROJ/reports"
ITER_TAG="$(date +%Y%m%d-%H%M%S)"
LOG="$REPORT_DIR/SA-Lead/dispatch-log.txt"
CLAUDE="/home/codespace/.local/bin/claude"

mkdir -p "$REPORT_DIR/groups" "$REPORT_DIR/SA-Lead" "$PROJ/specs/tor" "$PROJ/specs/runbooks" "$PROJ/specs/test-plans"

echo "[${ITER_TAG}] PM+SA dispatch starting" >> "$LOG"

# Groups A-G run in parallel — each claude process is isolated, writes to disk
# Group H (coordinator) runs after others complete
GROUPS=(A-security B-bus-spec C-devops-spec D-test-gaps E-doc-audit F-feature-discover G-organ-health)
PIDS=()

for grp in "${GROUPS[@]}"; do
  PROMPT_FILE="$PROMPT_DIR/${grp}.md"
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "[${ITER_TAG}] SKIP $grp — prompt file missing" >> "$LOG"
    continue
  fi

  echo "[${ITER_TAG}] LAUNCH $grp" >> "$LOG"

  "$CLAUDE" \
    --dangerously-skip-permissions \
    --model claude-haiku-4-5-20251001 \
    -p "$(cat "$PROMPT_FILE")" \
    > "$REPORT_DIR/groups/${grp}-${ITER_TAG}.log" 2>&1 &

  PIDS+=($!)
done

echo "[${ITER_TAG}] Launched ${#PIDS[@]} groups: ${PIDS[*]}" >> "$LOG"

# Wait for all groups (or skip if --no-wait)
if [[ "${1:-}" == "--wait" ]]; then
  echo "[${ITER_TAG}] Waiting for all groups..." >> "$LOG"
  FAILED=0
  for pid in "${PIDS[@]}"; do
    wait "$pid" || { echo "[${ITER_TAG}] WARN pid $pid failed" >> "$LOG"; FAILED=$((FAILED+1)); }
  done
  echo "[${ITER_TAG}] All groups done. Failures: $FAILED" >> "$LOG"

  # Run coordinator (H) after all groups
  echo "[${ITER_TAG}] Running coordinator H-innova-check" >> "$LOG"
  "$CLAUDE" \
    --dangerously-skip-permissions \
    --model claude-sonnet-4-6 \
    -p "$(cat "$PROMPT_DIR/H-innova-check.md")" \
    > "$REPORT_DIR/groups/H-innova-check-${ITER_TAG}.log" 2>&1

  TICKET_COUNT=$(ls "$PROJ/tickets/open/" | wc -l)
  echo "[${ITER_TAG}] DONE — tickets: $TICKET_COUNT" >> "$LOG"
else
  # Fire-and-forget: groups run in background, caller doesn't wait
  echo "[${ITER_TAG}] Fire-and-forget mode — groups running in background" >> "$LOG"
  # Run coordinator in background too after a delay
  (sleep 120 && "$CLAUDE" \
    --dangerously-skip-permissions \
    --model claude-sonnet-4-6 \
    -p "$(cat "$PROMPT_DIR/H-innova-check.md")" \
    > "$REPORT_DIR/groups/H-innova-check-${ITER_TAG}.log" 2>&1) &
  echo "[${ITER_TAG}] Coordinator scheduled in 120s" >> "$LOG"
fi

echo "[${ITER_TAG}] Dispatch complete" >> "$LOG"
