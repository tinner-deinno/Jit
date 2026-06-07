#!/usr/bin/env bash
# limbs/lib.sh — ห้องสมุดกลาง: shared utilities สำหรับทุก limb
# Source ไฟล์นี้ก่อนใช้ limb ใดๆ: source "$(dirname "$0")/lib.sh"

# ─── สี & สัญลักษณ์ ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}✅${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠️ ${RESET} $*"; }
err()  { echo -e "${RED}❌${RESET} $*" >&2; }
info() { echo -e "${CYAN}ℹ️ ${RESET} $*"; }
step() { echo -e "${BOLD}→${RESET} $*"; }

# ─── Configuration ──────────────────────────────────────────────────
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e4b}"

# Detect JIT_ROOT dynamically if not set or if it's the default placeholder
if [ -z "$JIT_ROOT" ] || [ "$JIT_ROOT" == "/workspaces/Jit" ]; then
  JIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "/workspaces/Jit")
fi
ORACLE_ROOT="${ORACLE_ROOT:-/workspaces/arra-oracle-v3}"

# ─── Path normalization ───────────────────────────────────────────────
# รองรับ path จาก Windows/WSL เช่น C:\Users\name\repo → /mnt/c/Users/name/repo
normalize_host_path() {
  local RAW="${1:-}"
  [ -z "$RAW" ] && return 0

  RAW="${RAW%\"}"
  RAW="${RAW#\"}"

  if [[ "$RAW" == ~/* ]]; then
    printf '%s/%s' "$HOME" "${RAW#~/}"
    return 0
  fi

  if [[ "$RAW" =~ ^[A-Za-z]:\\ ]]; then
    local RAW_FIXED="${RAW//\\//}"
    printf '%s' "$RAW_FIXED"
    return 0
  fi

  printf '%s' "$RAW"
}

resolve_innova_bot_path() {
  normalize_host_path "${INNOVA_BOT_PATH:-$JIT_ROOT/innova-bot}"
}

# ─── สติ: log ทุกการกระทำ (mindfulness journal) ────────────────────
JIT_LOG="${JIT_LOG:-/tmp/innova-actions.log}"
log_action() {
  local VERB="$1" DESC="$2"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$VERB] $DESC" >> "$JIT_LOG"
}

# auto-write SESSION_START เมื่อ lib.sh ถูก source ครั้งแรกในแต่ละ session
_LIB_MARKER="/tmp/innova-lib-session.$(date '+%Y%m%d')"
if [ ! -f "$_LIB_MARKER" ]; then
  touch "$_LIB_MARKER"
  log_action "SESSION_START" "innova awake — $(date '+%Y-%m-%dT%H:%M:%S') host=$(hostname)"
fi
unset _LIB_MARKER

# ─── ตรวจสอบ Oracle พร้อมหรือไม่ ─────────────────────────────────
oracle_ready() {
  curl -sf "$ORACLE_URL/api/health" | node -e "
    try {
      const d = JSON.parse(require('fs').readFileSync(0, 'utf8'));
      process.exit(d.oracle === 'connected' ? 0 : 1);
    } catch(e) { process.exit(1); }
  " 2>/dev/null
}

# ─── Oracle: บันทึกการเรียนรู้ ──────────────────────────────────────
oracle_learn() {
  local PATTERN="$1" CONTENT="$2" CONCEPTS="${3:-general}" TYPE="${4:-learning}"
  local JSON_DATA=$(node -e "
    const [p, c, co, t] = process.argv.slice(1);
    process.stdout.write(JSON.stringify({
      pattern: p, content: c, type: t,
      concepts: co.split(','),
      origin: 'innova-limbs'
    }));
  " "$PATTERN" "$CONTENT" "$CONCEPTS" "$TYPE")
  local ID=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d "$JSON_DATA" "$ORACLE_URL/api/learn" | node -e "
    try {
      const d = JSON.parse(require('fs').readFileSync(0, 'utf8'));
      process.stdout.write(d.id || 'error');
    } catch(e) { process.stdout.write('error'); }
  " 2>/dev/null)
  echo "$ID"
}

# ─── Oracle: ค้นหาความรู้ ───────────────────────────────────────────
oracle_search() {
  local QUERY="$1" LIMIT="${2:-3}"
  local QUERY_ENC=$(node -e "process.stdout.write(encodeURIComponent(process.argv[1]))" "$QUERY")
  curl -s "$ORACLE_URL/api/search?q=$QUERY_ENC" | node -e "
    try {
      const d = JSON.parse(require('fs').readFileSync(0, 'utf8'));
      const results = d.results || [];
      const limit = parseInt(process.argv[1]) || 3;
      results.slice(0, limit).forEach(r => {
        process.stdout.write('  [' + r.type + '] ' + r.id + '\n');
        process.stdout.write('    ' + r.content.slice(0, 120).replace(/\n/g, ' ') + '...\n');
      });
      if (results.length === 0) process.stdout.write('(ไม่พบข้อมูลใน Oracle)\n');
    } catch(e) { process.stdout.write('  (Oracle ไม่พร้อม)\n'); }
  " "$LIMIT" 2>/dev/null
}

# ─── JSON encode ────────────────────────────────────────────────────
json_str() {
  node -e "process.stdout.write(JSON.stringify(process.argv[1]))" "$1"
}
