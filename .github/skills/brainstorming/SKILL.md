---
name: brainstorming
description: "ระดมสมองหลาย model พร้อมกัน — ส่งหัวข้อให้ MDES Ollama chain วิเคราะห์จาก 3 มุมมอง (Creative, Critical, Strategic) แล้วสังเคราะห์เป็น action items พร้อมบันทึก Oracle. Triggers: brainstorm, ระดมสมอง, คิดไอเดีย, ideate, think together, คิดช่วย"
argument-hint: "หัวข้อที่ต้องการระดมสมอง เช่น 'feature ใหม่สำหรับ bot', 'วิธีปรับปรุงระบบ', 'แก้ปัญหา X'"
engines: ["mdes-ollama", "claude-cli", "openai-codex"]
jit-agents: ["innova", "soma", "lak"]
---

# SKILL: brainstorming — ระดมสมองร่วมกับ MDES Ollama 🧠

**ใช้ model ที่ดีที่สุดจาก MDES เป็น sub-agent คิดหลายมุม แล้วสังเคราะห์เป็น action plan**

## เมื่อไหร่ใช้ skill นี้

- ต้องการไอเดียใหม่สำหรับ feature, workflow, หรือแก้ปัญหา
- อยากได้ความเห็นจากหลาย perspective ก่อนตัดสินใจ
- ต้องการสร้าง action items จากหัวข้อที่คลุมเครือ
- ใช้ก่อน `/writing-plans` เสมอ เมื่อยังไม่มี direction ชัด

---

## MDES Ollama Sub-Agents

| Agent | Model | บทบาท |
|-------|-------|-------|
| 🎨 **Creative** | `gemma4:26b` | คิดนอกกรอบ, ไอเดียแปลก, มองโอกาส |
| 🔍 **Critical** | `qwen3.5:27b` | ตั้งคำถาม, หาจุดอ่อน, ความเสี่ยง |
| ♟️ **Strategic** | `qwen2.5-coder:32b` | วิเคราะห์ทางเทคนิค, feasibility, วางแผน |
| 🧩 **Synthesizer** | `gemma4:26b` | รวมทุกมุม → สรุป action items |

---

## Workflow

### Step 1 — ตรวจสอบ Oracle ก่อน

```bash
# มีความรู้เกี่ยวกับหัวข้อนี้ใน Oracle หรือไม่?
bash limbs/oracle.sh search "$TOPIC" 5
```

### Step 2 — ส่งให้ sub-agents คิดพร้อมกัน

```bash
# Creative perspective
bash limbs/ollama-chain.sh call gemma4:26b \
  "คุณคือนักสร้างสรรค์ ให้ไอเดียสร้างสรรค์ 5 ข้อสำหรับ: $TOPIC\nแต่ละข้อต้องเป็นรูปธรรม ทำได้จริง"

# Critical perspective  
bash limbs/ollama-chain.sh call qwen3.5:27b \
  "คุณคือนักวิจารณ์ผู้เชี่ยวชาญ วิเคราะห์ risks และ challenges ของ: $TOPIC\nระบุ 5 ประเด็นที่ต้องระวัง"

# Strategic/Technical perspective
bash limbs/ollama-chain.sh call qwen2.5-coder:32b \
  "คุณคือ senior engineer วิเคราะห์ feasibility และ technical approach สำหรับ: $TOPIC\nเสนอ 3 approach พร้อม trade-offs"
```

### Step 3 — Synthesize ทุกมุม

```bash
bash limbs/ollama-chain.sh call gemma4:26b \
  "รวมความคิดเหล่านี้แล้วสังเคราะห์เป็น action items ที่ชัดเจน:

Creative: $CREATIVE_OUTPUT
Critical: $CRITICAL_OUTPUT  
Strategic: $STRATEGIC_OUTPUT

สร้าง:
1. Top 3 ไอเดียที่ดีที่สุด (เรียงตาม impact)
2. Action items ที่ทำได้ทันที (quick wins)
3. Action items ระยะกลาง (1-2 weeks)
4. ความเสี่ยงหลักที่ต้องจัดการ"
```

### Step 4 — บันทึก Oracle

```bash
bash limbs/oracle.sh learn \
  "brainstorm:$TOPIC" \
  "$SYNTHESIS_OUTPUT" \
  "brainstorm,ideation,$TOPIC"
```

### Step 5 — ส่งผลลัพธ์ผ่าน Jit bus

```bash
# แจ้งทีมผ่าน nerve.sh
bash organs/nerve.sh signal "brainstorm:complete" \
  "หัวข้อ: $TOPIC | Action items: $(echo $SYNTHESIS | wc -l) items"

# ส่งให้ innova / soma ถ้าต้องการ follow-up
bash organs/mouth.sh tell innova "task:brainstorm-done" "ผล brainstorm: $TOPIC → ดู Oracle: brainstorm:$TOPIC"
```

---

## ใช้แบบด่วน (Quick Mode)

```bash
# ระดมสมองเรื่อง X ด้วย gemma4:26b อย่างเดียว (เร็ว)
bash limbs/ollama.sh think "ให้ 10 ไอเดียสำหรับ: $TOPIC" "Jit multiagent system context"
```

---

## Integration กับ Jit Organs

| อวัยวะ | หน้าที่ใน brainstorming |
|--------|----------------------|
| `eye.sh` | อ่าน context จาก repo ก่อนเริ่ม |
| `nose.sh` | sniff หา similar ปัญหาใน codebase |
| `hand.sh` | เขียน brainstorm output ลงไฟล์ |
| `mouth.sh` | แจ้งผลให้ team agents |
| `nerve.sh` | broadcast ผล brainstorm ทั่วระบบ |

---

## ตัวอย่างการใช้งาน

```bash
# ผู้ใช้พิมพ์ใน Discord:
# !AnuT1n brainstorm วิธีทำให้ karn bot ฟังเสียงได้จริง

# ผ่าน bot.js → skill brainstorming
bash .github/skills/brainstorming/run.sh "วิธีทำให้ karn bot ฟังเสียงได้จริง"
```

---

## ผลลัพธ์ที่ได้

```markdown
## 🧠 Brainstorm: [หัวข้อ]

### 🎨 มุมมองสร้างสรรค์
- ไอเดีย 1...
- ไอเดีย 2...

### 🔍 มุมมองวิจารณ์  
- ความเสี่ยง 1...

### ♟️ มุมมองเทคนิค
- Approach A: ...

### 🎯 Action Items
- [ ] Quick win: ...
- [ ] Week 1: ...
- [ ] Week 2: ...

### ⚠️ ความเสี่ยงหลัก
- ...

📚 บันทึกลง Oracle: brainstorm:[topic]
```

---

## 🔌 Engine Options — MDES / Claude CLI / Codex

ใช้ engine ที่เหมาะสมกับ context:

| Engine | เมื่อใช้ | คำสั่ง |
|--------|---------|-------|
| **MDES Ollama** (default) | ทุกกรณี, Thai, ทำงานได้ offline | `bash limbs/ollama-chain.sh call gemma4:26b "..."` |
| **Claude CLI** | ต้องการ deep reasoning, code review | `claude --print "brainstorm: $TOPIC"` |
| **OpenAI Codex** | เน้น code generation, API patterns | `curl https://api.openai.com/v1/chat/completions ...` |

### ใช้ Claude CLI เป็น sub-agent:

```bash
# ถ้ามี claude CLI installed
if command -v claude &>/dev/null; then
  claude --print "You are soma (Brain) of Jit multiagent system.
  Brainstorm topic: $TOPIC
  
  Context: Jit repo at $(pwd), MDES Ollama at https://ollama.mdes-innova.online
  
  Give 3-perspective analysis:
  1. Creative — ไอเดียใหม่
  2. Critical — risks และ challenges  
  3. Technical — implementation approach
  
  End with Top 3 action items." 2>/dev/null
fi
```

### ใช้ Codex (OpenAI) สำหรับ technical brainstorm:

```bash
# ต้องตั้ง OPENAI_API_KEY
if [ -n "${OPENAI_API_KEY:-}" ]; then
  curl -sf "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"Brainstorm technical solutions for Jit multiagent system: $TOPIC\"}]}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['choices'][0]['message']['content'])"
fi
```

---

## Jit Agent Hierarchy ใน Brainstorming

```
jit (orchestrator) → soma (deep strategy) → innova (technical impl)
                   ↓
              brainstorming skill
              ├── MDES Ollama (gemma4:26b) — Creative
              ├── MDES Ollama (qwen3.5:27b) — Critical  
              ├── MDES Ollama (qwen2.5-coder:32b) — Technical
              └── Oracle.learn() → bus.sh notify innova/soma
```
