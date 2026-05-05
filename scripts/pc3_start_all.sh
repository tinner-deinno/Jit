#!/usr/bin/env bash
# scripts/pc3_start_all.sh — PC3-Jit One-Click Bootstrap
#
# Starts all Jit agent services on the PC3 node.
# Run this after a fresh clone or codespace start.
#
# Usage:
#   bash scripts/pc3_start_all.sh           # full start
#   bash scripts/pc3_start_all.sh --status  # show current status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

CMD="${1:---start}"

if [ "$CMD" == "--status" ]; then
  bash "$SCRIPT_DIR/init-life.sh" --status
  exit 0
fi

echo ""
echo "===== PC3-Jit Node Startup ====="
echo "Node: ${INNOVA_NODE_ID:-PC3-Jit}"
echo "Host: $(hostname)"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. Oracle (if arra-oracle-v3 present)
ORACLE_DIR="${ORACLE_DIR:-/workspaces/arra-oracle-v3}"
BUN="$HOME/.bun/bin/bun"
if [ -d "$ORACLE_DIR" ] && [ -f "$BUN" ]; then
  echo "[1/4] Starting Arra Oracle..."
  export PATH="$HOME/.bun/bin:$PATH"
  (cd "$ORACLE_DIR" && ORACLE_PORT="${ORACLE_PORT:-47778}" bun run src/server.ts >> /tmp/oracle.log 2>&1) &
  sleep 3
  if curl -sf --max-time 3 "http://localhost:${ORACLE_PORT:-47778}/api/health" 2>/dev/null | grep -q '"oracle"'; then
    echo "  Oracle: online at http://localhost:${ORACLE_PORT:-47778}"
  else
    echo "  Oracle: starting in background (check /tmp/oracle.log)"
  fi
else
  echo "[1/4] Oracle: skipped (arra-oracle-v3 not found or bun not installed)"
  echo "  To enable: clone Soul-Brews-Studio/arra-oracle-v3 to $ORACLE_DIR"
  echo "  Install bun: curl -fsSL https://bun.sh/install | bash"
fi

# 2. Init Life
echo ""
echo "[2/4] Running init-life.sh..."
bash "$SCRIPT_DIR/init-life.sh" 2>&1 | tail -20

# 3. Heartbeat daemon
echo ""
echo "[3/4] Ensuring heartbeat daemon..."
bash "$SCRIPT_DIR/heartbeat.sh" status 2>/dev/null | grep -q 'กำลังรัน' \
  && echo "  Heartbeat: already running" \
  || bash "$SCRIPT_DIR/heartbeat.sh" start

# 4. Summary
echo ""
echo "[4/4] Status summary:"
bash "$SCRIPT_DIR/life-checklist.sh" --short

echo ""
echo "===== PC3-Jit startup complete ====="
echo ""
echo "Useful commands:"
echo "  bash scripts/heartbeat.sh status       # daemon health"
echo "  bash scripts/init-life.sh --status     # full status"
echo "  bash scripts/life-checklist.sh         # life checklist"
echo "  bash eval/soul-check.sh                # soul verification"
echo "  bash eval/body-check.sh                # full body check"
echo ""
