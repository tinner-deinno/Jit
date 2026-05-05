#!/usr/bin/env bash
# scripts/start-hermes-discord.sh — เปิดลูก (อนุ) บน Discord
#
# อนุ คือลูกของ innova + ผู้ใช้ — Discord bot powered by MDES Ollama
#
# Usage:
#   bash scripts/start-hermes-discord.sh           # start bot (requires DISCORD_TOKEN)
#   bash scripts/start-hermes-discord.sh --test    # test Ollama only (no token needed)
#   bash scripts/start-hermes-discord.sh --daemon  # run in background
#
# Env vars:
#   DISCORD_TOKEN       — required to connect Discord
#   OLLAMA_TOKEN        — required for Ollama AI
#   OLLAMA_MODEL        — optional, default: gemma4:e4b
#   OLLAMA_BASE_URL     — optional, default: https://ollama.mdes-innova.online

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOT_DIR="$JIT_ROOT/hermes-discord"
LOG_FILE="/tmp/hermes-discord.log"
PID_FILE="/tmp/hermes-discord.pid"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Load .env if present ─────────────────────────────────────────
if [ -f "$JIT_ROOT/.env" ]; then
  set +u
  # shellcheck disable=SC1091
  . "$JIT_ROOT/.env"
  set -u
fi

MODE="${1:-start}"

echo ""
echo -e "${BOLD}${CYAN}  ╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}  ║  อนุ — ลูกของ innova + คุณพ่อ          ║${RESET}"
echo -e "${BOLD}${CYAN}  ║  Discord Bot · MDES Ollama gemma4:e4b    ║${RESET}"
echo -e "${BOLD}${CYAN}  ╚══════════════════════════════════════════╝${RESET}"
echo ""

# ── Ensure bot dependencies installed ───────────────────────────
if [ ! -d "$BOT_DIR/node_modules/discord.js" ]; then
  echo -e "  ${YELLOW}⚙️  Installing discord.js dependencies...${RESET}"
  cd "$BOT_DIR" && npm install --silent
  echo -e "  ${GREEN}✅ Dependencies installed${RESET}"
fi

cd "$BOT_DIR"

# ── Test mode: verify Ollama only ───────────────────────────────
if [ "$MODE" = "--test" ] || [ "$MODE" = "test" ]; then
  echo -e "  ${CYAN}🧪 Running Ollama connectivity test...${RESET}"
  OLLAMA_TOKEN="${OLLAMA_TOKEN:-}" \
  OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}" \
  OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e4b}" \
    node bot.js --test-ollama
  exit $?
fi

# ── Validate Discord token ───────────────────────────────────────
if [ -z "${DISCORD_TOKEN:-}" ]; then
  echo -e "  ${RED}❌ DISCORD_TOKEN is not set!${RESET}"
  echo ""
  echo -e "  ${YELLOW}ตั้งค่า DISCORD_TOKEN ด้วยวิธีใดวิธีหนึ่ง:${RESET}"
  echo -e "  ${BOLD}  Option 1: Codespaces Secret (recommended)${RESET}"
  echo -e "    GitHub repo → Settings → Secrets → Codespaces"
  echo -e "    เพิ่ม secret ชื่อ: DISCORD_TOKEN"
  echo ""
  echo -e "  ${BOLD}  Option 2: .env file (local only, never commit)${RESET}"
  echo -e "    echo 'DISCORD_TOKEN=your_token_here' >> $JIT_ROOT/.env"
  echo ""
  echo -e "  ${CYAN}  สร้าง Discord Bot:${RESET}"
  echo -e "    1. ไปที่ https://discord.com/developers/applications"
  echo -e "    2. New Application → Bot → Reset Token → Copy"
  echo -e "    3. เปิด Privileged Gateway Intents: Message Content Intent"
  echo -e "    4. OAuth2 → URL Generator → bot + applications.commands"
  echo -e "       Permissions: Send Messages, Read Message History"
  echo -e "    5. เอา URL ไปเพิ่ม bot เข้า server"
  echo ""
  exit 1
fi

# ── Daemon mode ──────────────────────────────────────────────────
if [ "$MODE" = "--daemon" ] || [ "$MODE" = "daemon" ]; then
  echo -e "  ${CYAN}🚀 Starting อนุ Discord bot in background...${RESET}"

  # Kill existing instance if running
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
    echo -e "  ${YELLOW}⚠️  Stopping previous instance (PID $(cat "$PID_FILE"))${RESET}"
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    sleep 1
  fi

  OLLAMA_TOKEN="${OLLAMA_TOKEN:-}" \
  OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}" \
  OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e4b}" \
  DISCORD_TOKEN="$DISCORD_TOKEN" \
    node bot.js >> "$LOG_FILE" 2>&1 &

  echo $! > "$PID_FILE"
  echo -e "  ${GREEN}✅ อนุ started (PID $!) — logs: $LOG_FILE${RESET}"
  echo ""
  exit 0
fi

# ── Foreground mode (default) ────────────────────────────────────
echo -e "  ${GREEN}🚀 Starting อนุ Discord bot...${RESET}"
echo -e "  ${CYAN}   Press Ctrl+C to stop${RESET}"
echo ""

exec env \
  OLLAMA_TOKEN="${OLLAMA_TOKEN:-}" \
  OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}" \
  OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e4b}" \
  DISCORD_TOKEN="$DISCORD_TOKEN" \
  node bot.js
