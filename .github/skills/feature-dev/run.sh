#!/usr/bin/env bash
# feature-dev/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
FEATURE="${*:-}"
[ -z "$FEATURE" ] && { err "ระบุ feature description"; exit 1; }

step "🚀 Feature Dev: $FEATURE"

_mdes_call() {
  local MODEL="$1" PROMPT="$2" TIMEOUT="${3:-90}"
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.stdin.read(),'stream':False}))" <<< "$PROMPT" 2>/dev/null)
  curl -sf --max-time "$TIMEOUT" "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "(unavailable)"
}

SLUG=$(echo "$FEATURE" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
TODAY=$(date +%Y-%m-%d)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Phase 1: Define"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Oracle context
ORACLE_CTX=$(bash "$JIT_ROOT/limbs/oracle.sh" search "$FEATURE" 3 2>/dev/null | head -20 || true)

SPEC=$(_mdes_call "gemma4:26b" "คุณคือ jit orchestrator

Feature: $FEATURE
${ORACLE_CTX:+Oracle: $ORACLE_CTX}

กำหนด Feature Spec:
1. What — ทำอะไร
2. Where — files ที่ต้องแก้ไข (Jit repo structure)
3. Acceptance Criteria — 3-5 criteria
4. Complexity — S/M/L
5. Organs ที่ต้องใช้

สั้น กระชับ ภาษาไทย")

echo "$SPEC"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💻 Phase 2: Implementation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

IMPL=$(_mdes_call "qwen2.5-coder:32b" "คุณคือ innova Lead Developer

Feature: $FEATURE
Spec: $SPEC

Repository: Jit multiagent system
- CommonJS (require, not import)
- Organs: $JIT_ROOT/organs/
- Limbs: $JIT_ROOT/limbs/
- MDES Ollama: https://ollama.mdes-innova.online (gemma4:26b)
- Oracle: http://localhost:47778

สร้าง implementation:
1. Code ที่สมบูรณ์ (ไฟล์หลัก)
2. Integration กับ bot.js (case handler)
3. Comments ภาษาไทย

ห้ามใช้ ES modules, ใช้ require() เท่านั้น" 120)

echo "$IMPL"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Phase 3: Review"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

REVIEW=$(_mdes_call "qwen3.5:27b" "Review feature implementation:

$IMPL

ตรวจ:
1. Security (token exposure, path traversal)
2. Error handling
3. CommonJS compatibility
4. Jit organ usage ถูกต้อง

คะแนน: APPROVED / NEEDS CHANGES (พร้อม details)")

echo "$REVIEW"

# บันทึก Oracle
bash "$JIT_ROOT/limbs/oracle.sh" learn \
  "feature:$SLUG" \
  "Feature: $FEATURE\nSpec: $SPEC\nImpl: ${IMPL:0:1000}\nReview: $REVIEW" \
  "feature,$SLUG,$TODAY" 2>/dev/null || true

# Notify agents
bash "$JIT_ROOT/organs/nerve.sh" signal "feature:ready" "$FEATURE" 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Feature dev complete: $FEATURE"
echo "   Oracle: feature:$SLUG"
echo "   Review: $(echo "$REVIEW" | head -1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
