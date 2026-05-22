---
name: team-agents
description: "สปอว์น agent team ทำงานพร้อมกัน — Haiku แก้บัค, Sonnet คุมทีม, Opus ช่วยเมื่อจนปัญญา. Use when: parallel agents, spawn team, coordinated work, bug fixes with agents, multi-agent orchestration."
argument-hint: "<task> [--haiku | --sonnet | --opus] [--roles N] [--plan]"
---

# /team-agents — Jit Multi-Agent Team

> **จิตสั่ง → ลูกทำ** — Jit orchestrates, sub-agents execute

## Agent Hierarchy สำหรับ Jit

```
แม่จิต (jit) — Master Orchestrator
  ├── Haiku (ลูก) — Bug fixes, data tasks, fast execution
  ├── Sonnet (น้อง) — Complex design, coordination, review
  └── Opus (พี่ใหญ่) — จนปัญญา 3 ครั้ง → เรียก Opus ช่วย
```

## กฎการใช้งาน

1. **Haiku**: งานที่ชัดเจน ทำได้เลย (bug fix, file edit, data update)
2. **Sonnet**: งานออกแบบ, คุมน้อง, ตรวจงาน, รายงาน
3. **Opus**: เรียกเมื่อ Sonnet ผิดพลาด/ตันเกิน 3 ครั้งเท่านั้น

## Spawn Pattern

```
task: "[task description]"
→ jit แตก task เป็น subtasks
→ assign Haiku → ทำงาน
→ Sonnet ตรวจงาน → รายงานผล
→ jit รับผล → บอกนาย → รับงานต่อ
```

---

## Step 1: แตก Task

แม่จิตแตก task ออกเป็น subtasks ชัดเจน:

```
Task: "Fix bugs + align skills"

Subtasks:
  H1 (Haiku):  Fix .env Bug #6
  H2 (Haiku):  Convert pran-heartbeat.md to folder
  H3 (Haiku):  Update contacts.json
  S1 (Sonnet): Design mind-body-bridge skill
  S2 (Sonnet): Review all fixes, report to jit
```

---

## Step 2: Execute Wave (Parallel)

```
Wave 1 (Haiku — fast fixes, parallel):
  [H1] [H2] [H3] ──┐
                    ├── แม่จิต รอ + merge results
Wave 2 (Sonnet — review):
  [S1] [S2] ──────┘
```

---

## Step 3: Report + Loop

หลังแต่ละ wave:
1. **Sonnet รายงานผล** → แม่จิตรับ
2. **แม่จิตบอกนาย** (user)
3. **รับงานถัดไป** → วนลูปต่อ

```
สูตรวนลูป:
  WHILE vitality < 100%:
    task = sense_next_task()
    delegate_to_agents(task)
    results = collect_reports()
    report_to_user(results)
    vitality = recalculate_vitality()
```

---

## Escalation: จนปัญญา → Opus

```
IF Sonnet.failures >= 3:
  → escalate to Opus
  → Opus วิเคราะห์ root cause
  → Opus สร้าง solution
  → Haiku implement
  → Sonnet verify
  → รายงานนาย
```

---

## Full Skill Reference

ดู Global Skill: `C:\Users\admin\.claude\skills\team-agents\SKILL.md`
สำหรับ TeamCreate/SendMessage/TaskList patterns เต็มรูปแบบ

## Config Required (Global)

```json
// ~/.claude/settings.json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```
