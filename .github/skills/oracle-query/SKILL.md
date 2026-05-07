---
name: oracle-query
description: "Query the Arra Oracle V3 knowledge base for wisdom, patterns, and learnings. Use when: searching Oracle, asking what innova knows, querying knowledge base, ถามองค์ความรู้, ค้นหาความรู้, oracle search"
---

# Oracle Query Skill

Query the Arra Oracle V3 MCP server — 24 tools available for Claude Code.

## MCP Tools (24 total)

| Tool | Description |
|------|-------------|
| `arra_search` | Hybrid search (FTS5 + LanceDB vector) |
| `arra_reflect` | Random wisdom from knowledge base |
| `arra_learn` | Add new patterns/learnings |
| `arra_list` | Browse all documents |
| `arra_stats` | Database statistics |
| `arra_concepts` | List concept tags |
| `arra_supersede` | Mark documents as superseded |
| `arra_handoff` | Session handoff |
| `arra_inbox` | Inbox messages |
| `arra_verify` | Verify knowledge base integrity |
| `arra_thread` | Create thread |
| `arra_threads` | List threads |
| `arra_thread_read` | Read thread |
| `arra_thread_update` | Update thread |
| `arra_trace` | Create trace |
| `arra_trace_list` | List traces |
| `arra_trace_get` | Get trace |
| `arra_trace_link` | Link traces |
| `arra_trace_unlink` | Unlink traces |
| `arra_trace_chain` | Trace chain |
| `arra_schedule_add` | Add schedule entry |
| `arra_schedule_list` | List schedule |
| `arra_read` | Read full document |

## MCP Server Config (~/.claude.json)

```json
{
  "mcpServers": {
    "arra-oracle-v2": {
      "command": "/home/codespace/.bun/bin/bun",
      "args": ["/workspaces/arra-oracle-v3/src/index.ts"],
      "env": {
        "PATH": "/home/codespace/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "ORACLE_PORT": "47778"
      }
    }
  }
}
```

## Quick Start

```bash
# Start everything at once
bash /workspaces/Jit/scripts/setup-oracle-full.sh

# Check status
bash /workspaces/Jit/scripts/setup-oracle-full.sh --status

# Check Oracle health
curl -s http://localhost:47778/api/health

# Search via CLI
bun /workspaces/arra-oracle-v3/cli/src/cli.ts search "innova"

# Learn something
bun /workspaces/arra-oracle-v3/cli/src/cli.ts learn "new insight" --concepts "tag1,tag2"
```

## Usage in Claude Code

When the MCP server is connected, use tools directly:
- `arra_search("query")` — find relevant knowledge
- `arra_learn("pattern", content, concepts)` — save new learning
- `arra_reflect()` — get random wisdom
- `arra_stats()` — database overview
- `arra_schedule_add(title, date)` — add task to schedule
- `arra_trace(query)` — log discovery sessions

## HTTP API Alternative (port 47778)

```bash
# Search
curl -s "http://localhost:47778/api/search?q=<QUERY>"

# Learn
curl -s -X POST http://localhost:47778/api/learn \
  -H "Content-Type: application/json" \
  -d '{"pattern":"<title>","content":"<what-learned>","type":"learning","concepts":["tag1"],"origin":"innova-jit"}'
```

