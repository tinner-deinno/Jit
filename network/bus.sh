#!/usr/bin/env bash
# network/bus.sh — รถบัสข้อมูล: ส่งและรับ message ระหว่าง agents (with priority queues)
#
# หลักพุทธ: อิทัปปัจจยตา — เชื่อมโยงปัจจัยต่างๆ ให้เกิดผล
# บทบาท multiagent: reliable message delivery, priority queue management, TTL expiration, DLQ
#
# Usage:
#   ./bus.sh send [--ttl <seconds>] [--priority P1|P2|P3] <to> <subject> <body>
#   ./bus.sh recv <agent>                 — รับ messages (P1→P2→P3 order)
#   ./bus.sh queue                        — ดู queue ทั้งหมด (by priority)
#   ./bus.sh flush                        — ล้าง queue เก่า
#   ./bus.sh stats [--trace]              — สถิติ bus (with priority breakdown)
#   ./bus.sh trace <correlation-id>       — ติดตาม journey ของ message
#   ./bus.sh sweep                        — ย้าย expired messages ไป DLQ
#   ./bus.sh dlq {list|replay|purge|depth} — Dead Letter Queue management
#
# Priority Levels (JIT-027):
#   P1 — Critical/high-priority (auto-promoted: alert:critical, alert:anomaly)
#   P2 — Normal priority (default)
#   P3 — Low priority (DLQ replays to prevent starvation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

# ── Protocol Version (JIT-005) ─────────────────────────────────────
BUS_PROTOCOL_VERSION="1.0"  # SemVer: major.minor

CMD="${1:-queue}"
shift || true

BUS_ROOT="/tmp/manusat-bus"
DLQ_ROOT="$BUS_ROOT/_dlq"
REGISTRY="$SCRIPT_DIR/registry.json"
DLQ_THRESHOLD="${DLQ_THRESHOLD:-10}"  # Alert when DLQ depth exceeds this
METRICS_FILE="/tmp/manusat-bus-metrics.json"  # JIT-018: Metrics file

# ── TTL Defaults by Subject Type ───────────────────────────────────
# task: 1h, broadcast: 24h, alert: 15m, default: 1h
_get_default_ttl() {
  local subject="$1"
  case "$subject" in
    alert:*) echo 900 ;;      # 15 minutes for alerts
    broadcast:*) echo 86400 ;; # 24 hours for broadcasts
    task:*) echo 3600 ;;       # 1 hour for tasks
    *) echo 3600 ;;            # default 1 hour
  esac
}

# คำนวณ expires-at จาก ttl (seconds)
_compute_expires_at() {
  local ttl="$1"
  date -d "+${ttl} seconds" '+%Y-%m-%dT%H:%M:%S'
}

# สร้าง inbox ของทุก agent จาก registry (with priority buckets)
_init_bus() {
  mkdir -p "$BUS_ROOT"
  if [ -f "$REGISTRY" ]; then
    python3 -c "
import sys, json, os
reg_path = sys.argv[1]
bus_root = sys.argv[2]
with open(reg_path) as f:
    d = json.load(f)
for a in d.get('agents', []):
    agent_dir = os.path.join(bus_root, a['name'])
    os.makedirs(agent_dir, exist_ok=True)
    # Create priority buckets
    for priority in ['P1', 'P2', 'P3']:
        os.makedirs(os.path.join(agent_dir, priority), exist_ok=True)
" "$REGISTRY" "$BUS_ROOT"
  else
    mkdir -p "$BUS_ROOT/innova/P1" "$BUS_ROOT/innova/P2" "$BUS_ROOT/innova/P3"
    mkdir -p "$BUS_ROOT/soma/P1" "$BUS_ROOT/soma/P2" "$BUS_ROOT/soma/P3"
  fi
}

# ── DLQ Initialization ─────────────────────────────────────────────
_init_dlq() {
  mkdir -p "$DLQ_ROOT/expired" \
           "$DLQ_ROOT/unrouted" \
           "$DLQ_ROOT/max-retries" \
           "$DLQ_ROOT/error"

  # Initialize metadata if not exists
  if [ ! -f "$DLQ_ROOT/_metadata.json" ]; then
    cat > "$DLQ_ROOT/_metadata.json" << EOF
{
  "threshold": $DLQ_THRESHOLD,
  "created_at": "$(date '+%Y-%m-%dT%H:%M:%S')",
  "last_alert": null
}
EOF
  fi
}

# ── JIT-018: Metrics Collection ────────────────────────────────────
# Initialize metrics file with all agents from registry
_init_metrics() {
  if [ ! -f "$METRICS_FILE" ]; then
    python3 - "$REGISTRY" << 'PYEOF'
import json
import sys
from datetime import datetime

registry_path = sys.argv[1]

try:
    with open(registry_path, 'r', encoding='utf-8') as f:
        registry = json.load(f)

    agents = {}
    for agent in registry.get('agents', []):
        name = agent.get('name', 'unknown')
        agents[name] = {
            'sent': 0,
            'received': 0,
            'failed': 0,
            'expired': 0,
            'dlq_depth': 0
        }

    metrics = {
        'updated_at': datetime.now().strftime('%Y-%m-%dT%H:%M:%S%z'),
        'agents': agents,
        'totals': {
            'sent': 0,
            'received': 0,
            'failed': 0,
            'expired': 0,
            'dlq_depth': 0
        }
    }

    with open('/tmp/manusat-bus-metrics.json', 'w') as f:
        json.dump(metrics, f, indent=2)
except Exception as e:
    print(f"Error initializing metrics: {e}", file=sys.stderr)
PYEOF
  fi
}

# Update metrics for a specific agent and operation
# Args: agent_name operation_type (sent|received|failed|expired)
_update_metrics() {
  local agent="$1"
  local op="$2"

  python3 - "$METRICS_FILE" "$agent" "$op" << 'PYEOF'
import json
import sys
from datetime import datetime

metrics_file = sys.argv[1]
agent_name = sys.argv[2]
operation = sys.argv[3]

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)

    # Initialize agent if not exists
    if agent_name not in metrics.get('agents', {}):
        metrics['agents'][agent_name] = {
            'sent': 0,
            'received': 0,
            'failed': 0,
            'expired': 0,
            'dlq_depth': 0
        }

    # Increment the appropriate counter
    if operation in ['sent', 'received', 'failed', 'expired']:
        metrics['agents'][agent_name][operation] = metrics['agents'][agent_name].get(operation, 0) + 1
        metrics['totals'][operation] = metrics['totals'].get(operation, 0) + 1

    # Update timestamp
    tz = datetime.now().astimezone().strftime('%z')
    tz_formatted = f"{tz[:3]}:{tz[3:]}"
    metrics['updated_at'] = datetime.now().strftime('%Y-%m-%dT%H:%M:%S') + tz_formatted

    with open(metrics_file, 'w') as f:
        json.dump(metrics, f, indent=2)
except Exception as e:
    print(f"Error updating metrics: {e}", file=sys.stderr)
PYEOF
}

# Update DLQ depth for an agent
_update_dlq_depth() {
  local agent="$1"
  local depth="$2"

  python3 - "$METRICS_FILE" "$agent" "$depth" << 'PYEOF'
import json
import sys

metrics_file = sys.argv[1]
agent_name = sys.argv[2]
depth = int(sys.argv[3])

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)

    if agent_name in metrics.get('agents', {}):
        metrics['agents'][agent_name]['dlq_depth'] = depth

    # Recalculate total DLQ depth
    total_dlq = sum(a.get('dlq_depth', 0) for a in metrics['agents'].values())
    metrics['totals']['dlq_depth'] = total_dlq

    with open(metrics_file, 'w') as f:
        json.dump(metrics, f, indent=2)
except Exception as e:
    print(f"Error updating DLQ depth: {e}", file=sys.stderr)
PYEOF
}

# Refresh DLQ depths for all agents
_refresh_dlq_depths() {
  python3 - "$METRICS_FILE" "$DLQ_ROOT" << 'PYEOF'
import json
import sys
import os
from datetime import datetime

metrics_file = sys.argv[1]
dlq_root = sys.argv[2]

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)

    total_dlq = 0

    # Calculate DLQ depth per agent by scanning DLQ directories
    for agent_name in metrics['agents'].keys():
        agent_dlq_count = 0
        for reason_dir in ['expired', 'unrouted', 'max-retries', 'error']:
            dlq_path = os.path.join(dlq_root, reason_dir)
            if os.path.isdir(dlq_path):
                for msg_file in os.listdir(dlq_path):
                    if msg_file.endswith('.msg'):
                        msg_path = os.path.join(dlq_path, msg_file)
                        try:
                            with open(msg_path, 'r') as f:
                                content = f.read()
                                if f'to:{agent_name}' in content or f'original_to:{agent_name}' in content:
                                    agent_dlq_count += 1
                        except:
                            pass
        metrics['agents'][agent_name]['dlq_depth'] = agent_dlq_count
        total_dlq += agent_dlq_count

    metrics['totals']['dlq_depth'] = total_dlq

    # Update timestamp
    tz = datetime.now().astimezone().strftime('%z')
    tz_formatted = f"{tz[:3]}:{tz[3:]}"
    metrics['updated_at'] = datetime.now().strftime('%Y-%m-%dT%H:%M:%S') + tz_formatted

    with open(metrics_file, 'w') as f:
        json.dump(metrics, f, indent=2)
except Exception as e:
    print(f"Error refreshing DLQ depths: {e}", file=sys.stderr)
PYEOF
}

# ── JIT-020: Response Time Tracking ────────────────────────────────
# Counter file for sampling every 10th message
BUS_COUNTER_FILE="/tmp/manusat-bus-counter.json"

# Initialize or read counter
_init_bus_counter() {
  if [ ! -f "$BUS_COUNTER_FILE" ]; then
    echo '{"count": 0, "samples": []}' > "$BUS_COUNTER_FILE"
  fi
}

# ── Priority Queue Helpers ─────────────────────────────────────────
# Map subject patterns to priority (P1=highest, P2=normal, P3=lowest)
# Auto-promote alert:critical and alert:anomaly to P1
# DLQ replay messages default to P3
_get_priority_for_subject() {
  local subject="$1"
  local explicit_priority="$2"

  # If explicit priority provided, use it
  if [ -n "$explicit_priority" ]; then
    echo "$explicit_priority"
    return
  fi

  # Auto-promote critical alerts to P1
  case "$subject" in
    alert:critical|alert:anomaly)
      echo "P1"
      ;;
    alert:*)
      echo "P2"
      ;;
    *)
      echo "P2"  # Default priority
      ;;
  esac
}

# Get inbox path for a specific priority level
# Args: agent_name [priority]
_get_inbox_path() {
  local agent="$1"
  local priority="${2:-P2}"
  echo "$BUS_ROOT/$agent/$priority"
}

# Initialize priority buckets for an agent
_init_priority_buckets() {
  local agent="$1"
  mkdir -p "$BUS_ROOT/$agent/P1" \
           "$BUS_ROOT/$agent/P2" \
           "$BUS_ROOT/$agent/P3"
}

# ── Initialize all subsystems ──────────────────────────────────────
_init_bus
_init_dlq
_init_metrics
_init_bus_counter

# Update registry with response time (sample every 10th message)
# Args: to_agent, response_time_ms
_update_response_time() {
  local to_agent="$1"
  local response_time_ms="$2"

  if [ ! -f "$REGISTRY" ]; then
    return 1
  fi

  python3 - "$REGISTRY" "$to_agent" "$response_time_ms" "$BUS_COUNTER_FILE" << 'PYEOF' 2>/dev/null
import json
import sys
import os
import time

registry_path = sys.argv[1]
to_agent = sys.argv[2]
response_time_ms = int(sys.argv[3])
counter_file = sys.argv[4]

try:
    # Read and increment counter
    counter = {"count": 0, "samples": []}
    if os.path.exists(counter_file):
        with open(counter_file, 'r') as f:
            counter = json.load(f)

    counter['count'] = counter.get('count', 0) + 1

    # Sample every 10th message
    is_sample = (counter['count'] % 10 == 0)

    if is_sample:
        # Record sample with timestamp
        counter['samples'].append({
            'agent': to_agent,
            'response_time_ms': response_time_ms,
            'timestamp': time.time()
        })
        # Keep only last 100 samples
        counter['samples'] = counter['samples'][-100:]

        # Update registry with latest response time for this agent
        with open(registry_path, 'r', encoding='utf-8') as f:
            registry = json.load(f)

        for agent in registry.get('agents', []):
            if agent.get('name') == to_agent:
                agent['response_time_ms'] = response_time_ms
                break

        with open(registry_path, 'w', encoding='utf-8') as f:
            json.dump(registry, f, ensure_ascii=False, indent=2)

    # Write counter back
    with open(counter_file, 'w') as f:
        json.dump(counter, f, indent=2)

except Exception as e:
    print(f"Error updating response time: {e}", file=sys.stderr)
PYEOF
}

_init_bus_counter

# ── DLQ Helper Functions ───────────────────────────────────────────
# Move a message to DLQ with .reason sidecar
# Args: msg_file, reason_category, failure_reason
dlq_move_to() {
  local MSG_FILE="$1" REASON="$2" FAILURE_REASON="$3"
  local DLQ_DIR="$DLQ_ROOT/$REASON"

  mkdir -p "$DLQ_DIR"

  local BASENAME=$(basename "$MSG_FILE" .msg)
  local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  local DLQ_BASE="${TIMESTAMP}_${BASENAME}"

  # Extract metadata for .reason sidecar
  local ORIGINAL_TO=$(grep "^to:" "$MSG_FILE" 2>/dev/null | cut -d: -f2- | tr -d '\r\n')
  local ORIGINAL_FROM=$(grep "^from:" "$MSG_FILE" 2>/dev/null | cut -d: -f2- | tr -d '\r\n')
  local ORIGINAL_SUBJECT=$(grep "^subject:" "$MSG_FILE" 2>/dev/null | cut -d: -f2- | tr -d '\r\n')
  local FAILED_AT=$(date '+%Y-%m-%dT%H:%M:%S')
  local RETRY_COUNT=$(grep "^retry-attempts:" "$MSG_FILE" 2>/dev/null | cut -d: -f2- | tr -d ' \r\n')
  RETRY_COUNT=${RETRY_COUNT:-0}

  # Move message to DLQ
  mv "$MSG_FILE" "$DLQ_DIR/${DLQ_BASE}.msg"

  # Write .reason sidecar
  cat > "$DLQ_DIR/${DLQ_BASE}.reason" << EOF
original_to:$ORIGINAL_TO
original_from:$ORIGINAL_FROM
original_subject:$ORIGINAL_SUBJECT
failure_reason:$FAILURE_REASON
failed_at:$FAILED_AT
retry_count:$RETRY_COUNT
EOF

  log_action "BUS_DLQ" "moved $(basename "$MSG_FILE") to $REASON reason:$FAILURE_REASON"
}

# Check DLQ depth and emit alert if threshold exceeded
dlq_check_threshold() {
  local TOTAL=0
  for dir in "$DLQ_ROOT"/*/; do
    [ -d "$dir" ] || continue
    [[ "$(basename "$dir")" == _* ]] && continue
    COUNT=$(find "$dir" -name "*.msg" 2>/dev/null | wc -l)
    TOTAL=$((TOTAL + COUNT))
  done

  if [ "$TOTAL" -gt "$DLQ_THRESHOLD" ]; then
    # Update last_alert in metadata
    # JIT-021: Pass metadata path as argv to prevent Python injection
    if [ -f "$DLQ_ROOT/_metadata.json" ]; then
      local NOW_TS=$(date '+%Y-%m-%dT%H:%M:%S')
      python3 - "$DLQ_ROOT/_metadata.json" "$NOW_TS" << 'PYEOF'
import json
import sys
meta_path = sys.argv[1]
now_ts = sys.argv[2]
with open(meta_path, 'r+') as f:
    d = json.load(f)
    d['last_alert'] = now_ts
    f.seek(0)
    json.dump(d, f, indent=2)
    f.truncate()
PYEOF
    fi

    # Emit alert via bus broadcast
    warn "DLQ depth ($TOTAL) exceeds threshold ($DLQ_THRESHOLD)"
    bash "$0" broadcast "dlq-growing" "DLQ depth: $TOTAL messages (threshold: $DLQ_THRESHOLD)" 2>/dev/null || true
    log_action "ALERT_DLQ_GROWING" "depth:$TOTAL threshold:$DLQ_THRESHOLD"
    return 0
  fi
  return 1
}

# Get total DLQ depth
dlq_depth() {
  local TOTAL=0
  for dir in "$DLQ_ROOT"/*/; do
    [ -d "$dir" ] || continue
    [[ "$(basename "$dir")" == _* ]] && continue
    COUNT=$(find "$dir" -name "*.msg" 2>/dev/null | wc -l)
    TOTAL=$((TOTAL + COUNT))
  done
  echo "$TOTAL"
}

case "$CMD" in

  # ── ส่ง message ─────────────────────────────────────────────────
  send)
    # Parse optional --ttl, --trace-chain, and --priority flags
    TTL=""
    TRACE_CHAIN=""
    HOP_COUNT=""
    TIMESTAMP_CHAIN=""
    CORR_ID_OVERRIDE=""
    PRIORITY=""
    MAX_RETRIES=""
    RETRY_AFTER=""

    while [ $# -gt 0 ]; do
      case "$1" in
        --ttl)
          TTL="$2"
          shift 2
          ;;
        --trace-chain)
          TRACE_CHAIN="$2"
          shift 2
          ;;
        --hop-count)
          HOP_COUNT="$2"
          shift 2
          ;;
        --timestamp-chain)
          TIMESTAMP_CHAIN="$2"
          shift 2
          ;;
        --correlation-id)
          CORR_ID_OVERRIDE="$2"
          shift 2
          ;;
        --priority)
          PRIORITY="$2"
          shift 2
          ;;
        --max-retries)
          MAX_RETRIES="$2"
          shift 2
          ;;
        --retry-after)
          RETRY_AFTER="$2"
          shift 2
          ;;
        *)
          break
          ;;
      esac
    done

    TO="$1" SUBJECT="$2"
    shift 2 || { err "Usage: bus.sh send [--ttl <seconds>] [--priority P1|P2|P3] <to> <subject> <body>"; exit 1; }
    BODY="$*"
    FROM="${AGENT_NAME:-system}"

    # Auto-promote critical alerts to P1, default to P2 if not specified
    PRIORITY=$(_get_priority_for_subject "$SUBJECT" "$PRIORITY")

    # Validate recipient exists (check against registry or inbox directory)
    # JIT-021: Pass registry path as argv to prevent Python injection
    if [ -f "$REGISTRY" ]; then
      AGENT_EXISTS=$(python3 - "$REGISTRY" "$TO" << 'PYEOF' 2>/dev/null
import json
import sys
reg_path = sys.argv[1]
to_agent = sys.argv[2]
with open(reg_path) as f:
    d = json.load(f)
agents = [a['name'] for a in d.get('agents', [])]
print('yes' if to_agent in agents else 'no')
PYEOF
)
      if [ "$AGENT_EXISTS" = "no" ]; then
        # Create temporary message file for DLQ
        TS=$(date +%s%3N)
        TEMP_MSG="/tmp/manusat-bus/_dlq/_temp_${TS}.msg"
        mkdir -p "$(dirname "$TEMP_MSG")"
        cat > "$TEMP_MSG" << EOF
from:$FROM
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
---
$BODY
EOF
        # Move directly to unrouted DLQ
        dlq_move_to "$TEMP_MSG" "unrouted" "Unknown recipient: $TO"
        err "Unrouted message: recipient '$TO' not found in registry → DLQ/unrouted/"

        # JIT-018: Update metrics for failed message
        _update_metrics "$TO" "failed"

        log_action "BUS_UNROUTED" "to:$TO subject:$SUBJECT reason:unknown-recipient"
        exit 1
      fi
    fi

    # Generate or use override correlation-id
    if [ -n "$CORR_ID_OVERRIDE" ]; then
      CORR_ID="$CORR_ID_OVERRIDE"
    else
      CORR_ID="$(python3 -c "import uuid; print(str(uuid.uuid4())[:8])" 2>/dev/null || echo "$(date +%s)")"
    fi

    TS=$(date +%s%3N)
    # Route message to priority bucket
    MSG_FILE="$BUS_ROOT/$TO/$PRIORITY/${TS}_from-${FROM}.msg"

    # Compute hop_count and trace-chain
    if [ -z "$HOP_COUNT" ]; then
      HOP_COUNT="0"
    fi
    NEW_HOP_COUNT=$((HOP_COUNT + 1))

    # Build trace-chain: append current agent
    if [ -z "$TRACE_CHAIN" ]; then
      TRACE_CHAIN="$FROM"
    else
      TRACE_CHAIN="${TRACE_CHAIN}→${FROM}"
    fi

    # Build timestamp-chain: append current timestamp
    CURRENT_TS=$(date '+%Y-%m-%dT%H:%M:%S')
    if [ -z "$TIMESTAMP_CHAIN" ]; then
      TIMESTAMP_CHAIN="$CURRENT_TS"
    else
      TIMESTAMP_CHAIN="${TIMESTAMP_CHAIN},${CURRENT_TS}"
    fi

    # Compute TTL and expires-at
    if [ -n "$TTL" ]; then
      TTL_SECONDS="$TTL"
    else
      TTL_SECONDS=$(_get_default_ttl "$SUBJECT")
    fi
    EXPIRES_AT=$(_compute_expires_at "$TTL_SECONDS")

    # JIT-002: Generate idempotency key (from+subject+body-hash)
    IDEM_KEY=$(generate_idempotency_key "$FROM" "$SUBJECT" "$BODY")

    # JIT-017: Get agent version from registry
    # JIT-021: Pass registry path as argv to prevent Python injection
    AGENT_VERSION="1.0.0"  # Default fallback
    if [ -f "$REGISTRY" ]; then
      AGENT_VERSION=$(python3 - "$REGISTRY" "$FROM" << 'PYEOF' 2>/dev/null || echo "1.0.0"
import json
import sys
reg_path = sys.argv[1]
from_agent = sys.argv[2]
with open(reg_path) as f:
    d = json.load(f)
for a in d.get('agents', []):
    if a.get('name') == from_agent:
        print(a.get('version', '1.0.0'))
        break
PYEOF
)
    fi

    # JIT-003: Set retry policy headers (default: 3 retries, 1s base delay)
    RETRY_COUNT="${RETRY_COUNT:-0}"  # Track retry attempts
    MAX_RETRIES_VAL="${MAX_RETRIES:-3}"
    RETRY_AFTER_VAL="${RETRY_AFTER:-1}"  # Base delay in seconds

    cat > "$MSG_FILE" << EOF
from:$FROM
to:$TO
subject:$SUBJECT
timestamp:$CURRENT_TS
protocol-version:$BUS_PROTOCOL_VERSION
ttl:$TTL_SECONDS
expires-at:$EXPIRES_AT
correlation-id:$CORR_ID
idempotency-key:$IDEM_KEY
x-agent-version:$AGENT_VERSION
trace-chain:$TRACE_CHAIN
hop_count:$NEW_HOP_COUNT
timestamp_chain:$TIMESTAMP_CHAIN
max-retries:$MAX_RETRIES_VAL
retry-after:$RETRY_AFTER_VAL
retry-attempts:$RETRY_COUNT
---
$BODY
EOF
    ok "bus → $TO: [$SUBJECT] priority:$PRIORITY ttl:${TTL_SECONDS}s expires:$EXPIRES_AT (id:$CORR_ID hops:$NEW_HOP_COUNT idem:$IDEM_KEY retries:$MAX_RETRIES_VAL)"
    log_action "BUS_SEND" "to:$TO subject:$SUBJECT priority:$PRIORITY ttl:$TTL_SECONDS expires:$EXPIRES_AT trace:$TRACE_CHAIN hops:$NEW_HOP_COUNT idem:$IDEM_KEY max-retries:$MAX_RETRIES_VAL retry-after:${RETRY_AFTER_VAL}s"

    # JIT-002: Record idempotency key for sender (for audit trail)
    record_idempotency_key "$IDEM_KEY" "$FROM" "$SUBJECT"

    # JIT-018: Update metrics for sent message
    _update_metrics "$TO" "sent"

    # JIT-020: Track response time (sample every 10th message)
    # Simulate response time based on inbox depth (file-based bus latency proxy)
    inbox_depth=$(find "$BUS_ROOT/$TO" -name "*.msg" 2>/dev/null | wc -l)
    simulated_response_time=$((10 + inbox_depth * 5))  # Base 10ms + 5ms per message in queue
    _update_response_time "$TO" "$simulated_response_time"

    echo "$CORR_ID"
    ;;

  # ── รับ messages ─────────────────────────────────────────────────
  recv)
    # Parse optional --priority flag
    PRIORITY_FILTER=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --priority)
          PRIORITY_FILTER="$2"
          shift 2
          ;;
        *)
          break
          ;;
      esac
    done

    # Validate priority filter if provided
    if [ -n "$PRIORITY_FILTER" ]; then
      case "$PRIORITY_FILTER" in
        P1|P2|P3) ;;  # Valid
        *)
          err "Invalid priority: $PRIORITY_FILTER. Must be P1, P2, or P3"
          exit 1
          ;;
      esac
    fi

    AGENT="${1:-${AGENT_NAME:-innova}}"
    INBOX="$BUS_ROOT/$AGENT"

    # Count messages by priority
    P1_COUNT=$(find "$INBOX/P1" -name "*.msg" 2>/dev/null | wc -l)
    P2_COUNT=$(find "$INBOX/P2" -name "*.msg" 2>/dev/null | wc -l)
    P3_COUNT=$(find "$INBOX/P3" -name "*.msg" 2>/dev/null | wc -l)
    TOTAL_MSGS=$((P1_COUNT + P2_COUNT + P3_COUNT))

    if [ "$TOTAL_MSGS" -eq 0 ]; then
      info "$AGENT: inbox ว่าง"
      exit 0
    fi

    step "$AGENT: รรับ $TOTAL_MSGS messages (P1:$P1_COUNT P2:$P2_COUNT P3:$P3_COUNT)"
    recv_count=0

    # Process messages in priority order: P1 first, then P2, then P3
    for PRIORITY_DIR in P1 P2 P3; do
      # Skip if filtering by priority and this doesn't match
      if [ -n "$PRIORITY_FILTER" ] && [ "$PRIORITY_FILTER" != "$PRIORITY_DIR" ]; then
        continue
      fi

      PRIORITY_INBOX="$INBOX/$PRIORITY_DIR"
      [ -d "$PRIORITY_INBOX" ] || continue

      for MSG_FILE in "$PRIORITY_INBOX"/*.msg; do
        [ -f "$MSG_FILE" ] || continue

        # JIT-002: Check idempotency — skip duplicates
        IDEM_KEY=$(parse_idempotency_key "$MSG_FILE")
        if [ -n "$IDEM_KEY" ]; then
          if is_duplicate_key "$IDEM_KEY" "$AGENT"; then
            warn "BUS_DUPLICATE: skipping duplicate key=$IDEM_KEY file=$(basename "$MSG_FILE")"
            log_action "BUS_DUPLICATE" "agent:$AGENT key:$IDEM_KEY file:$(basename "$MSG_FILE")"
            # Move to DLQ instead of processing
            dlq_move_to "$MSG_FILE" "error" "Duplicate idempotency key detected"
            continue
          fi
          # Record key as processed (for future dedup)
          SUBJECT_LINE=$(grep "^subject:" "$MSG_FILE" | cut -d: -f2-)
          record_idempotency_key "$IDEM_KEY" "$AGENT" "$SUBJECT_LINE"
        fi

        # JIT-005: Check protocol version mismatch
        MSG_VERSION=$(grep "^protocol-version:" "$MSG_FILE" | cut -d: -f2- | tr -d '\r\n')
        if [ -n "$MSG_VERSION" ] && [ "$MSG_VERSION" != "$BUS_PROTOCOL_VERSION" ]; then
          # Extract major version for comparison
          MSG_MAJOR=$(echo "$MSG_VERSION" | cut -d. -f1)
          LOCAL_MAJOR=$(echo "$BUS_PROTOCOL_VERSION" | cut -d. -f1)
          if [ "$MSG_MAJOR" -gt "$LOCAL_MAJOR" ] 2>/dev/null; then
            warn "Protocol version mismatch: message=$MSG_VERSION > local=$BUS_PROTOCOL_VERSION — may have incompatible features"
          elif [ "$MSG_MAJOR" -lt "$LOCAL_MAJOR" ] 2>/dev/null; then
            info "Protocol version mismatch: message=$MSG_VERSION < local=$BUS_PROTOCOL_VERSION — backward compatible"
          else
            info "Protocol minor version diff: message=$MSG_VERSION vs local=$BUS_PROTOCOL_VERSION — backward compatible"
          fi
        fi

        echo ""
        echo -e "${CYAN}── $(basename "$MSG_FILE") [$PRIORITY_DIR] ──${RESET}"
        cat "$MSG_FILE"
        echo ""

        # JIT-020: Calculate response time from message timestamp to now
        MSG_TS=$(grep "^timestamp:" "$MSG_FILE" | cut -d: -f2-)
        if [ -n "$MSG_TS" ]; then
          MSG_EPOCH=$(date -d "$MSG_TS" +%s 2>/dev/null || echo "0")
          NOW_EPOCH=$(date +%s)
          RESPONSE_TIME=$((NOW_EPOCH - MSG_EPOCH))  # In seconds, convert to ms
          RESPONSE_TIME=$((RESPONSE_TIME * 1000))  # Convert to ms
          if [ "$RESPONSE_TIME" -gt 0 ] && [ "$RESPONSE_TIME" -lt 1000000 ]; then
            _update_response_time "$AGENT" "$RESPONSE_TIME"
          fi
        fi

        mv "$MSG_FILE" "${MSG_FILE%.msg}.read"
        log_action "BUS_RECV" "$(basename "$MSG_FILE") priority:$PRIORITY_DIR"

        # JIT-018: Update metrics for received message
        _update_metrics "$AGENT" "received"

        ((recv_count++))
      done
    done

    # Update agent's message_queue_depth in registry after receiving
    if [ -f "$REGISTRY" ]; then
      python3 - "$REGISTRY" "$AGENT" "$BUS_ROOT" << 'PYEOF' 2>/dev/null
import json
import sys
import os

registry_path = sys.argv[1]
agent_name = sys.argv[2]
bus_root = sys.argv[3]

try:
    with open(registry_path, 'r', encoding='utf-8') as f:
        registry = json.load(f)

    inbox_path = os.path.join(bus_root, agent_name)
    pending = 0
    if os.path.isdir(inbox_path):
        pending = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])

    for agent in registry.get('agents', []):
        if agent.get('name') == agent_name:
            agent['message_queue_depth'] = pending
            break

    with open(registry_path, 'w', encoding='utf-8') as f:
        json.dump(registry, f, ensure_ascii=False, indent=2)
except Exception as e:
    print(f"Error updating queue depth: {e}", file=sys.stderr)
PYEOF
    fi
    ;;

  # ── ดู queue ──────────────────────────────────────────────────────
  queue)
    echo ""
    echo -e "${BOLD}=== Message Bus Queue (by Priority) ===${RESET}"
    echo -e "   Bus: $BUS_ROOT"
    echo ""
    TOTAL=0
    for INBOX_DIR in "$BUS_ROOT"/*/; do
      [ -d "$INBOX_DIR" ] || continue
      AGENT=$(basename "$INBOX_DIR")
      P1_COUNT=$(find "$INBOX_DIR/P1" -name "*.msg" 2>/dev/null | wc -l)
      P2_COUNT=$(find "$INBOX_DIR/P2" -name "*.msg" 2>/dev/null | wc -l)
      P3_COUNT=$(find "$INBOX_DIR/P3" -name "*.msg" 2>/dev/null | wc -l)
      PENDING=$((P1_COUNT + P2_COUNT + P3_COUNT))
      READ=$(find "$INBOX_DIR" -name "*.read" 2>/dev/null | wc -l)
      TOTAL=$((TOTAL + PENDING))
      if [ "$PENDING" -gt 0 ]; then
        echo -e "   ${YELLOW}📬${RESET} $AGENT: P1:$P1_COUNT P2:$P2_COUNT P3:$P3_COUNT | $READ read"
      else
        echo -e "   ${GREEN}📭${RESET} $AGENT: ว่าง | $READ read"
      fi
    done
    echo ""
    echo "   Total pending: $TOTAL"
    echo ""
    ;;

  # ── broadcast ทุก agent ──────────────────────────────────────────
  broadcast)
    SUBJECT="$1"
    shift || true
    BODY="$*"
    FROM="${AGENT_NAME:-system}"
    COUNT=0
    # broadcast: default TTL 24h, default priority P2
    TTL_SECONDS=$(_get_default_ttl "broadcast:$SUBJECT")
    EXPIRES_AT=$(_compute_expires_at "$TTL_SECONDS")
    PRIORITY=$(_get_priority_for_subject "broadcast:$SUBJECT" "")
    CORR_ID="$(python3 -c "import uuid; print(str(uuid.uuid4())[:8])" 2>/dev/null || echo "$(date +%s)")"
    CURRENT_TS=$(date '+%Y-%m-%dT%H:%M:%S')
    for INBOX_DIR in "$BUS_ROOT"/*/; do
      [ -d "$INBOX_DIR" ] || continue
      AGENT=$(basename "$INBOX_DIR")
      [ "$AGENT" = "$FROM" ] && continue
      # Skip _dlq and other special directories
      [[ "$AGENT" == _* ]] && continue
      TS=$(date +%s%3N)
      # Ensure priority directory exists
      mkdir -p "$INBOX_DIR/$PRIORITY"
      cat > "$INBOX_DIR/$PRIORITY/${TS}_broadcast.msg" << EOF
from:$FROM
to:$AGENT
subject:broadcast:$SUBJECT
timestamp:$CURRENT_TS
protocol-version:$BUS_PROTOCOL_VERSION
priority:$PRIORITY
ttl:$TTL_SECONDS
expires-at:$EXPIRES_AT
correlation-id:$CORR_ID
trace-chain:$FROM
hop_count:1
timestamp_chain:$CURRENT_TS
---
$BODY
EOF
      ((COUNT++))
    done
    ok "broadcast → $COUNT agents: [$SUBJECT] priority:$PRIORITY ttl:${TTL_SECONDS}s expires:$EXPIRES_AT (id:$CORR_ID)"
    log_action "BUS_BROADCAST" "$SUBJECT to $COUNT agents priority:$PRIORITY ttl:$TTL_SECONDS expires:$EXPIRES_AT id:$CORR_ID"
    ;;

  # ── ล้าง read messages เก่า (> 24h) ──────────────────────────────
  flush)
    DELETED=0
    find "$BUS_ROOT" -name "*.read" -mmin +1440 -delete -print 2>/dev/null | while read -r f; do
      ((DELETED++))
    done
    ok "ล้าง messages เก่าแล้ว"
    log_action "BUS_FLUSH" "cleanup"
    ;;

  # ── สถิติ ────────────────────────────────────────────────────────
  stats)
    # Parse optional --trace and --json flags
    TRACE_MODE=""
    JSON_MODE=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --trace)
          TRACE_MODE="yes"
          shift
          ;;
        --json)
          JSON_MODE="yes"
          shift
          ;;
        *)
          shift
          ;;
      esac
    done

    # If JSON mode, output metrics file directly
    if [ "$JSON_MODE" = "yes" ]; then
      # Refresh DLQ depths before output
      _refresh_dlq_depths
      if [ -f "$METRICS_FILE" ]; then
        cat "$METRICS_FILE"
      else
        echo '{"error": "Metrics not initialized"}'
      fi
      echo ""
      exit 0
    fi

    TOTAL_MSGS=$(find "$BUS_ROOT" -name "*.msg" 2>/dev/null | wc -l)
    TOTAL_READ=$(find "$BUS_ROOT" -name "*.read" 2>/dev/null | wc -l)
    TOTAL_DLQ=$(dlq_depth)

    # JIT-027: Priority queue breakdown
    P1_TOTAL=$(find "$BUS_ROOT" -path "*/P1/*.msg" 2>/dev/null | wc -l)
    P2_TOTAL=$(find "$BUS_ROOT" -path "*/P2/*.msg" 2>/dev/null | wc -l)
    P3_TOTAL=$(find "$BUS_ROOT" -path "*/P3/*.msg" 2>/dev/null | wc -l)

    # JIT-026: Direct Channel Utilization
    DIRECT_CHANNEL_STATS=""
    if [ -f "/tmp/manusat-channels-stats.json" ]; then
      DIRECT_CHANNEL_STATS=$(python3 -c "
import json
with open('/tmp/manusat-channels-stats.json') as f:
    stats = json.load(f)
totals = stats.get('totals', {})
sent = totals.get('messages_sent', 0)
fallbacks = totals.get('fallbacks_to_bus', 0)
channels = len(stats.get('channels', {}))
if sent > 0:
    fallback_rate = (fallbacks / sent) * 100
    print(f'{sent} sent, {fallbacks} fallbacks ({fallback_rate:.1f}%), {channels} channels')
else:
    print(f'{channels} channels, no messages yet')
" 2>/dev/null)
    fi

    echo ""
    echo -e "${BOLD}Bus Stats:${RESET}"
    echo "   Pending:       $TOTAL_MSGS"
    echo "   Read:          $TOTAL_READ"
    echo "   DLQ:           $TOTAL_DLQ"
    echo ""
    echo -e "${BOLD}Priority Breakdown:${RESET}"
    echo "   P1 (Critical): $P1_TOTAL"
    echo "   P2 (Normal):   $P2_TOTAL"
    echo "   P3 (Low):      $P3_TOTAL"
    echo "   Path:          $BUS_ROOT"
    if [ -n "$DIRECT_CHANNEL_STATS" ]; then
      echo -e "   ${GREEN}Direct Channels:${RESET} $DIRECT_CHANNEL_STATS"
    fi

    if [ "$TRACE_MODE" = "yes" ]; then
      echo ""
      echo -e "${BOLD}Latency Traces (avg per agent pair):${RESET}"
      python3 << 'PYEOF'
import os
import glob
from collections import defaultdict

bus_root = "/tmp/manusat-bus"
pair_latencies = defaultdict(list)

# Scan all messages (pending and read)
for pattern in ["*.msg", "*.read"]:
    for msg_file in glob.glob(os.path.join(bus_root, "*", pattern)):
        if not os.path.isfile(msg_file):
            continue

        trace_chain = None
        timestamp_chain = None

        with open(msg_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith("trace-chain:"):
                    trace_chain = line.split(":", 1)[1]
                elif line.startswith("timestamp_chain:"):
                    timestamp_chain = line.split(":", 1)[1]
                if trace_chain and timestamp_chain:
                    break

        if trace_chain and timestamp_chain and "→" in trace_chain:
            agents = trace_chain.split("→")
            timestamps = timestamp_chain.split(",")

            # Calculate latency between consecutive hops
            for i in range(len(agents) - 1):
                from_agent = agents[i]
                to_agent = agents[i + 1]

                try:
                    from datetime import datetime
                    t1 = datetime.fromisoformat(timestamps[i])
                    t2 = datetime.fromisoformat(timestamps[i + 1])
                    latency_ms = (t2 - t1).total_seconds() * 1000

                    pair_key = f"{from_agent}→{to_agent}"
                    pair_latencies[pair_key].append(latency_ms)
                except:
                    pass

if pair_latencies:
    for pair, latencies in sorted(pair_latencies.items()):
        avg_latency = sum(latencies) / len(latencies)
        max_latency = max(latencies)
        min_latency = min(latencies)
        sample_count = len(latencies)
        print(f"   {pair}: avg={avg_latency:.1f}ms min={min_latency:.1f}ms max={max_latency:.1f}ms (n={sample_count})")
else:
    print("   No trace data available yet")
PYEOF
    fi
    echo ""
    ;;

  # ── JIT-018: Metrics subcommand ──────────────────────────────────
  metrics)
    # Parse optional --json flag
    JSON_MODE=""
    if [ "$1" = "--json" ]; then
      JSON_MODE="yes"
    fi

    # Refresh DLQ depths before showing metrics
    _refresh_dlq_depths

    if [ "$JSON_MODE" = "yes" ]; then
      if [ -f "$METRICS_FILE" ]; then
        cat "$METRICS_FILE"
      else
        echo '{"error": "Metrics not initialized"}'
      fi
      echo ""
      exit 0
    fi

    # Human-readable format
    echo ""
    echo -e "${BOLD}${CYAN}[ Bus Metrics Dashboard ]${RESET}"
    echo -e "   Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if [ ! -f "$METRICS_FILE" ]; then
      err "Metrics file not found. Run a message operation first."
      exit 1
    fi

    python3 - "$METRICS_FILE" << 'PYEOF'
import json
import sys

metrics_file = sys.argv[1]

with open(metrics_file, 'r') as f:
    metrics = json.load(f)

print(f"   Updated: {metrics.get('updated_at', 'N/A')}")
print("")
print(f"   {'Agent':<15} {'Sent':>6} {'Recv':>6} {'Fail':>6} {'Exp':>5} {'DLQ':>5}")
print(f"   {'─'*45}")

for agent_name, agent_metrics in sorted(metrics.get('agents', {}).items()):
    sent = agent_metrics.get('sent', 0)
    received = agent_metrics.get('received', 0)
    failed = agent_metrics.get('failed', 0)
    expired = agent_metrics.get('expired', 0)
    dlq_depth = agent_metrics.get('dlq_depth', 0)
    print(f"   {agent_name:<15} {sent:>6} {received:>6} {failed:>6} {expired:>5} {dlq_depth:>5}")

print(f"   {'─'*45}")
totals = metrics.get('totals', {})
print(f"   {'TOTAL':<15} {totals.get('sent', 0):>6} {totals.get('received', 0):>6} {totals.get('failed', 0):>6} {totals.get('expired', 0):>5} {totals.get('dlq_depth', 0):>5}")
print("")
PYEOF
    ;;

  # ── trace correlation-id ─────────────────────────────────────────
  trace)
    CORR_ID="$1"
    if [ -z "$CORR_ID" ]; then
      err "Usage: bus.sh trace <correlation-id>"
      echo "   Example: bus.sh trace abc123"
      exit 1
    fi

    echo ""
    echo -e "${BOLD}=== Message Trace: $CORR_ID ===${RESET}"
    echo ""

    python3 - "$CORR_ID" << 'PYEOF'
import os
import glob
from datetime import datetime
import sys

corr_id = sys.argv[1]
bus_root = "/tmp/manusat-bus"
messages = []

# Scan all messages (pending and read) for matching correlation-id
for pattern in ["*.msg", "*.read"]:
    for msg_file in glob.glob(os.path.join(bus_root, "*", pattern)):
        if not os.path.isfile(msg_file):
            continue

        metadata = {}
        body_start = False

        with open(msg_file, 'r') as f:
            for line in f:
                line = line.rstrip()
                if line == "---":
                    body_start = True
                    continue
                if body_start:
                    break
                if ":" in line:
                    key, value = line.split(":", 1)
                    metadata[key] = value.strip()

        if metadata.get("correlation-id") == corr_id:
            messages.append({
                "file": msg_file,
                "metadata": metadata
            })

if not messages:
    print(f"   No messages found with correlation-id: {corr_id}")
else:
    # Sort by timestamp
    messages.sort(key=lambda m: m["metadata"].get("timestamp", ""))

    print(f"   Found {len(messages)} message(s) in trace chain")
    print("")

    for i, msg in enumerate(messages):
        m = msg["metadata"]
        status = "pending" if msg["file"].endswith(".msg") else "read"
        status_icon = "📬" if status == "pending" else "✓"

        print(f"   {status_icon} Hop {i+1}: {m.get('from', '?')} → {m.get('to', '?')}")
        print(f"      subject: {m.get('subject', '?')}")
        print(f"      timestamp: {m.get('timestamp', '?')}")
        print(f"      trace-chain: {m.get('trace-chain', 'N/A')}")
        print(f"      hop_count: {m.get('hop_count', 'N/A')}")
        print(f"      timestamp_chain: {m.get('timestamp_chain', 'N/A')}")
        print(f"      status: {status}")
        print("")

    # Calculate total latency if we have timestamps
    if len(messages) >= 2:
        try:
            first_ts = messages[0]["metadata"].get("timestamp")
            last_ts = messages[-1]["metadata"].get("timestamp")
            if first_ts and last_ts:
                t1 = datetime.fromisoformat(first_ts)
                t2 = datetime.fromisoformat(last_ts)
                total_latency = (t2 - t1).total_seconds() * 1000
                print(f"   Total trace latency: {total_latency:.1f}ms")
        except:
            pass
PYEOF

    echo ""
    log_action "BUS_TRACE" "correlation-id:$CORR_ID"
    ;;

  # ── sweep expired messages ───────────────────────────────────────
  sweep)
    step "Scanning for expired messages..."
    NOW=$(date +%s)
    EXPIRED_COUNT=0

    for msg in $(find "$BUS_ROOT" -name "*.msg" 2>/dev/null); do
      [ -f "$msg" ] || continue
      expires_line=$(grep "^expires-at:" "$msg" 2>/dev/null | cut -d: -f2-)
      if [ -n "$expires_line" ]; then
        expires_ts=$(date -d "$expires_line" +%s 2>/dev/null || echo "0")
        if [ "$expires_ts" -lt "$NOW" ]; then
          # Move to DLQ with reason sidecar instead of just renaming
          dlq_move_to "$msg" "expired" "TTL exceeded (expired at $expires_line)"
          echo "   EXPIRED: $(basename "$msg") → DLQ/expired/"

          # JIT-018: Update metrics for expired message
          # Extract recipient from message to attribute to correct agent
          expired_to=$(grep "^to:" "$msg" 2>/dev/null | cut -d: -f2- | tr -d '\r\n')
          if [ -n "$expired_to" ]; then
            _update_metrics "$expired_to" "expired"
          fi

          ((EXPIRED_COUNT++))
        fi
      fi
    done

    if [ "$EXPIRED_COUNT" -eq 0 ]; then
      info "No expired messages found"
    else
      ok "Moved $EXPIRED_COUNT expired message(s) to DLQ"
      # Check if DLQ threshold exceeded
      dlq_check_threshold
      # Refresh metrics after sweep
      _refresh_dlq_depths
    fi
    log_action "BUS_SWEEP" "expired:$EXPIRED_COUNT"
    ;;

  # ── JIT-003: Retry failed messages ───────────────────────────────
  retry)
    step "Scanning for failed messages eligible for retry..."
    NOW=$(date +%s)
    RETRY_COUNT=0
    SKIPPED_COUNT=0

    # Scan DLQ/error and DLQ/max-retries for .msg files
    for DLQ_DIR in "$DLQ_ROOT/error" "$DLQ_ROOT/max-retries"; do
      [ -d "$DLQ_DIR" ] || continue

      for msg in "$DLQ_DIR"/*.msg; do
        [ -f "$msg" ] || continue

        # Extract retry metadata
        RETRY_ATTEMPTS=$(grep "^retry-attempts:" "$msg" 2>/dev/null | cut -d: -f2- | tr -d ' \r\n')
        MAX_RETRIES_VAL=$(grep "^max-retries:" "$msg" 2>/dev/null | cut -d: -f2- | tr -d ' \r\n')
        RETRY_AFTER_BASE=$(grep "^retry-after:" "$msg" 2>/dev/null | cut -d: -f2- | tr -d ' \r\n')

        # Default values if not present
        RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-0}
        MAX_RETRIES_VAL=${MAX_RETRIES_VAL:-3}
        RETRY_AFTER_BASE=${RETRY_AFTER_BASE:-1}

        # Check if max retries exceeded
        if [ "$RETRY_ATTEMPTS" -ge "$MAX_RETRIES_VAL" ]; then
          # Already exhausted retries, move to max-retries DLQ if not already there
          if [[ "$DLQ_DIR" != *"max-retries"* ]]; then
            dlq_move_to "$msg" "max-retries" "Exhausted $MAX_RETRIES_VAL retry attempts"
          fi
          ((SKIPPED_COUNT++))
          continue
        fi

        # Calculate retry-after time (exponential backoff: base * 2^attempts)
        BACKOFF_SECONDS=$((RETRY_AFTER_BASE * (2 ** RETRY_ATTEMPTS)))
        # Add jitter (0-500ms)
        JITTER_MS=$(python3 -c "import random; print(random.randint(0, 500))" 2>/dev/null || echo "0")

        # Get failed_at from .reason sidecar
        REASON_FILE="${msg%.msg}.reason"
        FAILED_AT=""
        if [ -f "$REASON_FILE" ]; then
          FAILED_AT=$(grep "^failed_at:" "$REASON_FILE" | cut -d: -f2-)
        fi

        if [ -n "$FAILED_AT" ]; then
          FAILED_EPOCH=$(date -d "$FAILED_AT" +%s 2>/dev/null || echo "0")
          READY_AT=$((FAILED_EPOCH + BACKOFF_SECONDS))

          # Check if retry-after time has elapsed
          if [ "$NOW" -lt "$READY_AT" ]; then
            # Not yet ready, skip
            ((SKIPPED_COUNT++))
            continue
          fi
        fi

        # Re-queue the message with incremented retry count
        TO=$(grep "^to:" "$msg" 2>/dev/null | cut -d: -f2- | tr -d '\r\n')
        SUBJECT=$(grep "^subject:" "$msg" 2>/dev/null | cut -d: -f2- | tr -d '\r\n')
        BODY=$(sed -n '/^---$/,$p' "$msg" | tail -n +2)

        if [ -z "$TO" ] || [ -z "$SUBJECT" ]; then
          warn "Invalid message format: $(basename "$msg") — missing to/subject"
          ((SKIPPED_COUNT++))
          continue
        fi

        # Increment retry attempts
        NEW_RETRY_ATTEMPTS=$((RETRY_ATTEMPTS + 1))

        # Determine priority (P3 for retries to prevent starvation)
        PRIORITY="P3"

        # Create new message file in inbox
        TS=$(date +%s%3N)
        NEW_MSG_FILE="$BUS_ROOT/$TO/$PRIORITY/${TS}_retry.msg"
        mkdir -p "$(dirname "$NEW_MSG_FILE")"

        # Copy message with updated retry-attempts
        cat > "$NEW_MSG_FILE" << EOF
from:bus-retry
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
priority:$PRIORITY
ttl:$(_get_default_ttl "$SUBJECT")
expires-at:$(_compute_expires_at "$(_get_default_ttl "$SUBJECT")")
correlation-id:$(python3 -c "import uuid; print(str(uuid.uuid4())[:8])" 2>/dev/null || echo "$(date +%s)")"
max-retries:$MAX_RETRIES_VAL
retry-after:$RETRY_AFTER_BASE
retry-attempts:$NEW_RETRY_ATTEMPTS
---
$BODY
EOF

        # Remove from DLQ
        rm -f "$msg" "$REASON_FILE"

        ok "Retried: $(basename "$msg") → $TO [$SUBJECT] attempt:$NEW_RETRY_ATTEMPTS/$MAX_RETRIES_VAL priority:$PRIORITY"
        log_action "BUS_RETRY" "requeued $(basename "$msg") to $TO subject:$SUBJECT attempt:$NEW_RETRY_ATTEMPTS/$MAX_RETRIES_VAL"
        ((RETRY_COUNT++))
      done
    done

    if [ "$RETRY_COUNT" -eq 0 ]; then
      info "No messages eligible for retry (skipped:$SKIPPED_COUNT)"
    else
      ok "Re-queued $RETRY_COUNT message(s) for retry (skipped:$SKIPPED_COUNT)"
    fi
    log_action "BUS_RETRY_SCAN" "requeued:$RETRY_COUNT skipped:$SKIPPED_COUNT"
    ;;

  # ── DLQ Management ────────────────────────────────────────────────
  dlq)
    DLQ_CMD="${1:-depth}"
    shift || true

    case "$DLQ_CMD" in

      # List DLQ contents
      list)
        REASON_FILTER="$1"
        echo ""
        echo -e "${BOLD}=== Dead Letter Queue ===${RESET}"
        echo -e "   Root: $DLQ_ROOT"
        echo ""

        if [ -n "$REASON_FILTER" ]; then
          # Show specific reason category
          DLQ_DIR="$DLQ_ROOT/$REASON_FILTER"
          if [ ! -d "$DLQ_DIR" ]; then
            err "Unknown DLQ category: $REASON_FILTER"
            echo "   Valid categories: expired, unrouted, max-retries, error"
            exit 1
          fi
          COUNT=$(find "$DLQ_DIR" -name "*.msg" 2>/dev/null | wc -l)
          echo -e "   ${YELLOW}📦${RESET} $REASON_FILTER: $COUNT messages"
          if [ "$COUNT" -gt 0 ]; then
            for msg in "$DLQ_DIR"/*.msg; do
              [ -f "$msg" ] || continue
              BASENAME=$(basename "$msg")
              REASON_FILE="${msg%.msg}.reason"
              if [ -f "$REASON_FILE" ]; then
                FAILURE=$(grep "^failure_reason:" "$REASON_FILE" | cut -d: -f2-)
                FAILED_AT=$(grep "^failed_at:" "$REASON_FILE" | cut -d: -f2-)
                echo -e "      ${CYAN}→${RESET} $BASENAME"
                echo -e "         failed: $FAILED_AT | reason: $FAILURE"
              else
                echo -e "      ${CYAN}→${RESET} $BASENAME (no .reason sidecar)"
              fi
            done
          fi
        else
          # Show all categories
          for dir in "$DLQ_ROOT"/*/; do
            [ -d "$dir" ] || continue
            [[ "$(basename "$dir")" == _* ]] && continue

            REASON=$(basename "$dir")
            COUNT=$(find "$dir" -name "*.msg" 2>/dev/null | wc -l)

            case "$REASON" in
              expired) ICON="⏰" ;;
              unrouted) ICON="🔀" ;;
              max-retries) ICON="🔄" ;;
              error) ICON="💥" ;;
              *) ICON="📦" ;;
            esac

            if [ "$COUNT" -gt 0 ]; then
              echo -e "   ${YELLOW}${ICON}${RESET} $REASON: $COUNT messages"
            else
              echo -e "   ${GREEN}✓${RESET} $REASON: empty"
            fi
          done

          TOTAL=$(dlq_depth)
          echo ""
          echo -e "   ${BOLD}Total DLQ depth: $TOTAL${RESET}"
          if [ "$TOTAL" -gt "$DLQ_THRESHOLD" ]; then
            echo -e "   ${RED}⚠️  WARNING: Exceeds threshold ($DLQ_THRESHOLD)${RESET}"
          fi
        fi
        echo ""
        ;;

      # Replay a specific message
      replay)
        MSG_FILE="$1"
        if [ -z "$MSG_FILE" ]; then
          err "Usage: bus.sh dlq replay <file>"
          echo "   Example: bus.sh dlq replay /tmp/manusat-bus/_dlq/error/20260607_123456_msg.msg"
          exit 1
        fi

        if [ ! -f "$MSG_FILE" ]; then
          err "File not found: $MSG_FILE"
          exit 1
        fi

        # Extract original destination and subject
        TO=$(grep "^to:" "$MSG_FILE" | cut -d: -f2- | tr -d '\r\n')
        SUBJECT=$(grep "^subject:" "$MSG_FILE" | cut -d: -f2- | tr -d '\r\n')

        # DLQ replay messages get P3 priority to prevent starvation
        PRIORITY="P3"

        # Re-queue the message
        TS=$(date +%s%3N)
        NEW_MSG_FILE="$BUS_ROOT/$TO/$PRIORITY/${TS}_replay.msg"

        # Create fresh message with original body
        BODY=$(sed -n '/^---$/,$p' "$MSG_FILE" | tail -n +2)
        TTL_SECONDS=$(_get_default_ttl "$SUBJECT")
        EXPIRES_AT=$(_compute_expires_at "$TTL_SECONDS")

        cat > "$NEW_MSG_FILE" << EOF
from:dlq-replay
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
priority:$PRIORITY
ttl:$TTL_SECONDS
expires-at:$EXPIRES_AT
correlation-id:$(python3 -c "import uuid; print(str(uuid.uuid4())[:8])" 2>/dev/null || echo "$(date +%s)")"
---
$BODY
EOF

        # Remove from DLQ
        REASON_FILE="${MSG_FILE%.msg}.reason"
        rm -f "$MSG_FILE" "$REASON_FILE"

        ok "Replayed: $(basename "$MSG_FILE") → $TO [$SUBJECT] priority:$PRIORITY"
        log_action "BUS_DLQ_REPLAY" "replayed $(basename "$MSG_FILE") to $TO priority:$PRIORITY"
        ;;

      # Purge old messages
      purge)
        OLDER_THAN=""
        REASON_FILTER=""

        while [ $# -gt 0 ]; do
          case "$1" in
            --older-than)
              OLDER_THAN="$2"
              shift 2
              ;;
            --reason)
              REASON_FILTER="$2"
              shift 2
              ;;
            *)
              shift
              ;;
          esac
        done

        if [ -z "$OLDER_THAN" ]; then
          err "Usage: bus.sh dlq purge --older-than <days>d"
          echo "   Example: bus.sh dlq purge --older-than 7d"
          exit 1
        fi

        # Parse days from format like "7d"
        DAYS=$(echo "$OLDER_THAN" | sed 's/d$//')
        MINUTES=$((DAYS * 1440))

        PURGE_COUNT=0
        if [ -n "$REASON_FILTER" ]; then
          DLQ_DIRS="$DLQ_ROOT/$REASON_FILTER"
        else
          DLQ_DIRS="$DLQ_ROOT"/*/
        fi

        for dir in $DLQ_DIRS; do
          [ -d "$dir" ] || continue
          [[ "$(basename "$dir")" == _* ]] && continue

          for msg in "$dir"/*.msg; do
            [ -f "$msg" ] || continue

            # Check file age
            if find "$msg" -mmin +$MINUTES 2>/dev/null | grep -q .; then
              REASON_FILE="${msg%.msg}.reason"
              rm -f "$msg" "$REASON_FILE"
              ((PURGE_COUNT++))
            fi
          done
        done

        ok "Purged $PURGE_COUNT old DLQ message(s) (older than ${DAYS}d)"
        log_action "BUS_DLQ_PURGE" "purged:$PURGE_COUNT older-than:${DAYS}d"
        ;;

      # Show DLQ depth
      depth)
        TOTAL=$(dlq_depth)
        echo ""
        echo -e "${BOLD}DLQ Depth: $TOTAL${RESET}"
        echo -e "   Threshold: $DLQ_THRESHOLD"
        if [ "$TOTAL" -gt "$DLQ_THRESHOLD" ]; then
          echo -e "   Status: ${RED}EXCEEDED${RESET}"
        else
          echo -e "   Status: ${GREEN}OK${RESET}"
        fi
        echo ""
        ;;

      *)
        echo "Usage: bus.sh dlq {list|replay|purge|depth}"
        echo ""
        echo "  list [reason]                  — List DLQ contents (optionally filter by reason)"
        echo "  replay <file>                  — Re-queue a specific message"
        echo "  purge --older-than <N>d        — Clean up messages older than N days"
        echo "  depth                          — Check total DLQ size"
        echo ""
        echo "  DLQ categories:"
        echo "    expired     — Messages that exceeded TTL"
        echo "    unrouted    — Messages with no valid recipient"
        echo "    max-retries — Messages that exhausted retry attempts"
        echo "    error       — Other failures"
        ;;
    esac
    ;;

  *)
    echo "Usage: bus.sh {send|recv|queue|broadcast|flush|stats|metrics|trace|sweep|retry|dlq}"
    echo ""
    echo "  send      [--ttl <s>] [--priority P1|P2|P3] [--max-retries N] [--retry-after S] <to> <subject> <body>"
    echo "                                     — ส่ง message (JIT-003: retry headers)"
    echo "  recv      [--priority P1|P2|P3] [agent]  — รับ messages (P1→P2→P3 order, or filter by priority)"
    echo "  queue                            — ดูสถานะ queue (by priority)"
    echo "  broadcast <subject> <body>       — ส่งทุก agent (24h TTL, P2 default)"
    echo "  flush                            — ล้าง read messages เก่า"
    echo "  stats     [--trace] [--json]     — สถิติ (with priority breakdown)"
    echo "  metrics   [--json]               — แสดง bus metrics dashboard (JIT-018)"
    echo "  trace     <correlation-id>       — ติดตาม journey ของ message"
    echo "  sweep                            — ย้าย expired messages ไป DLQ"
    echo "  retry                            — สแกนและ re-queue failed messages (JIT-003)"
    echo "  dlq       {list|replay|purge|depth} — Dead Letter Queue management"
    echo ""
    echo "  Retry Policy (JIT-003):"
    echo "    --max-retries N    Maximum retry attempts (default: 3)"
    echo "    --retry-after S    Base delay in seconds for exponential backoff (default: 1)"
    echo "    Backoff: base * 2^attempts + jitter(0-500ms)"
    echo ""
    echo "  Priority levels:"
    echo "    P1  Critical/high-priority (auto: alert:critical, alert:anomaly)"
    echo "    P2  Normal priority (default)"
    echo "    P3  Low priority (DLQ replays, retries)"
    ;;
esac
