# Direct Organ-to-Organ Messaging (JIT-026)

## Overview

ระบบ direct messaging channels ระหว่าง organs ด้วย named pipes (FIFOs) และ file-based queue fallback

## Architecture

```
┌─────────────┐                      ┌─────────────┐
│   Organ A   │                      │   Organ B   │
│             │  direct-channel.sh   │             │
│  mouth.sh   │ ───────────────────► │   ear.sh    │
└─────────────┘    Named Pipe FIFO   └─────────────┘
                          │
                          ▼
              /tmp/manusat-pipes/
              ├── organA--organB/
              │   ├── pipe.fifo      (named pipe)
              │   └── queue/         (file-based fallback)
              │       ├── <ts>.msg
              │       └── <ts>.read
              └── organC--organD/
                  └── ...
```

## Features

| Feature | Description |
|---------|-------------|
| **Named Pipes** | POSIX FIFOs at `/tmp/manusat-pipes/<organ1>--<organ2>/pipe.fifo` |
| **File Queue** | Fallback queue directory with max 100 pending messages |
| **Auto Fallback** | If channel unavailable or queue full → fallback to `bus.sh` |
| **Queue Limit** | Max 100 pending messages per channel |
| **Stats Tracking** | Messages sent/received/fallbacks per channel |
| **Bus Integration** | `bus.sh stats` shows direct channel utilization |

## Commands

### Create a channel

```bash
bash network/direct-channel.sh create <organ1> <organ2>

# Example:
bash network/direct-channel.sh create innova soma
```

### Send a message

```bash
bash network/direct-channel.sh send <from> <to> <message>

# Example:
bash network/direct-channel.sh send mue chamu "Execute test suite"

# Falls back to bus.sh if:
# - Channel doesn't exist
# - Queue is full (>= 100 messages)
```

### Receive messages

```bash
bash network/direct-channel.sh recv <organ1> <organ2> [count]

# Example:
bash network/direct-channel.sh recv chamu mue 10
```

### View statistics

```bash
# Human-readable
bash network/direct-channel.sh stats

# JSON format
bash network/direct-channel.sh stats --json
```

### Check queue depth

```bash
bash network/direct-channel.sh queue-depth <organ1> <organ2>

# Example:
bash network/direct-channel.sh queue-depth innova soma
# Output: 5 / 100
```

### Cleanup unused channels

```bash
bash network/direct-channel.sh cleanup
```

### Create all pairwise channels

```bash
bash network/direct-channel.sh create-all
```

## Bus Integration

Direct channel utilization appears in `bus.sh stats`:

```bash
bash network/bus.sh stats

# Output includes:
#    Direct Channels: 6 sent, 1 fallbacks (16.7%), 4 channels
```

## Stats JSON Schema

```json
{
  "channels": {
    "innova--soma": {
      "created_at": "2026-06-08T04:04:16",
      "messages_sent": 1,
      "messages_received": 1,
      "fallbacks_to_bus": 0,
      "current_queue_depth": 0
    }
  },
  "totals": {
    "created": 4,
    "messages_sent": 6,
    "messages_received": 1,
    "fallbacks_to_bus": 1
  },
  "updated_at": "2026-06-08T04:05:00"
}
```

## File Locations

| Path | Purpose |
|------|---------|
| `/tmp/manusat-pipes/` | Root directory for all channels |
| `/tmp/manusat-pipes/<a>--<b>/pipe.fifo` | Named pipe (FIFO) |
| `/tmp/manusat-pipes/<a>--<b>/queue/` | File-based message queue |
| `/tmp/manusat-channels-stats.json` | Channel statistics |

## Usage Patterns

### High-frequency organ pairs

For organs that communicate frequently:

```bash
# Create dedicated channels for hot paths
bash network/direct-channel.sh create soma lak      # strategy → architecture
bash network/direct-channel.sh create innova chamu  # code → test
bash network/direct-channel.sh create mue pada      # execute → deploy
```

### Standard feature flow with direct channels

```
human → vaja → jit → soma → lak → innova → chamu → neta → pada → vaja
        │      │     │     │       │        │       │       │
        └──────┴─────┴─────┴───────┴────────┴───────┴───────┘
                    Direct channels for adjacent organs
```

### Fallback behavior

When channel unavailable or queue full:

```bash
# This will fallback to bus.sh automatically
bash network/direct-channel.sh send unknown organ "Hello"
# ⚠️  Channel not found: unknown--organ — falling back to bus
# ✅ bus → organ: [direct:unknown] ...
```

## Acceptance Criteria (JIT-026)

- [x] Named pipes for organ pairs at `/tmp/manusat-pipes/<organ1>--<organ2>/`
- [x] Direct send function with `send_direct()`
- [x] Fallback to `bus.sh` when channel unavailable or queue full
- [x] Max 100 pending messages per channel
- [x] `bus.sh stats` reports direct-channel utilization
