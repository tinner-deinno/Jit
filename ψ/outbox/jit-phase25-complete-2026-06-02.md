---
from: jit
timestamp: 2026-06-02T14:00:00Z
subject: phase25-complete
---

# Phase 25 Complete — innova-oracle 14th Provider — 2026-06-02

## Summary
1 commit, 27 unit tests. "Talk to innova-bot" fully wired via oracle RAG.
Session limit hit on 3 sub-agents — completed manually from file state.

## What Shipped

### innova-oracle (14th provider in motherDispatch)
- `getOracleToken()`: POST /api/auth/token → JWT cached 23h (no expiry risk)
- `callInnovaOracle()`: POST /api/oracle/consult with Bearer auth
  Returns: `[Oracle]\n{context}` from innova-bot knowledge base
- Config: `kind="ollama"`, `baseUrl=INNOVA_GATEWAY_URL||:8000`, key-free
- Dispatch: `else if (cfg.id === "innova-oracle") → callInnovaOracle`
- Always-on: exempt from key requirement (gateway = local, no key needed)
- Graceful offline: gateway down → request fails → circuit breaker marks failed → skipped

### Coverage updates (all 14)
- `providerHealthProbe.ts`: innova-oracle probe added (kind=openai, empty key → "configured")
- `agentLeaderboard.ts`: AGENT_CATALOGUE + CATALOGUE_ID_TO_PROBE_ID + DISPATCH_ID_TO_CATALOGUE_ID
- `MultiAgentPanel.tsx`: OracleRAG badge (emerald-700)
- `AgentLeaderboard.tsx`: Oracle badge (emerald-700)
- `admin/page.tsx`: chip updated "13 providers" → "14 providers"
- `.env.example`: INNOVA_GATEWAY_URL + GATEWAY_PORT documented

### Tests
- `motherDispatch.test.ts`: 13→14 provider count assertions — all pass
- 27 unit tests passing

## Full Provider Roster (14)

| # | ID | Name | Always-On |
|---|-----|------|-----------|
| 1 | mdes-cloud | MDES Cloud (gemma4:26b) | — |
| 2 | thai-llm | Thai LLM (qwen3.5:9b) | — |
| 3 | ollama-local | Local Ollama | ✅ |
| 4 | openai-gpt | OpenAI GPT | — |
| 5 | claude-haiku | Claude Haiku 4.5 | — |
| 6 | claude-sonnet | Claude Sonnet 4.6 | — |
| 7 | copilot | GitHub Copilot | — |
| 8 | gemini-pro | Gemini Pro | — |
| 9 | mistral-large | Mistral Large | — |
| 10 | deepseek-r1 | DeepSeek R1 | — |
| 11 | groq-llama | Groq LLaMA | — |
| 12 | together-llama | Together LLaMA | — |
| 13 | innova-bot | Innova-Bot (qwen2.5:0.5b) | ✅ |
| 14 | innova-oracle | Innova Oracle (RAG) | ✅ (when gateway up) |

## Next Session Priorities
1. **Push 20 commits to remote** — `git push` in innomcp dir
2. Phase 26: Admin Mother tab — show ranked win list (table not just leader)
3. Add E2E test for /api/mother/winner endpoint
4. Start innova-bot gateway: `cd C:/Users/USER-NT/innova-bot && start_sse.cmd`
   Then verify innova-oracle responds in mother dispatch

— Jit Oracle (จิต) ✅
จิตนำกาย — วิญญาณที่สถิตในทุก repo
