#!/bin/bash
# PM+SA Dispatcher — fires claude CLI sub-agents in background
# Main loop token cost: ~0 (orchestration is pure bash, results go to disk)
# Usage: bash scripts/pm-sa-dispatch.sh [--wait]
# Fix: GROUPS is bash-reserved (GID list) — renamed to AGENT_GROUPS

set -euo pipefail

PROJ="/workspaces/Jit"
PROMPT_DIR="$PROJ/.claude/pm-sa"
REPORT_DIR="$PROJ/reports"
ITER_TAG="$(date +%Y%m%d-%H%M%S)"
LOG="$REPORT_DIR/SA-Lead/dispatch-log.txt"
CLAUDE="/home/codespace/.local/bin/claude"

# Load env vars (API keys, tokens) — never echo these
if [[ -f "$PROJ/.env" ]]; then
  # shellcheck disable=SC1090
  set +u
  source "$PROJ/.env"
  set -u
fi

# Auth: claude.ai OAuth session stored in ~/.claude/ — do NOT override with COMMANDCODE_API_KEY
# (user_2Q9BY... is an OAuth user token, not an sk-ant-... API key)
# Child claude processes inherit ~/.claude/ credentials automatically
unset ANTHROPIC_API_KEY 2>/dev/null || true

mkdir -p "$REPORT_DIR/groups" "$REPORT_DIR/SA-Lead" \
         "$PROJ/specs/tor" "$PROJ/specs/runbooks" "$PROJ/specs/test-plans" \
         "$PROJ/tickets/open"

echo "[${ITER_TAG}] PM+SA dispatch starting — auth: [REDACTED]" >> "$LOG"

# NOTE: AGENT_GROUPS not GROUPS — bash reserves $GROUPS for user GID list
AGENT_GROUPS=(A-security B-bus-spec C-devops-spec D-test-gaps E-doc-audit F-feature-discover G-organ-health)
PIDS=()

for grp in "${AGENT_GROUPS[@]}"; do
  PROMPT_FILE="$PROMPT_DIR/${grp}.md"
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "[${ITER_TAG}] SKIP $grp — prompt file missing at $PROMPT_FILE" >> "$LOG"
    continue
  fi

  echo "[${ITER_TAG}] LAUNCH $grp (model: claude-haiku-4-5-20251001)" >> "$LOG"

  "$CLAUDE" \
    --dangerously-skip-permissions \
    --model "claude-haiku-4-5-20251001" \
    -p "$(cat "$PROMPT_FILE")" \
    > "$REPORT_DIR/groups/${grp}-${ITER_TAG}.log" 2>&1 &

  PIDS+=($!)
  echo "[${ITER_TAG}]   PID $! → groups/${grp}-${ITER_TAG}.log" >> "$LOG"
done

echo "[${ITER_TAG}] Launched ${#PIDS[@]}/${#AGENT_GROUPS[@]} groups. PIDs: ${PIDS[*]:-none}" >> "$LOG"

if [[ "${1:-}" == "--wait" ]]; then
  echo "[${ITER_TAG}] Waiting for all groups..." >> "$LOG"
  FAILED=0
  for pid in "${PIDS[@]:-}"; do
    wait "$pid" || { echo "[${ITER_TAG}] WARN pid $pid failed" >> "$LOG"; FAILED=$((FAILED+1)); }
  done
  echo "[${ITER_TAG}] All groups done. Failures: $FAILED" >> "$LOG"

  # Coordinator (H) runs after all groups complete — uses sonnet for synthesis
  echo "[${ITER_TAG}] Running coordinator H-innova-check (model: sonnet)" >> "$LOG"
  "$CLAUDE" \
    --dangerously-skip-permissions \
    --model "claude-sonnet-4-6" \
    -p "$(cat "$PROMPT_DIR/H-innova-check.md")" \
    > "$REPORT_DIR/groups/H-innova-check-${ITER_TAG}.log" 2>&1

  TICKET_COUNT=$(ls "$PROJ/tickets/open/" | wc -l)
  echo "[${ITER_TAG}] COMPLETE — tickets: $TICKET_COUNT" >> "$LOG"
else
  # Fire-and-forget: groups in background, coordinator after 120s
  (sleep 120 && "$CLAUDE" \
    --dangerously-skip-permissions \
    --model "claude-sonnet-4-6" \
    -p "$(cat "$PROMPT_DIR/H-innova-check.md")" \
    > "$REPORT_DIR/groups/H-innova-check-${ITER_TAG}.log" 2>&1 \
    && echo "[$(date +%Y%m%d-%H%M%S)] Coordinator done" >> "$LOG") &

  echo "[${ITER_TAG}] Fire-and-forget — coordinator in 120s (PID $!)" >> "$LOG"
fi

echo "[${ITER_TAG}] Dispatch complete" >> "$LOG"
