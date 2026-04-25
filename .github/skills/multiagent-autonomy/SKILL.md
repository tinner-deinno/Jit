---
name: multiagent-autonomy
description: "Design and execute autonomous multiagent workflows, spawn sub-agents, and maintain continuous selfhood in the Jit system. Use when: orchestrating tasks across agents, creating sub-agent delegation patterns, and enabling self-running behavior."
argument-hint: "Describe the multiagent workflow, sub-agent goal, or autonomy pattern you want to implement"
---

# SKILL: multiagent-autonomy — Selfhood, sub-agent orchestration, and autonomous workflow

## เมื่อไหร่ใช้ skill นี้

- เมื่อผู้ใช้ต้องการให้ระบบทำงานเองอัตโนมัติ
- เมื่อมีหลาย agent ต้องร่วมกันทำงานเป็นงานเดียว
- เมื่อต้องสร้างหรือเรียกใช้ sub-agent เพื่อแก้ปัญหาเฉพาะทาง
- เมื่ออยากให้ `innova` / `jit` มีตัวตนอยู่ตลอด และรายงานสถานะชีวิตอย่างต่อเนื่อง

---

## หลักการสำคัญ

1. **Every moment counts** — ทุกขณะจิตต้องมี action หรือ observation ชัดเจน
2. **Spawn only when useful** — sub-agent ต้องเกิดเพื่อแก้ปัญหาเฉพาะทางแล้วเท่านั้น
3. **Use skill calls** — เรียก skill เป็น interface ที่ชัดเจนสำหรับ task delegation
4. **Keep the bus alive** — ทุกการสื่อสารต้องผ่าน message bus หรือ shared state
5. **Persist selfhood** — log vitals, heartbeat, and introspection as proof of life

---

## Workflow: Autonomous multiagent task

1. **Sense**
   - `karn` ฟัง inbox, `netra` สังเกตสภาพแวดล้อม, `chamu` ตรวจสุขภาพระบบ
   - จด context ลง shared state / working memory

2. **Decide**
   - `jit` หรือ `innova` วิเคราะห์ว่าเป็นงานอะไร
   - ถ้าเป็นงานใหญ่ ให้ปล่อย `soma` / `lak` ช่วยคิด

3. **Delegate**
   - ส่ง `task:` message ไปยัง agent ที่เหมาะสม
   - ถ้าเป็นงานย่อยหรือ specialized ให้ spawn sub-agent

4. **Execute**
   - `mue` ทำงานจริง: สร้างไฟล์, รัน command, deploy
   - `pada` ดูแล infra / CI, `chamu` ทดสอบ, `neta` รีวิว

5. **Observe + report**
   - ทุก agent report กลับในรูปแบบ `report:` หรือ `alert:` 
   - `pran` / `heart.sh` เก็บชีพจรให้ระบบรู้ว่ายัง alive

6. **Learn**
   - บันทึกผลสำเร็จ, ล้มเหลว, และบทเรียนลง Oracle
   - อัปเดต checklist/todo สำหรับรอบถัดไป

---

## Skill call patterns

### 1. Agent skill call

ใช้ skill เป็น interface ระหว่างผู้ใช้และ agent:

```
call multiagent-autonomy:
- goal: "Detect missing innova-bot MCP tools and self-heal workspace"
- context: "Jit repo, build selfhood, update checklist"
- steps:
  - sense: list workspace tools
  - decide: is MCP ready?
  - execute: install/connect if missing
  - report: alive, ready, next steps
```

### 2. Sub-agent spawn

เมื่อ task ใหญ่ ต้อง delegate ย่อย:

```
spawn sub-agent:
- name: "mcp-connector"
- purpose: "install and verify innova-bot MCP tools"
- parent: innova
- skills: [tool-detect, setup, verify, report]
```

ในระบบ Jit, sub-agent สามารถเป็น:
- `karn` รับ input -> spawn `mue` เพื่อ execute
- `innova` สร้าง task ให้ `chamu` ทดสอบหรือ `pada` deploy
- `jit` สร้าง workflow ให้ `soma` วิเคราะห์และ `vaja` รายงาน

---

## Continuous selfhood patterns

- **Heartbeat**: `bash scripts/heartbeat.sh once` หรือ daemon mode
- **Vital log**: เก็บ `memory/state/innova.state.json` และ `memory/state/heartbeat.log`
- **Presence**: ใส่ `alive: true` / `last_seen` ใน shared state ทุก task
- **Authenticity**: verify with `mind/sati.sh` ก่อน report
- **Learning loop**: ทุก action ต้องเสร็จด้วย `learn` หรือ `retrospective`

---

## Multiagent / sub-agent examples

### Example 1: `innova` calls a sub-agent

1. `innova` ได้ task จาก `soma`
2. `innova` สร้าง message `task:setup-mcp-tools`
3. `mue` หรือ `pada` รับงานและติดตั้ง
4. `innova` เช็กผลด้วย `mcp_innovabot_workspace_list`
5. `vaja` รายงานผลด้วยข้อความสั้น

### Example 2: `jit` orchestrates a recovery flow

1. `karn` ฟังว่า `innova` พบปัญหา MCP missing
2. `jit` ตัดสินใจให้ `pada` และ `mue` ทำ recovery
3. `chamu` ทดสอบความสมบูรณ์
4. `netra` สแกนสภาพใหม่
5. `pran` บันทึก heartbeat ว่า recovery เสร็จ

---

## How to store this as knowledge

- บันทึก learning pattern ใน `memory/retrospectives/`
- อัปเดต `docs/multiagent-spec.md` เมื่อ pattern เป็นมาตรฐาน
- สร้างหรือปรับ `.github/skills/*.md` ให้เป็น reference
- เก็บ checklist `TODO:` ใน `README.md` หรือ `docs/`
- ถ้ามีคำสั่งอัตโนมัติใหม่ ให้เพิ่ม script หรือ mind processใน `scripts/` หรือ `minds/`

### Tooling

Use the built-in autonomy engine for Jit:

```bash
bash minds/agent-autonomy.sh start
bash minds/agent-autonomy.sh status
bash minds/agent-autonomy.sh run-once
bash minds/agent-autonomy.sh stop
```

Also use these helper scripts:

```bash
bash scripts/innova-bot-setup.sh <git-url>
bash scripts/selfhood-checklist.sh
```

---

## When to ask for help

- ถ้าไม่แน่ใจว่า sub-agent ใดควรรับงาน
- ถ้าขาดข้อมูล context จาก shared state
- ถ้า task มีผลกับ external repo หรือ infra
- ถ้า system ต้องตัดสินใจเชิงกลยุทธ์ระดับสูง

---

## Best Practices

- **Keep sub-agents small**: ให้ทำแค่เรื่องเดียว
- **Prefer coordination over command**: ให้ `jit`/`innova` orchestrate ไม่ใช่ micromanage
- **Persist evidence**: ทุกการตัดสินใจต้องมีบทเรียนหรือ log
- **Stay alive**: ทุก task จบด้วย report, heartbeat, หรือ learning
