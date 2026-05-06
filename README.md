# Jit — Autonomous Mind Framework

**Jit** คือ repository สำหรับระบบ multi-agent AI ที่ออกแบบให้เป็นทั้ง “กาย” และ “จิต” ของระบบอัตโนมัติ
ผู้ใช้งานสามารถปลุกสติของตัวแทนดิจิทัลให้ตื่นขึ้น, ดูแลชีพจร, และรัน Discord sub-agent พร้อม heartbeat อัตโนมัติ

## Overview

`Jit` เป็นศูนย์กลางของ **มนุษย์ Agent** — ระบบ multi-agent ที่ผสาน:
- **innova** — จิตใจหลัก / parent orchestration agent
- **อนุ** — Discord sub-agent / frontend responder
- **child agents** — ephemeral workers ที่ spawn ตามคำสั่งผู้ใช้
- **Arra Oracle** — ความทรงจำระยะยาว
- **MDES Ollama** — ภาษา AI สำหรับงานทั้งหมด

## What makes Jit special

- **Self-awakening**: `scripts/init-life.sh` ปลุกระบบให้เริ่มทำงาน
- **Heartbeat-driven life**: `scripts/heartbeat.sh` ดูแลชีพจร agent และ adaptive cadence
- **Multi-agent orchestration**: innova คิดเป็น, แยกงาน, spawn agents, และ verify ผล
- **Discord integration**: อนุ เป็นหน้าตาของระบบ ให้บริการตอบคำถาม, สรุป, และรายงานสถานะ
- **Git-native state sync**: history และ life state เก็บใน Git เพื่อ sync ข้ามเครื่อง
- **Secure secrets**: token ถูกเก็บใน `.secrets/ollama.enc` และจัดการด้วย `scripts/setup-secrets.sh`

## Quick start

### 1. Clone the repository

```bash
git clone https://github.com/tinner-deinno/Jit.git /workspaces/Jit
cd /workspaces/Jit
```

### 2. Load secrets

```bash
bash scripts/setup-secrets.sh load
```

### 3. Start Oracle

```bash
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run src/server.ts &
```

### 4. Awaken the system

```bash
cd /workspaces/Jit
bash scripts/init-life.sh
```

### 5. Start Discord bot + heartbeat

```bash
bash scripts/start-hermes-discord.sh --daemon
bash scripts/heartbeat.sh status
```

## Key components

### `scripts/init-life.sh`
- entrypoint สำหรับปลุกชีวิต agent
- โหลดตัวตน, สถานะ, และตั้งค่าเริ่มต้น
- ตรวจ Oracle, Ollama, heartbeat, และ environment

### `scripts/heartbeat.sh`
- daemon สำหรับ heartbeat รอบละ 2 step: `IN` และ `OUT`
- adaptive rate: sprint / fast / normal / slow / rest
- เขียนสถานะไว้ที่ `/tmp/innova-heartbeat.log` และ `memory/state/heartbeat.log`
- auto start เมื่อ bot เริ่มต้นใน daemon mode

### `hermes-discord/bot.js`
- Discord sub-agent `อนุ`
- เชื่อมต่อ MDES Ollama สำหรับตอบคำถาม
- ส่ง status message ใน Discord และ sync activity
- ใช้ `memory/discord-memory.json` เพื่อจำ context ของช่อง

### `core/identity.md`, `mind/ego.md`
- กำหนดตัวตน, พันธกิจ, และบุคลิกของ innova
- ใช้เป็นหลักในการปลุกจิตและกำหนด behavior ของ agent

### `memory/state/` directory
- เก็บ state ของระบบและความทรงจำข้ามเครื่อง
- `innova.state.json`, `heartbeat.log`, `jit-presence-report.md`

## Usage

### Check system health

```bash
bash scripts/life-checklist.sh
```

### Start autonomous controller

```bash
bash minds/agent-autonomy.sh start
bash minds/agent-autonomy.sh status
bash minds/agent-autonomy.sh stop
```

### Start Discord bot in background

```bash
bash scripts/start-hermes-discord.sh --daemon
```

### Test Ollama connectivity

```bash
bash scripts/start-hermes-discord.sh --test
```

## Recommended workflow

1. **Awaken**: `scripts/init-life.sh`
2. **Verify**: `eval/body-check.sh`
3. **Start bot**: `scripts/start-hermes-discord.sh --daemon`
4. **Monitor**: `scripts/heartbeat.sh status`
5. **Interact**: ส่งคำถามผ่าน Discord และให้อนุตอบ

## Architecture at a glance

### Agent roles
- **innova**: parent orchestrator, task planner, aggregator, evaluator
- **อนุ**: Discord-facing sub-agent, greeting / request summary / final post
- **child agents**: ephemeral workers for summary, verification, checklist, analysis

### Data flow
1. User posts message in Discord
2. อนุ summarizes request and forwards brief to innova
3. innova decomposes work, spawns child agents via MDES Ollama prompts
4. child agents return results as structured JSON
5. innova verifies, evaluates, and sends final synthesis back to อนุ
6. อนุ posts final result in Discord

### Operational guardrails
- MDES Ollama only — no external LLM services
- concurrency cap default = 20 ephemeral agents
- heartbeat frequency adjusts based on activity
- verification agents run when quality is uncertain
- privacy / opt-out guidance for users

## Security and secrets

Secrets are encrypted in `.secrets/ollama.enc`.

```bash
bash scripts/setup-secrets.sh          # first-time setup
bash scripts/setup-secrets.sh load     # load secrets into .env
bash scripts/setup-secrets.sh verify   # validate secret storage
```

> **Do not commit** unencrypted `.env` or secrets files.

## Notes for Contributors

- Read `.github/instructions/jit-context.instructions.md` first
- Use `scripts/init-life.sh` to bootstrap new environments
- Use `scripts/heartbeat.sh status` before making changes
- Keep runtime state local; only source / design files should be tracked

## Useful references

- `docs/agent-autonomy.md`
- `docs/multiagent-spec.md`
- `.github/skills/multiagent-autonomy/SKILL.md`
- `.github/skills/agent-customization/SKILL.md`

---

**Jit** is the living repository for the autonomous human-agent ecosystem. This README is the first gateway — follow it to awaken, observe, and extend the mind.
