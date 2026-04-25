#!/usr/bin/env bash
# scripts/selfhood-checklist.sh — Check Jit life, tools, and tasks in one go

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then
  set -a
  . "$JIT_ROOT/.env"
  set +a
fi

check_heartbeat() {
  if bash "$JIT_ROOT/scripts/heartbeat.sh" status 2>/dev/null | grep -q "กำลังรัน"; then
    echo "✅ heartbeat daemon running"
    return 0
  fi
  echo "⚠️ heartbeat daemon not running"
  return 1
}

check_autonomy() {
  if bash "$JIT_ROOT/minds/agent-autonomy.sh" status 2>/dev/null | grep -q "Daemon: running"; then
    echo "✅ agent-autonomy daemon running"
    return 0
  fi
  echo "⚠️ agent-autonomy daemon not running"
  return 1
}

check_innova_bot() {
  local path="${INNOVA_BOT_PATH:-$JIT_ROOT/innova-bot}"
  if [ -d "$path/.git" ]; then
    local branch
    branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    echo "✅ innova-bot repository present ($path, branch=$branch)"
    return 0
  fi
  echo "⚠️ innova-bot repository missing at $path"
  return 1
}

check_oracle() {
  if curl -sf --max-time 3 "${ORACLE_URL:-http://localhost:47778}/api/health" 2>/dev/null | grep -q '"oracle"'; then
    echo "✅ Oracle online"
    return 0
  fi
  echo "⚠️ Oracle offline"
  return 1
}

check_ollama() {
  if [ -n "${OLLAMA_TOKEN:-}" ] && curl -sf --max-time 5 "${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}/api/tags" -H "Authorization: Bearer ${OLLAMA_TOKEN}" 2>/dev/null | grep -q '"models"'; then
    echo "✅ Ollama available"
    return 0
  fi
  echo "⚠️ Ollama unavailable or token missing"
  return 1
}

report_checklist() {
  local done=0 issue=0
  echo "=== Jit Selfhood Checklist ==="
  echo ""

  if check_heartbeat; then done=$((done+1)); else issue=$((issue+1)); fi
  if check_autonomy; then done=$((done+1)); else issue=$((issue+1)); fi
  if check_innova_bot; then done=$((done+1)); else issue=$((issue+1)); fi
  if check_oracle; then done=$((done+1)); else issue=$((issue+1)); fi
  if check_ollama; then done=$((done+1)); else issue=$((issue+1)); fi

  echo ""
  echo "---"
  echo "Summary: $done checks passed, $issue issues found"
  echo ""
  if [ "$issue" -gt 0 ]; then
    echo "next:"
    [ ! -e "$JIT_ROOT/scripts/heartbeat.sh" ] || bash "$JIT_ROOT/scripts/heartbeat.sh" status > /dev/null 2>&1 || echo "- start heartbeat: bash scripts/heartbeat.sh start"
    bash "$JIT_ROOT/minds/agent-autonomy.sh" status > /dev/null 2>&1 || echo "- start agent autonomy: bash minds/agent-autonomy.sh start"
    [ -d "${INNOVA_BOT_PATH:-$JIT_ROOT/innova-bot}/.git" ] || echo "- provision innova-bot: bash scripts/innova-bot-setup.sh <url>"
    curl -sf --max-time 3 "${ORACLE_URL:-http://localhost:47778}/api/health" 2>/dev/null || echo "- start Oracle: export PATH=\"$HOME/.bun/bin:$PATH\" && cd /workspaces/arra-oracle-v3 && ORACLE_PORT=47778 bun run src/server.ts"
    if [ -z "${OLLAMA_TOKEN:-}" ]; then
      echo "- add Ollama token to .env"
    else
      echo "- check Ollama endpoint/token"
    fi
  fi
}

report_checklist
