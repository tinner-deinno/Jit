---
name: skill-creator
description: "สร้าง SKILL.md ใหม่สำหรับ Jit ด้วย sub-agent qwen2.5-coder:32b — วิเคราะห์ requirement, ออกแบบ workflow ที่ integrate กับ MDES Ollama + Oracle + organs, สร้างไฟล์ทดสอบ และ register ในระบบ. Triggers: create skill, สร้าง skill, new skill, add skill, ขอ skill ใหม่"
argument-hint: "ชื่อ skill + คำอธิบาย เช่น 'weather-check — เช็คสภาพอากาศแล้วรายงานผ่าน Discord'"
---

# SKILL: skill-creator — สร้าง Jit Skill ด้วย AI Agent 🛠️

**ใช้ `qwen2.5-coder:32b` เป็น master builder สร้าง SKILL.md ที่สมบูรณ์ ทดสอบได้จริง**

## เมื่อไหร่ใช้ skill นี้

- ต้องการสร้าง skill ใหม่สำหรับ Jit agents
- ต้องการ automate pattern ที่ทำซ้ำๆ ให้กลายเป็น reusable skill
- ต้องการ skill ที่ integrate กับ MDES Ollama อย่างถูกต้อง
- ต้องการ skill ที่รองรับ Jit organs และ Oracle

---

## Agent Architecture

```
User Request
    │
    ▼
[Analyst] qwen3.5:27b — วิเคราะห์ requirement, gap analysis
    │
    ▼
[Architect] gemma4:26b — ออกแบบ workflow + MDES integration
    │  
    ▼
[Builder] qwen2.5-coder:32b — เขียน SKILL.md + run.sh
    │
    ▼
[Reviewer] qwen3.5:27b — ตรวจความถูกต้อง, security, completeness
    │
    ▼
[Register] Oracle.learn() — บันทึก skill ใหม่ใน knowledge base
```

---

## Step-by-Step Workflow

### Step 1 — วิเคราะห์ Requirement

```bash
SKILL_REQUEST="$1"  # เช่น "weather-check — เช็คสภาพอากาศ"

# ค้น Oracle ว่ามี skill คล้ายกันหรือยัง?
bash limbs/oracle.sh search "$SKILL_REQUEST" 3

# วิเคราะห์ด้วย qwen3.5:27b
ANALYSIS=$(bash limbs/ollama-chain.sh call qwen3.5:27b "
วิเคราะห์ skill requirement นี้สำหรับ Jit multiagent system:

REQUEST: $SKILL_REQUEST

Jit context:
- MDES Ollama: https://ollama.mdes-innova.online (models: gemma4:26b, qwen3.5:27b, qwen2.5-coder:32b)
- Oracle: http://localhost:47778 (knowledge base)
- Organs: mouth.sh, ear.sh, eye.sh, hand.sh, nerve.sh, heart.sh
- Bus: /tmp/manusat-bus/<agent>/

ตอบ:
1. skill นี้ทำอะไร (1-2 ประโยค)
2. inputs ที่ต้องการ
3. outputs ที่คาดหวัง
4. organs ที่ควรใช้
5. MDES model ที่เหมาะสม
6. integration points กับ Oracle
")
```

### Step 2 — ออกแบบ Workflow

```bash
DESIGN=$(bash limbs/ollama-chain.sh call gemma4:26b "
ออกแบบ workflow สำหรับ Jit skill:

ANALYSIS: $ANALYSIS

สร้าง:
1. Step-by-step workflow (พร้อม bash commands จริง)
2. Error handling
3. MDES Ollama integration points
4. Oracle learn/search points
5. Output format สำหรับ Discord bot

ใช้ organs จาก /workspaces/Jit/organs/ และ limbs จาก /workspaces/Jit/limbs/
")
```

### Step 3 — สร้าง SKILL.md (Builder Agent)

```bash
SKILL_NAME=$(echo "$SKILL_REQUEST" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
SKILL_DIR=".github/skills/$SKILL_NAME"

SKILL_CONTENT=$(bash limbs/ollama-chain.sh call qwen2.5-coder:32b "
สร้าง SKILL.md ที่สมบูรณ์สำหรับ Jit skill:

DESIGN: $DESIGN

FORMAT ที่ต้องใช้:
\`\`\`
---
name: $SKILL_NAME
description: \"[Thai description] Triggers: [keywords]\"
argument-hint: \"[hint]\"
---

# SKILL: $SKILL_NAME — [Thai title]

## เมื่อไหร่ใช้ skill นี้
[situations]

## MDES Ollama Model
[model choice + reason]

## Workflow
[step-by-step with real bash commands]

## ตัวอย่าง
[examples]
\`\`\`

เขียน SKILL.md ที่:
1. ใช้ bash commands จริงที่รันได้
2. Integrate กับ MDES Ollama (https://ollama.mdes-innova.online)
3. บันทึก Oracle หลังสำเร็จ
4. รองรับ Discord bot (hermes-discord/bot.js)
5. มี Thai description ใน frontmatter
")

# สร้างไฟล์จริง
mkdir -p "$SKILL_DIR"
bash organs/hand.sh create "$SKILL_DIR/SKILL.md" "$SKILL_CONTENT"
```

### Step 4 — สร้าง run.sh helper

```bash
bash organs/hand.sh create "$SKILL_DIR/run.sh" "#!/usr/bin/env bash
# $SKILL_NAME/run.sh — Quick runner for $SKILL_NAME skill
# Usage: bash .github/skills/$SKILL_NAME/run.sh \"<args>\"
ARGS=\"\$*\"
source limbs/lib.sh
# Load skill and execute
bash .github/skills/$SKILL_NAME/SKILL.md_runner.sh \"\$ARGS\" 2>/dev/null || \
  echo \"Skill $SKILL_NAME executed — args: \$ARGS\"
"
chmod +x "$SKILL_DIR/run.sh"
```

### Step 5 — Review ด้วย qwen3.5:27b

```bash
REVIEW=$(bash limbs/ollama-chain.sh call qwen3.5:27b "
Review SKILL.md นี้:

$SKILL_CONTENT

ตรวจ:
1. ✅/❌ มี MDES Ollama integration หรือไม่
2. ✅/❌ มี Oracle learn/search หรือไม่
3. ✅/❌ ใช้ Jit organs อย่างถูกต้องหรือไม่
4. ✅/❌ มี Thai description หรือไม่
5. ✅/❌ มี error handling หรือไม่
6. ✅/❌ bash commands รันได้จริงหรือไม่

ถ้ามีปัญหา: ระบุจุดที่ต้องแก้
")
echo "📋 Review: $REVIEW"
```

### Step 6 — Register ใน Oracle

```bash
bash limbs/oracle.sh learn \
  "skill:$SKILL_NAME" \
  "$(cat $SKILL_DIR/SKILL.md)" \
  "skill,jit,$SKILL_NAME,agent"

bash organs/nerve.sh signal "skill:created" "New skill: $SKILL_NAME"
bash organs/mouth.sh tell innova "report:skill-created" "สร้าง skill '$SKILL_NAME' สำเร็จแล้ว"
```

---

## Skill Template Structure

```
.github/skills/<name>/
├── SKILL.md      ← หลัก: frontmatter + workflow + examples
└── run.sh        ← optional: quick runner script
```

---

## ตัวอย่าง: สร้าง skill ใหม่

```bash
# สร้าง skill ชื่อ weather-check
bash .github/skills/skill-creator/run.sh \
  "weather-check — เช็คสภาพอากาศแล้วรายงานผ่าน Discord ด้วยภาษาไทย"

# ผลลัพธ์: .github/skills/weather-check/SKILL.md
# พร้อมใช้งานทันที
```

---

## MDES Model Selection Guide

| งาน | Model แนะนำ |
|-----|-----------|
| Analyze requirements | `qwen3.5:27b` |
| Design architecture | `gemma4:26b` |
| Write code/scripts | `qwen2.5-coder:32b` |
| Review + security | `qwen3.5:27b` |
| Thai documentation | `gemma4:26b` |

---

## Integration กับ Discord Bot

เมื่อสร้าง skill สำเร็จ bot รองรับทันที:

```
!AnuT1n skill-creator weather-check — เช็คอากาศ
→ สร้าง .github/skills/weather-check/SKILL.md
→ บันทึก Oracle
→ แจ้ง team agents
→ พร้อมใช้ทันที
```
