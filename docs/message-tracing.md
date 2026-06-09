# Message Tracing

> **JIT-021** — Correlation IDs and trace chains for cross-agent message debugging

## Overview

Every message sent through the bus now carries a **correlation ID** and **trace chain** that enables full journey tracking from sender to final recipient. This is essential for debugging stuck messages, identifying bottlenecks, and measuring inter-agent latency.

## Key Concepts

| Term | Description |
|------|-------------|
| **correlation-id** | Unique 8-character ID assigned to each message |
| **trace-chain** | Arrow-separated path of agents the message visited (e.g., `vaja→jit→soma→innova`) |
| **hop_count** | Number of hops the message has taken |
| **timestamp_chain** | Comma-separated timestamps for each hop |

## Message Format

Every message includes these tracing headers:

```
from:vaja
to:jit
subject:task:report-status
timestamp:2026-06-08T04:30:00
correlation-id:abc12345
trace-chain:vaja→jit→soma
hop_count:3
timestamp_chain:2026-06-08T04:30:00,2026-06-08T04:30:01,2026-06-08T04:30:02
---
message body here
```

## How Tracing Works

### 1. Message Creation

When `mouth.sh` sends a message:

```bash
bash organs/mouth.sh tell innova "Implement feature X"
```

The bus generates:
- A new `correlation-id` (UUID prefix)
- Initial `trace-chain` starting with sender
- `hop_count: 0`
- `timestamp_chain` with creation time

### 2. Message Forwarding

When an agent forwards a message to another agent, the bus:
- Appends current agent to `trace-chain`
- Increments `hop_count`
- Appends current timestamp to `timestamp_chain`

### 3. Message Completion

When the final recipient reads the message, the full journey is recorded and can be queried.

## Usage

### Trace a Message by Correlation ID

```bash
# View full journey of a specific message
bash network/bus.sh trace abc12345
```

Example output:
```
=== Message Trace: abc12345 ===

   Found 3 message(s) in trace chain

   📬 Hop 1: vaja → jit
      subject: task:report-status
      timestamp: 2026-06-08T04:30:00
      trace-chain: vaja→jit
      hop_count: 1
      timestamp_chain: 2026-06-08T04:30:00,2026-06-08T04:30:01
      status: read

   📬 Hop 2: jit → soma
      subject: task:report-status
      timestamp: 2026-06-08T04:30:01
      trace-chain: vaja→jit→soma
      hop_count: 2
      timestamp_chain: 2026-06-08T04:30:00,2026-06-08T04:30:01,2026-06-08T04:30:02
      status: pending

   Total trace latency: 2000.0ms
```

### View Latency Statistics

```bash
# Show average latency per agent pair
bash network/bus.sh stats --trace
```

Example output:
```
Latency Traces (avg per agent pair):
   vaja→jit: avg=45.2ms min=12.0ms max=120.0ms (n=15)
   jit→soma: avg=89.5ms min=34.0ms max=245.0ms (n=12)
   soma→innova: avg=156.3ms min=78.0ms max=890.0ms (n=8)
   innova→chamu: avg=23.1ms min=5.0ms max=67.0ms (n=20)
```

### Identify Slow Paths

Messages taking longer than 1 second are flagged by netra:

```bash
# Netra reports slow message paths
bash organs/eye.sh check-latency
```

## Configuration

### Sampling for Response Time

Response times are sampled every 10th message to reduce overhead. Configured in `network/bus.sh`:

```bash
BUS_COUNTER_FILE="/tmp/manusat-bus-counter.json"
```

### Latency Thresholds

| Metric | Warning Threshold | Critical Threshold |
|--------|-------------------|-------------------|
| Per-hop latency | > 500ms | > 1000ms |
| End-to-end latency | > 2000ms | > 5000ms |
| Queue depth | > 50 messages | > 100 messages |

## Debugging Scenarios

### Scenario 1: Stuck Message

```bash
# User reports message not delivered
# Step 1: Find the correlation ID from sender logs
# Step 2: Trace the message
bash network/bus.sh trace abc12345

# Step 3: Check where it's stuck
# If status shows "pending" at a specific hop, check that agent's inbox
bash network/bus.sh queue

# Step 4: Check if agent is offline
cat network/registry.json | jq '.agents[] | select(.name == "soma") | {health_status, last_heartbeat}'
```

### Scenario 2: Performance Bottleneck

```bash
# System seems slow
# Step 1: Check latency stats
bash network/bus.sh stats --trace

# Step 2: Identify slow agent pairs
# Look for high average latency or high max latency

# Step 3: Check queue depths
bash network/bus.sh metrics

# Step 4: Check if DLQ is growing (messages failing)
bash network/bus.sh dlq depth
```

### Scenario 3: Message Loop Detection

```bash
# Suspicious: same message appearing multiple times
# Step 1: Trace all messages with similar correlation IDs
bash network/bus.sh trace abc12345

# Step 2: Look for cycles in trace-chain
# A trace-chain like "a→b→c→a" indicates a loop

# Step 3: Check hop_count - unusually high numbers indicate looping
```

## Programmatic Access

### JSON Output

```bash
# Get metrics in JSON format for dashboards
bash network/bus.sh stats --json
bash network/bus.sh metrics --json
```

### Python Example

```python
import json
import glob
from datetime import datetime

bus_root = "/tmp/manusat-bus"

def find_messages_by_correlation_id(corr_id):
    messages = []
    for pattern in ["*.msg", "*.read"]:
        for msg_file in glob.glob(f"{bus_root}/*/{pattern}"):
            with open(msg_file) as f:
                content = f.read()
                if f"correlation-id:{corr_id}" in content:
                    messages.append(parse_message(content))
    return messages

def parse_message(content):
    metadata = {}
    body_start = False
    for line in content.split('\n'):
        if line == "---":
            body_start = True
            continue
        if body_start:
            break
        if ":" in line:
            key, value = line.split(":", 1)
            metadata[key] = value.strip()
    return metadata
```

## Files and Paths

| Path | Purpose |
|------|---------|
| `/tmp/manusat-bus/<agent>/P{1,2,3}/*.msg` | Message files with trace headers |
| `/tmp/manusat-bus-counter.json` | Sampling counter for response times |
| `/tmp/manusat-bus-metrics.json` | Aggregated metrics per agent |
| `network/registry.json` | Agent health and queue depth |

## Best Practices

1. **Always include correlation-id in logs** — When debugging, reference the correlation ID
2. **Check trace-chain for routing issues** — Unexpected paths indicate misconfiguration
3. **Monitor hop_count** — Messages should typically have 1-3 hops; more may indicate inefficiency
4. **Use timestamp_chain for SLA tracking** — Calculate end-to-end latency for critical paths

## Related Documentation

- [[registry-health]] — Agent health monitoring
- [[protocol]] — Message format specification
- [[multiagent-spec]] — System architecture

---

*Document version: 1.0 | Created: 2026-06-08 | Owner: netra*
