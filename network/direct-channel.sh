#!/usr/bin/env bash
# network/direct-channel.sh — Direct organ-to-organ messaging via named pipes
#
# หลักพุทธ: อุปาทยะ — อาศัยกันและกันเกิด (direct dependency, no intermediary)
# บทบาท: Fast-path communication between organ pairs with queue management
#
# Usage:
#   ./direct-channel.sh create <organ1> <organ2>     — สร้าง named pipe channel
#   ./direct-channel.sh send <from> <to> <message>   — ส่งผ่าน direct channel (fallback to bus)
#   ./direct-channel.sh recv <organ1> <organ2>       — รับจาก channel (non-blocking)
#   ./direct-channel.sh stats                        — สถิติทุก channels
#   ./direct-channel.sh queue-depth <organ1> <organ2> — ดู queue depth ของ channel
#   ./direct-channel.sh cleanup                      — ล้าง channels ที่ไม่ใช้แล้ว

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-stats}"
shift || true

# ── Constants ──────────────────────────────────────────────────────
PIPES_ROOT="/tmp/manusat-pipes"
BUS_ROOT="/tmp/manusat-bus"
MAX_QUEUE_DEPTH=100  # Max pending messages per channel
REGISTRY="$SCRIPT_DIR/registry.json"

# ── Channel Stats File ─────────────────────────────────────────────
CHANNEL_STATS_FILE="/tmp/manusat-channels-stats.json"

# ── Get list of all organs from registry ───────────────────────────
_get_organs() {
  if [ -f "$REGISTRY" ]; then
    python3 -c "
import json
with open('$REGISTRY') as f:
    d = json.load(f)
for a in d.get('agents', []):
    print(a['name'])
" 2>/dev/null
  else
    echo "innova soma jit vaja chamu rupa pada netra karn mue pran sayanprasathan lak neta"
  fi
}

# ── Initialize pipes directory ─────────────────────────────────────
_init_pipes() {
  mkdir -p "$PIPES_ROOT"
}

# ── Channel ID (sorted pair for consistent naming) ─────────────────
_channel_id() {
  local organ1="$1"
  local organ2="$2"
  # Sort alphabetically for consistent channel naming
  if [[ "$organ1" < "$organ2" ]]; then
    echo "${organ1}--${organ2}"
  else
    echo "${organ2}--${organ1}"
  fi
}

# ── Get channel path ───────────────────────────────────────────────
_channel_path() {
  local organ1="$1"
  local organ2="$2"
  local channel_id=$(_channel_id "$organ1" "$organ2")
  echo "$PIPES_ROOT/$channel_id"
}

# ── Initialize channel stats ───────────────────────────────────────
_init_channel_stats() {
  if [ ! -f "$CHANNEL_STATS_FILE" ]; then
    cat > "$CHANNEL_STATS_FILE" << EOF
{
  "channels": {},
  "totals": {
    "created": 0,
    "messages_sent": 0,
    "messages_received": 0,
    "fallbacks_to_bus": 0
  }
}
EOF
  fi
}

# ── Update channel stats ───────────────────────────────────────────
_update_channel_stats() {
  local channel_id="$1"
  local stat_type="$2"  # sent, received, fallback, created
  local value="${3:-1}"

  python3 - "$CHANNEL_STATS_FILE" "$channel_id" "$stat_type" "$value" << 'PYEOF'
import json
import sys
from datetime import datetime

stats_file = sys.argv[1]
channel_id = sys.argv[2]
stat_type = sys.argv[3]
value = int(sys.argv[4]) if len(sys.argv) > 4 else 1

try:
    with open(stats_file, 'r') as f:
        stats = json.load(f)

    # Initialize channel if not exists
    if channel_id not in stats['channels']:
        stats['channels'][channel_id] = {
            'created_at': datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
            'messages_sent': 0,
            'messages_received': 0,
            'fallbacks_to_bus': 0,
            'current_queue_depth': 0
        }

    # Update the appropriate counter
    if stat_type == 'sent':
        stats['channels'][channel_id]['messages_sent'] += value
        stats['totals']['messages_sent'] += value
    elif stat_type == 'received':
        stats['channels'][channel_id]['messages_received'] += value
        stats['totals']['messages_received'] += value
    elif stat_type == 'fallback':
        stats['channels'][channel_id]['fallbacks_to_bus'] += value
        stats['totals']['fallbacks_to_bus'] += value
    elif stat_type == 'created':
        stats['totals']['created'] += value

    # Update timestamp
    stats['updated_at'] = datetime.now().strftime('%Y-%m-%dT%H:%M:%S')

    with open(stats_file, 'w') as f:
        json.dump(stats, f, indent=2)
except Exception as e:
    print(f"Error updating channel stats: {e}", file=sys.stderr)
PYEOF
}

# ── Update queue depth for channel ─────────────────────────────────
_update_queue_depth() {
  local channel_id="$1"
  local depth="$2"

  python3 - "$CHANNEL_STATS_FILE" "$channel_id" "$depth" << 'PYEOF'
import json
import sys

stats_file = sys.argv[1]
channel_id = sys.argv[2]
depth = int(sys.argv[3])

try:
    with open(stats_file, 'r') as f:
        stats = json.load(f)

    if channel_id in stats['channels']:
        stats['channels'][channel_id]['current_queue_depth'] = depth

    with open(stats_file, 'w') as f:
        json.dump(stats, f, indent=2)
except Exception as e:
    print(f"Error updating queue depth: {e}", file=sys.stderr)
PYEOF
}

# ── Create a direct channel between two organs ─────────────────────
create_channel() {
  local organ1="$1"
  local organ2="$2"

  if [ -z "$organ1" ] || [ -z "$organ2" ]; then
    err "Usage: direct-channel.sh create <organ1> <organ2>"
    exit 1
  fi

  local channel_dir=$(_channel_path "$organ1" "$organ2")
  local channel_id=$(_channel_id "$organ1" "$organ2")

  # Check if channel already exists
  if [ -d "$channel_dir" ]; then
    info "Channel already exists: $channel_id"
    return 0
  fi

  # Create channel directory
  mkdir -p "$channel_dir"

  # Create named pipe (FIFO) for writing
  if ! mkfifo "$channel_dir/pipe.fifo" 2>/dev/null; then
    # If mkfifo fails (e.g., filesystem doesn't support), use file-based queue
    warn "mkfifo not supported, using file-based queue"
  fi

  # Create queue directory for file-based fallback
  mkdir -p "$channel_dir/queue"

  # Initialize stats
  _init_channel_stats
  _update_channel_stats "$channel_id" "created" 1

  ok "Created direct channel: $organ1 ↔ $organ2"
  echo "   Path: $channel_dir"
  echo "   Channel ID: $channel_id"
  echo "   Max queue depth: $MAX_QUEUE_DEPTH"

  log_action "DIRECT_CHANNEL_CREATE" "channel:$channel_id organs:$organ1,$organ2"
}

# ── Send message through direct channel ────────────────────────────
send_direct() {
  local from_organ="$1"
  local to_organ="$2"
  shift 2 || true
  local message="$*"

  if [ -z "$from_organ" ] || [ -z "$to_organ" ] || [ -z "$message" ]; then
    err "Usage: direct-channel.sh send <from> <to> <message>"
    exit 1
  fi

  local channel_dir=$(_channel_path "$from_organ" "$to_organ")
  local channel_id=$(_channel_id "$from_organ" "$to_organ")

  # Check if channel exists
  if [ ! -d "$channel_dir" ]; then
    # Fallback to bus if channel doesn't exist
    warn "Channel not found: $channel_id — falling back to bus"
    _init_channel_stats
    _update_channel_stats "$channel_id" "fallback" 1
    bash "$SCRIPT_DIR/bus.sh" send "$to_organ" "direct:$from_organ" "$message"
    return 0
  fi

  # Check queue depth before sending
  local queue_depth=$(find "$channel_dir/queue" -name "*.msg" 2>/dev/null | wc -l)

  if [ "$queue_depth" -ge "$MAX_QUEUE_DEPTH" ]; then
    # Queue full, fallback to bus
    warn "Channel queue full ($queue_depth/$MAX_QUEUE_DEPTH): $channel_id — falling back to bus"
    _update_channel_stats "$channel_id" "fallback" 1
    bash "$SCRIPT_DIR/bus.sh" send "$to_organ" "direct:$from_organ" "$message"
    return 0
  fi

  # Create message file
  local ts=$(date +%s%N)
  local msg_file="$channel_dir/queue/${ts}.msg"

  cat > "$msg_file" << EOF
from:$from_organ
to:$to_organ
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
channel:$channel_id
---
$message
EOF

  # Try to write to FIFO if it exists (non-blocking)
  if [ -p "$channel_dir/pipe.fifo" ]; then
    # Non-blocking write to FIFO
    (echo "$message" > "$channel_dir/pipe.fifo" &) 2>/dev/null || true
  fi

  _update_channel_stats "$channel_id" "sent" 1

  ok "direct → $to_organ: [$from_organ] (channel:$channel_id queue:$((queue_depth + 1))/$MAX_QUEUE_DEPTH)"
  log_action "DIRECT_CHANNEL_SEND" "from:$from_organ to:$to_organ channel:$channel_id"
}

# ── Receive message from direct channel ────────────────────────────
recv_direct() {
  local organ1="$1"
  local organ2="$2"
  local count="${3:-10}"

  if [ -z "$organ1" ] || [ -z "$organ2" ]; then
    err "Usage: direct-channel.sh recv <organ1> <organ2> [count]"
    exit 1
  fi

  local channel_dir=$(_channel_path "$organ1" "$organ2")
  local channel_id=$(_channel_id "$organ1" "$organ2")

  if [ ! -d "$channel_dir" ]; then
    info "Channel not found: $channel_id"
    exit 0
  fi

  local queue_dir="$channel_dir/queue"
  local msg_count=$(find "$queue_dir" -name "*.msg" 2>/dev/null | wc -l)

  if [ "$msg_count" -eq 0 ]; then
    info "Channel $channel_id: queue ว่าง"
    exit 0
  fi

  step "รับ $msg_count messages จาก channel $channel_id"
  local recv_count=0

  for msg_file in $(ls -t "$queue_dir"/*.msg 2>/dev/null | head -n "$count"); do
    [ -f "$msg_file" ] || continue
    echo ""
    echo -e "${CYAN}── $(basename "$msg_file") ──${RESET}"
    cat "$msg_file"
    echo ""

    # Move to .read after reading
    mv "$msg_file" "${msg_file%.msg}.read"
    ((recv_count++))
  done

  # Update stats
  _init_channel_stats
  _update_channel_stats "$channel_id" "received" "$recv_count"

  # Update queue depth
  local new_depth=$(find "$queue_dir" -name "*.msg" 2>/dev/null | wc -l)
  _update_queue_depth "$channel_id" "$new_depth"

  log_action "DIRECT_CHANNEL_RECV" "channel:$channel_id count:$recv_count"
}

# ── Show channel statistics ────────────────────────────────────────
show_stats() {
  local json_mode=""
  if [ "$1" = "--json" ]; then
    json_mode="yes"
  fi

  _init_channel_stats

  if [ "$json_mode" = "yes" ]; then
    if [ -f "$CHANNEL_STATS_FILE" ]; then
      cat "$CHANNEL_STATS_FILE"
    else
      echo '{"error": "Channel stats not initialized"}'
    fi
    echo ""
    exit 0
  fi

  echo ""
  echo -e "${BOLD}${CYAN}[ Direct Channel Statistics ]${RESET}"
  echo -e "   Pipes Root: $PIPES_ROOT"
  echo -e "   Max Queue Depth: $MAX_QUEUE_DEPTH per channel"
  echo ""

  if [ ! -f "$CHANNEL_STATS_FILE" ]; then
    info "No channel activity yet"
    exit 0
  fi

  python3 - "$CHANNEL_STATS_FILE" << 'PYEOF'
import json
import sys
import os

stats_file = sys.argv[1]

with open(stats_file, 'r') as f:
    stats = json.load(f)

totals = stats.get('totals', {})
print(f"   {'Channel':<25} {'Sent':>6} {'Recv':>6} {'Fallback':>8} {'Queue':>6}")
print(f"   {'─'*55}")

for channel_id, channel_stats in sorted(stats.get('channels', {}).items()):
    sent = channel_stats.get('messages_sent', 0)
    received = channel_stats.get('messages_received', 0)
    fallbacks = channel_stats.get('fallbacks_to_bus', 0)
    queue_depth = channel_stats.get('current_queue_depth', 0)

    # Color code queue depth
    if queue_depth >= 80:
        queue_str = f"\033[31m{queue_depth}\033[0m"  # Red
    elif queue_depth >= 50:
        queue_str = f"\033[33m{queue_depth}\033[0m"  # Yellow
    else:
        queue_str = str(queue_depth)

    print(f"   {channel_id:<25} {sent:>6} {received:>6} {fallbacks:>8} {queue_str:>6}")

print(f"   {'─'*55}")
print(f"   {'TOTAL':<25} {totals.get('messages_sent', 0):>6} {totals.get('messages_received', 0):>6} {totals.get('fallbacks_to_bus', 0):>8}")
print("")

# Show utilization summary
total_channels = len(stats.get('channels', {}))
active_channels = sum(1 for c in stats.get('channels', {}).values() if c.get('messages_sent', 0) > 0)
total_fallbacks = totals.get('fallbacks_to_bus', 0)
total_sent = totals.get('messages_sent', 0)

if total_sent > 0:
    fallback_rate = (total_fallbacks / total_sent) * 100
    print(f"   Channels created: {total_channels}")
    print(f"   Active channels: {active_channels}")
    print(f"   Fallback rate: {fallback_rate:.1f}% ({total_fallbacks}/{total_sent})")
else:
    print("   No messages sent yet")
PYEOF

  echo ""
}

# ── Show queue depth for specific channel ──────────────────────────
show_queue_depth() {
  local organ1="$1"
  local organ2="$2"

  if [ -z "$organ1" ] || [ -z "$organ2" ]; then
    err "Usage: direct-channel.sh queue-depth <organ1> <organ2>"
    exit 1
  fi

  local channel_dir=$(_channel_path "$organ1" "$organ2")
  local channel_id=$(_channel_id "$organ1" "$organ2")

  if [ ! -d "$channel_dir" ]; then
    info "Channel not found: $channel_id"
    echo "0"
    exit 0
  fi

  local queue_depth=$(find "$channel_dir/queue" -name "*.msg" 2>/dev/null | wc -l)
  echo "$queue_depth / $MAX_QUEUE_DEPTH"

  if [ "$queue_depth" -ge "$MAX_QUEUE_DEPTH" ]; then
    warn "Queue FULL — new messages will fallback to bus"
  elif [ "$queue_depth" -ge $((MAX_QUEUE_DEPTH * 80 / 100)) ]; then
    warn "Queue nearly full (>80%)"
  fi
}

# ── Cleanup unused channels ────────────────────────────────────────
cleanup() {
  step "Cleaning up unused channels..."

  local cleaned=0
  for channel_dir in "$PIPES_ROOT"/*/; do
    [ -d "$channel_dir" ] || continue

    local msg_count=$(find "$channel_dir/queue" -name "*.msg" 2>/dev/null | wc -l)
    local read_count=$(find "$channel_dir/queue" -name "*.read" 2>/dev/null | wc -l)

    # Remove channel if empty and older than 1 hour
    if [ "$msg_count" -eq 0 ]; then
      local dir_age=$(find "$channel_dir" -mmin +60 2>/dev/null | head -1)
      if [ -n "$dir_age" ]; then
        rm -rf "$channel_dir"
        ((cleaned++))
      fi
    fi
  done

  ok "Cleaned up $cleaned unused channels"
  log_action "DIRECT_CHANNEL_CLEANUP" "cleaned:$cleaned"
}

# ── Create all pairwise channels (bootstrap) ───────────────────────
create_all() {
  step "Creating all pairwise channels..."

  local organs=($(_get_organs))
  local created=0

  for ((i=0; i<${#organs[@]}; i++)); do
    for ((j=i+1; j<${#organs[@]}; j++)); do
      local organ1="${organs[$i]}"
      local organ2="${organs[$j]}"

      # Skip if already exists
      local channel_dir=$(_channel_path "$organ1" "$organ2")
      if [ ! -d "$channel_dir" ]; then
        mkdir -p "$channel_dir/queue"
        _init_channel_stats
        _update_channel_stats "$(_channel_id "$organ1" "$organ2")" "created" 1
        ((created++))
      fi
    done
  done

  ok "Created $created new channels"
  echo "   Total possible channels: $((${#organs[@]} * (${#organs[@]} - 1) / 2))"
  log_action "DIRECT_CHANNEL_CREATE_ALL" "created:$created"
}

# ── Main command handler ───────────────────────────────────────────
_init_pipes
_init_channel_stats

case "$CMD" in
  create)
    create_channel "$@"
    ;;
  send)
    send_direct "$@"
    ;;
  recv)
    recv_direct "$@"
    ;;
  stats)
    show_stats "$@"
    ;;
  queue-depth)
    show_queue_depth "$@"
    ;;
  cleanup)
    cleanup
    ;;
  create-all)
    create_all
    ;;
  *)
    echo "Usage: direct-channel.sh {create|send|recv|stats|queue-depth|cleanup|create-all}"
    echo ""
    echo "  create <organ1> <organ2>         — สร้าง named pipe channel"
    echo "  send <from> <to> <message>       — ส่งผ่าน direct channel (fallback to bus)"
    echo "  recv <organ1> <organ2> [count]   — รับจาก channel"
    echo "  stats [--json]                   — สถิติทูก channels"
    echo "  queue-depth <organ1> <organ2>    — ดู queue depth"
    echo "  cleanup                          — ล้าง channels ที่ไม่ใช้แล้ว"
    echo "  create-all                       — สร้างทุก pairwise channels"
    echo ""
    echo "  Features:"
    echo "  - Named pipes (FIFOs) at /tmp/manusat-pipes/<organ1>--<organ2>/"
    echo "  - File-based queue fallback"
    echo "  - Max 100 pending messages per channel"
    echo "  - Auto-fallback to bus.sh when channel unavailable or queue full"
    ;;
esac
