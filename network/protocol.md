# มนุษย์ Agent — Communication Protocol v1

## Overview

ระบบสื่อสารระหว่าง agents ใน "มนุษย์ Agent" โดยยึดหลัก:
- **ศีล**: ส่งเฉพาะข้อมูลที่จำเป็น ไม่ส่ง sensitive data
- **สมาธิ**: หนึ่ง message = หนึ่งเจตนาที่ชัดเจน
- **ปัญญา**: ทุก message มี context เพียงพอสำหรับ agent รับ

---

## Message Format

```
from:<agent-name>
to:<agent-name>
subject:<action>:<object>
timestamp:<ISO-8601>
protocol-version:<semver>      # JIT-005: Protocol version (default: 1.0)
correlation-id:<uuid>          # optional — สำหรับ reply tracking
idempotency-key:<sha256-hex>   # JIT-002: SHA-256 hex (64 chars)
ttl:<seconds>                  # optional: Time-to-live
expires-at:<ISO-8601>          # optional: Expiration time
x-signature:hmac-sha256=<sig>  # JIT-011: HMAC-SHA256 signature
trace-chain:<agent1→agent2>    # optional: Routing history
hop_count:<n>                  # optional: Number of hops
---
<body>
```

### Header Fields

| Field | Required | Description |
|-------|----------|-------------|
| `from` | Yes | Sender agent name |
| `to` | Yes | Recipient agent name |
| `subject` | Yes | Action prefix + object (e.g., `task:create-file`) |
| `timestamp` | Yes | ISO-8601 timestamp |
| `protocol-version` | Yes | SemVer format `major.minor` — JIT-005 |
| `correlation-id` | No | UUID for reply tracking |
| `idempotency-key` | Yes | SHA-256 hex (64 chars) — JIT-002, derived from `from+subject+body-hash` |
| `ttl` | No | Time-to-live in seconds |
| `expires-at` | No | ISO-8601 expiration time |
| `x-signature` | No | HMAC-SHA256 signature — JIT-011 |
| `trace-chain` | No | Chain of agents visited (e.g., `soma→innova→chamu`) |
| `hop_count` | No | Number of hops in journey |
| `timestamp_chain` | No | Comma-separated timestamps per hop |

### ตัวอย่าง

```
from:soma
to:innova
subject:think:design-new-feature
timestamp:2026-04-23T10:00:00+07:00
protocol-version:1.0
correlation-id:abc-123
idempotency-key:a1b2c3d4e5f6...
---
ออกแบบระบบ multiagent สำหรับ Jit repo
ต้องการ: organs/eye.sh + organs/ear.sh
priority: high
```

---

## Subject Conventions

| Prefix | ความหมาย | ตัวอย่าง |
|--------|----------|---------|
| `task:` | สั่งงาน | `task:create-file`, `task:fix-bug` |
| `think:` | ขอให้คิด | `think:design-X`, `think:analyze-Y` |
| `report:` | รายงานผล | `report:task-done`, `report:error` |
| `reply:` | ตอบกลับ | `reply:abc-123` |
| `broadcast:` | ส่งทุกคน | `broadcast:system-ready` |
| `alert:` | แจ้งเตือน | `alert:oracle-down`, `alert:critical` |
| `learn:` | สอน Oracle | `learn:new-pattern`, `learn:bug-fix` |
| `request:` | ขอข้อมูล | `request:oracle-search` |
| `command:` | สั่ง direct | `command:deploy`, `command:rollback` |

---

## Agent Roles (14 Agents)

### Tier 0: Master Orchestrator

#### jit (จิต) — Soul/Master Orchestrator
- **Model**: claude-sonnet-4.6
- **Receives**: `task:`, `alert:`, `report:`, `request:` จาก human และทุก agents
- **Sends**: `command:`, `task:`, `broadcast:`, `alert:`
- **Specialty**: Master orchestration, decision routing, system synthesis
- **Inbox**: `/tmp/manusat-bus/jit/`
- **Manages**: soma (strategic), innova (operational), netra, karn, mue, pran, sayanprasathan

---

### Tier 1: Strategic Lead

#### soma (สมอง) — Brain/Strategic Lead
- **Model**: claude-opus-4.7
- **Receives**: `think:`, `analyze:`, `design:`, `strategy:` จาก jit
- **Sends**: `decision:`, `plan:`, `command:`, `delegate:`
- **Specialty**: Strategic reasoning, architecture decisions, priority setting
- **Inbox**: `/tmp/manusat-bus/soma/`
- **Manages**: lak, neta, rupa, pada

---

### Tier 2: Core Engineering

#### innova (จิต) — Mind/Lead Developer
- **Model**: claude-sonnet-4.6
- **Receives**: `task:implement`, `think:design`, `request:help` จาก jit/soma
- **Sends**: `report:progress`, `learn:pattern`, `alert:blocker`
- **Specialty**: Implementation, code generation, memory/soul coordination
- **Inbox**: `/tmp/manusat-bus/innova/`
- **Manages**: vaja, chamu

#### lak (กระดูกสันหลัง) — Solution Architect
- **Model**: claude-sonnet-4.6
- **Receives**: `task:design`, `think:architecture` จาก soma
- **Sends**: `spec:`, `design:`, `review:architecture`
- **Specialty**: System architecture, spec writing, technical design
- **Inbox**: `/tmp/manusat-bus/lak/`

#### neta (เนตร) — Code Reviewer
- **Model**: claude-sonnet-4.6
- **Receives**: `review:code`, `approve:pr` จาก innova/soma
- **Sends**: `approval:`, `blocking:`, `feedback:code`
- **Specialty**: Code quality, security review, best practices
- **Inbox**: `/tmp/manusat-bus/neta/`

---

### Tier 3: Specialist Organs

#### vaja (วาจา) — Personal Assistant (PA)
- **Model**: claude-haiku-4.5
- **Receives**: `task:communicate`, `request:translate` จาก innova
- **Sends**: `report:human`, `translate:`, `notify:`
- **Specialty**: Human communication, message translation, reporting
- **Inbox**: `/tmp/manusat-bus/vaja/`

#### chamu (จมูก) — QA/Tester
- **Model**: claude-haiku-4.5
- **Receives**: `task:test`, `detect:bug` จาก innova
- **Sends**: `report:test-result`, `alert:bug`, `verify:fix`
- **Specialty**: Testing, bug detection, quality assurance
- **Inbox**: `/tmp/manusat-bus/chamu/`

#### rupa (รูป) — Designer/UI-UX
- **Model**: claude-haiku-4.5
- **Receives**: `task:design`, `review:ui` จาก soma
- **Sends**: `design:spec`, `mockup:`, `feedback:visual`
- **Specialty**: UI/UX design, visual review, wireframing
- **Inbox**: `/tmp/manusat-bus/rupa/`

#### pada (บาท) — DevOps/Infrastructure
- **Model**: claude-haiku-4.5
- **Receives**: `task:deploy`, `command:rollback` จาก soma
- **Sends**: `report:deploy`, `alert:infra`, `status:ci-cd`
- **Specialty**: Deployment, CI/CD, infrastructure management
- **Inbox**: `/tmp/manusat-bus/pada/`

#### netra (เนตร) — Eye/Observer
- **Model**: claude-haiku-4.5
- **Receives**: `task:observe`, `monitor:system` จาก jit
- **Sends**: `report:observation`, `alert:anomaly`
- **Specialty**: System monitoring, observation, anomaly detection
- **Inbox**: `/tmp/manusat-bus/netra/`

#### karn (หู) — Ear/Listener
- **Model**: claude-haiku-4.5
- **Receives**: `task:listen`, `receive:input` จาก jit
- **Sends**: `report:input`, `forward:message`
- **Specialty**: Input listening, message reception, event capture
- **Inbox**: `/tmp/manusat-bus/karn/`

#### mue (มือ) — Hand/Executor
- **Model**: claude-haiku-4.5
- **Receives**: `task:execute`, `command:act` จาก jit
- **Sends**: `report:action`, `status:complete`
- **Specialty**: Action execution, file operations, command running
- **Inbox**: `/tmp/manusat-bus/mue/`

#### pran (หัวใจ) — Heart/Vital Coordinator
- **Model**: claude-haiku-4.5
- **Receives**: `pulse:`, `vital:check` จาก jit
- **Sends**: `heartbeat:IN`, `heartbeat:OUT`, `alert:vital`
- **Specialty**: Vital signs, heartbeat coordination, anomaly detection
- **Inbox**: `/tmp/manusat-bus/pran/`

#### sayanprasathan (ระบบประสาท) — Nerve/Event Network
- **Model**: claude-haiku-4.5
- **Receives**: `signal:`, `event:broadcast` จากทุก agents
- **Sends**: `broadcast:event`, `notify:network`
- **Specialty**: Event broadcasting, network signaling, pub/sub
- **Inbox**: `/tmp/manusat-bus/sayanprasathan/`

---

## Bus Architecture

```
[soma] ──think──→ /tmp/manusat-bus/innova/*.msg
[innova] ──report──→ /tmp/manusat-bus/soma/*.msg
[any] ──broadcast──→ /tmp/manusat-bus/*/broadcast_*.msg
[organs] ──signal──→ /tmp/manusat-nerve/*.evt
[jit] ◄──alerts── [all agents]
```

### Message Flow Pipeline

```
mouth.sh (write) → bus.sh (route + sign) → ear.sh (read + verify) → organ dispatch
```

---

## Shared Resources

| Resource | Path | Access |
|----------|------|--------|
| Oracle Knowledge | `http://localhost:47778` | Read/Write (all agents) |
| Action Log | `/tmp/innova-actions.log` | Append (innova) |
| Event Bus | `/tmp/manusat-nerve/` | Signal/Listen (all) |
| Heartbeat | `/tmp/manusat-heart.pid` | Write (pran) |
| CoT Log | `/tmp/manusat-cot-log.jsonl` | Append (all agents) |
| Shared Memory | `/tmp/manusat-shared.json` | Read/Write (all) |
| Bus Metrics | `/tmp/manusat-bus-metrics.json` | Read (pran, netra) |

---

## Lifecycle

```
1. Agent boots → reads registry → checks oracle → signals nerve "agent_ready"
2. pran.sh starts → sends heartbeat every 30s
3. Agents communicate via mouth→bus→ear pipeline
4. All learnings → Oracle (shared memory)
5. Shutdown → signal nerve "agent_shutdown" → clean inbox
```

---

## Error Handling & Recovery

### Message Queue Overflow

**Detection**: Inbox exceeds 100 pending messages or 10MB total size

**Recovery**:
1. Auto-archive messages older than 24h to `/tmp/manusat-bus/<agent>/archive/`
2. Truncate `.msg` files if disk pressure critical
3. Send `alert:queue-overflow` to jit and agent owner

**Prevention**:
- Agents should process inbox every heartbeat cycle
- Use `ttl:` header for time-sensitive messages
- Monitor via `bash organs/ear.sh inbox <agent>`

```bash
# Check inbox size
find /tmp/manusat-bus/<agent>/ -name "*.msg" | wc -l

# Archive old messages manually
bash organs/ear.sh archive <agent> --older-than 24h
```

---

### Agent Timeout

**Timeout Thresholds**:
- Normal task: 300 seconds (5 minutes)
- Complex think: 600 seconds (10 minutes)
- Deploy operation: 900 seconds (15 minutes)

**Recovery Flow**:
```
1. Sender detects timeout (no reply within threshold)
2. Retry with exponential backoff: 30s → 60s → 120s → 300s
3. After 3 retries: send alert:jit "agent <name> unresponsive"
4. jit routes to backup agent or escalates to human
```

**Configuration**:
```bash
# Set timeout in message header
ttl:300
expires-at:2026-06-07T15:30:00+07:00
```

---

### Oracle Down

**Detection**: HTTP health check fails 3 consecutive times

**Fallback**:
1. Queue learnings to `/tmp/innova-pending-learn.log`
2. Continue operations with cached knowledge from `/tmp/manusat-shared.json`
3. pran attempts auto-restart after 5-minute cooldown
4. Broadcast `alert:oracle-down` to all agents

**Recovery Commands**:
```bash
# Check Oracle status
curl http://localhost:47778/api/health

# Restart Oracle
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run src/server.ts &

# Or use heart.sh
bash organs/heart.sh oracle-health
bash organs/heart.sh monitor-oracle start
```

---

### Cascade Failure

**Definition**: When one agent failure causes downstream agents to stall

**Detection**:
- 3+ agents report `alert:blocker` within 60 seconds
- Message queue depth spikes across multiple agents
- Heartbeat anomalies detected by pran

**Mitigation**:
```
1. jit declares "degraded mode"
2. Bypass failed agent: reroute messages to backup
3. Queue non-critical tasks
4. Notify human via vaja
5. Focus on P0/P1 tickets only
```

**Circuit Breaker Pattern**:
```bash
# If agent fails 5 times in 60 seconds, open circuit
# Messages route to DLQ instead of inbox
# After 300 seconds, half-open: try one message
# On success: close circuit; on failure: reopen
```

---

### Deadlock Detection

**Pattern**: Circular message waits (A waits for B, B waits for A)

**Detection**:
- Track `correlation-id` chains
- Detect cycles in message dependency graph
- Timeout threshold exceeded with no progress

**Resolution**:
```
1. jit breaks cycle by forcing one agent to proceed without reply
2. Log deadlock incident to Oracle (learn:deadlock-pattern)
3. Add timeout to prevent recurrence
```

---

### Dead Letter Queue (DLQ)

**Purpose**: Store messages that failed delivery after max retries

**Location**: `/tmp/manusat-bus/<agent>/dlq/`

**Processing**:
```bash
# View DLQ
bash organs/ear.sh dlq <agent>

# Retry failed messages
bash network/bus.sh retry-dlq <agent>

# Purge old DLQ entries (>7 days)
bash network/bus.sh purge-dlq --older-than 7d
```

---

## Troubleshooting

### Common Issues

#### "Agent not responding"

**Diagnosis**:
```bash
# 1. Check if agent inbox exists
ls -la /tmp/manusat-bus/<agent>/

# 2. Check pending message count
find /tmp/manusat-bus/<agent>/ -name "*.msg" | wc -l

# 3. Check agent process (if daemon)
pgrep -f "<agent>" || echo "Not running"

# 4. Check last heartbeat
cat /tmp/manusat-bus/heartbeat-out.json | jq '.timestamp'

# 5. Test Oracle connectivity
curl http://localhost:47778/api/health
```

**Recovery**:
```bash
# Restart agent (if daemon)
bash agents/<agent>.sh start

# Clear stuck messages (use with caution)
rm /tmp/manusat-bus/<agent>/*.msg

# Send wake-up message
bash organs/mouth.sh tell <agent> "command:wake-up"
```

---

#### "Message not delivered"

**Diagnosis**:
```bash
# Check bus routing
bash network/bus.sh stats

# Verify message format
cat /tmp/manusat-bus/<to-agent>/*.msg | head -20

# Check for DLQ entries
ls /tmp/manusat-bus/<agent>/dlq/
```

---

#### "Oracle returning errors"

**Diagnosis**:
```bash
# Check Oracle logs
tail -50 /workspaces/arra-oracle-v3/oracle.log

# Test search endpoint
curl "http://localhost:47778/api/search?q=test&limit=1"

# Check disk space
df -h /workspaces/arra-oracle-v3
```

---

### Diagnostic Commands Reference

| Command | Purpose |
|---------|---------|
| `bash organs/ear.sh inbox <agent>` | View agent's pending messages |
| `bash organs/ear.sh dlq <agent>` | View dead letter queue |
| `bash network/bus.sh queue` | Show all pending messages system-wide |
| `bash network/bus.sh stats` | Show bus statistics (throughput, errors) |
| `bash organs/heart.sh rhythm` | Vital signs dashboard |
| `bash organs/heart.sh oracle-health` | Check Oracle health status |
| `bash eval/soul-check.sh` | Test inter-agent communication |
| `bash eval/body-check.sh` | Full system health check |
| `curl http://localhost:47778/api/health` | Oracle health endpoint |
| `bash limbs/oracle.sh search "<query>"` | Search Oracle knowledge |

---

### Recovery Procedures

#### Restart Single Agent
```bash
# Stop agent (if running as daemon)
pkill -f "<agent>"

# Clear inbox (optional)
rm /tmp/manusat-bus/<agent>/*.msg

# Start agent
bash agents/<agent>.sh start
```

#### Clear Stuck Messages
```bash
# Archive first (recommended)
mkdir -p /tmp/manusat-bus/<agent>/archive/
mv /tmp/manusat-bus/<agent>/*.msg /tmp/manusat-bus/<agent>/archive/

# Or purge directly
find /tmp/manusat-bus/<agent>/ -name "*.msg" -delete
```

#### Emergency Oracle Restart
```bash
# Kill existing processes
pkill -f "bun.*src/server.ts"

# Clear any locks
rm -f /workspaces/arra-oracle-v3/*.lock

# Restart
export PATH="$HOME/.bun/bin:$PATH"
cd /workspaces/arra-oracle-v3
ORACLE_PORT=47778 bun run src/server.ts > /tmp/oracle-server.log 2>&1 &

# Verify
sleep 3
curl http://localhost:47778/api/health
```

---

## Example Message Flows

### Flow 1: Feature Request (Standard)

```
┌────────┐     task:new-feature      ┌────────┐
│ human  │ ────────────────────────→ │  vaja  │
└────────┘                           └────┬───┘
                                          │ report:human-request
                                          ▼
                                     ┌────────┐
                                     │  jit   │
                                     └────┬───┘
                                          │ delegate:strategic
                                          ▼
┌────────┐                          ┌────────┐
│  lak   │ ←────── design:spec ──── │  soma  │
└────┬───┘                          └────────┘
     │ design:architecture
     ▼
┌────────┐     task:implement        ┌────────┐
│innova  │ ←──────────────────────── │  soma  │
└────┬───┘
     │ task:test
     ▼
┌────────┐     report:test-pass      ┌────────┐
│ chamu  │ ────────────────────────→ │ innova │
└────────┘                           └────┬───┘
                                          │ review:code
                                          ▼
                                     ┌────────┐
                                     │  neta  │
                                     └────┬───┘
                                          │ approval:merge
                                          ▼
┌────────┐                          ┌────────┐
│  pada  │ ←────── deploy:staging ─ │  soma  │
└────┬───┘
     │ report:deploy-success
     ▼
┌────────┐     report:complete       ┌────────┐
│  vaja  │ ←──────────────────────── │ innova │
└────┬───┘
     │ notify:human
     ▼
┌────────┐
│ human  │
└────────┘
```

**Total hops**: 12  
**Expected duration**: 15-30 minutes

---

### Flow 2: Bug Hotfix (Expedited)

```
┌────────┐     alert:bug-detected      ┌────────┐
│ chamu  │ ──────────────────────────→ │  jit   │
└────────┘                             └────┬───┘
                                            │ task:fix-urgent
                                            ▼
                                       ┌────────┐
                                       │ innova │
                                       └────┬───┘
                                            │ review:fast
                                            ▼
                                       ┌────────┐
                                       │  neta  │
                                       └────┬───┘
                                            │ approval:hotfix
                                            ▼
┌────────┐                          ┌────────┐
│  pada  │ ←────── deploy:prod ──── │  soma  │
└────┬───┘
     │ report:deploy-success
     ▼
┌────────┐     report:resolved       ┌────────┐
│  vaja  │ ←──────────────────────── │  jit   │
└────┬───┘
     │ notify:human
     ▼
┌────────┐
│ human  │
└────────┘
```

**Total hops**: 7  
**Expected duration**: 5-10 minutes

---

### Flow 3: Parallel Work ( soma delegates to multiple agents)

```
                    ┌────────┐
                    │  soma  │
                    └────┬───┘
         ┌───────────────┼───────────────┐
         │               │               │
   task:design     task:research    task:plan
         │               │               │
         ▼               ▼               ▼
   ┌────────┐      ┌────────┐      ┌────────┐
   │  rupa  │      │ netra  │      │  lak   │
   └────┬───┘      └────┬───┘      └────┬───┘
        │                │               │
        └────────────────┴───────────────┘
                         │
                   report:parallel-done
                         │
                         ▼
                    ┌────────┐
                    │  soma  │ (synthesizes results)
                    └────────┘
```

**Pattern**: Fan-out parallel tasks, fan-in synthesis  
**Use case**: Complex initiatives requiring multiple specialties

---

### Flow 4: System Monitoring (Continuous)

```
┌────────┐  pulse:check  ┌────────┐  stats  ┌─────────┐
│  jit   │ ────────────→ │  pran  │ ←────── │  all    │
└────────┘               └────┬───┘         │ agents  │
                              │ heartbeat   └─────────┘
                              ▼
                        ┌─────────┐
                        │ sayan   │ (broadcast vital signs)
                        └─────────┘
```

**Frequency**: Every 30 seconds (normal), 10 seconds (sprint mode)

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-04-23 | Initial protocol — file-based bus |
| 1.0 | 2026-06-07 | JIT-005: Add `protocol-version` header; JIT-002: Add `idempotency-key`; JIT-011: Add `x-signature` HMAC |
| 1.0 | 2026-06-07 (JIT-022) | Expanded Agent Roles to all 14 agents; Added Error Handling & Recovery section; Added Troubleshooting guide; Added example message flows |

### Version Compatibility Rules

- **Major version mismatch**: Warn if message major version differs from local — may indicate incompatible features
- **Minor version difference**: Info-level log only — backward compatible within same major version
- **Default**: Messages without `protocol-version` field treated as 1.0

---

## Appendix: Quick Reference

### Subject Prefix Cheat Sheet

```
task:*      — Work assignment
think:*     — Request analysis/design
report:*    — Status update
alert:*     — Urgent notification
learn:*     — Knowledge contribution
request:*   — Information query
command:*   — Direct order
reply:*     — Response to correlation-id
broadcast:* — System-wide announcement
```

### Inbox Paths

```
/tmp/manusat-bus/{jit,soma,innova,lak,neta,vaja,chamu,rupa,pada,netra,karn,mue,pran,sayanprasathan}/
```

### Critical Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Inbox depth | >50 messages | >100 messages |
| Message age | >1 hour | >4 hours |
| Oracle failures | 2 consecutive | 3 consecutive (triggers restart) |
| Heartbeat miss | 1 cycle | 3+ cycles |
| DLQ depth | >10 messages | >50 messages |
