# innova-bridge.sh — Mind-Body Bridge Documentation

**File**: `Jit/limbs/innova-bridge.sh`
**Version**: 1.0 | **Phase**: 3 of JARVIS+ integration

## What it does

Connects Jit (mind/soul repo) to innova-bot (body/MCP server) via:
- **File-based events** — writes JSON to `innova-bot/events/` (always works, offline-capable)
- **Optional MCP HTTP** — tries `innova-bot/sse:7010` if running (non-fatal fallback)

## Setup

```bash
# Source it to get functions in current shell
source limbs/innova-bridge.sh

# Or run directly
bash limbs/innova-bridge.sh status
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `INNOVA_BOT_ROOT` | auto-detect (`/c/Users/admin/DEV/...`) | path to innova-bot repo |
| `INNOVA_BOT_SSE` | `http://localhost:7010` | SSE endpoint (optional) |
| `BRIDGE_DEBUG` | `` (off) | set to `1` for verbose output |

## Functions

### `bridge_publish_event <phase> <status> [message]`

Writes a JSON event file + optionally pings MCP HTTP.

```bash
bridge_publish_event "phase-3" "complete" "mind-body bridge deployed"
# → innova-bot/events/bridge-phase3-complete.json
```

Output JSON format:
```json
{"phase":"3","status":"complete","message":"...","timestamp":"ISO","from":"jit","bridge_version":"1.0"}
```

### `bridge_remember <topic> <content>`

Stores a Jit knowledge entry in innova-bot's workspace.

```bash
bridge_remember "architecture" "Use hexagonal ports/adapters for all MCP tools"
# → innova-bot/workspace/jit-architecture.txt
```

### `bridge_search <query>`

Searches `events/` + `workspace/` for any match.

```bash
bridge_search "phase-3"
bridge_search "architecture"
```

### `bridge_status`

Shows full connection status: repo path, event count, workspace entries, SSE health.

```bash
bridge_status
# [BRIDGE] === innova-bot bridge status ===
# [BRIDGE] INNOVA_BOT_ROOT: /c/Users/admin/...
# [BRIDGE] repo: FOUND
# [BRIDGE] events: 5 JSON files
# [BRIDGE] SSE endpoint: DOWN (file-only mode active)
```

## End-of-Phase Ritual Integration

Every phase should end with:

```bash
source limbs/innova-bridge.sh
bridge_publish_event "<phase>" "complete" "<one-line summary>"
```

Example (Phase 3 completion):
```bash
bridge_publish_event "3" "complete" "mind-body bridge deployed — 4 functions live"
```

## File Locations

```
Jit/
└── limbs/
    ├── innova-bridge.sh    ← this file (source or run)
    └── innova-bridge.md    ← this doc

innova-bot/
├── events/
│   ├── bridge-phase3-complete.json   ← published by Jit
│   └── jit-bridge.md                 ← innova-bot side documentation
└── workspace/
    └── jit-*.txt                     ← Jit memories
```

## Fallback Behavior

| Condition | Behavior |
|-----------|---------|
| innova-bot not installed | Error on publish, non-fatal |
| SSE not running | File-only mode (always works) |
| No curl installed | Skip HTTP, file only |
| events/ doesn't exist | Auto-created on first publish |
