---
name: jit-subagent-orchestrator
description: Orchestrate Jit sub-agents with GPT-5.5 as lead, route work across MDES/ThaiLLM/Ollama local/cloud, and collaborate with innova-bot over MCP SSE for verified execution.
---

# Jit Subagent Orchestrator

Use this skill when the user asks to run or coordinate multiple sub-agents in `Jit` with innova-bot collaboration.

## Mission

- Lead agent: GPT-5.5 (planner/verifier/orchestrator).
- Worker agents: fast model lanes for execution and checks.
- Runtime backends: `ollama_mdes`, `thaillm`, `ollama_local`, `ollama_cloud`, with `copilot/openai` fallback when available.
- MCP collaboration: talk to innova-bot via `http://127.0.0.1:7010/sse`.

## Startup Checklist

1. Verify auth and base services.
2. Print backend readiness from `hermes-discord/model-router.js` `status()`.
3. Verify innova-bot SSE with:
   - `C:\Users\USER-NT\DEV\innova-bot-template\devtools\innova-bot\scripts\e2e_mcp_sse.py --url http://127.0.0.1:7010/sse --timeout 20`
4. Run one live prompt per enabled backend before spawning parallel work.

## Routing Contract

- GPT-5.5 keeps global plan and acceptance criteria.
- Assign bounded tasks to children:
  - `explore` style child: repo lookup, file mapping.
  - `executor` style child: isolated code change.
  - `verifier` style child: test + evidence extraction.
- Never let children mutate shared critical files in parallel.

## Backend Policy

- Primary order:
  - `ollama_mdes -> thaillm -> ollama_local -> ollama_cloud`
- Paid/entitlement lanes:
  - `copilot`, `openai` only when verified live in current session.
- If a lane fails:
  - mark lane `degraded`
  - continue with remaining healthy lanes
  - preserve exact error text in report

## innova-bot Collaboration Pattern

1. Connect SSE.
2. List tools.
3. Call one coordination tool (`what_should_i_do_next` or `ask_local_ai`).
4. Feed response to GPT-5.5 planner for next action.

## Done Criteria

- Backend matrix tested and recorded.
- At least one successful innova-bot tool call in-session.
- Sub-agent work integrated by lead with verification evidence.
- Final summary includes:
  - PASS/FAIL per backend
  - innova-bot call evidence
  - residual blockers and exact remediation.
