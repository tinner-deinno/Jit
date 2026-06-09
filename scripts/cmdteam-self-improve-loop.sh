#!/usr/bin/env bash
# 🤖 Sonnet 4.6
# cmdteam-self-improve-loop.sh — background loop, runs self-improve every 1hr
# Use: nohup bash scripts/cmdteam-self-improve-loop.sh >> logs/cmdteam-loop.log 2>&1 &
set -uo pipefail

REPO_DIR="/workspaces/Jit"
LOG_DIR="${REPO_DIR}/logs"
LOG_FILE="${LOG_DIR}/cmdteam-self-improve.log"
INTERVAL=3600  # 1hr

mkdir -p "${LOG_DIR}"

cd "${REPO_DIR}"
# Source .env once
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

echo "[$(date -Iseconds)] cmdteam-self-improve-loop: started (interval=${INTERVAL}s)" >> "${LOG_FILE}"

while true; do
  echo "[$(date -Iseconds)] running self-improve..." >> "${LOG_FILE}"
  bash cmdteam/self-improve.sh >> "${LOG_FILE}" 2>&1 || echo "[$(date -Iseconds)] self-improve exited non-zero" >> "${LOG_FILE}"

  # Sleep in 60s chunks so we react quickly to kill signals
  for ((i=0; i<INTERVAL; i+=60)); do
    sleep 60
  done
done
