#!/usr/bin/env bash
# eval/test-hermes-discord.sh — Test suite for hermes-discord (อนุ) bot
#
# Validates all components without requiring DISCORD_TOKEN:
#   1. hermes npm package installed
#   2. discord.js installed
#   3. Bot source files present
#   4. Ollama API connectivity
#   5. Ollama model responds correctly
#   6. Startup script structure
#   7. Codespaces devcontainer config
#
# Usage:
#   bash eval/test-hermes-discord.sh
#
# Exit codes:
#   0 = all tests passed (PASS)
#   1 = one or more tests failed (FAIL)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

# ── Load .env ────────────────────────────────────────────────────
if [ -f "$JIT_ROOT/.env" ]; then
  set +u
  # shellcheck disable=SC1091
  . "$JIT_ROOT/.env"
  set -u
fi

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║  🧪 hermes-discord (อนุ) — Test Suite           ║${RESET}"
echo -e "${BOLD}${CYAN}║  มนุษย์ Agent · Jit repo · $(date '+%Y-%m-%d %H:%M')      ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Helper functions ─────────────────────────────────────────────
pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  TOTAL=$((TOTAL + 1))
  echo -e "  ${GREEN}✅ PASS${RESET} — $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TOTAL=$((TOTAL + 1))
  echo -e "  ${RED}❌ FAIL${RESET} — $1"
  [ -n "${2:-}" ] && echo -e "         ${YELLOW}→ $2${RESET}"
}

warn() {
  echo -e "  ${YELLOW}⚠️  WARN${RESET} — $1"
}

section() {
  echo ""
  echo -e "${BOLD}  ── $1 ──${RESET}"
}

# ════════════════════════════════════════════════════════════════
section "1. hermes npm package"
# ════════════════════════════════════════════════════════════════

if command -v hermes >/dev/null 2>&1; then
  VERSION=$(hermes --version 2>/dev/null || echo "unknown")
  pass "hermes installed (v$VERSION)"
else
  fail "hermes not installed" "Run: npm install -g hermes"
fi

# ════════════════════════════════════════════════════════════════
section "2. hermes-discord package files"
# ════════════════════════════════════════════════════════════════

if [ -f "$JIT_ROOT/hermes-discord/bot.js" ]; then
  pass "hermes-discord/bot.js exists"
else
  fail "hermes-discord/bot.js missing"
fi

if [ -f "$JIT_ROOT/hermes-discord/package.json" ]; then
  pass "hermes-discord/package.json exists"
else
  fail "hermes-discord/package.json missing"
fi

if [ -d "$JIT_ROOT/hermes-discord/node_modules/discord.js" ]; then
  DJ_VER=$(node -e "console.log(require('$JIT_ROOT/hermes-discord/node_modules/discord.js/package.json').version)" 2>/dev/null || echo "unknown")
  pass "discord.js installed (v$DJ_VER)"
else
  fail "discord.js not installed" "Run: cd hermes-discord && npm install"
fi

# ════════════════════════════════════════════════════════════════
section "3. hermes-ollama plugin"
# ════════════════════════════════════════════════════════════════

if [ -f "$JIT_ROOT/hermes-ollama/index.js" ]; then
  pass "hermes-ollama/index.js exists"
else
  fail "hermes-ollama/index.js missing"
fi

if [ -f "$JIT_ROOT/hermes.json" ]; then
  pass "hermes.json config exists"
else
  fail "hermes.json missing"
fi

# ════════════════════════════════════════════════════════════════
section "4. startup scripts"
# ════════════════════════════════════════════════════════════════

if [ -f "$JIT_ROOT/scripts/start-hermes-discord.sh" ]; then
  pass "scripts/start-hermes-discord.sh exists"
  if [ -x "$JIT_ROOT/scripts/start-hermes-discord.sh" ]; then
    pass "start-hermes-discord.sh is executable"
  else
    warn "start-hermes-discord.sh not executable (chmod +x)"
    chmod +x "$JIT_ROOT/scripts/start-hermes-discord.sh"
    pass "start-hermes-discord.sh — fixed chmod +x"
  fi
else
  fail "scripts/start-hermes-discord.sh missing"
fi

if [ -f "$JIT_ROOT/scripts/start-hermes.sh" ]; then
  pass "scripts/start-hermes.sh (REPL) exists"
fi

# ════════════════════════════════════════════════════════════════
section "5. Codespaces devcontainer config"
# ════════════════════════════════════════════════════════════════

DEVCONTAINER="$JIT_ROOT/.devcontainer/devcontainer.json"
if [ -f "$DEVCONTAINER" ]; then
  pass ".devcontainer/devcontainer.json exists"
  if grep -q "start-hermes-discord" "$DEVCONTAINER"; then
    pass "devcontainer includes start-hermes-discord auto-start"
  else
    warn "devcontainer does not include start-hermes-discord yet"
  fi
  if grep -q "postStartCommand" "$DEVCONTAINER"; then
    pass "devcontainer has postStartCommand"
  fi
else
  fail ".devcontainer/devcontainer.json missing"
fi

# ════════════════════════════════════════════════════════════════
section "6. environment variables"
# ════════════════════════════════════════════════════════════════

OLLAMA_TOKEN_VAL="${OLLAMA_TOKEN:-}"
if [ -n "$OLLAMA_TOKEN_VAL" ]; then
  pass "OLLAMA_TOKEN is set (${#OLLAMA_TOKEN_VAL} chars)"
else
  fail "OLLAMA_TOKEN not set" "Add to .env or Codespaces secret"
fi

DISCORD_TOKEN_VAL="${DISCORD_TOKEN:-}"
if [ -n "$DISCORD_TOKEN_VAL" ]; then
  pass "DISCORD_TOKEN is set"
else
  warn "DISCORD_TOKEN not set (bot cannot connect to Discord without it)"
  warn "  Set via: GitHub repo → Settings → Secrets → Codespaces → DISCORD_TOKEN"
fi

# ════════════════════════════════════════════════════════════════
section "7. Ollama API connectivity"
# ════════════════════════════════════════════════════════════════

OLLAMA_URL="${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}"
echo -e "     Testing: $OLLAMA_URL"

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  -H "Authorization: Bearer $OLLAMA_TOKEN_VAL" \
  "$OLLAMA_URL/api/tags" 2>/dev/null) || HTTP_CODE="000"

if [ "$HTTP_CODE" = "200" ]; then
  pass "Ollama API reachable (HTTP $HTTP_CODE)"
else
  fail "Ollama API not reachable (HTTP $HTTP_CODE)" "Check connectivity to $OLLAMA_URL"
fi

# ════════════════════════════════════════════════════════════════
section "8. Ollama bot.js --test-ollama (full pipeline)"
# ════════════════════════════════════════════════════════════════

echo -e "     Running bot.js --test-ollama (may take 10-30s)..."
TEST_OUT=$(cd "$JIT_ROOT/hermes-discord" && \
  OLLAMA_TOKEN="$OLLAMA_TOKEN_VAL" \
  OLLAMA_BASE_URL="$OLLAMA_URL" \
  OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e4b}" \
  node bot.js --test-ollama 2>&1) || TEST_EXIT=$?

TEST_EXIT="${TEST_EXIT:-0}"

if [ "$TEST_EXIT" -eq 0 ] && echo "$TEST_OUT" | grep -q "✅ Ollama OK"; then
  REPLY=$(echo "$TEST_OUT" | grep "reply:" | head -1 | cut -d':' -f2- | xargs)
  pass "Ollama full pipeline OK — อนุ replied: \"$REPLY\""
else
  fail "Ollama full pipeline FAILED" "$TEST_OUT"
fi

# ════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo -e "${BOLD}${GREEN}║  🎉 ALL $TOTAL TESTS PASSED — PASS               ║${RESET}"
  echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
  if [ -z "${DISCORD_TOKEN:-}" ]; then
    echo -e "  ${YELLOW}📝 NOTE: DISCORD_TOKEN not set.${RESET}"
    echo -e "     Bot is ready but cannot connect Discord without token."
    echo -e "     Add DISCORD_TOKEN as Codespaces secret to enable Discord connection."
  fi
  echo ""
  echo -e "  ${CYAN}▶ Start Discord bot:${RESET}  bash scripts/start-hermes-discord.sh"
  echo -e "  ${CYAN}▶ Start REPL bot:${RESET}      bash scripts/start-hermes.sh"
  echo -e "  ${CYAN}▶ Daemon mode:${RESET}         bash scripts/start-hermes-discord.sh --daemon"
  echo ""
  exit 0
else
  echo -e "${BOLD}${RED}║  ❌ $FAIL_COUNT/$TOTAL TESTS FAILED — FAIL           ║${RESET}"
  echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════╝${RESET}"
  echo ""
  exit 1
fi
