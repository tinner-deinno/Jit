# .GCC — Git Checkpoint Control

This directory tracks stable state checkpoints for the Jit agent system.

## Structure

```
.GCC/
  main.md              — this file (index)
  branches/
    main/
      log.md           — timestamped bootstrap/event log
      commit.md        — last known good commit info
      metadata.json    — branch metadata (node, date, status)
```

## Policy

- Only stable, verified states are checkpointed here.
- Git is NOT used as a high-frequency message bus.
- Heartbeat commits go to memory/state/heartbeat.log (tracked).
- Runtime/tmp data stays in /tmp (untracked).

## Node

**PC3-Jit** — Codespace bootstrap node (codespaces-a07d24)
Bootstrapped: 2026-05-05
