# Chain-of-Thought Logging

> **JIT-022** — Structured reasoning trace for agent decision-making

## Overview

Chain-of-Thought (CoT) logging captures the **reasoning steps** behind every significant decision made by agents. This enables self-reflection, debugging of decision-making patterns, and learning from mistakes across sessions.

## Philosophy

> "สัมมาสังกัปปะ — ความดำริชอบ"  
> Before acting, understand why. Before deciding, trace the reasoning.

## Log Format

CoT logs are stored in **JSONL format** (one JSON object per line) at `/tmp/manusat-cot-log.jsonl`.

### Entry Structure

```json
{
  "agent": "innova",
  "timestamp": "2026-06-08T04:30:00+07:00",
  "intent": "implement feature X",
  "step": 1,
  "substeps": ["understand", "plan", "execute"],
  "oracle_queries": 2,
  "decision": "sequential",
  "context": {
    "task": "Add health tracking to registry",
    "constraints": ["no breaking changes", "backward compatible"],
    "options_considered": ["direct update", "migration script"]
  },
  "rationale": "Chose direct update because schema is additive only",
  "outcome": "success"
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `agent` | string | Agent that made the decision |
| `timestamp` | ISO 8601 | When the decision was made |
| `intent` | string | What the agent intended to accomplish |
| `step` | integer | Step number in the reasoning chain |
| `substeps` | array | Granular actions within this step |
| `oracle_queries` | integer | Number of knowledge base queries made |
| `decision` | string | Decision pattern used |
| `context` | object | Relevant task context |
| `rationale` | string | Why this decision was chosen |
| `outcome` | string | Result: `success`, `failure`, `partial` |

## Usage

### View Recent CoT Logs

```bash
# Show last 10 reasoning chains
bash limbs/think.sh log --cot
```

Example output:
```
=== Chain-of-Thought Logs (Last 10 Entries) ===

[2026-06-08T04:30:00] innova — implement feature X
  Steps: understand → plan → execute
  Oracle queries: 2
  Decision pattern: sequential
  Rationale: Chose direct update because schema is additive only
  Outcome: success

[2026-06-08T04:25:00] soma — architectural review
  Steps: analyze → compare → decide
  Oracle queries: 3
  Decision pattern: comparative
  Rationale: Selected Option B for better long-term maintainability
  Outcome: success
```

### Search CoT Logs

```bash
# Find all decisions related to a topic
grep "registry" /tmp/manusat-cot-log.jsonl | jq .

# Find failed decisions
grep '"outcome": "failure"' /tmp/manusat-cot-log.jsonl | jq .

# Find decisions by a specific agent
grep '"agent": "innova"' /tmp/manusat-cot-log.jsonl | jq .
```

### Analyze Decision Patterns

```bash
# Count decisions by pattern
cat /tmp/manusat-cot-log.jsonl | jq -r '.decision' | sort | uniq -c

# Average oracle queries per decision
cat /tmp/manusat-cot-log.jsonl | jq -s '[.[].oracle_queries] | add / length'

# Success rate
cat /tmp/manusat-cot-log.jsonl | jq -s 'group_by(.outcome) | map({outcome: .[0].outcome, count: length})'
```

## Integration with think.sh

The `think.sh` script now logs reasoning when using the `plan` command:

```bash
# Plan with automatic CoT logging
bash limbs/think.sh plan "Add new endpoint" "API expansion for mobile team"
```

This triggers:
1. Oracle query for existing patterns
2. Step documentation (understand → plan → execute)
3. Decision rationale recording
4. Log entry written to `/tmp/manusat-cot-log.jsonl`

## Decision Patterns

Common decision patterns observed in the system:

| Pattern | Description | When Used |
|---------|-------------|-----------|
| `sequential` | Step-by-step execution | Linear tasks with clear dependencies |
| `comparative` | Evaluate multiple options | Architecture decisions, trade-offs |
| `iterative` | Cycle until convergence | Refinement tasks, optimization |
| `oracle-first` | Query knowledge before acting | Unfamiliar domains, compliance checks |
| `reflex` | Immediate action | Emergency responses, known patterns |

## Retrospectives

Soma uses CoT logs for periodic retrospectives:

```bash
# Generate retrospective report
bash minds/soma-retro.sh --cot --period weekly
```

This analyzes:
- Decision patterns over time
- Common failure modes
- Oracle query efficiency
- Agent-specific tendencies

## Example Scenarios

### Scenario 1: Debugging a Bad Decision

```bash
# Something went wrong — find the decision that caused it
# Step 1: Find recent failures
grep '"outcome": "failure"' /tmp/manusat-cot-log.jsonl | tail -5 | jq .

# Step 2: Examine the rationale
# Look for gaps in reasoning or missing constraints

# Step 3: Check oracle_queries count
# Low numbers may indicate insufficient research

# Step 4: Review options_considered
# May reveal tunnel vision or missed alternatives
```

### Scenario 2: Learning from Success

```bash
# Capture successful patterns for future reference
# Step 1: Find successful decisions on similar topics
grep "registry" /tmp/manusat-cot-log.jsonl | grep '"outcome": "success"' | jq .

# Step 2: Extract common patterns
# Look for repeated decision patterns, oracle usage, substeps

# Step 3: Save as Oracle knowledge
bash limbs/oracle.sh learn "successful-pattern" "..." "decision-making,pattern"
```

### Scenario 3: Agent Behavior Analysis

```bash
# Compare decision-making across agents
# innova vs soma decision speeds
grep '"agent": "innova"' /tmp/manusat-cot-log.jsonl | jq -s 'length'
grep '"agent": "soma"' /tmp/manusat-cot-log.jsonl | jq -s 'length'

# Success rates by agent
cat /tmp/manusat-cot-log.jsonl | jq -s '
  group_by(.agent) | 
  map({
    agent: .[0].agent,
    total: length,
    success: map(select(.outcome == "success")) | length,
    failure: map(select(.outcome == "failure")) | length
  })
'
```

## Configuration

### Log Location

```bash
COT_LOG_FILE="/tmp/manusat-cot-log.jsonl"
```

### Retention

Logs are stored in `/tmp` and persist across sessions but not reboots. For permanent retention:

```bash
# Archive CoT logs to project directory
cp /tmp/manusat-cot-log.jsonl memory/archive/cot-log-$(date +%Y%m%d).jsonl
```

## Best Practices

1. **Log every significant decision** — Not just code changes, but architectural choices
2. **Include rationale** — The "why" is more important than the "what"
3. **Record options considered** — Future agents can learn from rejected alternatives
4. **Track oracle usage** — High query counts may indicate knowledge gaps
5. **Review regularly** — Schedule periodic CoT log reviews for continuous improvement

## Files and Paths

| Path | Purpose |
|------|---------|
| `/tmp/manusat-cot-log.jsonl` | Primary CoT log file |
| `limbs/think.sh` | Script that generates CoT entries |
| `memory/archive/cot-log-*.jsonl` | Archived historical logs |

## Related Documentation

- [[memory-embeddings]] — Semantic search across decisions
- [[registry-health]] — Track agent decision latency
- [[message-tracing]] — Trace decision propagation through messages

---

*Document version: 1.0 | Created: 2026-06-08 | Owner: innova*
