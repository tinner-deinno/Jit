#!/usr/bin/env bash
# ============================================================
#  git-checkpoint.sh — Manual Git Milestone Checkpoint
#
#  Creates a meaningful commit with agent activity summary.
#  NOTE: Auto-cron git-add is FORBIDDEN by jit-topology.json.
#        Use this script manually or at deliberate milestones.
#
#  Usage:
#    bash scripts/git-checkpoint.sh [message]
#    bash scripts/git-checkpoint.sh "milestone: feature X done"
# ============================================================
set -euo pipefail

JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
cd "$JIT_ROOT"

G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; C='\033[1;36m'; NC='\033[0m'

# ── Collect agent activity summary ────────────────────────────
get_agent_summary() {
  local summary=""
  for f in /tmp/agent-*.log; do
    [[ -f "$f" ]] || continue
    local agent; agent=$(basename "$f" .log | sed 's/agent-//' | tr '[:lower:]' '[:upper:]')
    local last; last=$(tail -1 "$f" 2>/dev/null | grep -oP 'CYCLE#\d+.*' | head -c 60)
    [[ -n "$last" ]] && summary+="[$agent] $last | "
  done
  echo "${summary:0:200}"
}

# ── Build commit message ──────────────────────────────────────
TS=$(date '+%Y-%m-%d %H:%M')
CUSTOM_MSG="${1:-}"

if [[ -n "$CUSTOM_MSG" ]]; then
  COMMIT_MSG="checkpoint: $CUSTOM_MSG [$TS]"
else
  AGENT_SUMMARY=$(get_agent_summary)
  if [[ -n "$AGENT_SUMMARY" ]]; then
    COMMIT_MSG="checkpoint: agent activity @ $TS"
    COMMIT_BODY="$AGENT_SUMMARY"
  else
    COMMIT_MSG="checkpoint: manual milestone @ $TS"
    COMMIT_BODY=""
  fi
fi

# ── Check for changes ─────────────────────────────────────────
echo -e "${C}[GIT] Checking for changes...${NC}"
git status --short

CHANGED=$(git status --porcelain 2>/dev/null | grep -v '^\?\?' || true)
if [[ -z "$CHANGED" ]]; then
  echo -e "${Y}[GIT] Nothing to commit (no tracked file changes).${NC}"
  echo -e "${Y}[GIT] Untracked files (if any) were intentionally skipped.${NC}"
  exit 0
fi

# ── Stage and commit ─────────────────────────────────────────
echo -e "${C}[GIT] Staging changes...${NC}"
git add -A -- . \
  ':!.env' ':!*.enc' ':!*.pem' ':!*.key' ':!*secret*' ':!*token*'

echo -e "${C}[GIT] Committing: $COMMIT_MSG${NC}"
if [[ -n "${COMMIT_BODY:-}" ]]; then
  git commit -m "$COMMIT_MSG" -m "$COMMIT_BODY"
else
  git commit -m "$COMMIT_MSG"
fi

echo -e "${G}[GIT] Commit created:${NC}"
git log --oneline -1

echo ""
echo -e "${Y}[GIT] To push: git push origin main${NC}"
echo -e "${Y}[GIT] (Push is intentionally manual — see jit-topology.json)${NC}"
