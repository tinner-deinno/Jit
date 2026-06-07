---
pattern: A focused skill-development loop (12 iterations, ~54k tokens/iter) can systematically improve 139+ skill files, build 5 new tools, and pivot from hygiene to capability — all autonomously
date: 2026-06-07
source: loop: Jit
concepts: [loop, skill-dev, windows-compat, a2a, organ-pulse, win-compat-lint, dependency-guard, autonomous]
---

# Loop Learning: 12 Iterations of Autonomous Skill Development

## Summary

Between 2026-06-04 and 2026-06-07, a `/loop` session ran 13 iterations autonomously across the Jit Oracle repo, systematically transforming the skill layer from fragile (platform-broken, dependency-blind) to robust (Windows-compat, dependency-guarded, A2A-capable). Final state: 0 FAIL across 139 skills, 5 new tools, bidirectional organ messaging.

---

## What Was Built (by Phase)

### Phase 1 — Hygiene Foundation (Iterations 1–4)
- Identified 26+ skills using `python3` (not available on Windows)
- Built `dig-node.js` — Node.js replacement for `python3 -c "..."` one-liners (date math, JSON ops)
- Patched every failing skill; achieved **0 FAIL across 139 skills**
- Established the "read before edit" discipline (Read tool required before any Edit)

### Phase 2 — Windows Compatibility (Iterations 5–8)
- Built **win-compat-lint** skill: 18 lint patterns for common Windows-incompatible shell idioms
  - Detects: `python3`, `#!/bin/bash`, `$()` in SKILL.md examples, `/usr/bin/env`, `&&` chains, etc.
  - Added `--fix` mode for automated remediation
  - Runs automatically before any SKILL.md write (triggered via pre-write hook)
- Built **skills-list.js** — inventory tool that reports skill count, profile tier, type, script status

### Phase 3 — Dependency Guards (Iterations 9–11)
- Built **dependency-guard** skill: checks CLI tools before skill execution
  - Guards: `gh`, `jq`, `bun`, `docker`, `tmux`, `fzf`
  - Returns INSTALLED (version) or MISSING with platform-specific install instructions
- Built **gh-guard**: wraps `gh` calls, fails fast with helpful message if not installed
- Built **jq-guard**: wraps `jq`, suggests Node.js `JSON.parse` alternative on Windows
- Patched 12+ skills that called guarded CLIs without checking

### Phase 4 — A2A Capability (Iterations 12–13)
- Built **organ-pulse** skill: Node.js bus bridge for sending messages to all 14 organs
  - Bus format: `/tmp/manusat-bus/<organ>/<ms-epoch>_from-<sender>.msg`
  - Message header: `from/to/subject/timestamp/---/body`
  - `--inbox` mode: non-destructive peek at any organ's inbox
  - `--wait` mode (iter 13): correlation-id polling for bidirectional reply-wait
    - Embeds `[corr-id: pulse-<ts>-<rand4hex>]` in body
    - Polls jit's inbox every 500ms; matches `reply:` subject + corr-id
    - Graceful timeout with message ID preserved for debugging
- Verified: message files are bus-compatible with `mouth.sh` / `ear.sh` shell agents

---

## 5 New Skills Created

| Skill | Purpose |
|-------|---------|
| **win-compat-lint** | 18-pattern Windows compatibility linter for SKILL.md files; --fix mode |
| **dependency-guard** | Pre-flight CLI checker (gh, jq, bun, docker, tmux, fzf) before skill execution |
| **organ-pulse** | A2A bus bridge: send/receive messages to 14 organs from any Claude Code session |
| **auto-compact** | Context compression daemon; fires at 72%/85% thresholds; writes handoff to ψ/inbox/ |
| **_shared/guards/** | Reusable guard modules (gh-guard.js, jq-guard.js) imported by multiple skills |

---

## Token Efficiency (~54k/iteration average)

**What worked:**
- Each iteration started with a precise context block ("Iterations 1-N complete, your task is...") — no re-exploration needed
- Advisor called once per major design decision (bus protocol, lint replacement rules), not every step
- Reports were factual and dense (≤200 words) — became the next iteration's context without bloat
- Parallel tool calls: Read + Glob + Grep in one message instead of sequential
- Write/Edit only after full understanding — no throwaway drafts

**What to avoid:**
- Don't re-read files you just edited (Edit confirms success; no verification read needed)
- Don't call advisor for implementation details — only for design choices with non-obvious tradeoffs
- Don't pad reports with "I did X, then Y, then Z" — just results + key finding

---

## Loop Design Rules (Learned Empirically)

1. **One concrete deliverable per iteration — never partial.** Each iteration must end with a testable artifact. "Added --wait flag but didn't test it" = partial = wasted iteration.

2. **Call advisor() before complex design choices.** Bus protocol (flat header vs JSON?), lint rule replacement strategies, correlation-id design — these warrant a second opinion. Implementation mechanics do not.

3. **Pivot when a domain is exhausted.** After Phase 1 reached 0 FAIL, continuing to fix hygiene had diminishing returns. Pivoting to win-compat-lint (Phase 2) unlocked a new class of value. Know when to shift.

4. **Each iteration's report becomes the next iteration's context — keep reports factual.** Avoid interpretation; stick to what was built, what was tested, what the output was. Vague reports ("improved things") force the next iteration to re-explore.

---

## How to Restart This Loop (Future Session)

```bash
# Start iteration 14
/loop "Continue skill development loop from iteration 14. Read the learning file first."

# State file (loop progress)
# C:/Users/USER-NT/Jit/.claude/ralph-loop.local.md

# Full context
# C:/Users/USER-NT/Jit/ψ/memory/learnings/2026-06-07_loop-12-iterations-skill-dev.md
```

**Current state entering iteration 14:**
- organ-pulse --wait: implemented and tested (5s timeout path verified)
- Bus: write-compatible with mouth.sh/ear.sh
- All 139 skills: 0 FAIL, Windows-compat, dependency-guarded
- Next frontier: real agent reply-wait integration test OR skill quality metrics dashboard

**Recommended iteration 14 task:** skill quality metrics dashboard — see "Iteration 14 Recommendation" below.

---

## Iteration 14 Recommendation

**Build a skill quality metrics dashboard** (`~/.claude/skills/_shared/scripts/skill-metrics.js`).

Why: The loop has produced 139 patched skills + 5 new tools. We now have no visibility into which skills are actually used, which have test coverage, which are stale. A metrics script that outputs:
- Total skills by profile tier (core/standard/plugin)
- Skills with scripts vs SKILL.md-only
- Last-modified dates (staleness ranking)
- Win-compat-lint pass/fail count
- Dependency-guard coverage

...would close the loop on observability. It's the natural capstone for a hygiene+capability loop: you can't maintain what you can't measure.

The organ-pulse --wait integration test (option A) requires a live agent to be running, which isn't currently guaranteed. Metrics (option B) is fully self-contained and delivers permanent value to every future session.
