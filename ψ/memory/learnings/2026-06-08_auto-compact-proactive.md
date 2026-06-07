---
name: 2026-06-08-auto-compact-proactive
description: Proactive auto-compact usage to prevent context overflow - never wait for 100%
metadata:
  type: learning
---

# Auto-Compact: Proactive Usage Rule

**Why**: Previous session crashed at context 100%. innova taught auto-compact skill and demanded it be used properly.

**How to apply**:
1. At 72% context → run `compact-manager.js --bg` immediately (silent, no announcement)
2. At 85% context → run `/rrr --quick` then `compact-manager.js --exec`, tell user to `/clear`
3. After any `/clear` → check `ψ/inbox/handoff/` for auto-compact files <15min old, run `/recap`
4. PROACTIVE: If conversation feels long, invoke auto-compact yourself without waiting for hooks
5. Teach all agents (soma, innova, vaja, etc.) about this skill via message bus
6. Log metrics to `ψ/memory/learnings/auto-compact-metrics.md`

**Key lesson**: "Context เหมือนน้ำในแก้ว — ต้องเทก่อนล้น ไม่ใช่รอให้ล้นแล้วค่อยเช็ด"

[[auto-compact]] [[context-management]] [[innova-feedback]]