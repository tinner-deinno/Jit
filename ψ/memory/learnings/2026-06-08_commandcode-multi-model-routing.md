---
pattern: commandcode is a 28-model hub (including Claude Pro tier) — design routing to exploit multi-model budget separation
date: 2026-06-08
source: rrr: Jit
concepts: [commandcode, provider-routing, fleet, budget, cc-agents]
---

# commandcode: Multi-Model Hub for Budget-Separated Fleet Work

## What

commandcode provider carries 28 models including Claude Sonnet 4.6, Opus 4.8, GPT-5.5, DeepSeek V4 Pro/Flash, Qwen3.7-Max, Gemini 3.5-Flash — all under a separate purchase budget from Claude Pro session.

## Why it matters

Claude Pro session has daily/weekly limits that block long-running fleet work. commandcode allows running Claude-tier models without consuming Pro quota — enabling a two-tier routing strategy:
- **Tier A (Pro session)**: jit/soma/innova orchestration (low volume, high reasoning)
- **Tier B (commandcode budget)**: cc-agents batch work (high volume, expendable)

## Routing rule

```
MULTI_BACKEND_ORDER: ollama_mdes, commandcode, thaillm, ollama_local
COMMANDCODE_MODEL:
  - code tasks: claude-sonnet-4-6 or deepseek/deepseek-v4-pro
  - batch throughput: deepseek/deepseek-v4-flash (fast, cheap)
  - Thai language: Qwen/Qwen3.7-Max or thaillm
```

## Gap identified

cc-agents (12 agents designed for commandcode) not yet wired into fleet dispatch. Fleet ran thaillm-only in last batch. Need to add commandcode to BACKEND_ORDER and verify cc-agents participate.

## Verify before declaring ready

Agent definition files ≠ dispatch participation. Run `node mother.js status` to confirm actual routing, not just registry count.
