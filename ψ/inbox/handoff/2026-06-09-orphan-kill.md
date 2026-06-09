# 🧹 Housekeeping Action — Killed 2 Pre-Supervisor Orphan Loops

**Time**: 2026-06-09 08:46 UTC
**Action**: Killed orphan self-improve loops (pids 126283, 665261)
**Saved**: 2 redundant loop processes, ~0 CPU but real cleanup

## What happened

After the calm-down round 1 (07:22 UTC), the persistent supervisor was
started with 7 subshell loops. But **2 pre-supervisor self-improve
processes** were left running (started at 03:58 and 06:41 UTC, both
orphaned with PPID=1 when their parent shells exited).

| PID | Started | Uptime at kill | State |
|-----|---------|----------------|-------|
| 126283 | 03:58 UTC | 4h 46m | Stuck in old self-improve loop, never reaped |
| 665261 | 06:41 UTC | 1h 42m | Same — pre-supervisor, never killed |

Both were doing nothing useful (self-improve is on a 2h interval; they'd
already completed their first tick and were sleeping). The supervisor's
restart logic only restarts its own children, not pre-existing orphans.

## Why it matters

- 2 redundant bash processes holding memory + session slots
- Could mask real problems (status-broadcaster would have shown wrong "loops=9" count)
- Risk of duplicate work if the scripts modify shared state (low risk for self-improve, but still)

## Fix

`kill -TERM <pid>` for each orphan. Both exited cleanly (no zombie). After
65s wait, the supervisor re-checked and confirmed all 7 children still alive.

## Recommended Pattern

Add orphan cleanup to the supervisor's startup, before launching its own loops:

```bash
# At supervisor startup, kill any pre-existing loop orphans
for proc in $(ps -eo pid,cmd | grep -E "loop\.sh" | grep -v grep | awk '{print $1}'); do
  ppid=$(ps -o ppid= -p "$proc" 2>/dev/null | tr -d ' ')
  if [ "$ppid" = "1" ] || [ -z "$ppid" ]; then
    log "killing pre-existing orphan loop pid=$proc"
    kill -TERM "$proc" 2>/dev/null
  fi
done
sleep 5  # let them exit
```

This way, restarting the supervisor is idempotent — no orphan buildup
over time.

## Status Now

- ✅ Supervisor alive (pid 713076, 1h25m uptime)
- ✅ 7/7 children owned by supervisor
- ✅ 0 orphan loops
- ✅ All loop output to correct log files
- ✅ Status-broadcaster (the one with a "wrong log file" symptom) actually
  works fine — it logs to discord-broadcast.log, not status-broadcaster.log
  (this is by design in the script, not a bug)

🤖 Generated with Claude Code (https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
