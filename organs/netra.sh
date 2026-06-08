#!/usr/bin/env bash
# organs/netra.sh — เนตร (Eye/Observer): เฝ้ามอง สังเกต แจ้งเตือน
#
# หลักพุทธ: สัมปชัญญะ (Awareness) — รู้ตัวอยู่ตลอดเวลา
# บทบาท multiagent: Observer, Monitor, Anomaly Detector
#
# Usage:
#   ./netra.sh eye-check              — Check registry health + slow paths (>1s latency)
#   ./netra.sh health-report          — Generate health report for all agents
#   ./netra.sh anomaly-detect         — Detect anomalies in system behavior
#   ./netra.sh watch <agent>          — Watch specific agent status
#   ./netra.sh trace-analysis         — Analyze message trace latencies, detect slow paths
#   ./netra.sh status                 — Show netra status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-eye-check}"
shift || true

REGISTRY="$JIT_ROOT/network/registry.json"
BUS_ROOT="/tmp/manusat-bus"
NETRA_LOG="/tmp/manusat-netra.log"
OFFLINE_THRESHOLD=300  # 5 minutes in seconds

# ── Helper: Parse ISO8601 timestamp to epoch ────────────────────────
_parse_timestamp() {
  local ts="$1"
  if [ -z "$ts" ] || [ "$ts" = "null" ]; then
    echo "0"
    return
  fi
  # Try to parse ISO8601 format (e.g., 2026-06-07T12:00:00+07:00)
  date -d "$ts" +%s 2>/dev/null || echo "0"
}

# ── Helper: Get current time in epoch ───────────────────────────────
_now_epoch() {
  date +%s
}

# ── eye-check: Check registry health, flag offline agents ───────────
eye_check() {
  local now=$(_now_epoch)
  local threshold="${OFFLINE_THRESHOLD:-300}"
  local BUS_METRICS_FILE="/tmp/manusat-bus-metrics.json"
  local ANOMALY_LOG="/tmp/manusat-anomalies.jsonl"
  local BASELINE_FILE="/tmp/manusat-baseline.json"

  echo ""
  echo -e "${BOLD}${CYAN}[ Netra Eye-Check — Agent Health Status ]${RESET}"
  echo -e "   Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo -e "   Offline Threshold: ${threshold}s (${threshold}/60 min)"
  echo ""

  # JIT-024: Include anomaly summary in health report
  echo -e "${BOLD}${CYAN}[ Anomaly Summary (JIT-024) ]${RESET}"
  if [ -f "$BASELINE_FILE" ]; then
    python3 - "$BASELINE_FILE" "$ANOMALY_LOG" << 'PYEOF'
import json
import sys
import os
from datetime import datetime, timedelta

baseline_file = sys.argv[1]
anomaly_log = sys.argv[2]

try:
    with open(baseline_file, 'r') as f:
        baseline = json.load(f)
except:
    print("   Baseline: Not yet collected (need 5 heartbeats)")
    baseline = None

if baseline:
    collected = baseline.get("collected", 0)
    completed = baseline.get("completed_at")
    if completed:
        print(f"   Baseline: Complete ({collected}/5 samples)")
        print(f"   Agents tracked: {len(baseline.get('agents', {}))}")
    else:
        print(f"   Baseline: Collecting... ({collected}/5 samples)")

# Count recent anomalies (last 10 minutes)
anomaly_counts = {"critical": 0, "high": 0, "medium": 0, "low": 0}
recent_anomalies = []
cutoff = datetime.now() - timedelta(minutes=10)

if os.path.exists(anomaly_log):
    try:
        with open(anomaly_log, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    a = json.loads(line)
                    severity = a.get("severity", "low")
                    anomaly_counts[severity] = anomaly_counts.get(severity, 0) + 1

                    # Check if recent
                    ts_str = a.get("timestamp", "")
                    if ts_str:
                        try:
                            ts = datetime.fromisoformat(ts_str.replace("+07:00", "+07:00"))
                            if ts > cutoff:
                                recent_anomalies.append(a)
                        except:
                            pass
                except:
                    pass
    except:
        pass

total_anomalies = sum(anomaly_counts.values())
print(f"   Total anomalies logged: {total_anomalies}")
print(f"   Recent (10 min): Critical={anomaly_counts['critical']}, High={anomaly_counts['high']}, Medium={anomaly_counts['medium']}, Low={anomaly_counts['low']}")

if recent_anomalies:
    print("")
    print("   Recent anomalies:")
    for a in recent_anomalies[-5:]:  # Show last 5
        print(f"      [{a.get('severity', '?').upper()}] {a.get('agent', '?')}: {a.get('type', '?')}")
PYEOF
  else
    echo "   Baseline: Not initialized"
  fi
  echo ""

  # JIT-018: Include bus metrics in health report
  echo -e "${BOLD}${CYAN}[ Bus Metrics Summary ]${RESET}"
  if [ -f "$BUS_METRICS_FILE" ]; then
    python3 - "$BUS_METRICS_FILE" << 'PYEOF'
import json
import sys

metrics_file = sys.argv[1]

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)

    totals = metrics.get('totals', {})
    print(f"   Messages Sent:     {totals.get('sent', 0)}")
    print(f"   Messages Received: {totals.get('received', 0)}")
    print(f"   Messages Failed:   {totals.get('failed', 0)}")
    print(f"   Messages Expired:  {totals.get('expired', 0)}")
    print(f"   DLQ Depth:         {totals.get('dlq_depth', 0)}")
    print(f"   Last Updated:      {metrics.get('updated_at', 'N/A')}")
except Exception as e:
    print(f"   Unable to read metrics: {e}")
PYEOF
  else
    echo "   No metrics data available yet"
  fi
  echo ""

  if [ ! -f "$REGISTRY" ]; then
    err "Registry not found: $REGISTRY"
    exit 1
  fi

  # Read registry and check each agent
  python3 - "$REGISTRY" "$BUS_ROOT" "$now" "$threshold" << 'PYEOF'
import json
import sys
import os
from datetime import datetime

registry_path = sys.argv[1]
bus_root = sys.argv[2]
now = int(sys.argv[3])
threshold = int(sys.argv[4])

with open(registry_path, 'r', encoding='utf-8') as f:
    registry = json.load(f)

agents = registry.get('agents', [])
offline_agents = []
degraded_agents = []
healthy_agents = []

print(f"   Total Agents: {len(agents)}")
print("")

for agent in agents:
    name = agent.get('name', 'unknown')
    health_status = agent.get('health_status', 'unknown')
    last_heartbeat = agent.get('last_heartbeat')
    response_time = agent.get('response_time_ms')
    queue_depth = agent.get('message_queue_depth', 0)

    # Check inbox for actual pending messages
    inbox_path = os.path.join(bus_root, name)
    pending_count = 0
    if os.path.isdir(inbox_path):
        pending_count = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])

    # Determine if offline based on last_heartbeat
    is_offline = False
    seconds_since_heartbeat = None

    if last_heartbeat and last_heartbeat != 'null':
        try:
            # Parse ISO8601 timestamp
            hb_time = datetime.fromisoformat(last_heartbeat.replace('+07:00', '+07:00'))
            hb_epoch = int(hb_time.timestamp())
            seconds_since_heartbeat = now - hb_epoch
            if seconds_since_heartbeat > threshold:
                is_offline = True
        except:
            pass
    else:
        # No heartbeat recorded yet
        is_offline = True
        seconds_since_heartbeat = None

    # Build status line
    if is_offline:
        status_icon = "\U0001F534"  # Red circle - offline
        status_text = "OFFLINE"
        offline_agents.append((name, seconds_since_heartbeat))
    elif health_status == 'degraded':
        status_icon = "\U0001F7E0"  # Orange circle - degraded
        status_text = "DEGRADED"
        degraded_agents.append((name, response_time, queue_depth))
    else:
        status_icon = "\U0001F7E2"  # Green circle - healthy
        status_text = "OK"
        healthy_agents.append((name, response_time, queue_depth))

    # Format last heartbeat display
    if seconds_since_heartbeat is not None:
        hb_display = f"{seconds_since_heartbeat}s ago"
    else:
        hb_display = "never"

    print(f"   {status_icon} {name:20s} | {status_text:8s} | HB: {hb_display:15s} | Queue: {pending_count}")

print("")
print(f"   {chr(0x1F7E2)} Healthy:  {len(healthy_agents)}")
print(f"   {chr(0x1F7E0)} Degraded: {len(degraded_agents)}")
print(f"   {chr(0x1F534)} Offline:  {len(offline_agents)}")
print("")

# Alert on offline agents
if offline_agents:
    print(f"   {chr(0x1F6A8)}{chr(0x1F6A8)}{chr(0x1F6A8)} ALERT: Offline Agents (>5 min) {chr(0x1F6A8)}{chr(0x1F6A8)}{chr(0x1F6A8)}")
    print("")
    for name, secs in offline_agents:
        if secs is not None:
            mins = secs // 60
            print(f"      - {name}: offline for {mins} min ({secs}s)")
        else:
            print(f"      - {name}: no heartbeat recorded")
    print("")

    # Emit alert to message bus
    offline_names = ", ".join([a[0] for a in offline_agents])
    print(f"   Broadcasting alert for: {offline_names}")
PYEOF

  # Emit alert via bus if any agents offline
  python3 - "$REGISTRY" "$BUS_ROOT" "$now" "$threshold" << 'PYEOF' 2>/dev/null
import json
import subprocess
import os
from datetime import datetime

registry_path = sys.argv[1]
bus_root = sys.argv[2]
now = int(sys.argv[3])
threshold = int(sys.argv[4])

with open(registry_path, 'r', encoding='utf-8') as f:
    registry = json.load(f)

offline_agents = []
for agent in registry.get('agents', []):
    name = agent.get('name', 'unknown')
    last_heartbeat = agent.get('last_heartbeat')

    if last_heartbeat and last_heartbeat != 'null':
        try:
            hb_time = datetime.fromisoformat(last_heartbeat.replace('+07:00', '+07:00'))
            hb_epoch = int(hb_time.timestamp())
            if now - hb_epoch > threshold:
                offline_agents.append(name)
        except:
            pass
    else:
        offline_agents.append(name)

if offline_agents:
    # Send alert to jit (master orchestrator)
    bus_script = os.path.join(os.path.dirname(registry_path), '..', 'network', 'bus.sh')
    if os.path.exists(bus_script):
        offline_list = ", ".join(offline_agents)
        subprocess.run([
            'bash', bus_script, 'send', 'jit', 'alert:offline-agents',
            f'Netra detected offline agents: {offline_list}'
        ], capture_output=True)
PYEOF

  log_action "NETRA_EYE_CHECK" "completed"
}

# ── trace-analysis: Analyze message trace latencies ──────────────────
trace_analysis() {
  echo ""
  echo -e "${BOLD}${CYAN}[ Netra Trace Analysis — Slow Path Detection ]${RESET}"
  echo -e "   Threshold: ${SLOW_THRESHOLD_MS:-1000}ms (1 second)"
  echo -e "   Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  python3 << 'PYEOF'
import os
import glob
from datetime import datetime
from collections import defaultdict

bus_root = "/tmp/manusat-bus"
threshold_ms = 1000  # 1 second

slow_paths = []
all_latencies = []
pair_latencies = defaultdict(list)

# Scan all messages for trace data
for pattern in ["*.msg", "*.read"]:
    for msg_file in glob.glob(os.path.join(bus_root, "*", pattern)):
        if not os.path.isfile(msg_file):
            continue

        metadata = {}
        with open(msg_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line == "---":
                    break
                if ":" in line:
                    key, value = line.split(":", 1)
                    metadata[key] = value.strip()

        trace_chain = metadata.get("trace-chain", "")
        timestamp_chain = metadata.get("timestamp_chain", "")

        if trace_chain and timestamp_chain and "→" in trace_chain:
            agents = trace_chain.split("→")
            timestamps = timestamp_chain.split(",")

            for i in range(len(agents) - 1):
                from_agent = agents[i]
                to_agent = agents[i + 1]

                try:
                    t1 = datetime.fromisoformat(timestamps[i])
                    t2 = datetime.fromisoformat(timestamps[i + 1])
                    latency_ms = (t2 - t1).total_seconds() * 1000

                    all_latencies.append(latency_ms)
                    pair_latencies[f"{from_agent}→{to_agent}"].append(latency_ms)

                    if latency_ms > threshold_ms:
                        slow_paths.append({
                            "from": from_agent,
                            "to": to_agent,
                            "latency_ms": latency_ms,
                            "correlation_id": metadata.get("correlation-id", "unknown"),
                            "subject": metadata.get("subject", "unknown"),
                            "timestamp": timestamps[i + 1]
                        })
                except:
                    pass

# Report slow paths
if slow_paths:
    print(f"   ⚠️  SLOW PATHS DETECTED: {len(slow_paths)}")
    print("")
    for path in sorted(slow_paths, key=lambda x: x["latency_ms"], reverse=True)[:10]:
        print(f"   \U0001F40C {path['from']} → {path['to']}")
        print(f"      latency: {path['latency_ms']:.1f}ms")
        print(f"      subject: {path['subject']}")
        print(f"      correlation-id: {path['correlation_id']}")
        print("")
else:
    print(f"   ✓ No slow paths detected (>{threshold_ms}ms)")

# Latency summary by agent pair
print("")
print(f"   ─────────────────────────────────────────")
print(f"   │ Latency Summary by Agent Pair │")
print(f"   ─────────────────────────────────────────")

if pair_latencies:
    for pair, latencies in sorted(pair_latencies.items()):
        avg_latency = sum(latencies) / len(latencies)
        max_latency = max(latencies)
        min_latency = min(latencies)
        sample_count = len(latencies)
        status = "⚠️ SLOW" if avg_latency > threshold_ms else "✓"
        print(f"   {status} {pair}: avg={avg_latency:.1f}ms min={min_latency:.1f}ms max={max_latency:.1f}ms (n={sample_count})")
else:
    print("   No trace data available yet")

# Overall statistics
if all_latencies:
    print("")
    avg_latency = sum(all_latencies) / len(all_latencies)
    max_latency = max(all_latencies)
    min_latency = min(all_latencies)
    total_hops = len(all_latencies)

    print(f"   ─────────────────────────────────────────")
    print(f"   │ Overall Statistics │")
    print(f"   ─────────────────────────────────────────")
    print(f"   Total hops analyzed: {total_hops}")
    print(f"   Average latency: {avg_latency:.1f}ms")
    print(f"   Min latency: {min_latency:.1f}ms")
    print(f"   Max latency: {max_latency:.1f}ms")
PYEOF

  log_action "NETRA_TRACE_ANALYSIS" "slow_path_detection"
}

# ── health-report: Generate detailed health report ──────────────────
health_report() {
  echo ""
  echo -e "${BOLD}${CYAN}[ Netra Health Report ]${RESET}"
  echo -e "   Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  if [ ! -f "$REGISTRY" ]; then
    err "Registry not found: $REGISTRY"
    exit 1
  fi

  # Generate detailed report
  python3 - "$REGISTRY" "$BUS_ROOT" << 'PYEOF'
import json
import sys
import os
from datetime import datetime

registry_path = sys.argv[1]
bus_root = sys.argv[2]

with open(registry_path, 'r', encoding='utf-8') as f:
    registry = json.load(f)

print("## Registry Health Summary")
print(f"- Version: {registry.get('version', 'unknown')}")
print(f"- System: {registry.get('system', 'unknown')}")
print(f"- Updated: {registry.get('updated', 'unknown')}")
print("")

health_config = registry.get('health_tracking', {})
print("## Health Tracking Configuration")
print(f"- Enabled: {health_config.get('enabled', False)}")
print(f"- Offline Threshold: {health_config.get('offline_threshold_seconds', 300)}s")
print("")

print("## Agent Details")
print("")

for agent in registry.get('agents', []):
    name = agent.get('name', 'unknown')
    organ = agent.get('organ', 'unknown')
    health_status = agent.get('health_status', 'unknown')
    last_heartbeat = agent.get('last_heartbeat', 'never')
    response_time = agent.get('response_time_ms', 'N/A')
    queue_depth = agent.get('message_queue_depth', 0)

    # Get actual inbox depth
    inbox_path = os.path.join(bus_root, name)
    actual_pending = 0
    if os.path.isdir(inbox_path):
        actual_pending = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])

    print(f"### {name} ({organ})")
    print(f"- Health Status: {health_status}")
    print(f"- Last Heartbeat: {last_heartbeat}")
    print(f"- Response Time: {response_time}ms")
    print(f"- Queue Depth (tracked): {queue_depth}")
    print(f"- Queue Depth (actual): {actual_pending}")
    print("")
PYEOF

  # JIT-018: Include bus metrics in health report
  echo ""
  echo -e "${BOLD}${CYAN}[ Bus Metrics ]${RESET}"
  local BUS_METRICS_FILE="/tmp/manusat-bus-metrics.json"
  if [ -f "$BUS_METRICS_FILE" ]; then
    python3 - "$BUS_METRICS_FILE" << 'PYEOF'
import json
import sys

metrics_file = sys.argv[1]

try:
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)

    totals = metrics.get('totals', {})
    print(f"   Total Sent:     {totals.get('sent', 0)}")
    print(f"   Total Received: {totals.get('received', 0)}")
    print(f"   Total Failed:   {totals.get('failed', 0)}")
    print(f"   Total Expired:  {totals.get('expired', 0)}")
    print(f"   DLQ Depth:      {totals.get('dlq_depth', 0)}")
    print(f"   Updated:        {metrics.get('updated_at', 'N/A')}")

    # Check for per-agent anomalies
    anomalies = []
    for agent_name, agent_metrics in metrics.get('agents', {}).items():
        if agent_metrics.get('failed', 0) > 5:
            anomalies.append(f"{agent_name}: {agent_metrics['failed']} failed messages")
        if agent_metrics.get('dlq_depth', 0) > 5:
            anomalies.append(f"{agent_name}: DLQ depth {agent_metrics['dlq_depth']}")

    if anomalies:
        print("")
        print("   ⚠️  Metrics Anomalies:")
        for a in anomalies:
            print(f"      - {a}")
except Exception as e:
    print(f"   Unable to read metrics: {e}")
PYEOF
  else
    echo "   No metrics data available yet"
  fi
  echo ""

  log_action "NETRA_HEALTH_REPORT" "generated"
}

# ── anomaly-detect: Detect anomalies in system ──────────────────────
anomaly_detect() {
  echo ""
  echo -e "${BOLD}${CYAN}[ Netra Anomaly Detection ]${RESET}"
  echo ""

  local anomalies_found=0

  # Check for agents with high response times
  if [ -f "$REGISTRY" ]; then
    python3 - "$REGISTRY" << 'PYEOF'
import json
import sys

registry_path = sys.argv[1]

with open(registry_path, 'r', encoding='utf-8') as f:
    registry = json.load(f)

anomalies = []

for agent in registry.get('agents', []):
    name = agent.get('name', 'unknown')
    response_time = agent.get('response_time_ms')
    health_status = agent.get('health_status', 'unknown')

    # High response time anomaly (>500ms)
    if response_time and response_time > 500:
        anomalies.append(f"HIGH_LATENCY: {name} response time {response_time}ms > 500ms")

    # Degraded status anomaly
    if health_status == 'degraded':
        anomalies.append(f"DEGRADED: {name} marked as degraded")

    # Offline status anomaly
    if health_status == 'offline':
        anomalies.append(f"OFFLINE: {name} marked as offline")

if anomalies:
    print(f"   Found {len(anomalies)} anomalies:")
    print("")
    for a in anomalies:
        print(f"      ! {a}")
    print("")
else:
    print("   No anomalies detected")
    print("")
PYEOF
  fi

  # Check DLQ depth
  local dlq_depth=$(find /tmp/manusat-bus/_dlq -name "*.msg" 2>/dev/null | wc -l)
  if [ "$dlq_depth" -gt 10 ]; then
    echo "      ! DLQ_DEPTH: Dead Letter Queue has $dlq_depth messages (threshold: 10)"
    ((anomalies_found++))
  fi

  # Check for old messages in inboxes (>100 pending)
  for inbox in /tmp/manusat-bus/*/; do
    [ -d "$inbox" ] || continue
    agent=$(basename "$inbox")
    pending=$(find "$inbox" -name "*.msg" 2>/dev/null | wc -l)
    if [ "$pending" -gt 100 ]; then
      echo "      ! QUEUE_BACKLOG: $agent has $pending pending messages"
      ((anomalies_found++))
    fi
  done

  if [ "$anomalies_found" -eq 0 ]; then
    ok "No system anomalies detected"
  fi

  log_action "NETRA_ANOMALY_DETECT" "completed anomalies=$anomalies_found"
}

# ── watch: Watch specific agent status ──────────────────────────────
watch_agent() {
  local AGENT="$1"

  if [ -z "$AGENT" ]; then
    err "Usage: netra.sh watch <agent-name>"
    exit 1
  fi

  echo ""
  echo -e "${BOLD}${CYAN}[ Watching Agent: $AGENT ]${RESET}"
  echo -e "   Press Ctrl+C to stop"
  echo ""

  while true; do
    clear
    echo -e "${BOLD}${CYAN}[ Netra Watch: $AGENT ]${RESET}"
    echo -e "   Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if [ -f "$REGISTRY" ]; then
      python3 - "$REGISTRY" "$AGENT" << 'PYEOF'
import json
import sys
import os

registry_path = sys.argv[1]
target_agent = sys.argv[2]

with open(registry_path, 'r', encoding='utf-8') as f:
    registry = json.load(f)

for agent in registry.get('agents', []):
    if agent.get('name') == target_agent:
        print(f"Name:           {agent.get('name')}")
        print(f"Organ:          {agent.get('organ')}")
        print(f"Health Status:  {agent.get('health_status')}")
        print(f"Last Heartbeat: {agent.get('last_heartbeat')}")
        print(f"Response Time:  {agent.get('response_time_ms')}ms")
        print(f"Queue Depth:    {agent.get('message_queue_depth')}")

        # Check actual inbox
        inbox = os.path.join('/tmp/manusat-bus', target_agent)
        if os.path.isdir(inbox):
            pending = len([f for f in os.listdir(inbox) if f.endswith('.msg')])
            print(f"Pending Msgs:   {pending}")
        break
else:
    print(f"Agent '{target_agent}' not found in registry")
PYEOF
    fi

    sleep 2
  done
}

# ── anomaly-summary: Show JIT-024 anomaly summary ───────────────────
anomaly_summary() {
  local ANOMALY_LOG="/tmp/manusat-anomalies.jsonl"
  local BASELINE_FILE="/tmp/manusat-baseline.json"

  echo ""
  echo -e "${BOLD}${CYAN}[ Netra Anomaly Summary (JIT-024) ]${RESET}"
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

if completed:
    print(f"   Status: Complete ({collected}/5 samples)")
    print(f"   Agents tracked: {len(baseline.get('agents', {}))}")
else:
    print(f"   Status: Collecting... ({collected}/5 samples)")
PYEOF
  else
    echo "   Status: Not initialized"
  fi
  echo ""

  # Anomaly log summary
  echo -e "${BOLD}Anomaly Log:${RESET}"
  if [ -f "$ANOMALY_LOG" ]; then
    python3 - "$ANOMALY_LOG" << 'PYEOF'
import json
import sys
from collections import defaultdict
from datetime import datetime, timedelta

anomaly_log = sys.argv[1]
cutoff = datetime.now() - timedelta(minutes=10)

counts = defaultdict(int)
by_agent = defaultdict(int)
by_type = defaultdict(int)
recent = []

with open(anomaly_log, 'r') as f:
    for line in f:
        if not line.strip():
            continue
        try:
            a = json.loads(line)
            counts[a.get('severity', 'unknown')] += 1
            by_agent[a.get('agent', 'unknown')] += 1
            by_type[a.get('type', 'unknown')] += 1

            ts_str = a.get('timestamp', '')
            if ts_str:
                try:
                    ts = datetime.fromisoformat(ts_str.replace('+07:00', '+07:00'))
                    if ts > cutoff:
                        recent.append(a)
                except:
                    pass
        except:
            pass

total = sum(counts.values())
print(f"   Total anomalies: {total}")
print(f"   By severity: Critical={counts['critical']}, High={counts['high']}, Medium={counts['medium']}, Low={counts['low']}")
print("")
print(f"   By type: {dict(by_type)}")
print(f"   By agent: {dict(by_agent)}")

if recent:
    print("")
    print("   Recent (last 10 min):")
    for a in recent[-5:]:
        print(f"      [{a.get('severity', '?').upper()}] {a.get('agent', '?')}: {a.get('type', '?')}")
PYEOF
  else
    echo "   No anomalies logged yet"
  fi
  echo ""

  log_action "NETRA_ANOMALY_SUMMARY" "viewed"
}

# ── status: Show netra status ───────────────────────────────────────
show_status() {
  ok "เนตร (netra) — Observer/Monitor ready"
  echo ""
  echo "   Capabilities:"
  echo "   - eye-check          : Check all agents health, flag offline >5 min"
  echo "   - health-report      : Generate detailed health report"
  echo "   - anomaly-detect     : Detect system anomalies"
  echo "   - anomaly-summary    : JIT-024 anomaly summary (baseline + logs)"
  echo "   - watch <agent>      : Watch specific agent status"
  echo "   - trace-analysis     : Analyze message trace latencies, detect slow paths >1s"
  echo "   - status             : Show this help"
  echo ""
}

case "$CMD" in
  eye-check)
    eye_check
    ;;
  health-report)
    health_report
    ;;
  anomaly-detect)
    anomaly_detect
    ;;
  anomaly-summary)
    anomaly_summary
    ;;
  trace-analysis)
    trace_analysis
    ;;
  watch)
    watch_agent "$@"
    ;;
  status|help|*)
    show_status
    ;;
esac
