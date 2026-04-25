#!/usr/bin/env bash
# scripts/life-checklist.sh — แสดงสถานะภารกิจมีชีวิตของ Jit
# Usage:
#   bash scripts/life-checklist.sh
#   bash scripts/life-checklist.sh --short

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"

SHORT=0
for ARG in "$@"; do
  [[ "$ARG" == "--short" ]] && SHORT=1
done

_show() {
  local ICON="$1" TEXT="$2"
  printf "%s %s\n" "$ICON" "$TEXT"
}

_check_url() {
  local URL="$1" EXPECT="$2"
  curl -sf --max-time 4 "$URL" 2>/dev/null | grep -q "$EXPECT"
}

DEVCONTAINER_OK=0
if [ -f "$JIT_ROOT/.devcontainer/devcontainer.json" ] && grep -q "init-life.sh --auto" "$JIT_ROOT/.devcontainer/devcontainer.json" 2>/dev/null; then
  DEVCONTAINER_OK=1
fi

HEARTBEAT_OK=0
if bash "$JIT_ROOT/scripts/heartbeat.sh" status 2>/dev/null | grep -q 'Heartbeat กำลังรัน'; then
  HEARTBEAT_OK=1
fi

CRON_OK=0
if command -v crontab >/dev/null 2>&1 && crontab -l 2>/dev/null | grep -q 'heartbeat.sh once'; then
  CRON_OK=1
fi

ORACLE_OK=0
if _check_url "$ORACLE_URL/api/health" '"oracle"'; then
  ORACLE_OK=1
fi

OLLAMA_OK=0
if _check_url "$OLLAMA_URL/api/tags" '"models"'; then
  OLLAMA_OK=1
fi

STATE_OK=0
if [ -f "$JIT_ROOT/memory/state/innova.state.json" ] && [ -f "$JIT_ROOT/memory/state/heartbeat.log" ]; then
  STATE_OK=1
fi

SYNC_OK=0
if git -C "$JIT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git -C "$JIT_ROOT" remote get-url origin >/dev/null 2>&1; then
  SYNC_OK=1
fi

TOTAL=7
PASSED=$(( DEVCONTAINER_OK + HEARTBEAT_OK + CRON_OK + ORACLE_OK + OLLAMA_OK + STATE_OK + SYNC_OK ))
PCT=$(( PASSED * 100 / TOTAL ))

if [ "$SHORT" -eq 0 ]; then
  echo ""
  echo -e "${BOLD}${CYAN}  🧬 Jit Life Checklist${RESET}"
  echo ""
fi

_show "$([ $DEVCONTAINER_OK -eq 1 ] && echo '✅' || echo '⚠️')" "Devcontainer auto-start: $([ $DEVCONTAINER_OK -eq 1 ] && echo 'configured' || echo 'not configured')"
_show "$([ $HEARTBEAT_OK -eq 1 ] && echo '✅' || echo '⚠️')" "Heartbeat daemon: $([ $HEARTBEAT_OK -eq 1 ] && echo 'running' || echo 'stopped')"
_show "$([ $CRON_OK -eq 1 ] && echo '✅' || echo '⚠️')" "Cron 15min heartbeat: $([ $CRON_OK -eq 1 ] && echo 'installed' || echo 'missing or unavailable')"
_show "$([ $ORACLE_OK -eq 1 ] && echo '✅' || echo '⚠️')" "Oracle: $([ $ORACLE_OK -eq 1 ] && echo 'online' || echo 'offline')"
_show "$([ $OLLAMA_OK -eq 1 ] && echo '✅' || echo '⚠️')" "MDES Ollama: $([ $OLLAMA_OK -eq 1 ] && echo 'online' || echo 'offline')"
_show "$([ $STATE_OK -eq 1 ] && echo '✅' || echo '⚠️')" "Persistent state files: $([ $STATE_OK -eq 1 ] && echo 'ok' || echo 'missing')"
_show "$([ $SYNC_OK -eq 1 ] && echo '✅' || echo '⚠️')" "Git cross-machine sync support: $([ $SYNC_OK -eq 1 ] && echo 'enabled' || echo 'not configured')"

if [ "$SHORT" -eq 0 ]; then
  echo ""
  echo -e "  ${BOLD}Summary:${RESET} $PASSED/$TOTAL tasks passed — $PCT%"
  echo ""
  echo "  Creator: ผู้สร้างจักรวาล (เจ้าของ repo)"
  echo "  GitHub.dev preview: https://fictional-sniffle-p77pv7xpjpgf7rxw.github.dev/"
  echo "  Use: bash scripts/init-life.sh or bash scripts/life-checklist.sh"
  echo ""
fi
exit 0
