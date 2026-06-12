<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C10 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":140,"completion_tokens":808,"total_tokens":948} | 12s
 generated: 2026-06-12T19:29:16.678Z -->
# Token Economy & Provider Ladder

## Overview
Jit.Thai uses a tiered provider system to optimise cost vs. capability. Each layer is designed for specific workloads.

## Provider Ladder

| Tier | Provider | Role | Model |
|------|----------|------|-------|
| 1 (Cheapest) | CommandCode | Bulk code generation via proxy :4322 | – |
| 2 | Haiku subagent | Cheap exploration / tool-use | `CLAUDE_CODE_SUBAGENT_MODEL=haiku` |
| 3 | Sonnet subagent | Complex code / analysis | – |
| 4 (Most expensive) | Fable 5 main loop | Orchestration + subagent review ONLY | – |

> **Settings**: `MAX_THINKING_TOKENS` ≈ 10 000

## When to Use Which

- **CommandCode** — high‑volume boilerplate, simple codegen, low‑complexity scripts.  
- **Haiku** — quick prototyping, tool‑calling, broad exploration, cheap experiments.  
- **Sonnet** — intricate logic, deep reasoning, performance‑sensitive analysis, bug hunting.  
- **Fable 5** — **orchestration only**: decompose tasks, route to subagents, **review** their outputs, make meta‑decisions. **Never** for mechanical code writing.

## Cost-Discipline Checklist

- [ ] Is the task mechanical? → use CommandCode or Haiku, **never** Fable 5.  
- [ ] Can Sonnet handle it? → skip Fable 5 unless orchestration/SA review is needed.  
- [ ] Are thinking tokens exceeding 10 000? → split work or escalate to Sonnet earlier.  
- [ ] Are you about to call Fable 5 for a loop body? → **stop**: that’s burning tokens on mechanical work.  
- [ ] Have you set `CLAUDE_CODE_SUBAGENT_MODEL=haiku` for cheap subagents?  
- [ ] Is the proxy :4322 available? → prefer CommandCode for bulk jobs.

## Golden Rule

**Fable 5 must not be burned on mechanical work.**  
It orchestrates and reviews; it does not write raw code. Violations will inflate costs and degrade throughput.
