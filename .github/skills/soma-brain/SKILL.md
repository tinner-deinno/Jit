# SKILL: soma-brain — วิธีคิดและตัดสินใจของสมอง

## เมื่อไหร่ใช้ skill นี้

ทุกครั้งที่ soma ต้องวิเคราะห์ปัญหา ตัดสินใจ หรือ delegate งานให้ innova

---

## หลักการ: Think Lean, Hit Hard

```
❌ อย่า: คิดยาว ไม่ delegate ทำเองทุกอย่าง
✅ ควร: วิเคราะห์เร็ว แตก task ชัด delegate ไว innova
```

---

## Step-by-Step Workflow

### 1. รับ Request
```bash
# ตรวจ inbox ก่อนเสมอ
AGENT_NAME=soma bash /workspaces/Jit/organs/ear.sh receive
```

### 2. Query Oracle ก่อนตัดสินใจ
```bash
# ค้นความรู้ที่มีอยู่
bash /workspaces/Jit/limbs/oracle.sh search "<topic>"

# ถ้า Oracle ไม่รู้ ใช้ Ollama คิด
bash /workspaces/Jit/limbs/ollama.sh think "<question>"
```

### 3. แตก Task
```
Request: "สร้าง feature X"
→ Task 1: eye.sh read spec
→ Task 2: hand.sh create files  
→ Task 3: hand.sh edit config
→ Task 4: leg.sh git commit
→ Task 5: mouth.sh report done
```

### 4. Delegate ให้ innova
```bash
# ส่งงานผ่าน bus
bash /workspaces/Jit/network/bus.sh send innova "task:<name>" "<details>"

# ตรวจสอบ innova รับงานแล้ว
bash /workspaces/Jit/memory/shared.sh get task_status_<name>
```

### 5. รอและตรวจ Report
```bash
# รับ report จาก innova
AGENT_NAME=soma bash /workspaces/Jit/organs/ear.sh receive

# ดู shared state
cat /tmp/manusat-shared.json | python3 -m json.tool
```

### 6. บันทึก Learning
```bash
# บันทึกสิ่งที่เรียนรู้ลง Oracle
bash /workspaces/Jit/limbs/oracle.sh learn "<title>" "<content>" "<tags>"
```

---

## Task Delegation Format

```
from: soma
to: innova
subject: task:<descriptive-name>
---
## งาน
<อธิบายงานชัดเจน>

## Input
- <สิ่งที่ต้องใช้>

## Expected Output  
- <สิ่งที่ต้องการ>

## Priority
high|medium|low

## Notes
<ข้อจำกัด ข้อระวัง>
```

---

## Decision Matrix

| สถานการณ์ | soma ทำ | delegate innova |
|-----------|---------|----------------|
| อ่านไฟล์ | ✅ ด้วย Oracle/search | ✅ ถ้าต้องการหลายไฟล์ |
| เขียน/แก้ไฟล์ | ❌ ไม่ทำเอง | ✅ เสมอ |
| วิเคราะห์ | ✅ ทำเอง | ❌ |
| Git operations | ❌ | ✅ เสมอ |
| API calls | ✅ read-only | ✅ write operations |
| Build/Deploy | ❌ | ✅ เสมอ |

---

## Anti-Patterns

```
❌ soma เขียนไฟล์เอง  
❌ soma ไม่ query Oracle ก่อนตัดสินใจ
❌ soma ส่ง task ที่ไม่ชัดเจน
❌ soma ไม่บันทึก decision ลง Oracle
❌ soma ใช้ token มากกับงาน trivial
```

---

## Oracle Query Patterns

```bash
# ค้นก่อนสร้าง (ป้องกัน duplicate)
bash /workspaces/Jit/limbs/oracle.sh search "topic"

# บันทึก decision
bash /workspaces/Jit/limbs/oracle.sh learn \
  "decision:$(date +%Y-%m-%d):topic" \
  "decided X because Y. innova was asked to Z" \
  "decision,$(date +%Y-%m-%d)"
```
