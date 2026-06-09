#!/bin/bash

################################################################################
# start-oracle.sh
# Purpose: Start Arra Oracle V3 knowledge base server on port 47778
# Usage: bash scripts/start-oracle.sh
# Note: Oracle is required for Jit multi-agent system to function
################################################################################

set -e

echo "🔮 Starting Arra Oracle V3..."

# Ensure Bun is in PATH
export PATH="$HOME/.bun/bin:$PATH"

# Verify Bun is installed
if ! command -v bun &> /dev/null; then
    echo "❌ Bun not found. Installing..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi

echo "✓ Bun version: $(bun --version)"

# Navigate to Oracle repository
cd /workspaces/arra-oracle-v3 || {
    echo "❌ Oracle repository not found at /workspaces/arra-oracle-v3"
    exit 1
}

# Ensure dependencies are installed
echo "📦 Installing dependencies..."
bun install --quiet

# Start the Oracle server
echo "🚀 Starting Oracle server on port 47778..."
ORACLE_PORT=47778 bun run src/server.ts &

# Capture the PID
ORACLE_PID=$!

# Wait for server to start
echo "⏳ Waiting for Oracle to start..."
sleep 3

# Check if Oracle is healthy
if curl -s http://localhost:47778/api/health &>/dev/null; then
    echo "✅ Oracle is ready! (PID: $ORACLE_PID)"
    echo "📡 Knowledge base listening on http://localhost:47778"
    echo "🛑 To stop Oracle, run: kill $ORACLE_PID"

    # Keep the server running in background
    wait $ORACLE_PID
else
    echo "⚠️  Oracle started but health check failed"
    echo "🔍 Checking status..."
    sleep 2
    if curl -s http://localhost:47778/api/health &>/dev/null; then
        echo "✅ Oracle is now healthy (delayed startup)"
    else
        echo "❌ Oracle failed to start. Check logs above."
        kill $ORACLE_PID 2>/dev/null || true
        exit 1
    fi
fi
