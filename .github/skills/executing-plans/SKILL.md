---
name: executing-plans
description: "ลงมือทำตาม plan ที่วางไว้โดย route แต่ละ phase ให้ organs/agents ที่เหมาะสม — ติดตาม progress, handle errors, รายงานผ่าน bus. Triggers: execute plan, ลงมือทำ, run plan, start executing, ทำตามแผน, start plan"
argument-hint: "path ของ plan file หรือชื่อ task เช่น '.planning/2026-05-12_deploy-karn.plan.md'"
---

# SKILL: executing-plans — ลงมือทำ Plan ผ่าน Jit Organs ⚡

**heart.sh routes งานให้ organs ที่ถูกต้อง พร้อม progress tracking และ error recovery**

## เมื่อไหร่ใช้ skill นี้

- มี `.plan.md` จาก `/writing-plans` แล้ว พร้อมเริ่มทำงาน
- ต้องการ execute tasks โดยใช้ organs อัตโนมัติ
- ต้องการ track progress และ report กลับมา
- ใช้หลัง `/writing-plans` เสมอ

---

## Organ-to-Task Routing

| Task Type | Organ | คำสั่ง |
|-----------|-------|-------|
| เขียน/แก้ไฟล์ | `hand.sh` | `bash organs/hand.sh create/edit <path>` |
| อ่านไฟล์/observe | `eye.sh` | `bash organs/eye.sh read <path>` |
| รัน command/deploy | `leg.sh` | `bash organs/leg.sh run <cmd>` |
| ตรวจสุขภาพระบบ | `nose.sh` | `bash organs/nose.sh sniff` |
| ส่ง report/message | `mouth.sh` | `bash organs/mouth.sh tell <agent> <msg>` |
| Broadcast alerts | `nerve.sh` | `bash organs/nerve.sh signal <event>` |
| Route complex task | `heart.sh` | `bash organs/heart.sh pump task:<type>` |

---

## Workflow

### Step 1 — โหลด Plan

```bash
PLAN_INPUT="$1"

# ถ้าเป็น path ให้อ่านไฟล์
if [ -f "$PLAN_INPUT" ]; then
  PLAN_CONTENT=$(cat "$PLAN_INPUT")
  PLAN_FILE="$PLAN_INPUT"
else
  # ค้นหา plan file ที่ match
  PLAN_FILE=$(ls .planning/*${PLAN_INPUT}*.plan.md 2>/dev/null | head -1)
  PLAN_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null)
fi

if [ -z "$PLAN_CONTENT" ]; then
  echo "❌ ไม่พบ plan: $PLAN_INPUT"
  echo "   ใช้ /writing-plans ก่อนเพื่อสร้าง plan"
  exit 1
fi

echo "📋 Loading plan: $PLAN_FILE"
```

### Step 2 — Parse Phases

```bash
# ใช้ gemma4:26b แยก phases เป็น executable steps
EXECUTION_STEPS=$(bash limbs/ollama-chain.sh call gemma4:26b "
Parse plan นี้แล้วแสดง execution steps:

$PLAN_CONTENT

สำหรับแต่ละ phase ระบุ:
1. ชื่อ phase
2. bash commands ที่ต้องรัน (จาก /workspaces/Jit/ organs/ และ limbs/)
3. organ ที่รับผิดชอบ
4. success check command

ตอบเป็น JSON array:
[
  {
    \"phase\": \"Phase 1: name\",
    \"organ\": \"hand.sh\",
    \"commands\": [\"bash organs/hand.sh ...\"],
    \"check\": \"command to verify success\"
  }
]
")
```

### Step 3 — Execute Each Phase

```bash
PHASE_NUM=0
FAILED_PHASES=()

for PHASE in $(echo "$EXECUTION_STEPS" | python3 -c "
import json,sys
phases=json.load(sys.stdin)
for i,p in enumerate(phases):
  print(f'{i}:{p[\"phase\"][:40]}')
"); do
  PHASE_NUM=$((PHASE_NUM + 1))
  PHASE_NAME=$(echo "$PHASE" | cut -d: -f2-)
  
  echo ""
  echo "▶️ Phase $PHASE_NUM: $PHASE_NAME"
  echo "─────────────────────────────"
  
  # Update status ใน shared memory
  bash memory/shared.sh set "executing_phase" "$PHASE_NAME"
  bash memory/shared.sh set "last_heartbeat" "$(date -Iseconds)"
  
  # Execute commands
  PHASE_CMDS=$(echo "$EXECUTION_STEPS" | python3 -c "
import json,sys
phases=json.load(sys.stdin)
p=phases[$((PHASE_NUM-1))]
print('\n'.join(p.get('commands',[])))
" 2>/dev/null)
  
  while IFS= read -r CMD; do
    [ -z "$CMD" ] && continue
    echo "  ⚙️ $CMD"
    
    if eval "$CMD"; then
      echo "  ✅ สำเร็จ"
    else
      echo "  ❌ ล้มเหลว: $CMD"
      FAILED_PHASES+=("Phase $PHASE_NUM: $CMD")
      
      # ถาม MDES ว่าจะ recover อย่างไร
      RECOVERY=$(bash limbs/ollama-chain.sh call gemma4:26b "
Command นี้ล้มเหลวใน Jit system:
$CMD

Context: $PLAN_CONTENT (phase $PHASE_NUM)

เสนอ recovery steps 2-3 ขั้นตอน (bash commands จาก Jit repo):
")
      echo "  💡 Recovery suggestion: $RECOVERY"
    fi
  done <<< "$PHASE_CMDS"
  
  bash organs/nerve.sh signal "phase:complete" "Phase $PHASE_NUM: $PHASE_NAME" 2>/dev/null
done
```

### Step 4 — Verify + Report

```bash
TOTAL=$PHASE_NUM
FAILED=${#FAILED_PHASES[@]}
SUCCESS=$((TOTAL - FAILED))

STATUS_MSG="✅ $SUCCESS/$TOTAL phases สำเร็จ"
[ $FAILED -gt 0 ] && STATUS_MSG="$STATUS_MSG | ❌ $FAILED phases ล้มเหลว"

# ตรวจสอบ success criteria
bash organs/nose.sh sniff 2>/dev/null

# Learn จาก execution
bash limbs/oracle.sh learn \
  "execution:$(basename $PLAN_FILE .plan.md)" \
  "Plan executed: $STATUS_MSG\nFailed: ${FAILED_PHASES[*]}" \
  "execution,plan,result"

# รายงานผ่าน bus
bash organs/mouth.sh tell innova "report:plan-executed" "$STATUS_MSG"
bash organs/mouth.sh tell vaja "task:notify-user" "Plan execution complete: $STATUS_MSG"

# อัปเดต plan file
sed -i "s/Status: READY/Status: EXECUTED ($STATUS_MSG)/" "$PLAN_FILE" 2>/dev/null

echo ""
echo "═══════════════════════════"
echo "🏁 EXECUTION COMPLETE"
echo "$STATUS_MSG"
[ ${#FAILED_PHASES[@]} -gt 0 ] && printf "   Failed: %s\n" "${FAILED_PHASES[@]}"
echo "═══════════════════════════"
```

---

## Error Recovery Pattern

เมื่อ phase ล้มเหลว:
1. บันทึก error ลง Oracle
2. ถาม `gemma4:26b` หา recovery path
3. retry ถ้า recovery มี commands ที่ชัดเจน
4. ถ้า retry ล้มเหลว → แจ้ง `innova` ผ่าน `mouth.sh`

---

## Progress Tracking

```bash
# ดู execution status ปัจจุบัน
bash memory/shared.sh get "executing_phase"

# ดู phase history
bash limbs/oracle.sh search "execution:" 5
```

---

## Integration

```
writing-plans → executing-plans → verify
     ↓               ↓
  .plan.md      organs execute     Oracle learns
```

---

## ตัวอย่าง

```bash
# Execute plan ที่เขียนไว้
bash .github/skills/executing-plans/run.sh \
  ".planning/2026-05-12_deploy-karn-voice-api.plan.md"

# หรือใช้ keyword
bash .github/skills/executing-plans/run.sh "karn voice"
```
