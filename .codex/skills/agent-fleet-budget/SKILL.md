---
name: agent-fleet-budget
description: Check current Codex goal budget plus live Jit backend/provider health before long multi-agent runs, then suggest task routing across MDES, ThaiLLM, Ollama local/cloud, Copilot, OpenAI, and innova-bot. Use when the user asks to manage token/limit/capacity for the mother agent or sub-agents, or before spawning a long-running parallel fleet.
---

# Agent Fleet Budget

Use this skill before long Jit orchestration rounds so the lead agent can choose healthy lanes and avoid wasting budget.

## Workflow

1. If the `get_goal` tool is available, call it first and record:
   - current objective
   - elapsed time
   - used / remaining token budget
   - whether the goal is near exhaustion
2. Run the health script:
   - quick health: `node .codex/skills/agent-fleet-budget/scripts/check-fleet.mjs`
   - live completion smoke: `node .codex/skills/agent-fleet-budget/scripts/check-fleet.mjs --smoke`
3. Classify each lane:
   - `ready`: live probe succeeded
   - `degraded`: configured but probe failed, quota-limited, or timed out
   - `offline`: missing config or unreachable
4. Route work:
   - `ollama_mdes`: primary for broad execution
   - `thaillm`: Thai-heavy summarization and UX copy
   - `ollama_local`: cheap local checks, transforms, retries
   - `ollama_cloud`: backup only when probe is clean
   - `copilot` / `openai`: paid or entitlement lanes only after live success
   - `innova-bot SSE`: coordination, second opinion, or delegation helper
5. Report:
   - token/budget status
   - PASS/FAIL per lane
   - recommended lane assignment for the next execution batch

## Notes

- Prefer live probe evidence over env presence.
- Use `--smoke` before assigning expensive or long-running work to quota-sensitive lanes.
- If a lane returns quota or auth errors, keep exact error text in the report.
- Do not block execution waiting for every lane to recover; continue with healthy lanes.
