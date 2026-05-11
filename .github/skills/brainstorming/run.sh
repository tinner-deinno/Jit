#!/usr/bin/env bash
# brainstorming/run.sh — Quick runner
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
TOPIC="${*:-กลยุทธ์การพัฒนา Jit multiagent}"
step "🧠 Brainstorming: $TOPIC"

# ค้น Oracle ก่อน
ORACLE_CTX=""
if oracle_ready 2>/dev/null; then
  ORACLE_CTX=$(bash "$JIT_ROOT/limbs/oracle.sh" search "$TOPIC" 3 2>/dev/null || true)
  [ -n "$ORACLE_CTX" ] && info "Oracle context found"
fi

# สร้าง parallel perspective prompts
_mdes_call() {
  local MODEL="$1" PROMPT="$2" TIMEOUT="${3:-60}"
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.stdin.read(),'stream':False}))" <<< "$PROMPT" 2>/dev/null)
  curl -sf --max-time "$TIMEOUT" "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "(model unavailable)"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧠 BRAINSTORM: $TOPIC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 3-perspective analysis using gemma4:26b (most reliable)
COMBINED=$(_mdes_call "gemma4:26b" "คุณคือทีมผู้เชี่ยวชาญ 3 คน วิเคราะห์หัวข้อนี้จาก 3 มุมมอง:
หัวข้อ: $TOPIC
${ORACLE_CTX:+Context: $ORACLE_CTX}

**🎨 มุมมองสร้างสรรค์** (Creative): ให้ 3-5 ไอเดียแปลกใหม่
**🔍 มุมมองวิจารณ์** (Critical): ระบุ risks และ challenges หลัก 3 ข้อ  
**♟️ มุมมองเทคนิค** (Strategic): เสนอ approach ที่ทำได้จริงใน Jit repo

สรุปท้าย:
**🎯 Top 3 Action Items** (เรียงตาม impact สูงสุด)
ตอบเป็นภาษาไทย" 90)

echo "$COMBINED"

# บันทึก Oracle
SLUG=$(echo "$TOPIC" | tr ' ' '-' | cut -c1-40)
bash "$JIT_ROOT/limbs/oracle.sh" learn "brainstorm:$SLUG" "$COMBINED" "brainstorm,$SLUG" 2>/dev/null || true

echo ""
ok "Brainstorm complete — Oracle: brainstorm:$SLUG"
