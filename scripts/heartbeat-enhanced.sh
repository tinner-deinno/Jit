#!/usr/bin/env bash
# scripts/heartbeat-enhanced.sh — 💓 Enhanced 24/7 Heartbeat with Discord & Ollama
# 
# Features:
#   ✅ Spawn MDES Ollama agents for work
#   ✅ Send results to Discord via hermes bot
#   ✅ Auto commit/push heartbeat branches
#   ✅ Monitor failures & recovery
#   ✅ Persistent state across beats

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

# Configuration
HEARTBEAT_COUNT="${HEARTBEAT_COUNT:-0}"
HEARTBEAT_LOG="/tmp/innova-heartbeat-enhanced.log"
HEARTBEAT_STATE="/tmp/innova-heartbeat-state.json"
HEARTBEAT_FAILED="/tmp/innova-heartbeat-failed.log"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
BUS_ROOT="${BUS_ROOT:-/tmp/manusat-bus}"
PULSE_INTERVAL="${PULSE_INTERVAL:-900}"
PID_FILE="/tmp/innova-heartbeat-enhanced.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ──────────────────────────────────────────────────────────────────────
# Functions
# ──────────────────────────────────────────────────────────────────────

log_beat() {
  local level="$1"
  local msg="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" | tee -a "$HEARTBEAT_LOG"
}

log_failure() {
  local msg="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] FAILURE: $msg" | tee -a "$HEARTBEAT_FAILED"
}

# Initialize heartbeat state
init_state() {
  if [ ! -f "$HEARTBEAT_STATE" ]; then
    cat > "$HEARTBEAT_STATE" <<EOF
{
  "beat_count": 0,
  "last_beat": null,
  "last_push": null,
  "failures": 0,
  "last_failure_reason": null,
  "consecutive_failures": 0,
  "status": "ready"
}
EOF
  fi
}

# Get state value
get_state() {
  local key="$1"
  python3 -c "import json; s=json.load(open('$HEARTBEAT_STATE')); print(s.get('$key', ''))" 2>/dev/null || echo ""
}

# Update state
update_state() {
  local key="$1"
  local value="$2"
  python3 <<EOF
import json
with open('$HEARTBEAT_STATE', 'r') as f:
    state = json.load(f)
state['$key'] = '$value'
with open('$HEARTBEAT_STATE', 'w') as f:
    json.dump(state, f, indent=2)
EOF
}

# Spawn MDES Ollama agent for summary work
spawn_ollama_agent() {
  local beat_num="$1"
  local task="$2"
  
  log_beat "INFO" "🤖 Spawning MDES Ollama agent #$beat_num: $task"
  
  python3 <<PYTHON
import os
import json
import subprocess
import sys
from pathlib import Path

OLLAMA_TOKEN = os.getenv('OLLAMA_TOKEN', '')
OLLAMA_URL = os.getenv('OLLAMA_URL', 'https://ollama.mdes-innova.online')

if not OLLAMA_TOKEN:
    env_file = Path('/workspaces/Jit/.env')
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith('OLLAMA_TOKEN='):
                OLLAMA_TOKEN = line.split('=', 1)[1].strip()
                break

if not OLLAMA_TOKEN:
    print("ERROR: OLLAMA_TOKEN not found")
    sys.exit(1)

prompt = """Heartbeat #${beat_num} - System Summary Request

${task}

Please provide:
1. Quick status of all 14 agents (1-2 lines each)
2. Any critical issues detected
3. Recommendation for next beat

Format: concise JSON response"""

payload = {
    'model': 'gemma4:26b',
    'prompt': prompt,
    'stream': False
}

try:
    result = subprocess.check_output([
        'curl', '-s', '--location', '--max-time', '60', '--connect-timeout', '20',
        f'{OLLAMA_URL}/api/generate',
        '--header', f'Authorization: Bearer {OLLAMA_TOKEN}',
        '--header', 'Content-Type: application/json',
        '--data', json.dumps(payload)
    ], stderr=subprocess.PIPE, timeout=65)
    
    response = json.loads(result.decode('utf-8'))
    if 'response' in response:
        print(response['response'])
    else:
        print("ERROR: No response from Ollama")
        sys.exit(1)
except Exception as e:
    print(f"ERROR: {str(e)}")
    sys.exit(1)
PYTHON
}

# Send to Discord via webhook
send_to_discord() {
  local beat_num="$1"
  local message="$2"
  local status="${3:-success}"
  
  if [ -z "$DISCORD_WEBHOOK" ]; then
    log_beat "WARN" "Discord webhook not configured"
    return 0
  fi
  
  local color="3066993"  # green
  if [ "$status" = "failure" ]; then
    color="15158332"  # red
  elif [ "$status" = "warning" ]; then
    color="16776960"  # yellow
  fi
  
  local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "💓 Heartbeat #$beat_num",
    "description": "$message",
    "color": $color,
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }]
}
EOF
)
  
  curl -s -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null 2>&1 || log_beat "WARN" "Discord send failed"
}

# Perform heartbeat IN (diastole) - gather data
heartbeat_in() {
  local beat_num=$(($(get_state beat_count) + 1))
  log_beat "INFO" "💓 IN (Diastole) - Beat #$beat_num starting..."
  
  # Spawn Ollama agent to gather system state
  local ollama_result=$(spawn_ollama_agent "$beat_num" "Gather current system state and agent status" 2>&1 || echo "OLLAMA_ERROR")
  
  if [[ "$ollama_result" == "OLLAMA_ERROR"* ]]; then
    log_failure "Ollama agent failed on beat $beat_num"
    update_state "consecutive_failures" "$(($(get_state consecutive_failures) + 1))"
    return 1
  fi
  
  # Save result
  mkdir -p /tmp/heartbeat-results
  echo "$ollama_result" > "/tmp/heartbeat-results/beat-$beat_num-in.txt"
  
  log_beat "INFO" "✅ IN complete"
  return 0
}

# Perform heartbeat OUT (systole) - send results
heartbeat_out() {
  local beat_num=$(get_state beat_count)
  log_beat "INFO" "❤️‍🔥 OUT (Systole) - Beat #$beat_num processing..."
  
  # Read previous IN result
  local result_file="/tmp/heartbeat-results/beat-$beat_num-in.txt"
  if [ ! -f "$result_file" ]; then
    log_failure "Missing result file: $result_file"
    return 1
  fi
  
  local in_result=$(cat "$result_file")
  
  # Send to Discord
  send_to_discord "$beat_num" "$in_result" "success"
  
  log_beat "INFO" "✅ OUT complete - sent to Discord"
  return 0
}

# Auto commit and push
auto_commit_push() {
  local beat_num=$(get_state beat_count)
  
  log_beat "INFO" "📤 Auto-committing beat #$beat_num..."
  
  cd "$JIT_ROOT"
  
  # Create heartbeat branch if needed
  local beat_branch="heartbeat-$beat_num"
  if ! git show-ref --quiet refs/heads/"$beat_branch"; then
    git checkout -b "$beat_branch" 2>&1 | tee -a "$HEARTBEAT_LOG"
  else
    git checkout "$beat_branch" 2>&1 | tee -a "$HEARTBEAT_LOG"
  fi
  
  # Add heartbeat artifacts
  mkdir -p "$JIT_ROOT/memory/heartbeats"
  cat > "$JIT_ROOT/memory/heartbeats/beat-$beat_num.md" <<EOF
# Heartbeat #$beat_num
- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Status: $(get_state status)
- Consecutive Failures: $(get_state consecutive_failures)

## Results
\`\`\`
$(cat /tmp/heartbeat-results/beat-$beat_num-in.txt)
\`\`\`
EOF
  
  git add "$JIT_ROOT/memory/heartbeats/beat-$beat_num.md" 2>&1 || true
  git add "$JIT_ROOT/memory/state/" 2>&1 || true
  
  # Commit
  git commit -m "💓 Heartbeat #$beat_num - auto commit on beat" 2>&1 || true
  
  # Push
  git push -u origin "$beat_branch" 2>&1 | tee -a "$HEARTBEAT_LOG"
  
  log_beat "INFO" "✅ Auto-push complete"
  update_state "last_push" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# Main heartbeat cycle
heartbeat_cycle() {
  init_state
  
  local beat_num=$(($(get_state beat_count) + 1))
  log_beat "INFO" "════════════════════════════════════════"
  log_beat "INFO" "🫀 Heartbeat Cycle #$beat_num START"
  
  # IN phase
  if ! heartbeat_in; then
    log_failure "Heartbeat IN failed on beat $beat_num"
    send_to_discord "$beat_num" "❌ Heartbeat IN failed" "failure"
    return 1
  fi
  
  # Update count
  update_state "beat_count" "$beat_num"
  update_state "last_beat" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  
  # OUT phase
  if ! heartbeat_out; then
    log_failure "Heartbeat OUT failed on beat $beat_num"
    send_to_discord "$beat_num" "❌ Heartbeat OUT failed" "failure"
    return 1
  fi
  
  # Auto-commit/push
  if ! auto_commit_push; then
    log_failure "Auto-commit/push failed on beat $beat_num"
  fi
  
  # Reset consecutive failures on success
  update_state "consecutive_failures" "0"
  update_state "status" "healthy"
  
  log_beat "INFO" "🫀 Heartbeat Cycle #$beat_num SUCCESS"
  log_beat "INFO" "════════════════════════════════════════"
  
  return 0
}

# Monitor heartbeat
monitor_heartbeat() {
  log_beat "INFO" "📊 Starting heartbeat monitor..."
  
  while true; do
    heartbeat_cycle || {
      consecutive_fails=$(get_state consecutive_failures)
      if [ "$consecutive_fails" -ge 3 ]; then
        log_beat "CRITICAL" "❌ 3+ consecutive failures - heartbeat DYING"
        send_to_discord "?" "❌ CRITICAL: Heartbeat failing consecutively" "failure"
      fi
    }
    
    log_beat "INFO" "💤 Sleeping for $PULSE_INTERVAL seconds..."
    sleep "$PULSE_INTERVAL"
  done
}

# Main CLI
main() {
  local cmd="${1:-once}"
  
  case "$cmd" in
    once)
      heartbeat_cycle
      ;;
    monitor|daemon)
      init_state
      echo $$ > "$PID_FILE"
      monitor_heartbeat
      ;;
    status)
      init_state
      echo "=== Heartbeat Status ==="
      echo "Beat Count: $(get_state beat_count)"
      echo "Last Beat: $(get_state last_beat)"
      echo "Last Push: $(get_state last_push)"
      echo "Status: $(get_state status)"
      echo "Consecutive Failures: $(get_state consecutive_failures)"
      echo "Recent Log:"
      tail -10 "$HEARTBEAT_LOG"
      ;;
    reset)
      rm -f "$HEARTBEAT_STATE" "$HEARTBEAT_LOG" "$HEARTBEAT_FAILED"
      log_beat "INFO" "Heartbeat state reset"
      ;;
    *)
      echo "Usage: $0 {once|monitor|daemon|status|reset}"
      exit 1
      ;;
  esac
}

main "$@"
