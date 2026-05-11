#!/usr/bin/env bash
# executing-plans/run.sh
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true
PLAN_INPUT="${*:-}"
[ -z "$PLAN_INPUT" ] && { err "ระบุ plan file หรือ keyword"; exit 1; }

# หา plan file
PLAN_FILE=""
if [ -f "$PLAN_INPUT" ]; then
  PLAN_FILE="$PLAN_INPUT"
elif [ -f "$JIT_ROOT/$PLAN_INPUT" ]; then
  PLAN_FILE="$JIT_ROOT/$PLAN_INPUT"
else
  PLAN_FILE=$(ls "$JIT_ROOT/.planning/"*"${PLAN_INPUT}"*.plan.md 2>/dev/null | head -1 || true)
fi

if [ -z "$PLAN_FILE" ] || [ ! -f "$PLAN_FILE" ]; then
  warn "ไม่พบ plan file"
  echo "Plans ที่มี:"
  ls "$JIT_ROOT/.planning/"*.plan.md 2>/dev/null || echo "  (ยังไม่มี plan — ใช้ /writing-plans ก่อน)"
  exit 1
fi

step "⚡ Executing plan: $(basename $PLAN_FILE)"
echo ""
cat "$PLAN_FILE"
echo ""

# Extract tasks from plan
TASKS=$(grep -E '^\s*- \[ \]' "$PLAN_FILE" | sed 's/.*- \[ \] //')
TOTAL=$(echo "$TASKS" | grep -c . || echo 0)
DONE=0

echo "📋 Found $TOTAL tasks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

_mdes_call() {
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'gemma4:26b','prompt':sys.stdin.read(),'stream':False}))" <<< "$1" 2>/dev/null)
  curl -sf --max-time 60 "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo ""
}

while IFS= read -r TASK; do
  [ -z "$TASK" ] && continue
  echo ""
  echo "▶️ Task: $TASK"
  
  # ถาม MDES ว่า task นี้ทำอย่างไร
  EXEC_CMD=$(_mdes_call "แปลง task นี้เป็น bash command สำหรับ Jit repo:
Task: $TASK
Jit root: $JIT_ROOT
Organs: $JIT_ROOT/organs/
Limbs: $JIT_ROOT/limbs/

ตอบเฉพาะ bash command เดียว (1 บรรทัด) ที่รันได้ทันที หรือ 'MANUAL' ถ้าต้องทำเอง")
  
  if [ "$EXEC_CMD" = "MANUAL" ] || [ -z "$EXEC_CMD" ]; then
    echo "  ⏸️  Manual: $TASK"
  else
    echo "  ⚙️ Running: $EXEC_CMD"
    if bash -c "$EXEC_CMD" 2>/dev/null; then
      echo "  ✅ Done"
      DONE=$((DONE + 1))
      # Mark task as done in plan file
      sed -i "s/- \[ \] $TASK/- [x] $TASK/" "$PLAN_FILE" 2>/dev/null || true
    else
      echo "  ⚠️ Failed — marking as manual"
    fi
  fi
done <<< "$TASKS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏁 Execution: $DONE/$TOTAL tasks completed"
sed -i "s/Status: READY/Status: EXECUTED ($DONE\/$TOTAL)/" "$PLAN_FILE" 2>/dev/null || true

bash "$JIT_ROOT/limbs/oracle.sh" learn \
  "execution:$(basename $PLAN_FILE .plan.md)" \
  "Executed: $DONE/$TOTAL tasks from $(basename $PLAN_FILE)" \
  "execution,plan,result" 2>/dev/null || true

ok "Plan execution complete: $DONE/$TOTAL"
