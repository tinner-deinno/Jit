# mdes-hub — SA Specification
# Role: Jit (จิต) — Solution Architect + Personal Assistant
# Status: ACTIVE | Phase 1: Discovery & Bootstrap
# Started: 2026-05-20
# SA: jit | Builder: innova-bot | Goal: Production-ready hub สำหรับ MDES ecosystem

---

## Vision

**mdes-hub** = Central hub ที่รวม MDES ecosystem ทั้งหมดไว้ในที่เดียว:
- ควบคุม AI models (Ollama, GitHub Copilot)
- จัดการ agents (innova-bot, Jit, hermes)
- ติดตาม projects และ tasks
- ดู logs, metrics, health แบบ realtime

## Target Users
- MDES-Innova developers
- innova (the human operator)
- AI agents (innova-bot, Jit)

---

## Architecture (SA Design)

```
mdes-hub/
├── backend/          # FastAPI — ศูนย์กลาง API
│   ├── routers/
│   │   ├── agents.py     # status, inbox, tasks ของแต่ละ agent
│   │   ├── models.py     # Ollama model management
│   │   ├── projects.py   # project + TODO tracker
│   │   └── health.py     # system health check
│   └── main.py           # FastAPI app
│
├── frontend/         # Lightweight SPA (Vanilla JS หรือ Next.js)
│   ├── index.html
│   ├── components/
│   │   ├── AgentStatus.js
│   │   ├── ModelList.js
│   │   ├── TaskBoard.js
│   │   └── Logs.js
│   └── app.js
│
├── integrations/     # connectors
│   ├── ollama.py         # MDES Ollama API wrapper
│   ├── innova_bot.py     # innova-bot MCP client
│   ├── oracle.py         # Arra Oracle V3 client
│   └── jit.py            # Jit state reader
│
└── docker-compose.yml    # production deploy
```

## Tech Stack (SA Decision)
| Layer | Choice | Reason |
|-------|--------|--------|
| Backend | FastAPI + uvicorn | already used in innova-bot, team knows it |
| Frontend | Vanilla JS + Tailwind CDN | zero build step, fast to iterate |
| DB | SQLite (via innova-bot pattern) | consistent with ecosystem |
| Deploy | Docker Compose | same as innova-bot |
| AI | MDES Ollama (gemma4:26b) | team's primary model |

---

## Phase Plan

### Phase 1: Bootstrap (current)
- [ ] 1.1 สร้าง repo structure ใน C:\Users\admin\DEV\mdes-hub
- [ ] 1.2 FastAPI backend skeleton: /health, /agents, /models
- [ ] 1.3 ดึงข้อมูล Ollama models จาก ollama.mdes-innova.online
- [ ] 1.4 ดึงสถานะ innova-bot จาก port 7010
- [ ] 1.5 Frontend: basic dashboard แสดง status

### Phase 2: Core Features
- [ ] 2.1 Agent inbox viewer (อ่าน ψ/inbox ของแต่ละ agent)
- [ ] 2.2 Task board (integrates innova-bot TODO.md)
- [ ] 2.3 Model switching UI (เลือก Ollama model)
- [ ] 2.4 Log streaming (SSE)

### Phase 3: Production Hardening
- [ ] 3.1 Auth (Bearer token)
- [ ] 3.2 Docker Compose production config
- [ ] 3.3 CI/CD via GitHub Actions
- [ ] 3.4 Error handling + retry logic
- [ ] 3.5 Tests (unit + E2E)

---

## Bug Tracker

### Open Bugs
(จะเพิ่มเมื่อพบระหว่างพัฒนา)

### Resolved Bugs
(จะย้ายมาเมื่อแก้แล้ว)

---

## Jit SA Decisions Log

| Date | Decision | Reason |
|------|----------|--------|
| 2026-05-20 | ใช้ FastAPI (ไม่ใช่ Next.js) | align กับ innova-bot stack |
| 2026-05-20 | ใช้ Vanilla JS + Tailwind CDN | ไม่มี build step, deploy ง่าย |
| 2026-05-20 | Port 8765 สำหรับ mdes-hub | ไม่ชนกับ Oracle (47778), innova-bot (7010) |
| 2026-05-20 | Jit = SA + PA, innova-bot = Builder | Jit ออกแบบ + ติดตาม, innova-bot implement |

---

## Communication Protocol (Jit ↔ innova-bot)

Jit ส่ง task ผ่าน:
```
C:\Users\admin\DEV\PugAss1stant\innova-bot\ψ\inbox\jit-TIMESTAMP.json
```

Format:
```json
{
  "from": "jit",
  "to": "innova-bot",
  "project": "mdes-hub",
  "phase": "1",
  "subject": "task:implement",
  "body": "...",
  "timestamp": "ISO8601",
  "expect_reply_by": "ISO8601 + 5min"
}
```

innova-bot ตอบกลับผ่าน:
```
C:\Users\admin\Jit\ψ\inbox\innova-bot-TIMESTAMP.json
```
