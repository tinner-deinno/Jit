---
date: 2026-06-07
iteration: 11
topic: guard-patterns
tags: [jq, gh, win-compat, guard, loop]
---

# Loop Iterations 10-11: Guard Pattern Consolidation

## Key Learnings

- **_shared/guards/ pattern works.** `gh-guard.md` (iter 10) and `jq-guard.md` (iter 11) live at `~/.claude/skills/_shared/guards/`. Centralizing guard snippets means AI can cite the canonical fix path rather than re-inventing it per skill.

- **Safe vs unsafe tool boundary:** `gh --jq` embeds gojq — no system binary, safe on Windows. Standalone `| jq` requires system install; `python3` is absent on stock Windows; `readlink -f` is GNU coreutils only. Node.js is always safe (ships with Claude Code environment).

- **Guard placement must be per-block, not per-file.** Shell state does not persist across code blocks in SKILL.md. Each bash block that calls `jq` needs its own `command -v jq` guard, not a single guard at file top.

- **"Too complex to replace" triggers guard, not node rewrite.** The auto-retrospective jq chain (nested `//0` defaults, arithmetic, string interpolation) is valid jq but risky to port to Node.js inline. An honest guard is safer than a broken node rewrite that miscomputes context%.

- **0 FAIL milestone required 11 iterations:** python3 purge (1-4), win-compat-lint 18-pattern engine (5-8), dependency-guard checker (9), gh-guard shared snippet + release/forward/trace patches (10), jq-guard + 9-file sweep (11). Each iteration targeted a distinct failure class — no wasted passes.
