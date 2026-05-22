#!/usr/bin/env bash
# scripts/start-openclaude-wsl.sh — OpenClaude launcher สำหรับ WSL2/Ubuntu
#
# ใช้ MDES Ollama หรือ GitHub Copilot โดยไม่ต้องใส่ token ใน .env
#
# Usage:
#   bash scripts/start-openclaude-wsl.sh              # Interactive picker
#   bash scripts/start-openclaude-wsl.sh mdes         # MDES Ollama (gemma4:26b)
#   bash scripts/start-openclaude-wsl.sh mdes qwen2.5-coder:32b
#   bash scripts/start-openclaude-wsl.sh github       # GitHub Copilot
#   bash scripts/start-openclaude-wsl.sh local        # Local Ollama
#
# Note: WSL2 paths for Windows files use /mnt/c/...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# OpenClaude repo — try WSL path first, fall back to Windows mount
if   [ -d "/home/$USER/DEV/openclaude" ]; then
  OPENCLAUDE_DIR="/home/$USER/DEV/openclaude"
elif [ -d "/mnt/c/Users/admin/DEV/openclaude" ]; then
  OPENCLAUDE_DIR="/mnt/c/Users/admin/DEV/openclaude"
else
  echo "❌ openclaude not found. Clone or mount it."
  exit 1
fi

DIST_PATH="$OPENCLAUDE_DIR/dist/cli.mjs"
ENV_FILE="$JIT_ROOT/.env"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; RESET='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $*${RESET}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${RESET}"; }
log_err()  { echo -e "${RED}❌ $*${RESET}"; }
log_info() { echo -e "${CYAN}$*${RESET}"; }

echo -e "${CYAN}\n🤖 OpenClaude Launcher — WSL2/Ubuntu${RESET}"
echo -e "${CYAN}======================================\n${RESET}"

# ── Check if openclaude is available ─────────────────────────────
if ! command -v openclaude &>/dev/null && [ ! -f "$DIST_PATH" ]; then
  log_err "openclaude not installed."
  echo "  Install:  npm install -g @gitlawb/openclaude"
  echo "  OR build: cd $OPENCLAUDE_DIR && bun run build"
  exit 1
fi

# ── Load .env ────────────────────────────────────────────────────
OLLAMA_TOKEN=""
OLLAMA_BASE_URL="https://ollama.mdes-innova.online"
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
  log_ok "Loaded Jit .env"
fi

# ── Clear all provider vars (clean slate) ─────────────────────────
unset CLAUDE_CODE_USE_OPENAI CLAUDE_CODE_USE_GITHUB \
      ANTHROPIC_API_KEY OPENAI_API_KEY OPENAI_BASE_URL \
      OPENAI_MODEL GITHUB_TOKEN 2>/dev/null || true

# ── MDES Ollama models ────────────────────────────────────────────
MDES_MODELS=(
  "gemma4:26b         — Thai/General (หลัก)"
  "qwen2.5-coder:32b  — Coding specialist"
  "deepseek-coder:33b — Deep code analysis"
  "gemma4:e4b         — Lightweight/Fast"
)

PROFILE="${1:-}"
MODEL="${2:-}"

# ── Interactive picker ────────────────────────────────────────────
if [ -z "$PROFILE" ]; then
  echo "Select provider:"
  echo "  [1] MDES Ollama  — $OLLAMA_BASE_URL"
  echo "  [2] GitHub Copilot — ไม่ต้องใส่ token"
  echo "  [3] Local Ollama — http://127.0.0.1:11434"
  read -rp "Choice [1-3]: " choice
  case $choice in
    1) PROFILE="mdes" ;;
    2) PROFILE="github" ;;
    3) PROFILE="local" ;;
    *) PROFILE="mdes" ;;
  esac
fi

# ── Profile: MDES Ollama ─────────────────────────────────────────
if [ "$PROFILE" = "mdes" ]; then
  if [ -z "$OLLAMA_TOKEN" ] || [ "$OLLAMA_TOKEN" = "your_mdes_ollama_token_here" ]; then
    log_err "OLLAMA_TOKEN not set in $ENV_FILE"
    exit 1
  fi

  if [ -z "$MODEL" ]; then
    echo ""
    echo "Available MDES Ollama models:"
    for i in "${!MDES_MODELS[@]}"; do
      echo "  [$((i+1))] ${MDES_MODELS[$i]}"
    done
    read -rp "Model [1-${#MDES_MODELS[@]}] (Enter = gemma4:26b): " mChoice
    case $mChoice in
      1) MODEL="gemma4:26b" ;;
      2) MODEL="qwen2.5-coder:32b" ;;
      3) MODEL="deepseek-coder:33b" ;;
      4) MODEL="gemma4:e4b" ;;
      *) MODEL="gemma4:26b" ;;
    esac
  fi

  echo -e "\n${MAGENTA}🦙 MDES Ollama → $MODEL${RESET}"
  export CLAUDE_CODE_USE_OPENAI="1"
  export OPENAI_BASE_URL="$OLLAMA_BASE_URL/v1"
  export OPENAI_API_KEY="$OLLAMA_TOKEN"
  export OPENAI_MODEL="$MODEL"

# ── Profile: GitHub Copilot ───────────────────────────────────────
elif [ "$PROFILE" = "github" ]; then
  echo -e "\n${MAGENTA}🐙 GitHub Copilot mode (token-free auth)${RESET}"
  echo "   ℹ️  First time? type /onboard-github inside TUI"

  export CLAUDE_CODE_USE_GITHUB="1"

  # Try gh CLI token as fallback
  if command -v gh &>/dev/null; then
    GH_TOKEN_VALUE=$(gh auth token 2>/dev/null || true)
    if [ -n "$GH_TOKEN_VALUE" ]; then
      export GITHUB_TOKEN="$GH_TOKEN_VALUE"
      log_ok "GitHub token loaded from gh CLI"
    fi
  fi

# ── Profile: Local Ollama ─────────────────────────────────────────
elif [ "$PROFILE" = "local" ]; then
  [ -z "$MODEL" ] && MODEL="qwen2.5:0.5b"
  echo -e "\n${MAGENTA}🏠 Local Ollama → $MODEL${RESET}"

  if ! curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    log_err "Local Ollama not running. Start: ollama serve"
    exit 1
  fi
  log_ok "Local Ollama running"

  export CLAUDE_CODE_USE_OPENAI="1"
  export OPENAI_BASE_URL="http://127.0.0.1:11434/v1"
  export OPENAI_API_KEY="ollama"
  export OPENAI_MODEL="$MODEL"
fi

# ── Launch ────────────────────────────────────────────────────────
echo ""
log_ok "Starting OpenClaude..."
echo "   Tip: /model → switch model   /provider → change provider   /onboard-github → GitHub auth"
echo ""

cd "$OPENCLAUDE_DIR"
if command -v openclaude &>/dev/null; then
  exec openclaude "$@"
elif [ -f "$DIST_PATH" ]; then
  exec node "$DIST_PATH" "$@"
else
  log_err "openclaude not installed and dist/cli.mjs not built."
  echo "  Install:  npm install -g @gitlawb/openclaude"
  echo "  OR build: cd $OPENCLAUDE_DIR && bun run build"
  exit 1
fi
