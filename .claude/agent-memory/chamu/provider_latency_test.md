---
name: provider-latency-test
description: Provider latency measurement test for QA validation - measures response time for Claude, OpenAI, Ollama
metadata:
  type: project
---

## Provider Latency Test Framework

Created test harness at: `eval/provider-latency-test.sh`

### Test Details

**Purpose**: Measure and grade LLM provider response latencies to identify bottlenecks and performance degradation.

**Providers Tested**:
- `claude` (Anthropic via CommandCode proxy) - requires COMMANDCODE_API_KEY
- `openai` (GPT via OpenAI API) - requires OPENAI_API_KEY  
- `ollama` (MDES Ollama gemma4:26b) - requires OLLAMA_TOKEN

**Test Prompt**: "Hello, respond with 'ok'" (minimal, deterministic)

**Grading Scale**:
- `fast`: < 500ms
- `ok`: 500-2000ms
- `slow`: > 2000ms

### Running the Test

```bash
bash eval/provider-latency-test.sh           # Run silently, output JSON
bash eval/provider-latency-test.sh --verbose # Show [INFO]/[DEBUG] logs
bash eval/provider-latency-test.sh --json    # Same as default
```

### Output Format

```json
{
  "tests": [
    {"provider": "ollama", "latency_ms": 765, "success": 0, "speed": "ok"}
  ],
  "fastest": "ollama",
  "slowest": "ollama"
}
```

**Fields**:
- `provider`: provider name (claude, openai, ollama)
- `latency_ms`: total wall-clock time in milliseconds (includes timeout, marshaling)
- `success`: 0 = success, non-zero = failed
- `speed`: grade (fast/ok/slow) based on latency
- `fastest`: provider name with lowest latency among successful tests
- `slowest`: provider name with highest latency among successful tests

### Current Status (2026-06-08)

**Only Ollama is available**:
- OLLAMA_TOKEN present, endpoint reachable
- COMMANDCODE_API_KEY not set (Claude CLI unavailable)
- OPENAI_API_KEY not set (OpenAI unavailable)

**Ollama Baseline**:
- Typical latency: 738-1026ms (varies, model queuing effects)
- Speed grade: ok
- Test consistently passes

### Implementation Notes

- Uses provider adapter scripts from `limbs/providers/*.sh`
- Availability check runs before each test (verifies API keys + endpoint reachability)
- Tests are serial (one at a time) to avoid queue effects
- Latency includes full round-trip: marshaling, network, inference, parsing
- Failures are logged but not included in fastest/slowest calculation
- Script is independent - does not require Oracle or other services
