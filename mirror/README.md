# Mirror — External Repo Clones (study only)

This directory contains local clones of external repositories used for study
and reference by Jit agents. **Contents are not tracked in git** — each clone
must be re-fetched per node.

## Current mirrors

| Path | Upstream | Purpose | Cloned by |
|------|----------|---------|-----------|
| `aoengaoey/` | https://github.com/Soul-Brews-Studio/aoengaoey | Evergreen-Harness study (Hono v4 + Ollama + gemma4 patterns) | innova, 2026-06-09 |

## Why not tracked

- Mirror clones are large (aoengaoey = ~230MB with `.git`).
- They duplicate the upstream history (which we can fetch on demand).
- Agent study code should reference patterns, not embed upstream sources.

## How to re-clone

```bash
# aoengaoey (Evergreen-Harness)
git clone https://github.com/Soul-Brews-Studio/aoengaoey.git mirror/aoengaoey
```

## See also

- ψ/memory/traces/2026-06-08/1935_workshop-02-voice-bot.md — references aoengaoey voice patterns
- ψ/memory/learnings/2026-06-08_phase2-compile-clean.md — Hono v4 patterns from aoengaoey
