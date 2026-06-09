# Jit Oracle API Documentation

## Overview

Jit Oracle exposes multiple APIs for agent communication, knowledge management, and system monitoring. All APIs follow REST conventions and return JSON responses.

---

## Core APIs

### 1. Oracle Knowledge Base API

**Endpoint**: `http://localhost:47778`

The Oracle Knowledge Base (Arra Oracle V3) provides full-text search and vector embedding capabilities across the multi-agent system.

#### 1.1 Health Check

```http
GET /api/health
```

**Response**:
```json
{
  "status": "ok",
  "version": "3.0",
  "uptime_seconds": 3600,
  "db_size_mb": 125
}
```

**Usage**:
```bash
curl http://localhost:47778/api/health
```

---

#### 1.2 Search Knowledge

```http
GET /api/search?q=<query>&limit=<int>&offset=<int>
```

**Parameters**:
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `q` | string | Yes | Search query (supports full-text and vector matching) |
| `limit` | int | No | Max results (default: 10, max: 100) |
| `offset` | int | No | Pagination offset (default: 0) |

**Response**:
```json
{
  "status": "ok",
  "query": "multiagent architecture",
  "results": [
    {
      "id": "doc-001",
      "title": "System Architecture",
      "content": "The Jit Oracle system consists of 15 agents...",
      "concepts": ["multiagent", "architecture", "design"],
      "score": 0.95,
      "created_at": "2026-04-23T10:00:00Z"
    }
  ],
  "count": 1,
  "total": 15
}
```

**Example**:
```bash
bash limbs/oracle.sh search "feature-flags" 10
curl "http://localhost:47778/api/search?q=feature-flags&limit=10"
```

---

#### 1.3 Learn New Knowledge

```http
POST /api/learn
Content-Type: application/json
```

**Request Body**:
```json
{
  "pattern": "pattern-name",
  "content": "Detailed description of the pattern",
  "concepts": ["concept1", "concept2", "concept3"]
}
```

**Response**:
```json
{
  "status": "ok",
  "id": "doc-042",
  "pattern": "pattern-name",
  "created_at": "2026-06-08T10:16:57Z"
}
```

**Example**:
```bash
bash limbs/oracle.sh learn "system-patterns" \
  "Jit coordinates through soma→lak→innova→specialists" \
  "architecture,pattern,multiagent"
```

---

### 2. Message Bus API

**Endpoint**: File-based at `/tmp/manusat-bus/`

The message bus routes all inter-agent communication through a POSIX-compatible file-based queue.

#### 2.1 Send Message (mouth.sh)

```bash
bash organs/mouth.sh tell <agent-name> "<message>"
```

**Message Format**:
```
from:sender-agent
to:recipient-agent
subject:<prefix>:<object>
timestamp:<ISO-8601>
protocol-version:1.0
idempotency-key:<sha256-hex>
---
Message body text
```

**Subject Prefixes**:
| Prefix | Use Case | Example |
|--------|----------|---------|
| `task:` | Work assignment | `task:implement-feature` |
| `think:` | Request analysis | `think:design-api` |
| `report:` | Status update | `report:task-complete` |
| `alert:` | Urgent notification | `alert:oracle-down` |
| `learn:` | Knowledge contribution | `learn:bug-pattern` |
| `request:` | Info query | `request:system-status` |
| `command:` | Direct order | `command:deploy` |
| `broadcast:` | System-wide | `broadcast:ready` |

**Example**:
```bash
bash organs/mouth.sh tell innova "task:fix-bug-123"
bash organs/mouth.sh tell jit "alert:critical High memory usage"
```

---

#### 2.2 Read Messages (ear.sh)

```bash
bash organs/ear.sh inbox <agent-name>
bash organs/ear.sh dlq <agent-name>
bash organs/ear.sh archive <agent-name> --older-than 24h
```

**Response** (inbox):
```
Agent: innova
Inbox: /tmp/manusat-bus/innova/
Pending messages: 5
Total size: 1.2 MB

Message 001:
  from: soma
  subject: task:implement-feature
  timestamp: 2026-06-08T10:00:00Z
  ...
```

---

#### 2.3 Bus Monitoring

```bash
bash network/bus.sh queue      # Show pending messages
bash network/bus.sh stats      # Show statistics
bash network/bus.sh retry-dlq <agent-name>  # Retry failed messages
```

**Stats Response**:
```json
{
  "total_agents": 15,
  "total_pending": 42,
  "agent_stats": {
    "innova": {"pending": 8, "size_kb": 256},
    "jit": {"pending": 3, "size_kb": 48}
  },
  "dlq_total": 2,
  "errors_24h": 5
}
```

---

### 3. Heartbeat & Vital Signs API

**Endpoint**: Heart rhythm monitoring at `/tmp/manusat-heart.pid` and related files

#### 3.1 Check Vital Signs

```bash
bash organs/heart.sh rhythm
bash organs/heart.sh oracle-health
```

**Response** (rhythm):
```
═══════════════════════════════════════
         Jit Vital Signs Dashboard
═══════════════════════════════════════

Heartbeat:     🟢 Normal (30s cycle)
Last beat:     10 seconds ago
Oracle:        🟢 Online
Agent status:  14/15 responsive
Message queue: 42 pending (healthy)
Memory usage:  47% (normal)
```

---

#### 3.2 Monitor Oracle Health

```bash
bash organs/heart.sh oracle-health
bash organs/heart.sh monitor-oracle start
```

**Direct Health Check**:
```bash
curl http://localhost:47778/api/health
```

---

### 4. System Health Check API

#### 4.1 Individual Agent Check

```bash
bash eval/soul-check.sh
```

Tests inter-agent communication across all agents.

**Output**:
```
Testing agent communication...
✅ innova → soma (responded in 120ms)
✅ soma → lak (responded in 95ms)
✅ jit → innova (responded in 140ms)
...
All agents: HEALTHY
```

---

#### 4.2 Full System Health Check

```bash
bash eval/body-check.sh
```

Comprehensive check of all agents, message bus, Oracle, shared state, and organ assignments.

**Output**:
```
System Health Report:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Agent Tier 0 (Master):
  ✅ jit — responsive

Agent Tier 1 (Strategic):
  ✅ soma — responsive
  
Organ Assignments:
  ✅ All 15 organs assigned
  
Message Bus:
  ✅ 42 pending messages (healthy)
  
Oracle:
  ✅ Running on http://localhost:47778
  ✅ Health check: ok
  
Shared Memory:
  ✅ /tmp/manusat-shared.json (updated 5s ago)

System Status: ✅ HEALTHY
```

---

### 5. Ollama Thai Language API

**Endpoint**: `https://ollama.mdes-innova.online`

Specialized API for Thai language processing using Ollama.

#### 5.1 Process Thai Text

```bash
bash limbs/ollama.sh think "จิตของมนุษย์คืออะไร"
```

**Example Scenarios**:
```bash
# Thai language analysis
bash limbs/ollama.sh think "วิเคราะห์: มนุษย์ Agent คืออะไร"

# Translation to English
bash limbs/ollama.sh think "แปลเป็นภาษาอังกฤษ: ศีล สมาธิ ปัญญา"

# English queries also supported
bash limbs/ollama.sh think "What is the human spirit?"
```

**Configuration**:
- **Model**: gemma4:26b
- **Auth**: Token in `.github/agents/innova.agent.md`
- **Language**: Thai (th-TH) + English support

---

### 6. Voice Transcription API

**Endpoint**: karn Voice API at `http://localhost:8765`

The karn agent provides speech-to-text processing for voice input.

#### 6.1 Save Transcript

**File-based endpoint** (Python API):
```python
from karn_voice_api import KarnVoiceAPI

api = KarnVoiceAPI()
api.save_transcript(
  transcript="จิตนำกาย",
  language="th-TH",
  metadata={"agent": "karn", "session": "001"}
)
```

**CLI Usage**:
```bash
bash organs/ear.sh transcript "<transcript-text>" --lang th-TH
```

**Response**:
```markdown
# 🎧 karn Voice Transcript

**Timestamp**: 2026-06-08T10:16:57Z
**Language**: th-TH
**Words**: 3
**Status**: ✅ Recorded by karn

---

## Transcript

จิตนำกาย
```

---

## Common Workflows

### Workflow 1: Send Task to Agent

```bash
# Step 1: Compose message
bash organs/mouth.sh tell innova "task:implement-feature-X"

# Step 2: Check delivery
bash organs/ear.sh inbox innova

# Step 3: Wait for response
bash organs/ear.sh inbox soma
```

---

### Workflow 2: Query Oracle Knowledge

```bash
# Simple search
bash limbs/oracle.sh search "multiagent" 5

# Learn new pattern
bash limbs/oracle.sh learn "integration-pattern" \
  "Agents coordinate via file-based message bus" \
  "architecture,pattern,integration"
```

---

### Workflow 3: Monitor System Health

```bash
# Quick status
bash organs/heart.sh rhythm

# Full health check
bash eval/body-check.sh

# Check specific agent
bash organs/ear.sh inbox innova
```

---

### Workflow 4: Debug Message Delivery

```bash
# View all pending messages
bash network/bus.sh queue

# Check specific agent's inbox
bash organs/ear.sh inbox innova

# View dead letter queue (failed messages)
bash organs/ear.sh dlq innova

# Retry failed messages
bash network/bus.sh retry-dlq innova
```

---

## Error Handling

### Common Error Codes

| Error | Cause | Recovery |
|-------|-------|----------|
| `Oracle down` | HTTP 503 | Restart: `bash organs/heart.sh monitor-oracle start` |
| `Agent timeout` | No response after 300s | Check inbox: `bash organs/ear.sh inbox <agent>` |
| `Queue overflow` | >100 pending messages | Archive old: `bash organs/ear.sh archive <agent> --older-than 24h` |
| `Signature mismatch` | Invalid HMAC | Check `MANUSAT_BUS_SECRET` env var |
| `Message malformed` | Bad format | Check protocol: `/network/protocol.md` |

---

## Rate Limiting

| API | Limit | Window |
|-----|-------|--------|
| Oracle search | 100 requests | 60 seconds |
| Learn endpoint | 50 requests | 60 seconds |
| Heartbeat | Unlimited | 30 seconds per cycle |
| Message bus | Unlimited | File I/O dependent |

---

## Authentication

### Message Signing (Optional)

When `MANUSAT_BUS_SECRET` is set, all messages require HMAC-SHA256 signature:

```bash
export MANUSAT_BUS_SECRET="your-secret-key"
bash organs/mouth.sh tell jit "task:deploy"  # Auto-signed
```

### Oracle Token

Ollama requires token in `.github/agents/innova.agent.md`:
```
OLLAMA_TOKEN: <your-token>
```

---

## Performance Tuning

### Optimize Oracle Searches

```bash
# Limit results for faster response
bash limbs/oracle.sh search "pattern" 5  # Instead of default 10+

# Use specific concepts
curl "http://localhost:47778/api/search?q=feature&concepts=architecture&limit=5"
```

### Reduce Message Latency

- Keep message body <10 KB
- Use specific agent names (avoid broadcast unless necessary)
- Monitor inbox depth: `bash network/bus.sh stats`

---

## Reference

- **Protocol Details**: `/network/protocol.md`
- **Agent Registry**: `/network/registry.json`
- **System Spec**: `/docs/multiagent-spec.md`
- **Bootstrap**: `bash scripts/bootstrap.sh`

---

## Status

**Last Updated**: 2026-06-08  
**API Version**: 1.0  
**Agents**: 15 (All organs assigned)  
**Oracle**: v3.0  
**Status**: Production Ready
