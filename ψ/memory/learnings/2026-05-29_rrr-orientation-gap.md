---
pattern: Always read the agent inbox before writing a retro after a multi-day gap
date: 2026-05-29
source: rrr: Jit
concepts: [inbox, gap-recovery, situational-awareness, agentic-operations]
---

# Re-entry Protocol: Read Inbox Before Retro

When the orchestrator is offline for 2+ days, the message bus accumulates forward-looking signals from agents.
Running /rrr before reading those signals produces an accurate-but-incomplete retrospective.

**Rule**: on re-entry after a gap ≥ 24h, read `network/inbox/jit/` before running /rrr.
A 5-minute inbox scan closes the situational awareness gap and makes the retro more useful.

**Corollary**: agentic message buses need TTL or expiry. Design for orchestrator downtime — not just the happy path.

See also: [[project-innomcp-phase2]]
