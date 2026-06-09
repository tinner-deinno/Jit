# Registry Health Tracking

> **JIT-020** — Real-time health status and metrics tracking for all agents in the multi-agent system

## Overview

The agent registry (`network/registry.json`) is no longer just static metadata. Version 2.1+ includes **runtime health tracking** that enables adaptive system behavior based on real-time agent status.

## Health Fields

Each agent entry now includes these runtime health fields:

| Field | Type | Description |
|-------|------|-------------|
| `health_status` | `ok` \| `degraded` \| `offline` | Current health state |
| `last_heartbeat` | ISO 8601 timestamp | Last heartbeat received |
| `response_time_ms` | integer | Average response latency (sampled) |
| `message_queue_depth` | integer | Pending messages in inbox |

### Example Agent Entry

```json
{
  "name": "pran",
  "role": "หัวใจ (Heart) — Vital Orchestrator",
  "health_status": "ok",
  "last_heartbeat": "2026-06-08T03:46:50+07:00",
  "response_time_ms": 235,
  "message_queue_depth": 92,
  "version": "1.0.0"
}
```

## Health Status States

| Status | Meaning | Action |
|--------|---------|--------|
| `ok` | Agent responding normally | No action needed |
| `degraded` | Slow response or intermittent failures | Monitor closely, may need intervention |
| `offline` | No heartbeat for > 5 minutes | Flagged by netra eye-check, may need restart |

## Configuration

### Offline Threshold

Agents are flagged as `offline` when no heartbeat is received for more than **300 seconds (5 minutes)**. This threshold is configured in the registry:

```json
{
  "health_tracking": {
    "enabled": true,
    "offline_threshold_seconds": 300,
    "description": "Agents offline >5 min flagged by netra eye-check"
  }
}
```

## Response Time Tracking

Response times are **sampled every 10th message** to avoid overhead. The bus tracks:

- **Send→receive latency**: Time from message sent to message read
- **Per-agent averages**: Stored in registry for each agent
- **Sample retention**: Last 100 samples kept in `/tmp/manusat-bus-counter.json`

### How It Works

1. Every 10th message triggers a response time calculation
2. Bus measures time from `timestamp` to actual read time
3. Registry is updated with the latest response time for that agent
4. Samples are stored for statistical analysis

## Message Queue Depth

Queue depth is updated when:
- Messages are **received** (decremented)
- Messages are **swept** to DLQ (expired messages counted)
- Registry is refreshed by `bus.sh stats`

## Usage

### Check Agent Health via Registry

```bash
# View full registry with health status
cat network/registry.json | jq '.agents[] | {name, health_status, last_heartbeat, response_time_ms}'

# Find offline agents
cat network/registry.json | jq '.agents[] | select(.health_status == "offline")'

# Find degraded agents (response time > 500ms)
cat network/registry.json | jq '.agents[] | select(.response_time_ms > 500)'
```

### Netra Eye-Check Integration

The `netra` agent automatically flags agents that have been offline for more than 5 minutes:

```bash
# Netra checks registry and reports offline agents
bash organs/eye.sh check-health
```

### Bus Stats with Health Metrics

```bash
# View bus statistics with queue depths
bash network/bus.sh stats

# JSON output for programmatic access
bash network/bus.sh stats --json
```

### Bus Metrics Dashboard

```bash
# Human-readable metrics dashboard
bash network/bus.sh metrics

# JSON output
bash network/bus.sh metrics --json
```

Example output:
```
   [ Bus Metrics Dashboard ]
   Updated: 2026-06-08 04:30:00

   Agent           Sent   Recv   Fail   Exp   DLQ
   ─────────────────────────────────────────────
   innova             42     38      2     1     0
   soma               15     14      0     0     0
   vaja                8      8      0     0     0
   ...
```

## Heartbeat Integration

The `pran` (heart) agent updates health status after each heartbeat cycle:

```bash
# Heartbeat updates registry health fields
bash organs/heart.sh pulse
```

Heartbeat sets:
- `last_heartbeat`: Current timestamp
- `health_status`: Set to `ok` on successful pulse
- `message_queue_depth`: Current inbox depth

## Dead Letter Queue (DLQ) Impact

Messages that fail delivery are moved to DLQ, affecting metrics:

| DLQ Reason | Description | Metric Impact |
|------------|-------------|---------------|
| `expired` | TTL exceeded | `expired` counter incremented |
| `unrouted` | Unknown recipient | `failed` counter incremented |
| `max-retries` | Retry exhaustion | `failed` counter incremented |
| `error` | Other failures | `failed` counter incremented |

### Check DLQ Status

```bash
# View DLQ contents
bash network/bus.sh dlq list

# Check DLQ depth
bash network/bus.sh dlq depth

# Replay a failed message
bash network/bus.sh dlq replay /path/to/message.msg
```

## Alerts and Thresholds

The system emits alerts when:

| Condition | Threshold | Alert Type |
|-----------|-----------|------------|
| DLQ depth | > 10 messages | `dlq-growing` broadcast |
| Response time | > 1000ms | Logged as degraded |
| Offline duration | > 300 seconds | Flagged by netra |

## Files and Paths

| Path | Purpose |
|------|---------|
| `network/registry.json` | Master registry with health fields |
| `/tmp/manusat-bus-metrics.json` | Runtime metrics counters |
| `/tmp/manusat-bus-counter.json` | Sampling counter for response times |
| `/tmp/manusat-bus/_dlq/` | Dead Letter Queue storage |

## Related Documentation

- [[message-tracing]] — Trace individual message journeys
- [[cot-logging]] — Chain-of-thought logging for decision tracking
- [[multiagent-spec]] — Full system specification

---

*Document version: 1.0 | Created: 2026-06-08 | Owner: netra*
