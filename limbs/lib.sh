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
OLLAMA_TOKEN="${OLLAMA_TOKEN:-9e34679b9d60d8b984005ec46508579c}"
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:26b}"
JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
ORACLE_ROOT="${ORACLE_ROOT:-/workspaces/arra-oracle-v3}"

# ─── สติ: log ทุกการกระทำ (mindfulness journal) ────────────────────
JIT_LOG="${JIT_LOG:-/tmp/innova-actions.log}"
log_action() {
  local VERB="$1" DESC="$2"
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$VERB] $DESC" >> "$JIT_LOG"
}

# ─── ตรวจสอบ Oracle พร้อมหรือไม่ ─────────────────────────────────
oracle_ready() {
  curl -sf "$ORACLE_URL/api/health" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('oracle')=='connected' else 1)" 2>/dev/null
}

# ─── Oracle: บันทึกการเรียนรู้ ──────────────────────────────────────
oracle_learn() {
  local PATTERN="$1" CONTENT="$2" CONCEPTS="${3:-general}" TYPE="${4:-learning}"
  python3 -c "
import json,sys,urllib.request
data = json.dumps({
  'pattern': sys.argv[1],
  'content': sys.argv[2],
  'type': sys.argv[4],
  'concepts': sys.argv[3].split(','),
  'origin': 'innova-limbs'
}).encode()
req = urllib.request.Request('$ORACLE_URL/api/learn',
  data=data, headers={'Content-Type':'application/json'}, method='POST')
with urllib.request.urlopen(req, timeout=10) as r:
  d = json.load(r)
  print(d.get('id','error'))
" "$PATTERN" "$CONTENT" "$CONCEPTS" "$TYPE" 2>/dev/null
}

# ─── Oracle: ค้นหาความรู้ ───────────────────────────────────────────
oracle_search() {
  local QUERY="$1" LIMIT="${2:-3}"
  python3 -c "
import json,sys,urllib.request,urllib.parse
q = urllib.parse.quote(sys.argv[1])
with urllib.request.urlopen('$ORACLE_URL/api/search?q='+q, timeout=5) as r:
  d = json.load(r)
results = d.get('results',[])[:int(sys.argv[2])]
if not results:
  print('(ไม่พบข้อมูลใน Oracle)')
  sys.exit(0)
for r in results:
  print(f\"  [{r['type']}] {r['id']}\")
  c = r.get('content','')[:120].replace(chr(10),' ')
  print(f'    {c}...')
" "$QUERY" "$LIMIT" 2>/dev/null || echo "  (Oracle ไม่พร้อม)"
}

# ─── JSON encode ────────────────────────────────────────────────────
json_str() {
  python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1"
}
