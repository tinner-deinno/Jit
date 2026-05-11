---
name: sleep-research
description: "วิจัย/ค้นคว้าอัตโนมัติขณะนอนหลับ — queue research tasks ก่อนนอน, Jit ทำงานข้ามคืนด้วย MDES Ollama + Oracle + Claude CLI, ตื่นมาได้รายงานพร้อม. Inspired by github.com/wanshuiyin/Auto-claude-code-research-in-sleep. Triggers: sleep research, วิจัยข้ามคืน, research queue, overnight research, ทำงานข้ามคืน, research while sleep, queue research"
argument-hint: "'topic to research overnight' หรือ '--queue topic' หรือ '--run-queue' หรือ '--status'"
---

# SKILL: sleep-research — ให้ Jit วิจัยข้ามคืนขณะคุณนอนหลับ 🌙

**Inspired by [Auto-claude-code-research-in-sleep](https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep)**  
Queue งานวิจัยก่อนนอน → MDES Ollama + Oracle + Claude CLI ทำงานอัตโนมัติ → ตื่นมาได้ผลลัพธ์พร้อม

## เมื่อไหร่ใช้ skill นี้

- ต้องการข้อมูลเจาะลึกแต่ไม่อยากรอ (let AI work overnight)
- Queue งานวิจัยหลายหัวข้อพร้อมกัน
- ต้องการให้ Jit agents ทำงานร่วมกันโดยอัตโนมัติ
- ใช้ก่อน `/brainstorming` หรือ `/feature-dev` เพื่อ pre-research

---

## Architecture

```
ก่อนนอน                    ข้ามคืน                      ตื่นมา
─────────────────────────────────────────────────────────────────
user → queue topics         Jit daemon wakes             Results in
  via Discord/CLI          every 30 min:                Oracle + Discord:
  
  !AnuT1n sleep-research   ┌─ gemma4:26b (Research)      📋 Report
  "next.js 15 changes"     ├─ qwen3.5:27b (Deep Analysis) 🔗 Sources  
  "Jit skill best          ├─ qwen2.5-coder:32b (Code)    💡 Insights
   practices"              └─ Oracle.learn() (Save)       ⚡ Action items
  "Thai NLP models"
```

---

## Workflow

### Mode 1: Queue topic ก่อนนอน

```bash
bash .github/skills/sleep-research/run.sh --queue "หัวข้อที่ต้องการวิจัย"
# เช่น: --queue "Next.js 15 breaking changes"
#        --queue "Jit multiagent optimization patterns"
#        --queue "Thai LLM models comparison 2026"
```

Queue บันทึกใน `memory/sleep-research/queue/`

### Mode 2: Run queue (daemon / cron)

```bash
bash .github/skills/sleep-research/run.sh --run-queue

# หรือตั้ง cron ทุกวันตี 2:
# 0 2 * * * cd /workspaces/Jit && bash .github/skills/sleep-research/run.sh --run-queue
```

สำหรับแต่ละ topic ใน queue:

```bash
# Step 1: Gather data (firecrawl / brave-search / Oracle)
bash .github/skills/brave-search/run.sh "$TOPIC" 2>/dev/null
bash .github/skills/firecrawl/run.sh "https://search related urls" 2>/dev/null

# Step 2: Deep research via MDES chain
RESEARCH=$(bash limbs/ollama-chain.sh call gemma4:26b \
  "วิจัยเรื่อง: $TOPIC
  Context จาก Oracle: $ORACLE_CTX
  
  ค้นหาและสรุป:
  1. สถานะล่าสุด (current state)
  2. Best practices / patterns ที่แนะนำ
  3. ปัญหาที่คนพบบ่อย
  4. Relevance สำหรับ Jit/MDES ecosystem
  5. Action items สำหรับ innova team")

# Step 3: Technical depth (qwen3.5:27b)
DEEP=$(bash limbs/ollama-chain.sh call qwen3.5:27b \
  "วิเคราะห์เชิงลึก: $TOPIC\n\nResearch: $RESEARCH\n\nระบุ insights ที่ไม่ชัดเจนใน research นี้")

# Step 4: Code patterns (ถ้า topic เกี่ยวกับ code)
CODE=$(bash limbs/ollama-chain.sh call qwen2.5-coder:32b \
  "สรุป code patterns / implementation examples สำหรับ: $TOPIC")

# Step 5: Save to Oracle + notify
bash limbs/oracle.sh learn "research:$(date +%Y-%m-%d):$SLUG" \
  "$RESEARCH\n\n## Deep Analysis\n$DEEP\n\n## Code\n$CODE" \
  "research,overnight,$SLUG"

# Step 6: Discord notification via Hermes
bash organs/mouth.sh tell jit "report:research-done" \
  "🌙 Overnight research complete: $TOPIC"
```

### Mode 3: Claude CLI Integration (ถ้ามี claude CLI)

```bash
# ใช้ Claude Code เอง เป็น sub-agent researcher
if command -v claude &>/dev/null; then
  echo "Using Claude CLI as research sub-agent..."
  claude --print "Research task: $TOPIC
  
  You are innova, Lead Developer of Jit multiagent system.
  Research this topic thoroughly and save findings to Oracle at http://localhost:47778
  
  Use these tools:
  1. bash limbs/oracle.sh search '$TOPIC' 10
  2. bash .github/skills/brave-search/run.sh '$TOPIC'
  3. bash .github/skills/firecrawl/run.sh [relevant urls]
  4. bash limbs/oracle.sh learn 'research:$TOPIC' [findings] 'research'
  
  Save your complete findings." > "/tmp/jit-research-$SLUG.md"
fi
```

### Mode 4: Status / Morning Report

```bash
bash .github/skills/sleep-research/run.sh --status
# แสดง: queue size, completed overnight, Oracle records saved, Discord sent
```

---

## MDES Model Assignments

| งาน | Model | เหตุผล |
|-----|-------|-------|
| General research | `gemma4:26b` | Thai + general best |
| Deep analysis | `qwen3.5:27b` | Deep reasoning |
| Code research | `qwen2.5-coder:32b` | Code-specific |
| Synthesis | `gemma4:26b` | Thai summary |
| Vision (screenshots) | `qwen3-vl:32b` | Visual content |

---

## Integration กับ Jit Gang

```
sleep-research coordinates:
  ├── brave-search     — ดึงผลลัพธ์จากเว็บ
  ├── firecrawl        — อ่านเนื้อหาหน้าเว็บ
  ├── brainstorming    — สังเคราะห์ไอเดีย
  ├── socialcrawl      — monitor GitHub/Reddit/HN trends
  └── feature-dev      — ถ้า research นำไปสู่ feature ใหม่

Output channels:
  ├── Oracle           — knowledge base (permanent)
  ├── Hermes Discord   — morning report
  ├── .planning/       — auto-generated plan file ถ้าพบ actionable items
  └── mouth.sh tell jit — orchestrator notification
```

---

## ติดตั้ง

```bash
# Install + integrate จาก GitHub
bash scripts/install-sleep-research.sh

# Queue งานแรก
bash .github/skills/sleep-research/run.sh --queue "Jit skill optimization 2026"

# ดู status
bash .github/skills/sleep-research/run.sh --status
```

---

## ตั้งค่า Cron (ตี 2 ทุกวัน)

```bash
# Linux/Codespace:
(crontab -l 2>/dev/null; echo "0 2 * * * cd /workspaces/Jit && OLLAMA_TOKEN=\$OLLAMA_TOKEN bash .github/skills/sleep-research/run.sh --run-queue >> /tmp/jit-sleep-research.log 2>&1") | crontab -

# Windows Task Scheduler: 
# ใช้ scripts/install-sleep-research.sh สร้าง scheduled task อัตโนมัติ
```

---

## Source Repository

```
https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep
Local mirror: _reference_repos/sleep-research/
```
