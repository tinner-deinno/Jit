#!/usr/bin/env bash
# writing-plans/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
TASK="${*:-}"
[ -z "$TASK" ] && { err "ระบุ task ที่ต้องวางแผน"; exit 1; }

TODAY=$(date +%Y-%m-%d)
SLUG=$(echo "$TASK" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
PLAN_FILE="$JIT_ROOT/.planning/${TODAY}_${SLUG}.plan.md"
mkdir -p "$JIT_ROOT/.planning"

step "📝 Writing plan: $TASK"

_mdes_call() {
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'gemma4:26b','prompt':sys.stdin.read(),'stream':False}))" <<< "$1" 2>/dev/null)
  curl -sf --max-time 90 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo "(model unavailable)"
}

# Oracle context
ORACLE_CTX=""
if oracle_ready 2>/dev/null; then
  ORACLE_CTX=$(bash "$JIT_ROOT/limbs/oracle.sh" search "$TASK" 3 2>/dev/null | head -20 || true)
fi

PLAN=$(_mdes_call "คุณคือ innova Lead Developer ของ Jit multiagent system

Task: $TASK
${ORACLE_CTX:+Oracle Context: $ORACLE_CTX}

Jit Organs: mouth.sh (ส่งข้อความ), ear.sh (รับ), eye.sh (อ่านไฟล์), hand.sh (แก้ไฟล์), nose.sh (ตรวจระบบ), leg.sh (deploy), heart.sh (route), nerve.sh (broadcast)
MDES Ollama: https://ollama.mdes-innova.online (gemma4:26b)
Oracle: http://localhost:47778

สร้าง plan ใน Markdown:
## 🎯 เป้าหมาย
[ผลลัพธ์ชัดเจน]

## 📋 Phases (max 4)
### Phase 1: [ชื่อ] (~[เวลา])
- Agent: [agent]
- งาน: [ ] step1  [ ] step2

## ✅ Success Criteria
- [ ] criterion

## ⚠️ Risks & Mitigation
| Risk | แก้ไข |
|------|------|

เขียนสั้น กระชับ ทำตามได้ทันที ภาษาไทย" 90)

cat > "$PLAN_FILE" << PLANEOF
# Plan: $TASK

**Created**: $TODAY
**Status**: READY
**Oracle**: plan:$SLUG

$PLAN
PLANEOF

ok "Plan saved: $PLAN_FILE"
echo ""
cat "$PLAN_FILE"

bash "$JIT_ROOT/limbs/oracle.sh" learn "plan:$SLUG" "$PLAN" "plan,$SLUG,$(date +%Y-%m-%d)" 2>/dev/null || true
echo ""
echo "📁 File: .planning/${TODAY}_${SLUG}.plan.md"
