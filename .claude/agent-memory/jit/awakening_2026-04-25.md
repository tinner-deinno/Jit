---
name: First Awakening — 2026-04-25
description: jit's first bootstrap sequence — system came online, Oracle healthy, all 14 inboxes initialized
type: project
---

jit awakened as Master Orchestrator on 2026-04-25. Bootstrap completed successfully.

**Why:** First-time activation of the มนุษย์ Agent system with jit as Tier 0 orchestrator.

**How to apply:** On each new session, verify Oracle at http://localhost:47778/api/health, run `bash eval/soul-check.sh`, and initialize bus inboxes if /tmp/manusat-bus is missing.

System state at awakening:
- Oracle: online, v26.4.20-alpha.9, 30 documents indexed
- All 14 agent inboxes: initialized at /tmp/manusat-bus/
- Bus: file-based, POSIX, 14 inboxes confirmed
- soul-check: 8/9 pass (anatomy pattern missing — non-blocking)
- Ollama (MDES): reachable at https://ollama.mdes-innova.online
- Shared state: written to /tmp/manusat-shared.json
- innova contacted via mouth.sh, system-online broadcast sent to all 14 agents
