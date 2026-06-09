---
name: project-architecture-audit-2026-06-08
description: 2026-06-08 soma architecture audit — agents/bus/memory all functional but bus has no consumer, heartbeat flatlined, DLQ growing unanswered
metadata:
  type: project
---

Architecture audit run 2026-06-08. Snapshot — re-verify before acting; operational counts decay fast.

**Structurally sound:** registry self-consistent, all agents have inbox + agents/*.json + .github/agents/*.agent.md, tier structure intact. mouth→bus→ear chain verified live. All 3 memory layers present (context state files, shared JSON valid, Oracle connected :47778).

**Live operational gaps found:**
- Registry has 15 agents now (added `lung`/ปอด, reports_to pran) but CLAUDE.md still says 14 — doc drift.
- Bus transports but nothing consumes: ~1513 pending, every agent inbox ~94 stuck msgs, mostly `heartbeat:IN/OUT` broadcast spam. No agent drains inboxes.
- Heartbeat flatlined ~5h (last beat 03:46, audit at 08:41) while heart.out.json still says "alive". Two zombie procs parked in S state (heart.sh monitor-oracle, scripts/heartbeat.sh start) not actually beating.
- DLQ 326 files. `broadcast:dlq-growing` self-alarm fired 27+ times into every inbox — no responder acted on it. Alerts have no handler.

**Why:** matters for any future orchestration work — the system self-reports healthy (body-check 97%) while the message plane is effectively dead-lettering. body-check.sh checks file *existence*, not liveness.

**How to apply:** Before trusting "system alive" signals, check heartbeat *freshness* (timestamp vs now) and inbox *drain rate*, not just process presence or file existence. The real fix needs: (1) inbox consumer/reaper, (2) heartbeat liveness watchdog, (3) an alert responder for broadcast:dlq-growing. See [[error-recovery-audit]].
