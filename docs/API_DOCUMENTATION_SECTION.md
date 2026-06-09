# API Documentation — Jit Oracle Multi-Agent System

**Version**: 1.0  
**Last Updated**: 2026-06-08  
**Status**: Production Ready

---

## Table of Contents

1. [Introduction](#introduction)
2. [Authentication](#authentication)
3. [Request/Response Format](#requestresponse-format)
4. [Core API Endpoints](#core-api-endpoints)
5. [Rate Limiting](#rate-limiting)
6. [Error Handling](#error-handling)
7. [Security Best Practices](#security-best-practices)
8. [Integration Examples](#integration-examples)
9. [Performance Tuning](#performance-tuning)
10. [Troubleshooting](#troubleshooting)

---

## Introduction

The Jit Oracle API provides programmatic access to the **15-agent multi-agent system** through four major subsystems:

- **Agent Management API** — Control and communicate with 15 specialized agents across 3 tiers
- **Oracle Knowledge Base API** — Full-text search, learn, and vector-search over persistent knowledge
- **Message Bus API** — Asynchronous inter-agent communication via file-based queue
- **Vital Signs API** — Real-time health monitoring, heartbeat rhythm, and system metrics

### Base URL

```
http://localhost:47778/api/v1
```

### API Versioning

All endpoints follow semantic versioning (`/api/v1`, `/api/v2`, etc.). **Current stable version is v1.**

---

## Authentication

### 1. Bearer Token (OAuth 2.0)

Standard OAuth 2.0 Bearer token for most API endpoints.

**Header**:
```
Authorization: Bearer <token>
```

**Example**:
```bash
curl -H "Authorization: Bearer sk_live_abc123xyz789" \
  http://localhost:47778/api/v1/agents
```

### 2. API Key (Service-to-Service)

For internal service communication and CLI tools.

**Header**:
```
X-API-Key: <key>
```

**Example**:
```bash
curl -H "X-API-Key: key_dev_innova_12345" \
  http://localhost:47778/api/v1/health
```

### 3. MDES Ollama Token

Required for Thai language processing via Ollama.

**Header**:
```
X-MDES-Token: <ollama_token>
```

**Example**:
```bash
curl -H "X-MDES-Token: mdes_token_xyz" \
  http://localhost:47778/api/v1/agents/pran/think
```

---

## Request/Response Format

### Request Format

All requests (except health checks) must include `Content-Type: application/json`.

**Headers**:
```
POST /api/v1/agents/innova/message HTTP/1.1
Host: localhost:47778
Content-Type: application/json
Authorization: Bearer <token>
```

**Body**:
```json
{
  "subject": "task:implement_feature",
  "message": "Implement OAuth 2.0 support for API",
  "priority": "high",
  "metadata": {
    "ticket_id": "JIT-001",
    "due_date": "2026-06-15T18:00:00Z"
  }
}
```

### Response Format

All responses follow this envelope:

```json
{
  "status": "success|error|timeout",
  "code": 200,
  "message": "Operation description",
  "data": {
    "result": "specific data structure per endpoint"
  },
  "timestamp": "2026-06-08T10:19:45Z",
  "request_id": "req_abc123xyz789",
  "version": "1.0"
}
```

**Success Response Example**:
```json
{
  "status": "success",
  "code": 200,
  "message": "Message sent successfully",
  "data": {
    "message_id": "msg_12345",
    "recipient": "innova",
    "subject": "task:implement_feature",
    "queued_at": "2026-06-08T10:19:45Z"
  },
  "timestamp": "2026-06-08T10:19:45Z",
  "request_id": "req_abc123xyz789"
}
```

**Error Response Example**:
```json
{
  "status": "error",
  "code": 429,
  "message": "Rate limit exceeded",
  "data": {
    "retry_after_seconds": 30,
    "limit": 60,
    "current_usage": 62,
    "window_reset": "2026-06-08T10:21:00Z"
  },
  "timestamp": "2026-06-08T10:19:45Z",
  "request_id": "req_abc123xyz789"
}
```

---

## Core API Endpoints

### Agent Management API

#### 1. List All Agents

**Endpoint**: `GET /api/v1/agents`

**Authentication**: Bearer Token or API Key

**Parameters**: None

**Response**:
```json
{
  "status": "success",
  "data": {
    "agents": [
      {
        "id": "jit",
        "name": "Jit (จิต)",
        "tier": 0,
        "role": "Master Orchestrator",
        "model": "claude-sonnet-4.6",
        "status": "online",
        "last_heartbeat": "2026-06-08T10:19:40Z",
        "inbox_count": 0
      },
      {
        "id": "soma",
        "name": "Soma (สมอง)",
        "tier": 1,
        "role": "Strategic Lead",
        "model": "claude-opus-4.7",
        "status": "online",
        "last_heartbeat": "2026-06-08T10:19:42Z",
        "inbox_count": 2
      }
    ],
    "total": 15,
    "online": 15,
    "offline": 0
  }
}
```

#### 2. Get Agent Status

**Endpoint**: `GET /api/v1/agents/{agent_id}`

**Example**: `GET /api/v1/agents/innova`

**Response**:
```json
{
  "status": "success",
  "data": {
    "agent": {
      "id": "innova",
      "name": "Innova (จิต)",
      "tier": 2,
      "role": "Lead Developer",
      "organ": "ปัญญา (Wisdom)",
      "model": "claude-sonnet-4.6",
      "status": "online",
      "health": {
        "cpu_percent": 12.3,
        "memory_mb": 845,
        "response_time_ms": 142
      },
      "inbox": {
        "total": 5,
        "new": 2,
        "processed": 3
      },
      "last_heartbeat": "2026-06-08T10:19:42Z",
      "uptime_seconds": 3600
    }
  }
}
```

#### 3. Send Message to Agent

**Endpoint**: `POST /api/v1/agents/{agent_id}/message`

**Request Body**:
```json
{
  "subject": "task:code_review",
  "message": "Please review the OAuth implementation in PR #42",
  "priority": "high",
  "metadata": {
    "pr_number": 42,
    "reviewer": "neta"
  }
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "message_id": "msg_67890",
    "recipient": "innova",
    "subject": "task:code_review",
    "status": "queued",
    "position_in_queue": 1,
    "estimated_pickup_seconds": 5
  }
}
```

---

### Oracle Knowledge Base API

#### 1. Search Knowledge

**Endpoint**: `GET /api/v1/oracle/search`

**Query Parameters**:
- `q` (required): Search query
- `limit` (optional, default 10): Number of results
- `type` (optional): `text` | `vector` (default: `text`)

**Example**:
```bash
GET /api/v1/oracle/search?q=multi-agent+architecture&limit=5
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "query": "multi-agent architecture",
    "search_type": "text",
    "results": [
      {
        "id": "kb_001",
        "title": "Multi-Agent System Design Patterns",
        "content": "The 15-agent Jit system follows a 3-tier hierarchy...",
        "concepts": ["architecture", "multiagent", "pattern"],
        "created_at": "2026-05-06T08:00:00Z",
        "relevance_score": 0.98
      },
      {
        "id": "kb_002",
        "title": "Agent Communication Protocol",
        "content": "All inter-agent communication flows through the file-based message bus...",
        "concepts": ["protocol", "communication", "bus"],
        "created_at": "2026-05-10T14:30:00Z",
        "relevance_score": 0.92
      }
    ],
    "total": 24,
    "search_time_ms": 45
  }
}
```

#### 2. Learn New Knowledge

**Endpoint**: `POST /api/v1/oracle/learn`

**Request Body**:
```json
{
  "pattern": "system-pattern-oauth",
  "content": "OAuth 2.0 is now the standard auth mechanism across all 15 agents...",
  "concepts": ["authentication", "oauth", "security"],
  "tags": ["protocol", "security"]
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "knowledge_id": "kb_042",
    "pattern": "system-pattern-oauth",
    "concepts": 3,
    "created_at": "2026-06-08T10:19:45Z",
    "vector_indexed": true
  }
}
```

#### 3. Update Knowledge

**Endpoint**: `PUT /api/v1/oracle/knowledge/{id}`

**Request Body**:
```json
{
  "content": "Updated OAuth 2.0 implementation with refresh token support...",
  "concepts": ["authentication", "oauth", "security", "refresh_token"]
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "knowledge_id": "kb_042",
    "updated_at": "2026-06-08T10:20:00Z",
    "version": 2
  }
}
```

---

### Message Bus API

#### 1. Send Direct Message

**Endpoint**: `POST /api/v1/bus/send`

**Request Body**:
```json
{
  "from": "soma",
  "to": "innova",
  "subject": "think:architecture_review",
  "body": "Review and provide feedback on the new microservice design",
  "priority": "high"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "message_id": "msg_11111",
    "from": "soma",
    "to": "innova",
    "status": "queued",
    "queue_position": 1
  }
}
```

#### 2. Get Message Queue Status

**Endpoint**: `GET /api/v1/bus/queue`

**Query Parameters**:
- `agent` (optional): Filter by agent inbox
- `subject_prefix` (optional): Filter by subject prefix (e.g., `task:`, `think:`)

**Response**:
```json
{
  "status": "success",
  "data": {
    "total_messages": 42,
    "by_priority": {
      "critical": 2,
      "high": 8,
      "normal": 28,
      "low": 4
    },
    "oldest_message_age_seconds": 3600,
    "by_subject": {
      "task:": 15,
      "think:": 12,
      "report:": 8,
      "alert:": 7
    },
    "agents_with_messages": ["innova", "chamu", "lak", "neta"]
  }
}
```

#### 3. Broadcast Message

**Endpoint**: `POST /api/v1/bus/broadcast`

**Request Body**:
```json
{
  "from": "jit",
  "subject": "alert:critical",
  "message": "System entering maintenance window in 15 minutes",
  "priority": "critical"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "message_id": "msg_22222",
    "broadcast_to": 15,
    "agents": ["jit", "soma", "innova", "lak", "neta", "rupa", "pada", "vaja", "chamu", "netra", "karn", "mue", "pran", "lung", "sayanprasathan"],
    "status": "delivered_all"
  }
}
```

---

### Vital Signs & Monitoring API

#### 1. Get Health Status

**Endpoint**: `GET /api/v1/health`

**Response**:
```json
{
  "status": "success",
  "code": 200,
  "data": {
    "system_health": "healthy",
    "oracle": {
      "status": "online",
      "response_time_ms": 12,
      "database": "ready"
    },
    "message_bus": {
      "status": "online",
      "queue_depth": 5,
      "processing_rate": 12.5
    },
    "agents": {
      "online": 15,
      "offline": 0,
      "idle": 3,
      "processing": 12
    },
    "timestamp": "2026-06-08T10:19:45Z"
  }
}
```

#### 2. Get Heartbeat Rhythm

**Endpoint**: `GET /api/v1/vital/heartbeat`

**Query Parameters**:
- `interval` (optional): `1m`, `5m`, `1h` (default: `1m`)

**Response**:
```json
{
  "status": "success",
  "data": {
    "heartbeat": {
      "rhythm": "steady",
      "bpm": 120,
      "last_beat": "2026-06-08T10:19:45Z",
      "beats_per_interval": [118, 119, 120, 120, 121],
      "coordinator": "pran",
      "lung_status": "active",
      "oxygen_flow": "normal"
    },
    "interval": "1m",
    "data_points": 5
  }
}
```

#### 3. Get System Metrics

**Endpoint**: `GET /api/v1/vital/metrics`

**Response**:
```json
{
  "status": "success",
  "data": {
    "system": {
      "uptime_seconds": 86400,
      "load_average": [0.45, 0.38, 0.35],
      "memory_percent": 52.3,
      "disk_percent": 38.5,
      "network_io_mbps": 23.5
    },
    "agents": {
      "avg_response_time_ms": 145,
      "max_response_time_ms": 523,
      "processed_messages": 2841,
      "failed_messages": 3,
      "success_rate_percent": 99.89
    },
    "oracle": {
      "total_knowledge_items": 1247,
      "search_requests_per_second": 3.2,
      "avg_search_time_ms": 32
    },
    "timestamp": "2026-06-08T10:19:45Z"
  }
}
```

---

## Rate Limiting

All API endpoints are rate-limited to **60 requests per minute** per token/key.

### Rate Limit Headers

Every response includes these headers:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 42
X-RateLimit-Reset: 1718002200
```

### Burst Limit

Short bursts up to **150 requests** are allowed within a 1-minute window, but the average must not exceed 60 RPM.

### Example: Rate Limit Exceeded

**Response** (Status 429):
```json
{
  "status": "error",
  "code": 429,
  "message": "Too many requests",
  "data": {
    "limit": 60,
    "current_usage": 65,
    "retry_after_seconds": 30,
    "window_reset": "2026-06-08T10:21:00Z"
  }
}
```

**Recommendation**: Implement exponential backoff with jitter when retrying.

---

## Error Handling

### HTTP Status Codes

| Code | Name | Description | Retry? |
|------|------|-------------|--------|
| 200 | OK | Request succeeded | No |
| 400 | Bad Request | Invalid parameters or malformed JSON | No |
| 401 | Unauthorized | Missing or invalid authentication | No |
| 403 | Forbidden | Agent lacks permission | No |
| 404 | Not Found | Agent/knowledge/message not found | No |
| 408 | Request Timeout | Agent did not respond in time | Yes (exponential backoff) |
| 429 | Too Many Requests | Rate limit exceeded | Yes (with delay) |
| 500 | Internal Server Error | Oracle/bus error | Yes (after delay) |
| 503 | Service Unavailable | Agent temporarily unavailable | Yes (with backoff) |

### Error Response Structure

```json
{
  "status": "error",
  "code": 400,
  "message": "Invalid request body",
  "data": {
    "error": "missing_required_field",
    "field": "subject",
    "details": "The 'subject' field is required for all agent messages"
  },
  "timestamp": "2026-06-08T10:19:45Z",
  "request_id": "req_abc123xyz789"
}
```

### Retry Strategy

```python
import time
import random

def call_api_with_retry(url, max_retries=5):
    for attempt in range(max_retries):
        try:
            response = requests.get(url)
            if response.status_code == 200:
                return response.json()
            elif response.status_code in [408, 429, 500, 503]:
                # Calculate exponential backoff with jitter
                backoff = (2 ** attempt) + random.uniform(0, 1)
                time.sleep(backoff)
                continue
            else:
                raise Exception(f"Unrecoverable error: {response.status_code}")
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            backoff = (2 ** attempt) + random.uniform(0, 1)
            time.sleep(backoff)
    raise Exception("Max retries exceeded")
```

---

## Security Best Practices

### 1. Token Management

- **Rotate tokens** every 90 days
- **Never commit tokens** to version control
- **Use environment variables** for sensitive data:
  ```bash
  export JIT_API_TOKEN="sk_live_abc123xyz789"
  curl -H "Authorization: Bearer $JIT_API_TOKEN" http://localhost:47778/api/v1/agents
  ```

### 2. HTTPS Only

- Always use TLS 1.3+ for production
- API enforces HTTPS redirects

### 3. Input Validation

- All inputs are sanitized
- Maximum request body: 1 MB
- Maximum message length: 50 KB

### 4. Rate Limiting & DDoS Protection

- Per-token rate limiting: 60 RPM
- Automatic IP-based throttling after 1000 RPM
- Requests are logged for audit trails

### 5. CORS Policy

- Only `http://localhost:3000` and registered domains
- Credentials required for cross-origin requests
- `OPTIONS` preflight requests must succeed

---

## Integration Examples

### Example 1: Send Task to Agent (Bash)

```bash
#!/bin/bash

API_TOKEN="sk_live_abc123xyz789"
AGENT="innova"
MESSAGE_SUBJECT="task:implement_feature"
MESSAGE_BODY="Implement OAuth 2.0 support for API"

curl -X POST http://localhost:47778/api/v1/agents/$AGENT/message \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "'$MESSAGE_SUBJECT'",
    "message": "'$MESSAGE_BODY'",
    "priority": "high",
    "metadata": {
      "ticket_id": "JIT-100",
      "due_date": "2026-06-15T18:00:00Z"
    }
  }' | jq .
```

### Example 2: Search Oracle Knowledge (cURL)

```bash
curl -X GET "http://localhost:47778/api/v1/oracle/search?q=multi-agent+architecture&limit=10" \
  -H "X-API-Key: key_dev_innova_12345" | jq '.data.results[] | {title, relevance_score}'
```

### Example 3: Monitor Heartbeat (Python)

```python
import requests
import json
from datetime import datetime

API_URL = "http://localhost:47778/api/v1/vital/heartbeat"
HEADERS = {"X-API-Key": "key_dev_innova_12345"}

response = requests.get(API_URL, headers=HEADERS)
data = response.json()

heartbeat = data['data']['heartbeat']
print(f"[{datetime.now()}] Heartbeat: {heartbeat['bpm']} BPM, Rhythm: {heartbeat['rhythm']}")
print(f"Coordinator: {heartbeat['coordinator']}")
print(f"Lung Status: {heartbeat['lung_status']}")
```

### Example 4: Broadcast System Alert (Bash)

```bash
#!/bin/bash

API_TOKEN="sk_live_abc123xyz789"

curl -X POST http://localhost:47778/api/v1/bus/broadcast \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "jit",
    "subject": "alert:maintenance",
    "message": "System entering maintenance window. Expected duration: 30 minutes.",
    "priority": "high"
  }' | jq '.data | {message_id, broadcast_to, status}'
```

### Example 5: Error Handling with Retry (JavaScript)

```javascript
const axios = require('axios');

async function callApiWithRetry(url, options = {}, maxRetries = 5) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await axios.get(url, options);
      return response.data;
    } catch (error) {
      const status = error.response?.status;
      
      // Retryable errors
      if ([408, 429, 500, 503].includes(status)) {
        const backoff = Math.pow(2, attempt) + Math.random();
        console.log(`Attempt ${attempt + 1} failed (${status}). Retrying in ${backoff.toFixed(2)}s...`);
        await new Promise(resolve => setTimeout(resolve, backoff * 1000));
        continue;
      }
      
      // Non-retryable error
      throw error;
    }
  }
  throw new Error('Max retries exceeded');
}

// Usage
callApiWithRetry('http://localhost:47778/api/v1/agents', {
  headers: { 'X-API-Key': 'key_dev_innova_12345' }
}).then(data => console.log(data)).catch(err => console.error(err));
```

### Example 6: Batch Agent Operations (Bash)

```bash
#!/bin/bash

API_TOKEN="sk_live_abc123xyz789"
AGENTS=("innova" "lak" "neta" "chamu")

for agent in "${AGENTS[@]}"; do
  echo "Checking status of $agent..."
  
  STATUS=$(curl -s -X GET http://localhost:47778/api/v1/agents/$agent \
    -H "Authorization: Bearer $API_TOKEN" | jq '.data.agent.status')
  
  echo "  Status: $STATUS"
done
```

---

## Performance Tuning

### 1. Connection Pooling

Reuse HTTP connections to reduce overhead:

```python
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

session = requests.Session()
adapter = HTTPAdapter(pool_connections=10, pool_maxsize=10)
session.mount('http://', adapter)
session.mount('https://', adapter)

response = session.get('http://localhost:47778/api/v1/agents')
```

### 2. Batch Operations

Instead of sending 100 individual requests, send one broadcast or batch query:

```bash
# ✗ Slow: 100 individual requests
for i in {1..100}; do
  curl http://localhost:47778/api/v1/agents/$agent/message ...
done

# ✓ Fast: One broadcast
curl -X POST http://localhost:47778/api/v1/bus/broadcast ...
```

### 3. Caching Search Results

Cache Oracle search results locally to avoid repeated queries:

```python
cache = {}

def search_oracle(query, ttl_seconds=3600):
  if query in cache and cache[query]['expires'] > time.time():
    return cache[query]['data']
  
  data = api_call(f'/oracle/search?q={query}')
  cache[query] = {
    'data': data,
    'expires': time.time() + ttl_seconds
  }
  return data
```

### 4. Async Message Processing

Use async patterns to avoid blocking:

```javascript
async function sendMultipleMessages(messages) {
  const promises = messages.map(msg =>
    fetch('/api/v1/bus/send', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}` },
      body: JSON.stringify(msg)
    })
  );
  
  const results = await Promise.all(promises);
  return results;
}
```

---

## Troubleshooting

### Issue: 401 Unauthorized

**Cause**: Missing or invalid token.

**Solution**:
```bash
# Verify token is set
echo $JIT_API_TOKEN

# Re-generate token if expired
# Contact system admin for new token

# Include in request
curl -H "Authorization: Bearer $JIT_API_TOKEN" http://localhost:47778/api/v1/agents
```

### Issue: 429 Rate Limit Exceeded

**Cause**: Exceeded 60 requests per minute.

**Solution**:
1. Implement exponential backoff
2. Check `X-RateLimit-Reset` header
3. Use batch endpoints instead of individual requests
4. Request rate limit increase if legitimate use case

### Issue: 408 Request Timeout

**Cause**: Agent did not respond within timeout window.

**Solution**:
```bash
# Check agent status
curl -H "Authorization: Bearer $token" \
  http://localhost:47778/api/v1/agents/{agent_id}

# Retry with exponential backoff
# Wait 30+ seconds before retrying
```

### Issue: 503 Service Unavailable

**Cause**: Oracle or message bus temporarily down.

**Solution**:
1. Check system health: `GET /api/v1/health`
2. Wait 1-2 minutes
3. Retry with exponential backoff
4. Contact ops if persists > 5 minutes

### Debugging Checklist

- [ ] Is the API server running? (`curl http://localhost:47778/api/v1/health`)
- [ ] Is authentication token valid? (Check expiry, regenerate if needed)
- [ ] Are rate limits being exceeded? (Check `X-RateLimit-Remaining` header)
- [ ] Is the agent online? (`GET /api/v1/agents/{agent_id}`)
- [ ] Is the message queue processing? (`GET /api/v1/bus/queue`)
- [ ] Is Oracle responding? (Check `/health` → oracle.status)

---

## Support & Resources

- **Documentation**: https://github.com/tinner-deinno/Jit/tree/main/docs
- **Status Page**: http://localhost:47778/health
- **Agent Registry**: `/network/registry.json`
- **GitHub Issues**: https://github.com/tinner-deinno/Jit/issues

---

**Last Updated**: 2026-06-08  
**API Version**: 1.0  
**Status**: Production Ready  
**All 15 Agents Supported**: ✓
