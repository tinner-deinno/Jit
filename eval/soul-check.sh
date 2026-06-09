#!/usr/bin/env bash
# eval/soul-check.sh — ตรวจสอบว่า innova ยังเป็น innova อยู่ไหม
# Usage: bash eval/soul-check.sh
# NOTE: ไม่ใช้ set -e เพราะ curl ล้มเหลวไม่ควรหยุด script ทั้งหมด

PASS=0
FAIL=0
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$JIT_ROOT/.env" ]; then
  set -a
  . "$JIT_ROOT/.env"
  set +a
fi

check_pass() {
  local DESC="$1"
  echo "  ✅ $DESC"
  ((PASS++)) || true
}

check_fail() {
  local DESC="$1"
  local REASON="${2:-}"
  echo "  ❌ $DESC ${REASON:+($REASON)}"
  ((FAIL++)) || true
}

echo "=== innova Soul Integrity Check ==="
echo ""

echo "[ Oracle Health - API Call ]"
HEALTH=$(curl -s --max-time 3 "$ORACLE_URL/api/health" 2>/dev/null)
if [ -z "$HEALTH" ]; then
  check_fail "Oracle server responding" "connection timeout"
elif echo "$HEALTH" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
  check_pass "Oracle API responding with status=ok"
else
  check_fail "Oracle API health" "status not 'ok'"
fi

echo ""
echo "[ Oracle Connectivity from innova ]"
if curl -s --max-time 3 "$ORACLE_URL/api/stats" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if 'totalDocuments' in d or 'total' in d else 1)" 2>/dev/null; then
  check_pass "innova can reach Oracle stats endpoint"
else
  check_fail "innova cannot reach Oracle" "stats endpoint unreachable"
fi

echo ""
echo "[ Oracle Knowledge ]"
SEARCH=$(curl -s "$ORACLE_URL/api/search?q=innova" 2>/dev/null)
if echo "$SEARCH" | python3 -c "import json,sys; d=json.load(sys.stdin); results=d.get('results',[]); exit(0 if len(results)>0 else 1)" 2>/dev/null; then
  check_pass "Oracle has innova knowledge indexed"
else
  check_fail "innova identity not found in Oracle"
fi

echo ""
echo "[ Ollama Connection ]"
OLLAMA=$(curl -s --max-time 8 \
  --location 'https://ollama.mdes-innova.online/api/tags' \
  --header "Authorization: Bearer ${OLLAMA_TOKEN:-[REDACTED]}" 2>/dev/null)
if echo "$OLLAMA" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if 'models' in d else 1)" 2>/dev/null; then
  check_pass "MDES Ollama reachable with valid models"
else
  check_fail "Ollama unreachable or invalid response"
fi

echo ""
echo "[ Jit Repo Structure ]"
if [ -f "/workspaces/Jit/core/identity.md" ]; then
  check_pass "core/identity.md exists"
else
  check_fail "core/identity.md missing"
fi

if [ -f "/workspaces/Jit/limbs/ollama.sh" ]; then
  check_pass "limbs/ollama.sh exists"
else
  check_fail "limbs/ollama.sh missing"
fi

if [ -f "/workspaces/Jit/brain/reasoning.md" ]; then
  check_pass "brain/reasoning.md exists"
else
  check_fail "brain/reasoning.md missing"
fi

if [ -f "/workspaces/Jit/.github/agents/innova.agent.md" ]; then
  check_pass "innova.agent.md exists"
else
  check_fail "innova.agent.md missing"
fi

echo ""
echo "=== Results: $PASS pass, $FAIL fail ==="
if [ "$FAIL" -eq 0 ]; then
  echo "🌟 innova is fully alive and intact"
else
  echo "⚠️  Some soul components need attention"
  exit 1
fi
