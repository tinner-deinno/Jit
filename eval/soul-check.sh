#!/usr/bin/env bash
# eval/soul-check.sh — ตรวจสอบว่า innova ยังเป็น innova อยู่ไหม
# Usage: bash eval/soul-check.sh

set -e
PASS=0
FAIL=0
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"

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
OLLAMA=$(curl -s --max-time 10 \
  --location 'https://ollama.mdes-innova.online/api/generate' \
  --header 'Authorization: Bearer 9e34679b9d60d8b984005ec46508579c' \
  --header 'Content-Type: application/json' \
  --data '{"model":"gemma4:26b","prompt":"reply only: ALIVE","stream":false}' 2>/dev/null)
check "MDES Ollama reachable" "$OLLAMA" 'response'

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
