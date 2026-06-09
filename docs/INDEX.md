# Jit Documentation Index

> สารบัญเอกสารระบบ มนุษยย์ Agent — จัดหมวดหมู่ตามหน้าที่

## Getting Started

| Document | Description |
|----------|-------------|
| [[../README]] | Quick start, system overview, key commands |
| [[multiagent-spec]] | Full system specification v2.0 with 14-agent hierarchy |
| [[new-agent-guide]] | Bootstrap guide for adding agents to the system |
| [[PROTOCOL]] | Message format, subject conventions, error handling |

## Architecture

| Document | Description |
|----------|-------------|
| [[JIT_ARCHITECTURE]] | Mind/body/memory/limbs component map |
| [[JIT_INNOVA_BODY_BINDING]] | How Jit mind binds to innova-bot body |
| [[THE_GENESIS_OF_INNOVA]] | Origin story and evolution of the system |
| [[multi-provider-gateway]] | Multi-LLM provider gateway configuration |
| [[direct-channel-guide]] | Direct agent-to-agent channel setup |

## Features (JIT Tickets)

### Monitoring & Observability

| Document | Ticket | Owner |
|----------|--------|-------|
| [[registry-health]] | JIT-020 | netra |
| [[message-tracing]] | JIT-021 | netra |
| [[cot-logging]] | JIT-022 | innova |
| [[memory-embeddings]] | JIT-023 | innova |

### Implementation Reports

| Document | Description |
|----------|-------------|
| [[JIT-028-implementation]] | Latest feature implementation report |
| [[KARN_VOICE_PROGRESS]] | Voice input subsystem progress |
| [[MCP_PYVENV_TROUBLESHOOTING]] | MCP server virtualenv troubleshooting |
| [[PC3_AGENT_RUNBOOK]] | Agent operation runbook |

## Operational Guides

| Document | Description |
|----------|-------------|
| [[agent-autonomy]] | Autonomous agent operation and management |
| [[pm-sa-optimal-interval]] | Project Manager / Solution Architect optimal intervals |

## External References

| Resource | Description |
|----------|-------------|
| [Arra Oracle V3](https://github.com/Soul-Brews-Studio/arra-oracle-v3) | Knowledge base with vector search |
| [MDES Ollama](https://ollama.mdes-innova.online) | Thai language LLM endpoint |

---

## Quick Links by Task

### System Health
- Check agent status: `bash eval/soul-check.sh`
- Full system health: `bash eval/body-check.sh`
- Registry health docs: [[registry-health]]

### Debugging
- Trace a message: `bash network/bus.sh trace <correlation-id>`
- View message latency: `bash network/bus.sh stats --trace`
- Message tracing docs: [[message-tracing]]

### Decision Making
- Plan with CoT logging: `bash limbs/think.sh plan "task" "context"`
- View reasoning logs: `bash limbs/think.sh log --cot`
- CoT logging docs: [[cot-logging]]

### Memory & Knowledge
- Search Oracle: `bash limbs/oracle.sh search "topic"`
- Recall memories: `bash memory/shared.sh recall "query"`
- Memory embeddings docs: [[memory-embeddings]]

---

*Index last updated: 2026-06-08*
