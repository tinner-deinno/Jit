---
name: provider_test_baseline
description: Provider latency baseline test results — Claude 11092ms, Ollama 1805ms, OpenAI/Codex unavailable
metadata:
  type: reference
---

## Provider Performance Baseline Test
**Date**: 2026-06-08  
**Tester**: chamu (QA)

### Test Results

| Provider | Available | Latency | Model | Grade |
|----------|-----------|---------|-------|-------|
| Ollama | Yes | 1805ms | gemma4:26b | **FAST** |
| Claude | Yes | 11092ms | claude-sonnet-4-6 | OK |
| OpenAI | No | — | gpt-4o-mini | SKIPPED (no key) |
| Codex | No | — | gpt-5-codex | SKIPPED (not installed) |

### Key Findings

1. **Ollama is 6.1x faster** than Claude (1.8s vs 11s)
2. **Both available providers work** — system can route fallbacks
3. **OpenAI and Codex need setup**:
   - OpenAI: Set `OPENAI_API_KEY` environment variable
   - Codex: Install `codex` CLI tool
4. **System ready**: At least 2 providers operational, fallback chain functional

### Routing Recommendations

**Primary**: Ollama (fastest for real-time responses)  
**Fallback**: Claude (quality, higher latency acceptable)  
**Future**: OpenAI for redundancy once key is set

### Testing Pattern (for repeat tests)

```bash
# Fast latency test
START=$(date +%s%N)
timeout 20 claude "respond: OK" 2>&1
END=$(date +%s%N)
echo "$(( (END - START) / 1000000 ))ms"

# Ollama test
curl -s --max-time 25 https://ollama.mdes-innova.online/api/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OLLAMA_TOKEN" \
  -d '{"model":"gemma4:26b","messages":[{"role":"user","content":"test"}],"stream":false}'
```

### Environment Status
- `.env` loaded: Yes (COMMANDCODE_API_KEY, OLLAMA_TOKEN set)
- Message bus: Operational (121 pending messages)
- LLM gateway (`limbs/llm.sh`): Operational
- All 14 agents: Ready
