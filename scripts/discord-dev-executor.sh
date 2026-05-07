#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PAYLOAD_FILE="${1:-${JIT_BRIDGE_PAYLOAD_FILE:-}}"
BUS_DIR="${JIT_BUS_DIR:-/tmp/manusat-bus}"
STATE_DIR="${JIT_BODY_EXECUTOR_STATE_DIR:-/tmp/jit-discord-dev-executor}"
LOG_FILE="${JIT_BODY_EXECUTOR_LOG:-/tmp/jit-discord-dev-executor.log}"
FORWARD_COMMAND="${JIT_BODY_EXECUTOR_FORWARD:-}"

mkdir -p "$STATE_DIR/payloads" "$STATE_DIR/results" "$BUS_DIR/jit"

if [ -z "$PAYLOAD_FILE" ] || [ ! -f "$PAYLOAD_FILE" ]; then
  echo "payload file missing" >&2
  exit 1
fi

read_json() {
  node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const value=(process.argv[2]||'').split('.').reduce((acc,key)=>acc&&Object.prototype.hasOwnProperty.call(acc,key)?acc[key]:'', data); process.stdout.write(Array.isArray(value)?value.join(','):String(value||''));" "$PAYLOAD_FILE" "$1"
}

CORRELATION_ID="$(read_json correlation_id)"
TASK_TEXT="$(read_json task)"
USER_TAG="$(read_json discord.user_tag)"
CHANNEL_NAME="$(read_json discord.channel_name)"
RECIPIENTS="$(read_json recipients)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE_FILE="$STATE_DIR/payloads/${STAMP}_${CORRELATION_ID:-unknown}.json"
RESULT_FILE="$STATE_DIR/results/${STAMP}_${CORRELATION_ID:-unknown}.log"

cp "$PAYLOAD_FILE" "$ARCHIVE_FILE"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" | tee -a "$LOG_FILE" >> "$RESULT_FILE"
}

write_bus_report() {
  local subject="$1"
  local body="$2"
  local msg_file="$BUS_DIR/jit/$(date +%s)_${CORRELATION_ID:-executor}_from-discord-dev-executor.msg"
  cat > "$msg_file" <<EOF
from:discord-dev-executor
to:jit
subject:${subject}
timestamp:$(date -u +%Y-%m-%dT%H:%M:%S)
correlation-id:${CORRELATION_ID:-executor}
---
${body}

EOF
}

log "received correlation=${CORRELATION_ID:-unknown} user=${USER_TAG:-unknown} channel=${CHANNEL_NAME:-unknown} recipients=${RECIPIENTS:-}" 
log "task=${TASK_TEXT:-}" 

STATUS="accepted"
DETAIL="stored at $ARCHIVE_FILE"

if [ -n "$FORWARD_COMMAND" ]; then
  log "forwarding via configured executor command"
  if /bin/bash -lc "$FORWARD_COMMAND \"$PAYLOAD_FILE\"" >> "$RESULT_FILE" 2>&1; then
    STATUS="forwarded"
    DETAIL="forward command succeeded"
  else
    STATUS="forward-failed"
    DETAIL="forward command failed; see $RESULT_FILE"
  fi
else
  log "no JIT_BODY_EXECUTOR_FORWARD configured; stored payload only"
fi

write_bus_report "report:discord-dev-executor" "origin: discord-dev-executor
status: ${STATUS}
detail: ${DETAIL}
user: ${USER_TAG:-unknown}
channel: ${CHANNEL_NAME:-unknown}

task:
${TASK_TEXT:-}"

echo "status=${STATUS} correlation=${CORRELATION_ID:-unknown} archive=$ARCHIVE_FILE result=$RESULT_FILE"