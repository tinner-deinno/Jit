---
description: Use Arra Oracle MCP tools for knowledge management, search, threads, traces, and scheduling. Trigger when user asks to search knowledge, learn something, check inbox, create threads, trace work, or schedule.
allowed-tools:
  - mcp__arra-oracle-v2__arra_search
  - mcp__arra-oracle-v2__arra_learn
  - mcp__arra-oracle-v2__arra_list
  - mcp__arra-oracle-v2__arra_stats
  - mcp__arra-oracle-v2__arra_concepts
  - mcp__arra-oracle-v2__arra_reflect
  - mcp__arra-oracle-v2__arra_supersede
  - mcp__arra-oracle-v2__arra_handoff
  - mcp__arra-oracle-v2__arra_inbox
  - mcp__arra-oracle-v2__arra_verify
  - mcp__arra-oracle-v2__arra_read
  - mcp__arra-oracle-v2__arra_thread
  - mcp__arra-oracle-v2__arra_threads
  - mcp__arra-oracle-v2__arra_thread_read
  - mcp__arra-oracle-v2__arra_thread_update
  - mcp__arra-oracle-v2__arra_trace
  - mcp__arra-oracle-v2__arra_trace_list
  - mcp__arra-oracle-v2__arra_trace_get
  - mcp__arra-oracle-v2__arra_trace_link
  - mcp__arra-oracle-v2__arra_trace_unlink
  - mcp__arra-oracle-v2__arra_trace_chain
  - mcp__arra-oracle-v2__arra_schedule_add
  - mcp__arra-oracle-v2__arra_schedule_list
---

# Oracle Skill — Arra Oracle V2 MCP

Use the Oracle as a persistent knowledge base. Query before major decisions to avoid duplicating stored knowledge. Learn after solving novel problems.

## Tool Reference (22 tools)

### Knowledge
| Tool | When to use |
|------|-------------|
| `arra_search` | Search by keyword/concept — use first before arra_learn |
| `arra_learn` | Persist new patterns, decisions, retrospectives |
| `arra_list` | Browse all documents |
| `arra_read` | Read a specific document by ID |
| `arra_stats` | Check DB stats (doc count, vector count) |
| `arra_concepts` | List all concept tags |
| `arra_reflect` | Random wisdom (daily reflection) |
| `arra_supersede` | Mark old docs as replaced by newer version |
| `arra_verify` | Verify document integrity |
| `arra_handoff` | Write session handoff summary |
| `arra_inbox` | Read inbox messages from other agents |

### Threads (Forum-style discussion)
| Tool | When to use |
|------|-------------|
| `arra_thread` | Create a new thread or send a reply |
| `arra_threads` | List all threads |
| `arra_thread_read` | Read a specific thread with replies |
| `arra_thread_update` | Update thread status (open/closed/resolved) |

### Traces (Work tracking)
| Tool | When to use |
|------|-------------|
| `arra_trace` | Create a trace record for a task/decision |
| `arra_trace_list` | List all traces |
| `arra_trace_get` | Get a specific trace |
| `arra_trace_link` | Link two related traces |
| `arra_trace_unlink` | Remove link between traces |
| `arra_trace_chain` | Show full trace dependency chain |

### Schedule
| Tool | When to use |
|------|-------------|
| `arra_schedule_add` | Add a schedule entry |
| `arra_schedule_list` | List scheduled entries |

## Usage Patterns

### Oracle-First Pattern
Before any major decision or implementation:
1. `arra_search` → check if solution already exists
2. If found: use existing pattern, cite the doc
3. If new: solve, then `arra_learn` to persist

### Learn Format
```
concept: "pattern-name"  
content: "What was learned, why it matters, how to apply"
tags: ["tag1", "tag2", "category"]
```

### Handoff Format
At end of session: `arra_handoff` with summary of:
- What was accomplished
- Decisions made
- Next steps
- Blockers

## Trigger Phrases
- "search oracle", "ค้นหา oracle", "จำไว้"
- "learn this", "persist", "remember for next time"
- "check inbox", "oracle inbox"
- "create thread", "สร้าง thread"
- "trace", "track this work"
- "schedule", "add to schedule"
- "reflect", "wisdom"
