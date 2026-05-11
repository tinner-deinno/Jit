---
name: writing-plans
description: "เขียน plan ที่ชัดเจนและ actionable จาก idea หรือ requirement — ใช้ gemma4:26b วิเคราะห์ context แล้วสร้าง plan ที่ Jit agents ทำตามได้ทันที พร้อม milestones, risks, และ organ assignments. Triggers: write plan, วางแผน, สร้าง plan, make a plan, planning, draft plan"
argument-hint: "สิ่งที่ต้องการวางแผน เช่น 'deploy voice API ให้ karn', 'implement Chrome DevTools bridge'"
---

# SKILL: writing-plans — เขียน Plan ที่ Jit Agents ทำตามได้ 📝

**gemma4:26b สร้าง structured plan พร้อม organ assignments และ Oracle context**

## เมื่อไหร่ใช้ skill นี้

- ได้รับ task ใหม่ที่ต้องแบ่งเป็น steps ชัดเจน
- ต้องการ plan ที่ระบุว่า agent/organ ไหนทำอะไร
- ใช้หลัง `/brainstorming` เพื่อ convert ไอเดียเป็น actionable steps
- ใช้ก่อน `/executing-plans` เสมอ

---

## Plan Document Structure

```
.planning/
└── <date>_<slug>.plan.md
```

---

## Workflow

### Step 1 — รวบรวม Context

```bash
TASK="$1"

# อ่าน codebase context
bash organs/eye.sh read README.md 2>/dev/null | head -50
bash organs/nose.sh sniff 2>/dev/null  # ตรวจสถานะระบบ

# ค้น Oracle — มี plan คล้ายๆ กันมาก่อนหรือไม่?
bash limbs/oracle.sh search "plan:$TASK" 3
bash limbs/oracle.sh search "$TASK" 5
```

### Step 2 — สร้าง Plan ด้วย gemma4:26b

```bash
# อ่าน team structure
REGISTRY=$(cat network/registry.json | python3 -c "
import json,sys
r=json.load(sys.stdin)
agents=[f\"{a['name']} ({a.get('role','')})\" for a in r.get('agents',[])]
print('\n'.join(agents))
")

PLAN=$(bash limbs/ollama-chain.sh call gemma4:26b "
คุณคือ innova Lead Developer ของ Jit multiagent system

TASK: $TASK

Available Agents:
$REGISTRY

Available Organs (bash scripts ใน /workspaces/Jit/organs/):
- mouth.sh (ส่ง message), ear.sh (รับ message)
- eye.sh (อ่านไฟล์), hand.sh (แก้ไขไฟล์)
- nose.sh (ตรวจระบบ), heart.sh (route tasks)
- leg.sh (deploy/navigate), nerve.sh (broadcast events)

MDES Ollama: https://ollama.mdes-innova.online (gemma4:26b)
Oracle: http://localhost:47778

สร้าง plan ในรูปแบบ Markdown:
1. 🎯 **เป้าหมาย** — ผลลัพธ์ที่ต้องการ
2. 📋 **Phases** — แบ่งงานเป็น phases ชัดเจน (สูงสุด 4)
   - แต่ละ phase: ชื่อ, description, agent/organ รับผิดชอบ, estimated time
3. ✅ **Success Criteria** — วัดผลได้อย่างไร
4. ⚠️ **Risks** — ความเสี่ยงและวิธีรับมือ
5. 🔗 **Dependencies** — ต้องทำอะไรก่อน
6. 📦 **Deliverables** — output ที่จะได้รับ

เขียนเป็นภาษาไทย กระชับ ทำตามได้ทันที
")
```

### Step 3 — Validate Plan

```bash
VALIDATION=$(bash limbs/ollama-chain.sh call qwen3.5:27b "
ตรวจสอบ plan นี้:

$PLAN

ตรวจ:
1. ✅/❌ phases ชัดเจน ทำตามได้จริงหรือไม่
2. ✅/❌ agent assignments สมเหตุสมผลหรือไม่
3. ✅/❌ มี success criteria วัดได้หรือไม่
4. ✅/❌ risks ครบถ้วนหรือไม่
5. ❌ อะไรที่ขาดหายไป?

ถ้ามีปัญหาให้ระบุ ถ้า OK บอกว่า APPROVED
")

echo "🔍 Validation: $VALIDATION"
```

### Step 4 — บันทึก Plan

```bash
TODAY=$(date +%Y-%m-%d)
SLUG=$(echo "$TASK" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
PLAN_FILE=".planning/${TODAY}_${SLUG}.plan.md"

mkdir -p .planning
bash organs/hand.sh create "$PLAN_FILE" "# Plan: $TASK

**Created**: $TODAY  
**Agent**: innova  
**Status**: READY  

$PLAN

---
*Validation: $VALIDATION*
*Oracle ref: plan:$SLUG*
"

# บันทึก Oracle
bash limbs/oracle.sh learn \
  "plan:$SLUG" \
  "$PLAN" \
  "plan,$SLUG,task,jit"

echo "✅ Plan saved: $PLAN_FILE"
```

### Step 5 — แจ้ง Team

```bash
bash organs/nerve.sh signal "plan:ready" "$TASK"
bash organs/mouth.sh tell soma "task:plan-review" "Plan ready: $TASK → $PLAN_FILE"
```

---

## Plan Output Format

```markdown
# Plan: [Task Name]

**Created**: YYYY-MM-DD  
**Agent**: innova  
**Status**: READY  

## 🎯 เป้าหมาย
[ผลลัพธ์ที่ต้องการ]

## 📋 Phases

### Phase 1: [ชื่อ] (เวลา: X ชั่วโมง)
- **Agent**: innova / lak
- **Organ**: hand.sh, leg.sh
- งาน:
  - [ ] task 1
  - [ ] task 2

### Phase 2: [ชื่อ] ...

## ✅ Success Criteria
- [ ] criterion 1
- [ ] criterion 2

## ⚠️ Risks
| Risk | Mitigation |
|------|-----------|
| ... | ... |

## 🔗 Dependencies
- prereq 1
```

---

## Integration กับ Jit Workflow

```
brainstorming → writing-plans → executing-plans
     ↓               ↓               ↓
  Oracle           .planning/       organs/
  (ไอเดีย)         (plan files)    (execution)
```

---

## ตัวอย่าง

```bash
# วางแผน deploy karn voice API
bash .github/skills/writing-plans/run.sh "deploy karn voice API ให้ใช้งานได้จาก Discord"

# ผลลัพธ์: .planning/2026-05-12_deploy-karn-voice-api.plan.md
```
