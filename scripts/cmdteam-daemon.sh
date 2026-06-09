#!/usr/bin/env bash
# 🤖 Sonnet 4.6
# cmdteam-daemon.sh — systemd wrapper: source .env, exec cmdteam self-improve, log output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
LOG_FILE="${LOG_DIR}/cmdteam-daemon.log"
ENV_FILE="${REPO_DIR}/scripts/cmdteam-daemon.env"

mkdir -p "${LOG_DIR}"

# Load environment if present
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

cd "${REPO_DIR}"

echo "[$(date -Iseconds)] cmdteam-daemon: starting self-improve cycle" >> "${LOG_FILE}"

# Run cmdteam self-improve loop; replace shell with the process
exec bash cmdteam/cmdteam.sh self-improve >> "${LOG_FILE}" 2>&1