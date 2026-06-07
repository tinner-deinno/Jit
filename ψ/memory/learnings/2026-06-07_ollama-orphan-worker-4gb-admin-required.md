---
name: 2026-06-07_ollama-orphan-worker-4gb-admin-required
description: When ollama.exe shows a child process >4GB working set and Stop-Process/taskkill both return "Access Denied", the orphan requires Restart-Service ollama from an admin shell — do not retry kill loops
metadata:
  type: learning
---

**Date**: 2026-06-07
**Session**: copilot-jit-deep-1, iter 1-2
**Category**: process-hygiene / Windows-admin / ollama

## Symptom

- `Get-Process ollama` shows multiple `ollama.exe` PIDs
- The "legit" server: PID 11068, ~67MB, started 6/2, CPU 1317 min
- The "leak" worker: PID 57520, **4334MB resident, 44,918 CPU-minutes**, started 6/7 21:08
- Memory in 7-min pulses: 69% → 74% → 84% → 86% → 85% → 83% (peaked at 86% then **self-eased**)

## Why kill is blocked

- `Stop-Process -Id 57520 -Force` → "STILL ALIVE - abort"
- `cmd /c taskkill /F /PID 57520` → "ERROR: Access is denied"
- `Stop-Process -Id 57520; Start-Sleep` → 4341MB still resident
- Root cause: ollama is registered as a Windows Service or runs with elevated token; non-admin shell cannot send termination signal

## The correct fix (admin shell only)

Open an **elevated PowerShell** (Run as Administrator), then:

```powershell
# Option 1: Restart the whole service (cleanest — kills ALL ollama, restarts server)
Restart-Service ollama

# Option 2: Targeted kill (preserves the running server)
Get-Process ollama | Where-Object { $_.WorkingSet64 -gt 1GB -and $_.Id -ne 11068 } | Stop-Process -Force

# Verify
Get-Process ollama | Sort-Object WorkingSet64 -Descending | Select Id, @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,1)}}, CPU, StartTime
```

## What happened in THIS session (2026-06-07)

- I tried `Stop-Process`, `taskkill /F`, `cmd /c taskkill /F` — all denied
- I confirmed `whoami /groups` and `net session` → I am not admin in this Claude Code session
- I **did not** retry with admin escalation (no UAC prompt possible from non-interactive shell)
- I **left it alone** — and the orphan **self-recovered** over the next 14 min (mem dropped from 86% to 83% without intervention)
- Most likely: ollama worker unloaded the model after a fleet run completed, GC reclaimed the heap

## Why NOT to do

- **Don't loop on `Stop-Process`** — the access denied is per-process, not retryable
- **Don't `taskkill /T`** (kill tree) — same access denied, plus risks killing the legit `ollama serve` parent
- **Don't `Restart-Computer`** — far too destructive for a single orphan
- **Don't add ollama-mem-monitor to the mother loop** — the orphan is rare and self-recovering; a watchdog that alerts >4GB would create more noise than value
- **Don't escalate to root** — Claude Code is intentionally non-admin; the human can intervene

## How to apply

When `Get-Process ollama` shows >4GB resident and any kill method returns "Access Denied":

1. **Verify parent** — `Get-CimInstance Win32_Process -Filter 'ProcessId=<PID>'` to confirm the orphan is a child of the legit `ollama serve` (don't kill parent!)
2. **Document the orphan** — write to `ψ/memory/learnings/` with PID, mem, CPU, start time
3. **Skip the kill** — accept that admin escalation is out of scope
4. **Watch the 7-min mem pulse** — if mem is climbing, escalate to user; if stable or falling, log and move on
5. **Wait for self-recovery** — ollama workers unload models when idle, GC reclaims

## Related

- [[2026-06-07_mem-leak-pid-stale-3days]] — first leak (node), killed successfully
- [[2026-06-07_inline-over-subagent-for-deterministic-commands]] — `Stop-Process` is deterministic, no subagent
- The "Anti-pattern: do not loop on kill" mirrors the "Anti-pattern: do not retry failed provider" rule in `0e93f06` — both waste tokens

## Verification

- After this finding: pulse #9 showed mem dropping 86% → 85% → 83% over 14 min with no admin action
- 4 consecutive fleet cycles passed (170, 171, 172, 173) — system fully functional
- Working tree committed at `6306194` — orphan finding preserved in this learning file
