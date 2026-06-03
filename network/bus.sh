#!/usr/bin/env bash
# network/bus.sh — รถบัสข้อมูล: ส่งและรับ message ระหว่าง agents
#
# หลักพุทธ: อิทัปปัจจยตา — เชื่อมโยงปัจจัยต่างๆ ให้เกิดผล
# บทบาท multiagent: reliable message delivery, priority-queued management
#
# Usage:
#   ./bus.sh send <to> <priority> <subject> <body>   — ส่ง message (priority: high|med|low)
#   ./bus.sh broadcast <priority> <subject> <body>    — ส่ง broadcast ถึงทุก agent
#   ./bus.sh recv <agent>                           — รับ messages ของ agent (sorted by priority)
#   ./bus.sh queue                                  — ดู queue ทั้งหมด
#   ./bus.sh flush                                  — ล้าง queue เก่า
#   ./bus.sh stats                                  — สถิติ bus

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-queue}"
shift || true

BUS_ROOT="/tmp/manusat-bus"
STAGING_DIR="/tmp/manusat-bus-staging"
REGISTRY="$SCRIPT_DIR/registry.json"

# Initialize bus structure
_init_bus() {
  mkdir -p "$BUS_ROOT"
  mkdir -p "$STAGING_DIR"
  if [ -f "$REGISTRY" ]; then
    # Use python to read registry and create directories
    python3 -c "
import json, os
try:
    with open('$REGISTRY') as f:
        d = json.load(f)
    for a in d.get('agents', []):
        name = a['name']
        for p in ['high', 'med', 'low']:
            os.makedirs('$BUS_ROOT/' + name + '/' + p, exist_ok=True)
except Exception as e:
    print(f'Error initializing bus from registry: {e}')
"
  else
    # Fallback for basic agents if registry is missing
    for a in "innova" "soma" "jit"; do
      for p in "high" "med" "low"; do mkdir -p "$BUS_ROOT/$a/$p"; done
    done
  fi
}

# Atomic delivery to prevent race conditions
_deliver() {
  local to="$1"
  local priority="$2"
  local subject="$3"
  local body="$4"
  local from="${5:-system}"
  local corr_id="${6:-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -N 8 | head -n 1)}"

  # Validate priority
  case "$priority" in
    high|med|low) ;;
    *) priority="med" ;;
  esac

  # Generate high-precision timestamp for strict ordering (YYYYMMDDHHMMSS_nanos)
  local ts=$(date +%Y%m%d%H%M%S_%N)
  local filename="${ts}_${corr_id}.msg"
  local staging_file="$STAGING_DIR/$filename"
  local target_dir="$BUS_ROOT/$to/$priority"

  # Ensure target directory exists (in case agent was added since boot)
  mkdir -p "$target_dir"

  # 1. Write to staging directory (asynchronous/isolated)
  cat > "$staging_file" << EOF
from:$from
to:$to
priority:$priority
subject:$subject
timestamp:$(date '+%Y-%m-%dT%H:%M:%S.%N')
correlation-id:$corr_id
---
$body
EOF

  # 2. Atomic move to target inbox (prevents partial reads)
  mv "$staging_file" "$target_dir/$filename"
}

# Commands implementation
case "$CMD" in
  send)
    # Usage: send <to> <priority> <subject> <body> [from] [corr_id]
    to="$1"; priority="$2"; subject="$3"; body="$4"; from="$5"; corr_id="$6"
    if [ -z "$to" ] || [ -z "$body" ]; then
      echo "Usage: $0 send <to> <priority> <subject> <body> [from] [corr_id]"
      exit 1
    fi
    _init_bus
    _deliver "$to" "$priority" "$subject" "$body" "$from" "$corr_id"
    ;;

  broadcast)
    # Usage: broadcast <priority> <subject> <body> [from]
    priority="$1"; subject="$2"; body="$3"; from="$4"
    if [ -z "$priority" ] || [ -z "$body" ]; then
      echo "Usage: $0 broadcast <priority> <subject> <body> [from]"
      exit 1
    fi
    _init_bus
    if [ -f "$REGISTRY" ]; then
      agents=$(python3 -c "import json; d=json.load(open('$REGISTRY')); print('\n'.join([a['name'] for a in d.get('agents', [])]))")
      for agent in $agents; do
        _deliver "$agent" "$priority" "$subject" "$body" "$from"
      done
    else
      echo "Registry not found, cannot broadcast."
      exit 1
    fi
    ;;

  recv)
    # Usage: recv <agent>
    agent="$1"
    if [ -z "$agent" ]; then
      echo "Usage: $0 recv <agent>"
      exit 1
    fi

    # Process priorities in order: high -> med -> low
    for p in high med low; do
      dir="$BUS_ROOT/$agent/$p"
      if [ -d "$dir" ]; then
        # Files are naturally sorted by timestamp (filename)
        for msg in $(ls "$dir" | sort); do
          cat "$dir/$msg"
          echo "--------------------------------------------------"
          rm "$dir/$msg" # Consume message
        done
      fi
    done
    ;;

  queue)
    # List all pending messages in the system
    echo "--- Current Message Queue ---"
    find "$BUS_ROOT" -name "*.msg" | while read msg; do
      echo "File: $msg"
      grep -E "subject:|to:|from:" "$msg"
      echo "---"
    done
    ;;

  flush)
    # Clear all inboxes
    echo "Flushing all message queues..."
    rm -rf "$BUS_ROOT"/*
    rm -rf "$STAGING_DIR"/*
    _init_bus
    echo "Done."
    ;;

  stats)
    # Show basic bus statistics
    count=$(find "$BUS_ROOT" -name "*.msg" | wc -l)
    echo "Total pending messages: $count"
    for agent in $(ls "$BUS_ROOT" 2>/dev/null); do
      agent_count=$(find "$BUS_ROOT/$agent" -name "*.msg" | wc -l)
      echo "  $agent: $agent_count"
    done
    ;;

  *)
    echo "Unknown command: $CMD"
    echo "Usage: $0 {send|broadcast|recv|queue|flush|stats}"
    exit 1
    ;;
esac
