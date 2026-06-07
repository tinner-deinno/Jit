---
pattern: Never spawn a subagent for a single deterministic command — inline calls fail visibly and retry cheaply; subagents burn quota and can stall the whole workflow
date: 2026-06-07
source: rrr: Jit
concepts: [subagents, quota, usage-limits, windows, python, node, rrr, workflow-resilience]
---

# Inline over subagent for deterministic one-shot commands

## What happened

`/rrr` (04 Jun 13:55) spawned a background timestamp-miner subagent per the
skill spec — for a single deterministic command (parse one .jsonl, print
timestamps). The subagent hit the **weekly usage limit** ("resets Jun 6,
1pm"), returned 8 tokens of error, and the retro stalled for **3 days** until
a human resumed it. On resume (07 Jun), the identical extraction ran inline
via a node one-liner in ~10 seconds.

## The rules

1. **Subagent threshold**: spawn only when the work needs parallel context,
   multiple steps, or genuine fan-out. One command + one file = inline.
   A subagent is a separate quota consumer and a separate failure domain —
   when it dies (rate limit, usage limit), the parent gets nothing and often
   can't tell why until the notification arrives.
2. **Quota awareness**: right after a marathon session (heavy token burn),
   treat usage limits as imminent. Prefer the cheapest execution path for
   bookkeeping tasks.
3. **Windows oracle corollary**: `python`/`python3` are landmines on Windows
   (Microsoft Store alias stub). Skill scripts embedding `python3 -c` must
   ship a node fallback. This repo already migrated `limbs/lib.sh`,
   `ollama.sh`, `oracle.sh`, `bus.sh` to Node.js (`c2f8942`) for the same
   reason — node is the reliable runtime on this fleet, python is not.
4. **Report-time state beats session-start state**: in a repo shared by
   parallel sessions/loops, re-run git immediately before writing any
   report/pending table. This session's snapshots went stale within an hour
   (commits `72e2128`, `31604c7` landed 50 min after the recap).

## Apply

- In `/rrr` on Windows: run the timestamp extraction inline with node
  (working one-liner is in retro `2026-06/07/19.47_orientation-retro-quota-stall.md`).
- Before spawning any background agent, ask: "is this one deterministic
  command?" If yes — inline.
