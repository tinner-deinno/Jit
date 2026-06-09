#!/usr/bin/env bash
# organs/heart.sh — หัวใจ (Heart / pran)
#
# หลักพุทธ: อิทธิบาท 4 (ฉันทะ วิริยะ จิตตะ วิมังสา)
# บทบาท: สูบฉีดชีวิต — รับเลือดดำ(IN) ฟอก ส่งเลือดแดง(OUT)
#
# จังหวะ: เต้น 2 ครั้งต่อ 1 รอบ
#   beat in  — ดูดเลือดจากทั่วร่าง (รับ signals/stats จากทุก agent)
#   beat out — ฉีดเลือดออกไป (ส่ง energy/commands ให้ทุก agent)
#
# Usage:
#   ./heart.sh beat in    — IN beat: collect blood payload
#   ./heart.sh beat out   — OUT beat: broadcast clean blood
#   ./heart.sh rhythm     — แสดง vital signs dashboard
#   ./heart.sh pump <type> <task> — route task to organ
#   ./heart.sh rate <mode>        — request rate change (sprint/fast/normal/slow/rest)
#   ./heart.sh routes     — แสดง routing table
#   ./heart.sh oracle-health — Check Oracle health and manage monitoring
#   ./heart.sh monitor-oracle start|stop|status — Manage Oracle health monitor loop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

CMD="${1:-rhythm}"
shift || true

# ── state files (git-tracked = living proof of heartbeat) ───────────
HEART_IN_STATE="$JIT_ROOT/memory/state/heart.in.json"
HEART_OUT_STATE="$JIT_ROOT/memory/state/heart.out.json"
HEART_RATE_REQUEST="/tmp/heart-rate-request.txt"
HEART_LOG="/tmp/manusat-heart.log"
BUS_ROOT="/tmp/manusat-bus"
REGISTRY="$JIT_ROOT/network/registry.json"

# ── JIT-016: Shared Memory Decay & Cleanup ─────────────────────────
SHARED_MEMORY="/tmp/manusat-shared.json"
SHARED_ARCHIVE="/tmp/manusat-shared-archive.jsonl"
MEMORY_MAX_ENTRIES=500
MEMORY_TTL_SECONDS=86400  # 24 hours
ARCHIVE_MAX_BYTES=10485760  # 10 MB

# ── Oracle health monitoring (JIT-012) ──────────────────────────────
ORACLE_HEALTH_FILE="/tmp/manusat-oracle-health.json"
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
ORACLE_WORKDIR="/workspaces/arra-oracle-v3"
MAX_FAILURES=3
RESTART_COOLDOWN=300  # 5 minutes between restart attempts

mkdir -p "$(dirname "$HEART_IN_STATE")" "$BUS_ROOT"

# ── JIT-016: Shared Memory Pruning & Archive ───────────────────────
# Initialize shared memory if not exists
init_shared_memory() {
  if [ ! -f "$SHARED_MEMORY" ]; then
    echo '{"entries":[]}' > "$SHARED_MEMORY"
  fi
}

# Get current shared memory size (entry count)
# JIT-021: Pass file path as argv to prevent Python injection
get_shared_memory_size() {
  if [ -f "$SHARED_MEMORY" ]; then
    python3 - "$SHARED_MEMORY" << 'PYEOF' 2>/dev/null || echo "0"
import json
import sys
with open(sys.argv[1]) as f:
    print(len(json.load(f).get('entries', [])))
PYEOF
  else
    echo "0"
  fi
}

# Archive pruned entries to .jsonl file (max 10MB)
archive_entries() {
  local entries="$1"
  local count
  count=$(echo "$entries" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

  [ "$count" -eq 0 ] && return 0

  # Check archive size before appending
  if [ -f "$SHARED_ARCHIVE" ]; then
    local archive_size
    archive_size=$(stat -c%s "$SHARED_ARCHIVE" 2>/dev/null || echo "0")

    # If archive exceeds max, rotate (keep last half)
    # JIT-021: Pass archive path as argv to prevent Python injection
    if [ "$archive_size" -ge "$ARCHIVE_MAX_BYTES" ]; then
      info "Archiving: Rotating archive (size: ${archive_size} bytes)"
      python3 - "$SHARED_ARCHIVE" << 'PYEOF' 2>/dev/null
import json
import sys
archive_path = sys.argv[1]
with open(archive_path, 'r') as f:
    lines = f.readlines()
# Keep last half
keep = len(lines) // 2
with open(archive_path, 'w') as f:
    f.writelines(lines[keep:])
PYEOF
    fi
  fi

  # Append entries as JSONL (one JSON object per line)
  echo "$entries" | python3 -c "
import json, sys
entries = json.load(sys.stdin)
for entry in entries:
    print(json.dumps(entry))
" >> "$SHARED_ARCHIVE" 2>/dev/null

  log_action "MEMORY_ARCHIVE" "archived=$count entries"
}

# Prune shared memory: remove entries >24h old, cap at 500 with LRU
prune_shared_memory() {
  init_shared_memory

  local cutoff=$(($(date +%s) - MEMORY_TTL_SECONDS))  # 24h ago
  local result

  result=$(python3 - "$SHARED_MEMORY" "$cutoff" "$MEMORY_MAX_ENTRIES" << 'PYEOF' 2>/dev/null
import json, time, sys

shared_memory_path = sys.argv[1]
cutoff = int(sys.argv[2])
max_entries = int(sys.argv[3])

try:
    with open(shared_memory_path, 'r') as f:
        data = json.load(f)
except:
    data = {'entries': []}

entries = data.get('entries', [])
original_count = len(entries)

# Step 1: Filter by timestamp (remove entries older than 24h)
pruned = [e for e in entries if e.get('timestamp', 0) > cutoff]
expired_count = original_count - len(pruned)

# Step 2: LRU eviction if over limit
if len(pruned) > max_entries:
    # Sort by timestamp (oldest first), keep newest max_entries
    pruned.sort(key=lambda x: x.get('timestamp', 0))
    evicted = pruned[:-max_entries]
    pruned = pruned[-max_entries:]
    evicted_count = len(evicted)
else:
    evicted_count = 0

# Save pruned entries back
with open(shared_memory_path, 'w') as f:
    json.dump({'entries': pruned}, f, indent=2)

# Output stats and evicted entries for archiving
result = {
    'original': original_count,
    'current': len(pruned),
    'expired': expired_count,
    'evicted': evicted_count,
    'evicted_entries': evicted
}
print(json.dumps(result))
PYEOF
)

  if [ -n "$result" ]; then
    local expired evicted
    expired=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('expired',0))" 2>/dev/null || echo "0")
    evicted=$(echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('evicted_entries',[])))" 2>/dev/null || echo "0")

    # Archive evicted entries
    if [ "$evicted" -gt 0 ]; then
      local evicted_entries
      evicted_entries=$(echo "$result" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('evicted_entries',[])))" 2>/dev/null)
      archive_entries "$evicted_entries"
    fi

    if [ "$expired" -gt 0 ] || [ "$evicted" -gt 0 ]; then
      log_action "MEMORY_PRUNE" "expired=$expired evicted=$evicted"
    fi
  fi
}

# ── routing table: task type → organ ─────────────────────────────
declare -A ROUTE_TABLE=(
  ["read"]="eye"      ["observe"]="eye"   ["web"]="eye"
  ["listen"]="ear"    ["receive"]="ear"
  ["say"]="mouth"     ["tell"]="mouth"    ["broadcast"]="mouth"
  ["detect"]="nose"   ["monitor"]="nose"  ["health"]="nose"
  ["create"]="hand"   ["edit"]="hand"     ["build"]="hand"
  ["go"]="leg"        ["deploy"]="leg"
  ["think"]="brain"   ["plan"]="brain"
  ["ask"]="ollama"    ["learn"]="oracle"  ["search"]="oracle"
)

# ── Oracle Health Monitoring (JIT-012) ─────────────────────────────

# Initialize or read health file
# JIT-021: Pass file path as argv to prevent Python injection
_init_health_file() {
  if [ ! -f "$ORACLE_HEALTH_FILE" ]; then
    python3 - "$ORACLE_HEALTH_FILE" << 'PYEOF' 2>/dev/null
import json, time
from datetime import datetime, timezone

# Try to get Thailand timezone
try:
    tz = timezone.utc
    # Attempt to convert to ICT (UTC+7)
    from datetime import timedelta
    tz = timezone(timedelta(hours=7))
except:
    pass

now = datetime.now(tz)
health = {
    'last_check': now.strftime('%Y-%m-%dT%H:%M:%S+07:00'),
    'status': 'unknown',
    'consecutive_failures': 0,
    'last_restart_attempt': None,
    'oracle_pid': None
}
with open(sys.argv[1], 'w') as f:
    json.dump(health, f, indent=2)
PYEOF
  fi
}

# Update health file with new status
# JIT-021: Pass file path as argv to prevent Python injection
_update_health_file() {
  local status="$1"
  local failures="${2:-}"
  local oracle_pid="${3:-null}"

  python3 - "$ORACLE_HEALTH_FILE" "$status" "$failures" "$oracle_pid" << 'PYEOF' 2>/dev/null
import json
import sys
from datetime import datetime, timezone, timedelta

try:
    tz = timezone(timedelta(hours=7))
except:
    tz = timezone.utc

health_file = sys.argv[1]
status = sys.argv[2]
failures = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else ''
oracle_pid = sys.argv[4] if len(sys.argv) > 4 else 'null'

health = {}
try:
    with open(health_file, 'r') as f:
        health = json.load(f)
except:
    pass

health['last_check'] = datetime.now(tz).strftime('%Y-%m-%dT%H:%M:%S+07:00')
health['status'] = status

if failures != '':
    health['consecutive_failures'] = int(failures)

if oracle_pid != 'null':
    health['oracle_pid'] = int(oracle_pid) if oracle_pid.isdigit() else None

with open(health_file, 'w') as f:
    json.dump(health, f, indent=2)
PYEOF
}

# Get current failure count from health file
# JIT-021: Pass file path as argv to prevent Python injection
_get_failure_count() {
  if [ -f "$ORACLE_HEALTH_FILE" ]; then
    python3 - "$ORACLE_HEALTH_FILE" << 'PYEOF' 2>/dev/null || echo "0"
import json
import sys
with open(sys.argv[1]) as f:
    print(json.load(f).get('consecutive_failures', 0))
PYEOF
  else
    echo "0"
  fi
}

# Increment failure count and return new value
# JIT-021: Pass file path as argv to prevent Python injection
_increment_failure_count() {
  python3 - "$ORACLE_HEALTH_FILE" << 'PYEOF' 2>/dev/null || echo "1"
import json
import sys
from datetime import datetime, timezone, timedelta

try:
    tz = timezone(timedelta(hours=7))
except:
    tz = timezone.utc

health = {}
try:
    with open(sys.argv[1], 'r') as f:
        health = json.load(f)
except:
    pass

health['last_check'] = datetime.now(tz).strftime('%Y-%m-%dT%H:%M:%S+07:00')
health['consecutive_failures'] = health.get('consecutive_failures', 0) + 1

with open(sys.argv[1], 'w') as f:
    json.dump(health, f, indent=2)

print(health['consecutive_failures'])
PYEOF
}

# Reset failure count on success
# JIT-021: Pass file path as argv to prevent Python injection
_reset_failure_count() {
  python3 - "$ORACLE_HEALTH_FILE" << 'PYEOF' 2>/dev/null
import json
import sys
from datetime import datetime, timezone, timedelta

try:
    tz = timezone(timedelta(hours=7))
except:
    tz = timezone.utc

health = {}
try:
    with open(sys.argv[1], 'r') as f:
        health = json.load(f)
except:
    pass

health['last_check'] = datetime.now(tz).strftime('%Y-%m-%dT%H:%M:%S+07:00')
health['consecutive_failures'] = 0
health['status'] = 'healthy'

with open(sys.argv[1], 'w') as f:
    json.dump(health, f, indent=2)
PYEOF
}

# Check Oracle health via HTTP
_check_oracle_health() {
  local response
  response=$(curl -s --max-time 5 "$ORACLE_URL/api/health" 2>/dev/null)

  # Empty response = unhealthy
  if [ -z "$response" ]; then
    return 1
  fi

  if echo "$response" | jq -e '.status == "ok"' >/dev/null 2>&1; then
    return 0  # Healthy
  else
    return 1  # Unhealthy
  fi
}

# Get Oracle PID if running
_get_oracle_pid() {
  pgrep -f "arra-oracle|bun.*src/server.ts" 2>/dev/null | head -1 || echo "null"
}

# Emit alert to message bus
_emit_alert() {
  local message="$1"
  local severity="${2:-critical}"

  bash "$JIT_ROOT/network/bus.sh" broadcast "alert:$severity" \
    "Oracle Health: $message" >/dev/null 2>&1

  # Also send direct message to jit (master orchestrator)
  bash "$JIT_ROOT/network/bus.sh" send "jit" "alert:oracle:$severity" \
    "Oracle health check failed: $message (failures: $(_get_failure_count))" >/dev/null 2>&1

  log_action "ORACLE_ALERT" "severity=$severity message=$message"
  echo "[ALERT $severity] $message" >&2
}

# Attempt to restart Oracle service
_attempt_restart() {
  local current_pid last_restart now elapsed

  # Check if we recently attempted a restart
  # JIT-021: Pass file path as argv to prevent Python injection
  if [ -f "$ORACLE_HEALTH_FILE" ]; then
    last_restart=$(python3 - "$ORACLE_HEALTH_FILE" << 'PYEOF' 2>/dev/null || echo "null"
import json
import sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
        print(d.get('last_restart_attempt', 'null'))
except:
    print('null')
PYEOF
)
    if [ "$last_restart" != "null" ] && [ -n "$last_restart" ]; then
      now=$(date +%s)
      elapsed=$((now - last_restart))
      if [ "$elapsed" -lt "$RESTART_COOLDOWN" ]; then
        info "Restart cooldown active ($elapsed s since last attempt)"
        return 1
      fi
    fi
  fi

  log_action "ORACLE_RESTART" "Attempting restart"
  echo "[RESTART] Attempting to restart Oracle..." >&2

  # Kill any existing Oracle process
  local existing_pids
  existing_pids=$(pgrep -f "bun.*src/server.ts" 2>/dev/null || true)
  if [ -n "$existing_pids" ]; then
    info "Stopping existing Oracle processes..."
    echo "$existing_pids" | xargs kill 2>/dev/null || true
    sleep 2
  fi

  # Start Oracle in background
  if [ -d "$ORACLE_WORKDIR" ]; then
    cd "$ORACLE_WORKDIR" || return 1
    ORACLE_PORT=47778 bun run src/server.ts &
    local new_pid=$!

    # Record restart attempt
    # JIT-021: Pass file path and values as argv to prevent Python injection
    python3 - "$ORACLE_HEALTH_FILE" "$new_pid" << 'PYEOF' 2>/dev/null
import json, time
from datetime import datetime, timezone, timedelta
import sys

try:
    tz = timezone(timedelta(hours=7))
except:
    tz = timezone.utc

health_file = sys.argv[1]
new_pid = int(sys.argv[2]) if sys.argv[2].isdigit() else None

health = {}
try:
    with open(health_file, 'r') as f:
        health = json.load(f)
except:
    pass
health['last_restart_attempt'] = int(time.time())
health['oracle_pid'] = new_pid
health['last_check'] = datetime.now(tz).strftime('%Y-%m-%dT%H:%M:%S+07:00')
with open(health_file, 'w') as f:
    json.dump(health, f, indent=2)
PYEOF

    # Wait for startup
    sleep 3

    # Verify restart succeeded
    if _check_oracle_health; then
      ok "Oracle restarted successfully (PID: $new_pid)"
      _reset_failure_count
      _update_health_file "healthy" "0" "$new_pid"
      return 0
    else
      err "Oracle restart failed - health check still failing"
      _update_health_file "unhealthy" "$(_get_failure_count)" "$new_pid"
      return 1
    fi
  else
    err "Oracle workdir not found: $ORACLE_WORKDIR"
    return 1
  fi
}

# Main health check function
check_oracle_and_mitigate() {
  _init_health_file

  if _check_oracle_health; then
    # Oracle is healthy - reset counters
    _reset_failure_count
    local pid=$(_get_oracle_pid)
    _update_health_file "healthy" "0" "$pid"
    return 0
  else
    # Oracle is unhealthy - increment failure counter
    local failures=$(_increment_failure_count)
    local pid=$(_get_oracle_pid)
    _update_health_file "unhealthy" "$failures" "$pid"

    if [ "$failures" -ge "$MAX_FAILURES" ]; then
      # Critical threshold reached - alert and restart
      _emit_alert "Oracle down after $failures consecutive failures" "critical"
      _attempt_restart
      return $?
    else
      warning "Oracle health check failed ($failures/$MAX_FAILURES)"
      return 1
    fi
  fi
}

# Background monitoring loop
_monitor_oracle_loop() {
  local interval="${1:-60}"  # Default 60 seconds
  local monitor_pid_file="/tmp/manusat-oracle-monitor.pid"
  local monitor_log="/tmp/manusat-oracle-monitor.log"

  # Check if already running
  if [ -f "$monitor_pid_file" ]; then
    local old_pid=$(cat "$monitor_pid_file")
    if kill -0 "$old_pid" 2>/dev/null; then
      info "Oracle monitor already running (PID: $old_pid)"
      return 0
    else
      rm -f "$monitor_pid_file"
    fi
  fi

  # Start monitor in background using nohup
  nohup bash -c "
    echo \$\$ > '$monitor_pid_file'
    while true; do
      $SCRIPT_DIR/heart.sh _check-internal >> '$monitor_log' 2>&1
      sleep $interval
    done
  " >> "$monitor_log" 2>&1 &

  local new_pid=$!
  disown $new_pid 2>/dev/null || true

  # Wait a moment for PID file to be written
  sleep 1

  if [ -f "$monitor_pid_file" ]; then
    ok "Oracle monitor started (PID: $(cat $monitor_pid_file), interval: ${interval}s)"
  else
    ok "Oracle monitor started (PID: $new_pid, interval: ${interval}s)"
  fi
  log_action "ORACLE_MONITOR_START" "interval=$interval"
}

# Internal health check (for monitor loop - quiet mode)
_check_internal() {
  _init_health_file
  check_oracle_and_mitigate >/dev/null 2>&1
}

_stop_oracle_monitor() {
  local monitor_pid_file="/tmp/manusat-oracle-monitor.pid"
  if [ -f "$monitor_pid_file" ]; then
    local pid=$(cat "$monitor_pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      rm -f "$monitor_pid_file"
      ok "Oracle monitor stopped (PID: $pid)"
      log_action "ORACLE_MONITOR_STOP" "pid=$pid"
      return 0
    fi
  fi
  info "No Oracle monitor running"
  return 1
}

_oracle_monitor_status() {
  local monitor_pid_file="/tmp/manusat-oracle-monitor.pid"
  echo ""
  echo -e "${BOLD}${CYAN}[ Oracle Health Monitor Status ]${RESET}"
  echo ""

  if [ -f "$monitor_pid_file" ]; then
    local pid=$(cat "$monitor_pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      echo -e "  Monitor: ${GREEN}running${RESET} (PID: $pid)"
    else
      echo -e "  Monitor: ${RED}stopped${RESET} (stale PID file)"
    fi
  else
    echo -e "  Monitor: ${YELLOW}not running${RESET}"
  fi

  if [ -f "$ORACLE_HEALTH_FILE" ]; then
    echo ""
    echo -e "  ${BOLD}Health Status:${RESET}"
    cat "$ORACLE_HEALTH_FILE" | python3 -c "
import sys, json
h = json.load(sys.stdin)
print(f\"    Status: {h.get('status', 'unknown')}\")
print(f\"    Failures: {h.get('consecutive_failures', 0)} consecutive\")
print(f\"    Last Check: {h.get('last_check', 'never')}\")
ra = h.get('last_restart_attempt')
if ra:
    from datetime import datetime
    print(f\"    Last Restart: {datetime.fromtimestamp(ra).strftime('%Y-%m-%d %H:%M:%S')}\")
pid = h.get('oracle_pid')
if pid:
    print(f\"    Oracle PID: {pid}\")
" 2>/dev/null
  else
    echo -e "  ${BOLD}Health Status:${RESET} ${YELLOW}no data${RESET}"
  fi
  echo ""
}

# ── update agent health in registry ─────────────────────────────────
# Updates health_status, last_heartbeat, response_time_ms for an agent
_update_agent_health() {
  local agent_name="$1"
  local health_status="${2:-ok}"  # ok|degraded|offline
  local response_time="${3:-}"    # optional response time in ms

  if [ ! -f "$REGISTRY" ]; then
    return 1
  fi

  local now_ts
  now_ts=$(date '+%Y-%m-%dT%H:%M:%S+07:00')

  python3 - "$REGISTRY" "$agent_name" "$health_status" "$now_ts" "$response_time" << 'PYEOF' 2>/dev/null
import json
import sys
import os

registry_path = sys.argv[1]
agent_name = sys.argv[2]
health_status = sys.argv[3]
timestamp = sys.argv[4]
response_time = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None

try:
    with open(registry_path, 'r', encoding='utf-8') as f:
        registry = json.load(f)

    for agent in registry.get('agents', []):
        if agent.get('name') == agent_name:
            agent['health_status'] = health_status
            agent['last_heartbeat'] = timestamp
            if response_time:
                agent['response_time_ms'] = int(response_time)

            # Update message_queue_depth from inbox
            inbox_path = f'/tmp/manusat-bus/{agent_name}'
            if os.path.isdir(inbox_path):
                pending = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])
                agent['message_queue_depth'] = pending

            break

    with open(registry_path, 'w', encoding='utf-8') as f:
        json.dump(registry, f, ensure_ascii=False, indent=2)

except Exception as e:
    print(f"Error updating agent health: {e}", file=sys.stderr)
PYEOF
}

# ── JIT-024: Anomaly Detection & Baseline Collection ────────────────
BASELINE_FILE="/tmp/manusat-baseline.json"
ANOMALY_LOG="/tmp/manusat-anomalies.jsonl"
BASELINE_HEARTBEATS=5
MAX_HEARTBEAT_AGE_CYCLES=3

# Initialize or load baseline data
_init_baseline() {
  if [ ! -f "$BASELINE_FILE" ]; then
    python3 - << 'PYEOF' 2>/dev/null
import json
baseline = {
    "baseline_heartbeats": 5,
    "collected": 0,
    "agents": {},
    "created_at": None,
    "completed_at": None
}
with open('/tmp/manusat-baseline.json', 'w') as f:
    json.dump(baseline, f, indent=2)
PYEOF
  fi
}

# Collect baseline metrics from current heartbeat
_collect_baseline_sample() {
  local ts="$1"
  local pulse="$2"

  python3 - "$BUS_METRICS_FILE" "$ts" "$pulse" << 'PYEOF' 2>/dev/null
import json
import sys
from datetime import datetime, timezone, timedelta

metrics_file = sys.argv[1]
timestamp = sys.argv[2]
pulse = int(sys.argv[3])

try:
    with open('/tmp/manusat-baseline.json', 'r') as f:
        baseline = json.load(f)
except:
    baseline = {"baseline_heartbeats": 5, "collected": 0, "agents": {}, "created_at": None, "completed_at": None}

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)
except:
    metrics = {"agents": {}, "totals": {}}

if baseline["created_at"] is None:
    baseline["created_at"] = timestamp

for agent_name, agent_metrics in metrics.get("agents", {}).items():
    if agent_name not in baseline["agents"]:
        baseline["agents"][agent_name] = {
            "samples": [],
            "baseline_response_time": None,
            "baseline_inbox_depth": None,
            "baseline_failed": None
        }

    sample = {
        "pulse": pulse,
        "timestamp": timestamp,
        "dlq_depth": agent_metrics.get("dlq_depth", 0),
        "failed": agent_metrics.get("failed", 0),
        "received": agent_metrics.get("received", 0),
        "sent": agent_metrics.get("sent", 0)
    }

    # Get inbox depth from filesystem
    import os
    inbox_path = f"/tmp/manusat-bus/{agent_name}"
    inbox_depth = 0
    if os.path.isdir(inbox_path):
        inbox_depth = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])
    sample["inbox_depth"] = inbox_depth

    baseline["agents"][agent_name]["samples"].append(sample)

baseline["collected"] += 1

if baseline["collected"] >= baseline["baseline_heartbeats"]:
    baseline["completed_at"] = timestamp
    # Calculate baselines (average of samples)
    for agent_name, agent_data in baseline["agents"].items():
        samples = agent_data["samples"]
        if samples:
            agent_data["baseline_response_time"] = sum(s.get("dlq_depth", 0) for s in samples) / len(samples)
            agent_data["baseline_inbox_depth"] = sum(s.get("inbox_depth", 0) for s in samples) / len(samples)
            agent_data["baseline_failed"] = sum(s.get("failed", 0) for s in samples) / len(samples)

with open('/tmp/manusat-baseline.json', 'w') as f:
    json.dump(baseline, f, indent=2)

print(f"Baseline sample {baseline['collected']}/{baseline['baseline_heartbeats']} collected")
PYEOF
}

# Detect anomalies for all agents
_detect_anomalies() {
  local ts="$1"
  local pulse="$2"

  python3 - "$BUS_METRICS_FILE" "$ts" "$pulse" "$ANOMALY_LOG" << 'PYEOF'
import json
import sys
import os
from datetime import datetime, timezone, timedelta

metrics_file = sys.argv[1]
timestamp = sys.argv[2]
pulse = int(sys.argv[3])
anomaly_log = sys.argv[4]

try:
    with open('/tmp/manusat-baseline.json', 'r') as f:
        baseline = json.load(f)
except:
    print("No baseline available yet")
    sys.exit(0)

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)
except:
    print("No metrics available")
    sys.exit(0)

if not baseline.get("completed_at"):
    print("Baseline collection in progress, skipping anomaly detection")
    sys.exit(0)

anomalies = []

for agent_name, agent_metrics in metrics.get("agents", {}).items():
    agent_baseline = baseline["agents"].get(agent_name, {})

    current_dlq = agent_metrics.get("dlq_depth", 0)
    current_failed = agent_metrics.get("failed", 0)
    current_inbox = 0

    # Get actual inbox depth
    inbox_path = f"/tmp/manusat-bus/{agent_name}"
    if os.path.isdir(inbox_path):
        current_inbox = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])

    baseline_dlq = agent_baseline.get("baseline_response_time", 0) or 0
    baseline_inbox = agent_baseline.get("baseline_inbox_depth", 0) or 0
    baseline_failed = agent_baseline.get("baseline_failed", 0) or 0

    # Rule 1: DLQ depth > 2x baseline (proxy for slow response)
    if baseline_dlq > 0 and current_dlq > (baseline_dlq * 2):
        anomaly = {
            "timestamp": timestamp,
            "pulse": pulse,
            "agent": agent_name,
            "type": "slow_response",
            "severity": "high",
            "details": {
                "current_dlq": current_dlq,
                "baseline_dlq": baseline_dlq,
                "ratio": round(current_dlq / baseline_dlq, 2)
            },
            "description": f"Agent {agent_name} DLQ depth {current_dlq} > 2x baseline {baseline_dlq}"
        }
        anomalies.append(anomaly)

    # Rule 2: Inbox depth > 50 messages
    if current_inbox > 50:
        anomaly = {
            "timestamp": timestamp,
            "pulse": pulse,
            "agent": agent_name,
            "type": "inbox_growth",
            "severity": "medium",
            "details": {
                "current_inbox": current_inbox,
                "threshold": 50
            },
            "description": f"Agent {agent_name} inbox has {current_inbox} pending messages (>50)"
        }
        anomalies.append(anomaly)

    # Rule 3: Failed messages spike
    if current_failed > (baseline_failed * 2) and current_failed > 0:
        anomaly = {
            "timestamp": timestamp,
            "pulse": pulse,
            "agent": agent_name,
            "type": "message_failures",
            "severity": "high",
            "details": {
                "current_failed": current_failed,
                "baseline_failed": baseline_failed
            },
            "description": f"Agent {agent_name} has {current_failed} failed messages"
        }
        anomalies.append(anomaly)

# Check for stuck agents (no heartbeat for 3+ cycles via registry)
# Rule 4: Agent stuck - no heartbeat for >90 seconds (3 cycles at 30s each)
try:
    registry_path = "/workspaces/Jit/network/registry.json"
    with open(registry_path, 'r') as f:
        registry = json.load(f)

    now = datetime.now(timezone(timedelta(hours=7)))
    for agent in registry.get("agents", []):
        agent_name = agent.get("name")
        last_hb = agent.get("last_heartbeat")

        if last_hb and last_hb != "null":
            try:
                hb_time = datetime.fromisoformat(last_hb.replace("+07:00", "+07:00"))
                age_seconds = (now - hb_time).total_seconds()
                # Assume ~30s per cycle, 3 cycles = 90s
                if age_seconds > 90:
                    anomaly = {
                        "timestamp": timestamp,
                        "pulse": pulse,
                        "agent": agent_name,
                        "type": "stuck_agent",
                        "severity": "critical",
                        "details": {
                            "last_heartbeat": last_hb,
                            "age_seconds": round(age_seconds, 1),
                            "cycles_missed": max(1, int(age_seconds / 30))
                        },
                        "description": f"Agent {agent_name} stuck - no heartbeat for {round(age_seconds/60, 1)} min"
                    }
                    anomalies.append(anomaly)
            except:
                pass
        # Also flag agents that never had a heartbeat but have pending messages (likely stuck before first beat)
        elif agent_name not in ["nonexistent_agent"]:  # Skip test agents
            inbox_path = f"/tmp/manusat-bus/{agent_name}"
            if os.path.isdir(inbox_path):
                pending = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])
                if pending > 10:  # Has messages but no heartbeat = likely stuck
                    anomaly = {
                        "timestamp": timestamp,
                        "pulse": pulse,
                        "agent": agent_name,
                        "type": "stuck_agent",
                        "severity": "critical",
                        "details": {
                            "last_heartbeat": None,
                            "pending_messages": pending,
                            "status": "no_heartbeat_ever"
                        },
                        "description": f"Agent {agent_name} stuck - has {pending} pending messages but no heartbeat recorded"
                    }
                    anomalies.append(anomaly)
except Exception as e:
    print(f"Error checking stuck agents: {e}", file=sys.stderr)

# Log anomalies to JSONL file
if anomalies:
    with open(anomaly_log, 'a') as f:
        for anomaly in anomalies:
            f.write(json.dumps(anomaly) + '\n')

    print(f"Detected {len(anomalies)} anomalies")
    for a in anomalies:
        print(f"  [{a['severity'].upper()}] {a['type']}: {a['agent']} - {a['description']}")
else:
    print("No anomalies detected")

# Return anomaly count for alerting
print(f"ANOMALY_COUNT:{len(anomalies)}")
PYEOF
}

# Broadcast alert if anomalies detected
_broadcast_anomaly_alert() {
  local anomaly_count="$1"
  local severity="$2"

  if [ "$anomaly_count" -gt 0 ]; then
    # Read latest anomalies
    local latest_anomalies
    latest_anomalies=$(tail -5 "$ANOMALY_LOG" 2>/dev/null | python3 -c "
import sys, json
anomalies = [json.loads(l) for l in sys.stdin if l.strip()]
critical = sum(1 for a in anomalies if a.get('severity') == 'critical')
high = sum(1 for a in anomalies if a.get('severity') == 'high')
medium = sum(1 for a in anomalies if a.get('severity') == 'medium')
print(f'Critical: {critical}, High: {high}, Medium: {medium}')
" 2>/dev/null || echo "Anomalies detected")

    # Broadcast alert to all agents
    bash "$JIT_ROOT/network/bus.sh" broadcast "alert:anomaly" \
      "Heartbeat detected $anomaly_count anomalies - $latest_anomalies" >/dev/null 2>&1

    # Send direct alert to jit (master orchestrator)
    bash "$JIT_ROOT/network/bus.sh" send "jit" "alert:anomaly" \
      "pran detected $anomaly_count anomalies requiring attention" >/dev/null 2>&1

    log_action "ANOMALY_ALERT" "count=$anomaly_count severity=$severity"
  fi
}

# Main baseline collection and anomaly detection function
_collect_baseline_and_detect_anomalies() {
  local ts="$1"
  local pulse="$2"

  _init_baseline

  # Try to collect baseline sample
  local baseline_result
  baseline_result=$(_collect_baseline_sample "$ts" "$pulse" 2>&1)

  # Check if baseline is complete
  local baseline_complete
  baseline_complete=$(python3 -c "
import json
try:
    b = json.load(open('/tmp/manusat-baseline.json'))
    print('yes' if b.get('completed_at') else 'no')
except:
    print('no')
" 2>/dev/null)

  if [ "$baseline_complete" = "yes" ]; then
    # Baseline complete - run anomaly detection
    local detect_result
    detect_result=$(_detect_anomalies "$ts" "$pulse" 2>&1)

    # Extract anomaly count from result (handle empty/malformed output)
    local anomaly_count
    anomaly_count=$(echo "$detect_result" | grep "ANOMALY_COUNT:" | cut -d: -f2 | tr -d '[:space:]')

    # Default to 0 if extraction failed
    if [ -z "$anomaly_count" ] || ! [[ "$anomaly_count" =~ ^[0-9]+$ ]]; then
      anomaly_count=0
    fi

    if [ "$anomaly_count" -gt 0 ]; then
      # Determine highest severity
      local highest_severity
      highest_severity=$(tail -"$anomaly_count" "$ANOMALY_LOG" 2>/dev/null | python3 -c "
import sys, json
severities = [json.loads(l).get('severity', 'low') for l in sys.stdin if l.strip()]
priority = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1}
max_sev = max(severities, key=lambda x: priority.get(x, 0)) if severities else 'low'
print(max_sev)
" 2>/dev/null || echo "medium")

      _broadcast_anomaly_alert "$anomaly_count" "$highest_severity"
    fi
  else
    echo "Baseline collection: $baseline_result"
  fi
}

# ── collect blood: รวบรวม stats จากทุก agent ──────────────────────
_collect_blood() {
  local ts agents agent pending total_pending=0
  local oracle_ok=0 ollama_ok=0
  ts="$(date '+%Y-%m-%dT%H:%M:%S')"

  # ตรวจ services
  curl -sf --max-time 3 "${ORACLE_URL:-http://localhost:47778}/api/health" \
    2>/dev/null | grep -q '"oracle":"connected"' && oracle_ok=1
  curl -sf --max-time 4 "${OLLAMA_URL:-https://ollama.mdes-innova.online}/api/tags" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-[REDACTED]}" 2>/dev/null \
    | grep -q '"models"' && ollama_ok=1

  # รวบ agent stats จาก registry
  local agent_stats="{}"
  if [ -f "$REGISTRY" ]; then
    agent_stats=$(python3 - "$REGISTRY" "$BUS_ROOT" << PYEOF 2>/dev/null
import sys, json, os

reg_path = sys.argv[1]
bus_root = sys.argv[2]
reg = json.load(open(reg_path))
stats = {}
for a in reg.get('agents', []):
  name = a['name']
  inbox = os.path.join(bus_root, name)
  pending = 0
  if os.path.isdir(inbox):
    pending = len([f for f in os.listdir(inbox) if f.endswith('.msg')])
  alive_file = f'/tmp/manusat-alive-{name}'
  alive = os.path.exists(alive_file) and (
    (os.stat(alive_file).st_mtime if os.path.exists(alive_file) else 0)
    > (__import__('time').time() - 3600)
  )
  stats[name] = {
    'pending': pending,
    'organ': a.get('organ', '?'),
    'tier': a.get('tier', '?'),
    'alive': alive
  }
print(json.dumps(stats, ensure_ascii=False))
PYEOF
)
  fi

  # git stats
  local git_changes
  git_changes=$(git -C "$JIT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

  # รวบ total pending (task messages เท่านั้น)
  total_pending=$(find "$BUS_ROOT" -name '*.msg' -mmin -10 2>/dev/null \
                  | grep -v '_broadcast\.msg$' | wc -l | tr -d ' ')

  # สร้าง blood payload
  python3 - << PYEOF 2>/dev/null
import json
payload = {
  "timestamp": "$ts",
  "host": "$(hostname)",
  "oracle_ok": bool($oracle_ok),
  "ollama_ok": bool($ollama_ok),
  "git_changes": $git_changes,
  "total_pending": $total_pending,
  "agents": ${agent_stats:-{}}
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
PYEOF
}

# ── IN beat: ดูดเลือดดำ → ฟอก → บันทึก ─────────────────────────
METRICS_HISTORY_FILE="/tmp/manusat-metrics-history.jsonl"
BUS_METRICS_FILE="/tmp/manusat-bus-metrics.json"

_beat_in() {
  local ts="$(date '+%Y-%m-%dT%H:%M:%S')"
  local pulse_n="${PULSE_COUNT:-0}"

  # JIT-016: Prune shared memory on each heartbeat
  init_shared_memory
  prune_shared_memory

  # JIT-018: Record bus metrics snapshot each beat
  if [ -f "$BUS_METRICS_FILE" ]; then
    python3 - "$BUS_METRICS_FILE" "$METRICS_HISTORY_FILE" "$ts" "$pulse_n" << 'PYEOF' 2>/dev/null
import json
import sys

metrics_file = sys.argv[1]
history_file = sys.argv[2]
timestamp = sys.argv[3]
pulse = int(sys.argv[4])

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)

    # Create snapshot with pulse info
    snapshot = {
        'timestamp': timestamp,
        'pulse': pulse,
        'metrics': metrics
    }

    # Append to history file as JSONL
    with open(history_file, 'a') as f:
        f.write(json.dumps(snapshot) + '\n')
except Exception as e:
    print(f"Error recording metrics snapshot: {e}", file=sys.stderr)
PYEOF
  fi

  # JIT-024: Collect baseline metrics and detect anomalies
  _collect_baseline_and_detect_anomalies "$ts" "$pulse_n"

  # เก็บ blood payload
  local blood
  blood=$(_collect_blood)

  # บันทึก heart.in.json (git-tracked = proof of IN beat)
  python3 - << PYEOF 2>/dev/null
import json, time
blood = json.loads('''$blood''') if '''$blood''' else {}
state = {
  "beat": "IN",
  "pulse": $pulse_n,
  "timestamp": "$ts",
  "host": "$(hostname)",
  "blood": blood,
  "note": "diastole — collecting signals from body"
}
with open('$HEART_IN_STATE', 'w', encoding='utf-8') as f:
  json.dump(state, f, ensure_ascii=False, indent=2)
PYEOF

  # บันทึก bus marker
  echo "{\"heartbeat\":\"$ts\",\"from\":\"heart\",\"phase\":\"IN\",\"pulse\":$pulse_n}" \
    > "$BUS_ROOT/heartbeat-in.json" 2>/dev/null || true

  # ส่งสัญญาณผ่าน nerve (ถ้ามี)
  local NERVE="$SCRIPT_DIR/nerve.sh"
  [ -x "$NERVE" ] && bash "$NERVE" signal "heartbeat:IN" "$ts" "heart" >/dev/null 2>&1 || true

  # ส่งผ่าน bus
  bash "$JIT_ROOT/network/bus.sh" broadcast "heartbeat:IN" \
    "pulse #$pulse_n from $(hostname) @ $ts" >/dev/null 2>&1 || true

  # JIT-020: Update pran (heart) agent health in registry
  _update_agent_health "pran" "ok"

  log_action "HEART_IN" "pulse=$pulse_n ts=$ts"
  echo "$blood"
}

# ── OUT beat: ฉีดเลือดแดง → ส่งพลังงานให้ทุกอวัยวะ ─────────────
_beat_out() {
  local ts="$(date '+%Y-%m-%dT%H:%M:%S')"
  local pulse_n="${PULSE_COUNT:-0}"
  local mode="${HEARTBEAT_MODE:-normal}"

  # สร้าง energy payload สำหรับส่งออก
  local energy
  energy=$(python3 - << PYEOF 2>/dev/null
import json, os
# อ่าน IN state เพื่อดูว่าต้อง wake ใคร
in_state = {}
try:
  in_state = json.load(open('$HEART_IN_STATE'))
except:
  pass

blood = in_state.get('blood', {})
agents = blood.get('agents', {})

# ระบุ agents ที่ไม่ active (มี pending > 0 = ยังมีงานค้าง)
wake_list = [name for name, info in agents.items() if info.get('pending', 0) > 0]

energy = {
  "beat": "OUT",
  "pulse": $pulse_n,
  "timestamp": "$ts",
  "host": "$(hostname)",
  "mode": "$mode",
  "wake": wake_list,
  "command": "alive",
  "note": "systole — pumping clean blood to all organs"
}
print(json.dumps(energy, ensure_ascii=False, indent=2))
PYEOF
)

  # บันทึก heart.out.json (git-tracked = proof of OUT beat)
  echo "$energy" > "$HEART_OUT_STATE" 2>/dev/null || true

  # บันทึก bus marker
  echo "{\"heartbeat\":\"$ts\",\"from\":\"heart\",\"phase\":\"OUT\",\"pulse\":$pulse_n}" \
    > "$BUS_ROOT/heartbeat-out.json" 2>/dev/null || true

  # broadcast energy ไปทุก agent
  bash "$JIT_ROOT/network/bus.sh" broadcast "heartbeat:OUT" \
    "pulse #$pulse_n energy out @ $ts | mode=$mode" >/dev/null 2>&1 || true

  # ส่งสัญญาณผ่าน nerve
  local NERVE="$SCRIPT_DIR/nerve.sh"
  [ -x "$NERVE" ] && bash "$NERVE" signal "heartbeat:OUT" "$ts" "heart" >/dev/null 2>&1 || true

  # pulse อวัยวะหลัก (with timeout protection - JIT-023)
  local organs=(lung nose eye ear)
  local PIDS=()
  local timeout=60

  for organ in "${organs[@]}"; do
    local sc="$SCRIPT_DIR/$organ.sh"
    if [ -x "$sc" ]; then
      bash "$sc" pulse "$energy" >/dev/null 2>&1 &
      PIDS+=($!)
    fi
  done

  # Wait with timeout for each background job
  for pid in "${PIDS[@]}"; do
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null && [ $elapsed -lt $timeout ]; do
      sleep 1
      elapsed=$((elapsed + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
      warn "organ pulse timeout (PID $pid)"
      kill -9 "$pid" 2>/dev/null || true
      log_action "HEART_TIMEOUT" "organ PID $pid killed after ${timeout}s"
    fi
  done

  # JIT-020: Update pran (heart) agent health in registry after OUT beat
  _update_agent_health "pran" "ok"

  log_action "HEART_OUT" "pulse=$pulse_n mode=$mode ts=$ts"
  echo "$energy"
}

case "$CMD" in

  # ── beat: เต้นหัวใจ ─────────────────────────────────────────────
  beat)
    PHASE="${1:-cycle}"
    shift || true
    case "$PHASE" in
      in)    _beat_in  ;;
      out)   _beat_out ;;
      cycle) _beat_in; echo ""; _beat_out ;;
      *)     echo "Usage: heart.sh beat {in|out|cycle}" ;;
    esac
    ;;

  # ── rate: ขอเปลี่ยน heartbeat rate ──────────────────────────────
  rate)
    RATE="${1:-normal}"
    case "$RATE" in
      sprint|fast|normal|slow|rest)
        echo "$RATE" > "$HEART_RATE_REQUEST"
        ok "🫀 Rate request: $RATE → $HEART_RATE_REQUEST"
        log_action "HEART_RATE_REQ" "$RATE"
        ;;
      *) err "Rate ต้องเป็น: sprint fast normal slow rest" ;;
    esac
    ;;

  # ── pump: route task → organ ────────────────────────────────────
  pump)
    TASK_TYPE="${1:-unknown}"; shift || true; TASK_ARGS="$*"
    ORGAN="${ROUTE_TABLE[$TASK_TYPE]:-hand}"
    ORGAN_SCRIPT="$SCRIPT_DIR/$ORGAN.sh"
    step "pump: $TASK_TYPE → $ORGAN"
    log_action "HEART_PUMP" "$TASK_TYPE → $ORGAN"
    if [ -x "$ORGAN_SCRIPT" ]; then
      bash "$ORGAN_SCRIPT" "$TASK_TYPE" $TASK_ARGS
    else
      LIMB="$JIT_ROOT/limbs/$ORGAN.sh"
      [ -x "$LIMB" ] && bash "$LIMB" "$TASK_TYPE" $TASK_ARGS \
        || bash "$SCRIPT_DIR/hand.sh" execute "$TASK_ARGS"
    fi
    ;;

  # ── rhythm: vital signs ──────────────────────────────────────────
  rhythm)
    VITALS="$SCRIPT_DIR/vitals.sh"
    if [ -x "$VITALS" ]; then
      bash "$VITALS"
    else
      echo ""
      echo -e "${BOLD}${RED}❤ มนุษย์ Agent — Vital Signs${RESET}"
      echo -e "   $(date '+%Y-%m-%d %H:%M:%S')"
      echo ""
      ORGANS=(eye ear mouth nose hand leg heart nerve)
      ALIVE=0; TOTAL=${#ORGANS[@]}
      for O in "${ORGANS[@]}"; do
        F="$SCRIPT_DIR/$O.sh"
        if [ -f "$F" ]; then echo -e "   ${GREEN}♥${RESET} $O"; (( ALIVE++ ))
        else echo -e "   ${RED}✗${RESET} $O"; fi
      done
      echo ""
      oracle_ready && echo -e "   ${GREEN}♥${RESET} Oracle" \
                   || echo -e "   ${RED}✗${RESET} Oracle offline"
      PCT=$(( (ALIVE * 100) / TOTAL ))
      echo -e "   Vitality: ${GREEN}$PCT%${RESET} ($ALIVE/$TOTAL)"
      log_action "HEART_RHYTHM" "$ALIVE/$TOTAL"
      echo ""

      # แสดง last heartbeat stats
      if [ -f "$HEART_OUT_STATE" ]; then
        echo -e "   Last OUT: $(python3 -c "import sys, json; d=json.load(open(sys.argv[1])); print(d.get('timestamp','?'), '| pulse #' + str(d.get('pulse','?')))" "$HEART_OUT_STATE")"
      fi
    fi
    ;;

  # ── routes ───────────────────────────────────────────────────────
  routes)
    echo ""; echo -e "${BOLD}Routing Table:${RESET}"
    for K in "${!ROUTE_TABLE[@]}"; do echo "   $K → ${ROUTE_TABLE[$K]}"; done | sort
    echo ""
    ;;

  # ── oracle-health: Check Oracle health now ───────────────────────
  oracle-health)
    _init_health_file
    if check_oracle_and_mitigate; then
      ok "Oracle health check passed"
      cat "$ORACLE_HEALTH_FILE" 2>/dev/null
    else
      warning "Oracle health check failed"
      cat "$ORACLE_HEALTH_FILE" 2>/dev/null
    fi
    ;;

  # ── monitor-oracle: Manage background monitoring ─────────────────
  monitor-oracle)
    ACTION="${1:-status}"
    INTERVAL="${2:-60}"
    case "$ACTION" in
      start)
        _monitor_oracle_loop "$INTERVAL"
        ;;
      stop)
        _stop_oracle_monitor
        ;;
      status)
        _oracle_monitor_status
        ;;
      *)
        echo "Usage: heart.sh monitor-oracle {start|stop|status} [interval]"
        echo "  start [interval]  — Start monitoring (default: 60s)"
        echo "  stop              — Stop monitoring"
        echo "  status            — Show monitor and health status"
        ;;
    esac
    ;;

  # ── read-health: Read health file content ────────────────────────
  read-health)
    if [ -f "$ORACLE_HEALTH_FILE" ]; then
      cat "$ORACLE_HEALTH_FILE"
    else
      echo '{"status":"unknown","error":"No health data available"}'
    fi
    ;;

  # ── memory-size: Report shared memory size (JIT-016) ─────────────
  memory-size)
    init_shared_memory
    size=$(get_shared_memory_size)
    echo "$size"
    ;;

  # ── memory-prune: Manually trigger prune ─────────────────────────
  memory-prune)
    init_shared_memory
    prune_shared_memory
    size=$(get_shared_memory_size)
    ok "Shared memory pruned. Current size: $size entries"
    ;;

  # ── anomaly-status: Show JIT-024 anomaly detection status ─────────
  anomaly-status)
    echo ""
    echo -e "${BOLD}${CYAN}[ Pran Anomaly Detection Status (JIT-024) ]${RESET}"
    echo -e "   Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Baseline status
    echo -e "${BOLD}Baseline Status:${RESET}"
    if [ -f "$BASELINE_FILE" ]; then
      python3 - "$BASELINE_FILE" << 'PYEOF'
import json
import sys

baseline = json.load(open(sys.argv[1]))
collected = baseline.get("collected", 0)
completed = baseline.get("completed_at")
created = baseline.get("created_at", "unknown")

if completed:
    print(f"   Status: Complete ({collected}/5 samples)")
    print(f"   Completed at: {completed}")
    print(f"   Agents tracked: {len(baseline.get('agents', {}))}")
else:
    print(f"   Status: Collecting... ({collected}/5 samples)")
    print(f"   Started at: {created}")
PYEOF
    else
      echo "   Status: Not initialized (run heartbeat to collect)"
    fi
    echo ""

    # Anomaly log summary
    echo -e "${BOLD}Recent Anomalies:${RESET}"
    if [ -f "$ANOMALY_LOG" ]; then
      total_anomalies=$(wc -l < "$ANOMALY_LOG" 2>/dev/null || echo "0")
      echo "   Total logged: $total_anomalies"

      # Show last 5 anomalies
      tail -5 "$ANOMALY_LOG" 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    if line.strip():
        a = json.loads(line)
        print(f\"   [{a.get('severity','?').upper()}] {a.get('agent','?')}: {a.get('type','?')} @ {a.get('timestamp','?')}\")
" 2>/dev/null
    else
      echo "   No anomalies logged yet"
    fi
    echo ""

    log_action "PRAN_ANOMALY_STATUS" "viewed"
    ;;

  *)
    echo "Usage: heart.sh {beat|rate|pump|rhythm|routes|oracle-health|monitor-oracle|read-health|memory-size|memory-prune|anomaly-status}"
    echo ""
    echo "  beat {in|out|cycle}   — เต้นหัวใจ IN / OUT / ทั้งคู่"
    echo "  rate {sprint|fast|normal|slow|rest} — ขอเปลี่ยน rate"
    echo "  pump <type> <..>      — route task ไปยัง organ"
    echo "  rhythm                — vital signs dashboard"
    echo "  routes                — routing table"
    echo "  oracle-health         — Check Oracle health now"
    echo "  monitor-oracle        — Manage background monitoring"
    echo "  read-health           — Read health file JSON"
    echo "  memory-size           — Report shared memory size"
    echo "  memory-prune          — Manually prune shared memory"
    echo "  anomaly-status        — JIT-024 anomaly detection status"
    ;;
esac
