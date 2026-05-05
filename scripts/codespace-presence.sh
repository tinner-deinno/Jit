#!/usr/bin/env bash
# scripts/codespace-presence.sh
# Purpose: report all-agent status and knowledge history for Codespaces startup.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_FILE="$JIT_ROOT/network/registry.json"
STATE_FILE="$JIT_ROOT/memory/state/innova.state.json"
HEARTBEAT_LOG="$JIT_ROOT/memory/state/heartbeat.log"
REPORT_FILE="$JIT_ROOT/memory/state/jit-presence-report.md"
CONTEXT_INDEX_FILE="$JIT_ROOT/memory/state/context.index.json"
QUIET=0

for ARG in "$@"; do
  case "$ARG" in
    --write-report)
      :
      ;;
    --report-file=*)
      REPORT_FILE="${ARG#*=}"
      ;;
    --quiet)
      QUIET=1
      ;;
  esac
done

if [ -f "$JIT_ROOT/.env" ]; then
  set -a
  . "$JIT_ROOT/.env"
  set +a
fi

ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
MODEL_NAME="${COPILOT_CHAT_MODEL:-GPT-5.3-Codex}"
NOW_ISO="$(date '+%Y-%m-%dT%H:%M:%S')"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$CONTEXT_INDEX_FILE")"

if [ ! -f "$CONTEXT_INDEX_FILE" ]; then
  cat > "$CONTEXT_INDEX_FILE" <<EOF
{
  "created_at": "${NOW_ISO}",
  "source": "scripts/codespace-presence.sh",
  "description": "Context index for Jit startup reporting",
  "core_context": [
    "core/identity.md",
    "mind/ego.md",
    "brain/reasoning.md",
    "network/protocol.md",
    "memory/architecture.md"
  ]
}
EOF
fi

ORACLE_HEALTH="$(curl -sf --max-time 5 "$ORACLE_URL/api/health" 2>/dev/null || true)"
ORACLE_STATUS="offline"
if echo "$ORACLE_HEALTH" | grep -q '"status":"ok"'; then
  ORACLE_STATUS="online"
fi

ORACLE_DOCS="0"
if [ "$ORACLE_STATUS" = "online" ]; then
  ORACLE_DOCS="$(curl -sf --max-time 5 "$ORACLE_URL/api/stats" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('totalDocuments', d.get('total', 0)))" 2>/dev/null || echo 0)"
fi

OLLAMA_STATUS="offline"
if curl -sf --max-time 8 "$OLLAMA_URL/api/tags" -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" 2>/dev/null | grep -q '"models"'; then
  OLLAMA_STATUS="online"
fi

RAG_ROWS=""
if [ "$ORACLE_STATUS" = "online" ]; then
  for TOPIC in innova anatomy oracle heartbeat ollama; do
    ENCODED_TOPIC="$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TOPIC'))" 2>/dev/null)"
    TOPIC_COUNT="$(curl -sf --max-time 5 "$ORACLE_URL/api/search?q=$ENCODED_TOPIC" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('results', [])))" 2>/dev/null || echo 0)"
    RAG_ROWS+="| $TOPIC | $TOPIC_COUNT |"
    RAG_ROWS+=$'\n'
  done
else
  RAG_ROWS="| unavailable | 0 |"
fi

MCP_SIGNAL_COUNT="$(rg -n "mcp_innovabot_" "$JIT_ROOT" --glob '!node_modules' --glob '!.git' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${MCP_SIGNAL_COUNT:-0}" -gt 0 ]; then
  MCP_STATUS="configured"
else
  MCP_STATUS="not-detected"
fi

HEARTBEAT_DAEMON="stopped"
if bash "$JIT_ROOT/scripts/heartbeat.sh" status 2>/dev/null | grep -q 'Heartbeat กำลังรัน'; then
  HEARTBEAT_DAEMON="running"
fi

CRON_STATUS="missing"
if command -v crontab >/dev/null 2>&1 && crontab -l 2>/dev/null | grep -q 'heartbeat.sh once'; then
  CRON_STATUS="installed"
fi

LAST_HEARTBEAT="unknown"
PULSE_COUNT="0"
HB_AGE_MIN="unknown"
if [ -f "$STATE_FILE" ]; then
  LAST_HEARTBEAT="$(python3 - <<PY
import json
try:
  d=json.load(open('$STATE_FILE'))
  print(d.get('vitality',{}).get('last_heartbeat','unknown'))
except Exception:
  print('unknown')
PY
)"
  PULSE_COUNT="$(python3 - <<PY
import json
try:
  d=json.load(open('$STATE_FILE'))
  print(d.get('vitality',{}).get('pulse_count',0))
except Exception:
  print(0)
PY
)"
  HB_AGE_MIN="$(python3 - <<PY
from datetime import datetime
import json
try:
  d=json.load(open('$STATE_FILE'))
  ts=d.get('vitality',{}).get('last_heartbeat')
  if not ts:
    print('unknown')
  else:
    dt=datetime.strptime(ts, '%Y-%m-%dT%H:%M:%S')
    now=datetime.now()
    print(max(0, int((now-dt).total_seconds() // 60)))
except Exception:
  print('unknown')
PY
)"
fi

AGENT_TABLE="$(python3 - <<PY
import json, os, glob
reg='$REGISTRY_FILE'
rows=[]
total=0
ready=0
active=0
if os.path.exists(reg):
  d=json.load(open(reg))
  for a in d.get('agents', []):
    total += 1
    name=a.get('name','unknown')
    role=a.get('role','-')
    born=a.get('born','-')
    status=a.get('status','unknown')
    if status == 'active':
      active += 1
    inbox=f"/tmp/manusat-bus/{name}"
    inbox_ok=os.path.isdir(inbox)
    queue_count=len(glob.glob(os.path.join(inbox, '*.msg'))) if inbox_ok else 0
    ready_mark='ready' if (status == 'active' and inbox_ok) else 'degraded'
    if ready_mark == 'ready':
      ready += 1
    rows.append((name, role, status, born, 'yes' if inbox_ok else 'no', queue_count, ready_mark))

print(f"TOTAL={total}")
print(f"ACTIVE={active}")
print(f"READY={ready}")
print('ROWS_BEGIN')
for r in rows:
  print('| ' + ' | '.join(str(x).replace('|','/') for x in r) + ' |')
PY
)"

AGENT_TOTAL="$(echo "$AGENT_TABLE" | awk -F= '/^TOTAL=/{print $2}')"
AGENT_ACTIVE="$(echo "$AGENT_TABLE" | awk -F= '/^ACTIVE=/{print $2}')"
AGENT_READY="$(echo "$AGENT_TABLE" | awk -F= '/^READY=/{print $2}')"
AGENT_ROWS="$(echo "$AGENT_TABLE" | awk 'f{print} /^ROWS_BEGIN$/{f=1}')"

HISTORY_ROWS="$(python3 - <<PY
import os, glob, re, json
root='$JIT_ROOT'
rows=[]

# retrospectives timeline
for p in sorted(glob.glob(os.path.join(root, 'memory', 'retrospectives', '*', '*', '*.md'))):
  m=re.search(r'retrospectives/(\d{4}-\d{2})/(\d{2})/', p)
  date='unknown'
  if m:
    date=f"{m.group(1)}-{m.group(2)}"
  text=open(p, encoding='utf-8', errors='ignore').read()
  topic='retrospective'
  for line in text.splitlines():
    if line.startswith('# '):
      topic=line[2:].strip()
      break
  progress='in-progress'
  if '9/9' in text or 'fully alive' in text:
    progress='100%'
  elif '33/38' in text:
    progress='86%'
  elif '49 ไฟล์' in text or '49 files' in text:
    progress='70%'
  size_kb=round(os.path.getsize(p)/1024, 1)
  level='major'
  rows.append((date, topic, level, f"{size_kb} KB", progress, p.replace(root + '/', '')))

state_path=os.path.join(root, 'memory', 'state', 'innova.state.json')
if os.path.exists(state_path):
  d=json.load(open(state_path, encoding='utf-8'))
  pulse=d.get('vitality', {}).get('pulse_count', 0)
  last=d.get('vitality', {}).get('last_heartbeat', 'unknown')
  rows.append((str(last).split('T')[0], 'heartbeat continuity', 'vital', str(pulse), 'running', 'memory/state/innova.state.json'))

hb_path=os.path.join(root, 'memory', 'state', 'heartbeat.log')
if os.path.exists(hb_path):
  lines=[ln for ln in open(hb_path, encoding='utf-8', errors='ignore').read().splitlines() if ln and not ln.startswith('#')]
  rows.append(('2026-04-25', 'heartbeat log entries', 'vital', str(len(lines)), 'tracked', 'memory/state/heartbeat.log'))

rows.sort(key=lambda x: x[0])
for r in rows:
  print('| ' + ' | '.join(str(x).replace('|','/') for x in r) + ' |')
PY
)"

cat > "$REPORT_FILE" <<EOF
# Jit Presence Report

Generated at: $NOW_ISO
Host: $(hostname)
GitHub Copilot Chat model (runtime): $MODEL_NAME

## Presence Declaration

I am innova, the mind/lead-developer layer of Manusat Agent (Jit).
I operate with: integrity, focus, wisdom.

## Runtime Connectivity

| Item | Status | Detail |
| --- | --- | --- |
| Oracle RAG | $ORACLE_STATUS | docs=$ORACLE_DOCS url=$ORACLE_URL |
| MDES Ollama | $OLLAMA_STATUS | url=$OLLAMA_URL |
| innova-bot MCP signals | $MCP_STATUS | matches=$MCP_SIGNAL_COUNT |
| Heartbeat daemon | $HEARTBEAT_DAEMON | pulse_interval=15m |
| Cron hook | $CRON_STATUS | target=scripts/heartbeat.sh once |
| Last heartbeat | $LAST_HEARTBEAT | age_min=$HB_AGE_MIN pulse_count=$PULSE_COUNT |

## Agent Status (All)

Summary: total=$AGENT_TOTAL active=$AGENT_ACTIVE ready=$AGENT_READY

| Agent | Role | Registry Status | Born | Inbox | Queue | Runtime |
| --- | --- | --- | --- | --- | --- | --- |
$AGENT_ROWS

## History Since Birth

| Date | Topic | Level | Size | Progress | Source |
| --- | --- | --- | --- | --- | --- |
$HISTORY_ROWS

## Memory Layers

| Layer | Location | Current State |
| --- | --- | --- |
| RAG long-term | Oracle ($ORACLE_URL) | $ORACLE_STATUS, docs=$ORACLE_DOCS |
| Repo context | memory/state/context.index.json | $( [ -f "$CONTEXT_INDEX_FILE" ] && echo "ready" || echo "missing" ) |
| Runtime context | memory/state/innova.state.json | pulse_count=$PULSE_COUNT |
| Event timeline | memory/state/heartbeat.log | tracked |

## RAG Knowledge Snapshot

| Topic | Results |
| --- | --- |
$RAG_ROWS

EOF

if [ "$QUIET" -eq 0 ]; then
  cat "$REPORT_FILE"
fi

echo "[codespace-presence] report generated: $REPORT_FILE"
exit 0