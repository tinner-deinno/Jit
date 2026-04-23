#!/usr/bin/env bash
# scripts/bootstrap.sh — ติดตั้งระบบทั้งหมดสำหรับ Jit agent
# Usage: bash scripts/bootstrap.sh [agent-name]
# ตามขั้นตอนใน README ของ arra-oracle-v3

set -e
AGENT_NAME="${1:-innova}"
echo "🚀 Bootstrapping $AGENT_NAME agent..."
echo ""

# ==============================
# Step 1: Install Bun
# ==============================
echo "[ Step 1/6 ] Installing Bun runtime..."
if ! command -v bun &>/dev/null && ! [ -f "$HOME/.bun/bin/bun" ]; then
  curl -fsSL https://bun.sh/install | bash
fi
export PATH="$HOME/.bun/bin:$PATH"
echo "  ✅ Bun $(bun --version)"

# ==============================
# Step 2: Clone Arra Oracle V3
# ==============================
echo ""
echo "[ Step 2/6 ] Cloning Arra Oracle V3..."
if [ ! -d "/workspaces/arra-oracle-v3" ]; then
  git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3.git /workspaces/arra-oracle-v3
  echo "  ✅ Cloned"
else
  echo "  ✅ Already exists"
fi

# ==============================
# Step 3: bun install
# ==============================
echo ""
echo "[ Step 3/6 ] Installing dependencies..."
cd /workspaces/arra-oracle-v3
bun install 2>&1 | tail -3
echo "  ✅ Dependencies installed"

# ==============================
# Step 4: .env + mkdir ~/.oracle
# ==============================
echo ""
echo "[ Step 4/6 ] Setup .env and database directory..."
if [ ! -f ".env" ]; then
  cp .env.example .env
  sed -i 's|OLLAMA_BASE_URL=http://localhost:11434|OLLAMA_BASE_URL=https://ollama.mdes-innova.online|' .env
fi
mkdir -p ~/.oracle
bun run db:push 2>&1 | tail -3
echo "  ✅ Database schema ready"

# ==============================
# Step 5: Index + Start Server
# ==============================
echo ""
echo "[ Step 5/6 ] Starting Oracle server..."
bun run index 2>&1 | tail -5
pkill -f "bun.*server.ts" 2>/dev/null || true
sleep 1
ORACLE_PORT=47778 bun run server > /tmp/oracle-server.log 2>&1 &
sleep 3
HEALTH=$(curl -s http://localhost:47778/api/health)
echo "  ✅ Server: $(echo $HEALTH | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["status"], "—", d["version"])')"

# ==============================
# Step 6: Soul Check
# ==============================
echo ""
echo "[ Step 6/6 ] Running soul integrity check..."
cd /workspaces/Jit
bash eval/soul-check.sh

echo ""
echo "🌟 $AGENT_NAME is ALIVE and ready!"
echo ""
echo "Next steps:"
echo "  • Use @innova in VS Code Copilot chat"
echo "  • Run /wake-up to check status"
echo "  • Run /remember to save learnings"
