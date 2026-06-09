#!/usr/bin/env bash
# scripts/bootstrap.sh — ติดตั้งระบบทั้งหมดสำหรับ Jit agent
# Usage: bash scripts/bootstrap.sh [agent-name]
# ตามขั้นตอนใน README ของ arra-oracle-v3
#
# JIT-008: Added pinned version checkout + last-known-good snapshot

set -e
AGENT_NAME="${1:-innova}"
ORACLE_DIR="/workspaces/arra-oracle-v3"
STATE_DIR="/var/lib/jit"
echo "🚀 Bootstrapping $AGENT_NAME agent..."
echo ""

# ==============================
# Step 0: Snapshot Last Known Good (BEFORE any mutation)
# ==============================
echo "[ Step 0/7 ] Snapshotting current state for rollback..."
mkdir -p "$STATE_DIR"
if [ -d "$ORACLE_DIR/.git" ]; then
  CURRENT_COMMIT=$(git -C "$ORACLE_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
  echo "$CURRENT_COMMIT" > "$STATE_DIR/last-known-good.txt"
  echo "  ✅ Snapshot: $CURRENT_COMMIT"
else
  echo "  ⚠️  No git repo found — skipping snapshot"
fi

# ==============================
# Step 1: Install Bun
# ==============================
echo "[ Step 1/7 ] Installing Bun runtime..."
if ! command -v bun &>/dev/null && ! [ -f "$HOME/.bun/bin/bun" ]; then
  curl -fsSL https://bun.sh/install | bash
fi
export PATH="$HOME/.bun/bin:$PATH"
echo "  ✅ Bun $(bun --version)"

# ==============================
# Step 2: Clone Arra Oracle V3
# ==============================
echo ""
echo "[ Step 2/7 ] Cloning Arra Oracle V3..."
if [ ! -d "$ORACLE_DIR" ]; then
  git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3.git "$ORACLE_DIR"
  echo "  ✅ Cloned"
else
  echo "  ✅ Already exists"
fi

# ==============================
# Step 3: Pin to Known Good Version (JIT-008)
# ==============================
echo ""
echo "[ Step 3/7 ] Pinning Oracle to known good version..."
cd "$ORACLE_DIR"
git fetch --tags --quiet 2>/dev/null || true
PINNED_VERSION="${ARRA_ORACLE_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo '')}"
if [ -n "$PINNED_VERSION" ]; then
  git checkout "$PINNED_VERSION" --quiet
  echo "  ✅ Pinned to: $PINNED_VERSION"
else
  echo "  ⚠️  No tags found — staying on current branch"
fi

# ==============================
# Step 4: bun install
# ==============================
echo ""
echo "[ Step 4/7 ] Installing dependencies..."
bun install 2>&1 | tail -3
echo "  ✅ Dependencies installed"

# ==============================
# Step 5: .env + mkdir ~/.oracle
# ==============================
echo ""
echo "[ Step 5/7 ] Setup .env and database directory..."
if [ ! -f ".env" ]; then
  cp .env.example .env
  sed -i 's|OLLAMA_BASE_URL=http://localhost:11434|OLLAMA_BASE_URL=https://ollama.mdes-innova.online|' .env
fi
mkdir -p ~/.oracle

# Pre-deploy migration safety check (JIT-008)
echo ""
echo "[ Step 5b/7 ] Checking migrations for destructive operations..."
if bash /workspaces/Jit/scripts/check-migrations.sh; then
  echo "  ✅ Migrations safe to apply"
  bun run db:push 2>&1 | tail -3
else
  echo "  ❌ Destructive migration detected — aborting!"
  echo ""
  echo "Rollback instructions:"
  echo "  bash /workspaces/Jit/scripts/rollback.sh"
  exit 1
fi
echo "  ✅ Database schema ready"

# ==============================
# Step 6: Index + Start Server
# ==============================
echo ""
echo "[ Step 6/7 ] Starting Oracle server..."
bun run index 2>&1 | tail -5
pkill -f "bun.*server.ts" 2>/dev/null || true
sleep 1
ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &
sleep 3
HEALTH=$(curl -s http://localhost:47778/api/health)
echo "  ✅ Server: $(echo $HEALTH | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["status"], "—", d["version"])')"

# ==============================
# Step 7: Soul Check
# ==============================
echo ""
echo "[ Step 7/7 ] Running soul integrity check..."
cd /workspaces/Jit
bash eval/soul-check.sh

echo ""
echo "🌟 $AGENT_NAME is ALIVE and ready!"
echo ""
echo "Next steps:"
echo "  • Use @innova in VS Code Copilot chat"
echo "  • Run /wake-up to check status"
echo "  • Run /remember to save learnings"
echo ""
echo "Rollback (if needed):"
echo "  • bash /workspaces/Jit/scripts/rollback.sh"
