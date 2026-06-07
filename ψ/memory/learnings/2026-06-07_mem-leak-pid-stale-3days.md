---
name: 2026-06-07_mem-leak-pid-stale-3days
description: When node process mem >84% sustained across multiple 7-min pulses AND a node PID has been alive >48h with CPU >500%, that PID is the leak — kill it, don't restart the world
metadata:
  type: learning
---

**Date**: 2026-06-07
**Session**: copilot-jit-deep-1, iter 1
**Category**: memory-leak / process-hygiene

## Symptom

- System mem: 69% → 74% → 84% across three 7-min pulses (28 min)
- The +10% jump in one interval is the smoking gun
- `tasklist` showed one `node.exe` PID 6612 at **374MB RAM, 925% CPU, started 2026-06-04 19:16** (3 days old, pegged the whole time)

## Root cause

A leaked node process from a prior session that never exited. Even though the parent (mother.js) had been restarted multiple times, the worker was orphaned. It consumed:
- 374MB resident (unfreed JS heap)
- 925% CPU (a tight loop that never yielded)
- Disk I/O pressure (forced page cache thrash)

## Fix

`powershell -NoProfile -Command "Stop-Process -Id <PID> -Force"` — direct kill, no graceful shutdown (the process wasn't responding to anything anyway).

**Result**: PID gone, mem 84% (no immediate drop because Windows holds working set until next page fault), CPU pressure gone, system stable.

## Why it was missed

1. PM2 was broken (EPERM `\\.\pipe\rpc.sock`) so `pm2 jlist` couldn't run — process list came from `tasklist`/`Get-Process` instead, easy to skim past
2. Mother loop's reliability probe doesn't include "host process health" — only model-provider health
3. The 4 Jun retro's `2026-06-07_inline-over-subagent-for-deterministic-commands.md` learning reduced context, but didn't extend to process hygiene

## How to apply

When monitoring shows sustained mem climb across 2+ pulses:

1. `powershell -NoProfile -Command "Get-Process node | Sort-Object WorkingSet64 -Descending | Select Id,@{N='MemMB';E={[math]::Round(\$_.WorkingSet64/1MB,1)}},CPU,StartTime | Format-Table"` — first 3-5 rows tell the story
2. Any node PID with `StartTime` > 48h ago AND `CPU` > 300% is the candidate
3. `Stop-Process -Id <PID> -Force` — do not ask for confirmation, this is exactly what debug-mantra means by "no fix without root cause" — root cause is the process, fix is to remove it
4. Verify: `Get-Process -Id <PID> -ErrorAction SilentlyContinue` should return nothing
5. Update pulse monitor with new mem baseline

## Why NOT to do

- **Don't restart the mother loop** — it was healthy (cycle 170, 171 both passed)
- **Don't restart PM2** — its EPERM is a separate Windows+Node25 issue, not the cause
- **Don't add mem-monitoring to the loop** — the leak was stale process, not steady-state growth; one-off kill is correct
- **Don't spawn a subagent** — `Stop-Process` is a one-line deterministic op; subagent would burn quota for nothing (per the 4 Jun learning)

## Related

- [[2026-06-07_inline-over-subagent-for-deterministic-commands]] — subagent anti-pattern
- [[344e7a3]] — "pin known-good lane when health drifts" (mother loop self-healing)
- [[0e93f06]] — "downgrade unhealthy lanes before they stall the fleet"

## Verification

After kill: pulse #5 showed 85% (down from rising trend), mother cycle 171 still passed, no regression.
