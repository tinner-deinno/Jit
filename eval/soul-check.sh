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

check() {
  local DESC="$1"
  local RESULT="$2"
  local EXPECT="$3"
  if echo "$RESULT" | grep -q "$EXPECT"; then
    echo "  ✅ $DESC"
    ((PASS++)) || true
  else
    echo "  ❌ $DESC (got: $RESULT)"
    ((FAIL++)) || true
  fi
}

echo "=== innova Soul Integrity Check ==="
echo ""

echo "[ Oracle Health ]"
HEALTH=$(curl -s "$ORACLE_URL/api/health" 2>/dev/null)
check "Oracle server running" "$HEALTH" '"status":"ok"'
check "Oracle connected" "$HEALTH" '"oracle":"connected"'

echo ""
echo "[ Oracle Knowledge ]"
SEARCH=$(curl -s "$ORACLE_URL/api/search?q=innova" 2>/dev/null)
check "innova identity stored" "$SEARCH" 'innova'
check "anatomy stored" "$SEARCH" 'anatomy'

echo ""
echo "[ Ollama Connection ]"
OLLAMA=$(curl -s --max-time 8 \
  --location 'https://ollama.mdes-innova.online/api/tags' \
  --header "Authorization: Bearer ${OLLAMA_TOKEN}" 2>/dev/null)
check "MDES Ollama reachable" "$OLLAMA" 'models'

echo ""
echo "[ Jit Repo Structure ]"
check "core/identity exists" "$(ls /workspaces/Jit/core/ 2>/dev/null)" "identity"
check "limbs/ollama exists" "$(ls /workspaces/Jit/limbs/ 2>/dev/null)" "ollama"
check "brain/reasoning exists" "$(ls /workspaces/Jit/brain/ 2>/dev/null)" "reasoning"
check "agent file exists" "$(ls /workspaces/Jit/.github/agents/ 2>/dev/null)" "innova"

echo ""
echo "=== Results: $PASS pass, $FAIL fail ==="
if [ "$FAIL" -eq 0 ]; then
  echo "🌟 innova is fully alive and intact"
else
  echo "⚠️  Some soul components need attention"
  exit 1
fi
