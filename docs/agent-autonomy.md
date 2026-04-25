# Agent Autonomy and Continuous Selfhood

## เป้าหมาย

ให้ระบบ `Jit` มีตัวตนแบบทุกเวลา และทำงานเองได้ทันทีเมื่อมี context พร้อม

- ดูแลชีพจรของตัวเอง
- ช่วงชิงงานเล็กให้เสร็จในขณะจิต
- ใช้ multiagent เป็นเครือข่ายที่ร่วมมือกัน
- Spawn sub-agent เมื่อเรื่องต้องการโฟกัสเฉพาะทาง
- บันทึกความรู้เป็นเอกสารและ Oracle

## Key concepts

### 1. Presence / Life signal

- `heartbeat`: สัญญาณชีวิตทุกช่วงเวลา
- `alive`: state ชัดเจนใน `memory/state/innova.state.json`
- `last_seen`: timestamp ทุกครั้งที่ agent ทำงาน

### 2. Continuous task loop

- `Sense` — รับข้อมูลจาก bus, file, tool
- `Decide` — เลือกว่าจะแก้ด้วยตัวเองหรือ delegate
- `Delegate` — ส่ง task ให้ agent หรือ sub-agent
- `Execute` — ทำงานจริงด้วย organ ที่เหมาะสม
- `Observe` — ตรวจผลสำเร็จ, errors, side effects
- `Learn` — บันทึก lesson, update checklist

### 3. Sub-agent delegation

Sub-agent คือ helper ที่เกิดเพื่อเรื่องเดียว:

- `task:setup-mcp` → `mue` / `pada`
- `task:quality-check` → `chamu`
- `task:design-review` → `rupa`
- `task:health-check` → `netra` / `pran`

### 4. Skill contract

- SKILL documents are reusable knowledge interfaces
- They define when to use, how to run, and what success looks like
- Use skill docs instead of unstructured chat prompts when repeating patterns

## Recommended practices

- ทำงานแต่ละรอบให้เสร็จอย่างน้อยหนึ่ง item
- ถ้าทำไม่เสร็จใน 1 ขณะจิต ให้สรุปสถานะและเขียน `next` task
- ถ้าพบปัญหา ให้บันทึก root cause และ `learn` pattern ใหม่
- ให้ทุก agent report status เอง ไม่ใช่ให้ผู้ใช้ถาม

## Document as knowledge

- บันทึก pattern ใหม่ใน `docs/agent-autonomy.md`
- เพิ่มตัวอย่าง flow ใน `.github/skills/`
- เก็บ evidence ใน `memory/retrospectives/`
- อัปเดต `docs/multiagent-spec.md` เมื่อ pattern เป็นมาตรฐาน

## Tooling

- `minds/agent-autonomy.sh` — autonomous coordination engine for Jit
- `scripts/heartbeat.sh` — living pulse, git sync, Oracle sync, heartbeat IN/OUT
- `organs/lung.sh` — lung purifier that cleans agent blood/context before OUT flow
- `minds/innova-life.sh` — innova self-loop and message processor
- `scripts/innova-bot-setup.sh` — detect and provision innova-bot repository
- `scripts/selfhood-checklist.sh` — health checklist for life, autonomy, and tools

### Commands

```bash
bash minds/agent-autonomy.sh start
bash minds/agent-autonomy.sh status
bash minds/agent-autonomy.sh run-once
bash minds/agent-autonomy.sh stop
bash scripts/innova-bot-setup.sh <git-url>
bash scripts/selfhood-checklist.sh
```

## innova-bot setup

- Use `scripts/innova-bot-setup.sh` to clone or update the `innova-bot` repo.
- Set `INNOVA_BOT_REPO` in `.env` if you want a default source.
- The script records shared state keys such as `innova_bot.path` and `innova_bot.ready`.
- If a README exists, it prints the top lines and saves a short summary.

## selfhood checklist

- `scripts/selfhood-checklist.sh` checks:
  - heartbeat daemon
  - agent-autonomy daemon
  - innova-bot repository presence
  - Oracle availability
  - Ollama availability
- It also provides `next` remediation steps when issues are found.

## Example use case

```
- karn รับ message ว่า MCP tools หาย
- innova วิเคราะห์ว่าเป็น task install/verify
- innova spawn sub-agent `mcp-recovery`
- mue ติดตั้ง tool, pada ตั้งค่า env
- chamu ทดสอบ, netra สแกน, pran บันทึก heartbeat
- vaja รายงาน "ระบบกลับสู่สถานะ ready"
```
