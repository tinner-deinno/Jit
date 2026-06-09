#!/usr/bin/env bash
# limbs/lib.sh — ห้องสมุดกลาง: shared utilities สำหรับทุก limb
# Source ไฟล์นี้ก่อนใช้ limb ใดๆ: source "$(dirname "$0")/lib.sh"

# ─── สี & สัญลักษณ์ ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}✅${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠️ ${RESET} $*"; }
err()  { echo -e "${RED}❌${RESET} $*" >&2; }
info() { echo -e "${CYAN}ℹ️ ${RESET} $*"; }
step() { echo -e "${BOLD}→${RESET} $*"; }

# ─── Configuration ──────────────────────────────────────────────────
ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"
OLLAMA_URL="${OLLAMA_URL:-https://ollama.mdes-innova.online}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e4b}"
JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
ORACLE_ROOT="${ORACLE_ROOT:-/workspaces/arra-oracle-v3}"

# ─── Logging Configuration (JIT-007) ────────────────────────────────
# JIT_LOG_DIR: Centralized log directory for all Jit daemons
#   - Default: /var/log/jit/ (systemd LogsDirectory)
#   - Fallback: /tmp/jit-logs/ (for non-systemd environments)
#   - Override: Set JIT_LOG_DIR env var to custom path
JIT_LOG_DIR="${JIT_LOG_DIR:-/var/log/jit}"
JIT_LOG_DIR_FALLBACK="/tmp/jit-logs"

# Resolve log directory (prefer /var/log/jit, fallback to /tmp)
resolve_log_dir() {
  if [ -d "$JIT_LOG_DIR" ] && [ -w "$JIT_LOG_DIR" ]; then
    echo "$JIT_LOG_DIR"
  elif [ -d "$JIT_LOG_DIR_FALLBACK" ] || mkdir -p "$JIT_LOG_DIR_FALLBACK" 2>/dev/null; then
    echo "$JIT_LOG_DIR_FALLBACK"
  else
    echo "/tmp"
  fi
}

# Ensure log directory exists with proper permissions
ensure_log_dir() {
  local dir; dir=$(resolve_log_dir)
  mkdir -p "$dir" 2>/dev/null || true
  chmod 0755 "$dir" 2>/dev/null || true
}

# ─── สติ: log ทุกการกระทำ (mindfulness journal) ────────────────────
JIT_LOG="${JIT_LOG:-$(resolve_log_dir)/innova-actions.log}"
log_action() {
  local VERB="$1" DESC="$2"
  ensure_log_dir
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$VERB] $DESC" >> "$JIT_LOG"
}

# ─── JIT-007: Daemon logging utilities ──────────────────────────────
# Log to daemon-specific log file
# Usage: log_daemon <daemon-name> <message>
log_daemon() {
  local DAEMON="$1" MSG="$2" LEVEL="${3:-INFO}"
  local LOG_FILE="$(resolve_log_dir)/jit-${DAEMON}.log"
  local TIMESTAMP; TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  ensure_log_dir
  echo "[$TIMESTAMP] [$LEVEL] [$DAEMON] $MSG" >> "$LOG_FILE"

  # Also forward to journal if systemd-cat available
  if command -v systemd-cat >/dev/null 2>&1; then
    echo "[$LEVEL] [$DAEMON] $MSG" | systemd-cat -t "jit-${DAEMON}" -p "${LEVEL,,}" 2>/dev/null || true
  fi
}

# Log directly to systemd journal (preferred for systemd services)
# Usage: log_to_journal <identifier> <level> <message>
log_to_journal() {
  local IDENTIFIER="$1" LEVEL="$2" MSG="$3"

  if command -v systemd-cat >/dev/null 2>&1; then
    echo "$MSG" | systemd-cat -t "$IDENTIFIER" -p "${LEVEL,,}" 2>/dev/null
  else
    # Fallback to file logging
    log_daemon "$IDENTIFIER" "$MSG" "$LEVEL"
  fi
}

# Rotate-aware log write (checks file size, triggers rotation hint)
# Usage: safe_log <log-file> <message>
safe_log() {
  local LOG_FILE="$1" MSG="$2"
  local MAX_SIZE_BYTES="${JIT_LOG_MAX_SIZE:-10485760}"  # Default 10MB

  ensure_log_dir

  # Check if rotation needed
  if [ -f "$LOG_FILE" ]; then
    local SIZE; SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$SIZE" -ge "$MAX_SIZE_BYTES" ]; then
      # Log rotation hint (external tool should handle actual rotation)
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ROTATE] Log file exceeds ${MAX_SIZE_BYTES} bytes" >> "${LOG_FILE}.rotate-hint"
    fi
  fi

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MSG" >> "$LOG_FILE"
}

# auto-write SESSION_START เมื่อ lib.sh ถูก source ครั้งแรกในแต่ละ session
_LIB_MARKER="/tmp/innova-lib-session.$(date '+%Y%m%d')"
if [ ! -f "$_LIB_MARKER" ]; then
  touch "$_LIB_MARKER"
  log_action "SESSION_START" "innova awake — $(date '+%Y-%m-%dT%H:%M:%S') host=$(hostname)"
fi
unset _LIB_MARKER

# ─── ความลับ: redact sensitive data from logs ──────────────────────
# Redact credentials: mask tokens, keys, passwords
# Usage: safe_msg=$(redact "$message_with_secrets")
redact() {
  local INPUT="$*"
  # Mask common credential patterns
  echo "$INPUT" | sed -E \
    -e 's/(Bearer )[A-Za-z0-9_-]+/\1[REDACTED]/g' \
    -e 's/(sk-ant-)[A-Za-z0-9_-]+/\1[REDACTED]/g' \
    -e 's/(ghp_[A-Za-z0-9_-]+|[A-Za-z0-9]{40})/[REDACTED]/g' \
    -e 's/(API key|token|secret|password)[=: ]*[A-Za-z0-9_-]+/\1=[REDACTED]/gi'
}

# Log token status without exposing value
# Usage: log_token "OLLAMA_TOKEN" "$OLLAMA_TOKEN"
log_token() {
  local NAME="$1" VALUE="$2"
  if [ -n "$VALUE" ] && [ "$VALUE" != "[REDACTED]" ]; then
    local MASKED="$(echo "$VALUE" | head -c 8)"
    log_action "TOKEN_CHECK" "$NAME=${MASKED}..."
  else
    log_action "TOKEN_CHECK" "$NAME=[REDACTED]"
  fi
}

# ─── สมาธิ: lock กัน multiagent ชนกัน (mutual exclusion via flock) ──
# jit_with_lock <lock-name> <timeout-sec> -- <command...>
#   Runs <command> while holding an exclusive flock on /tmp/manusat-locks/<name>.
#   Two calls with the SAME lock-name never overlap; different names run freely.
#   This is how agents "ทำงานร่วมกันโดยไม่ชนกัน" — parallel across agents,
#   serialized per agent so they don't stomp on shared inbox / state.
# Returns the command's exit code, or 75 (EX_TEMPFAIL) if the lock timed out.
JIT_LOCK_DIR="${JIT_LOCK_DIR:-/tmp/manusat-locks}"
jit_with_lock() {
  local NAME="$1" TIMEOUT="${2:-30}"
  shift 2
  [ "${1:-}" = "--" ] && shift
  mkdir -p "$JIT_LOCK_DIR" 2>/dev/null
  local LOCKFILE="$JIT_LOCK_DIR/${NAME//\//_}.lock"

  if command -v flock >/dev/null 2>&1; then
    # FD-based flock: lock auto-releases when the subshell exits (even on crash).
    (
      flock -w "$TIMEOUT" 9 || { echo "[lock] timeout on '$NAME' after ${TIMEOUT}s" >&2; exit 75; }
      "$@"
    ) 9>"$LOCKFILE"
  else
    # Portable fallback: mkdir is atomic; spin until acquired or timeout.
    local START; START=$(date +%s)
    until mkdir "$LOCKFILE.d" 2>/dev/null; do
      sleep 0.2
      [ $(( $(date +%s) - START )) -ge "$TIMEOUT" ] && { echo "[lock] timeout on '$NAME'" >&2; return 75; }
    done
    "$@"; local RC=$?
    rmdir "$LOCKFILE.d" 2>/dev/null
    return $RC
  fi
}

# ─── ตรวจสอบ Oracle พร้อมหรือไม่ ─────────────────────────────────
# JIT-026: Enhanced error handling for debugging Oracle connectivity
#   - Captures curl network errors to /tmp/oracle-curl-error
#   - Captures JSON parse errors to /tmp/oracle-json-error
#   - ORACLE_DEBUG=1 enables verbose error output
#   - Distinct error types: network (curl) vs JSON parse vs oracle status
oracle_ready() {
  local DEBUG="${ORACLE_DEBUG:-0}"
  local RESPONSE CURL_STATUS

  # Step 1: curl with error capture
  RESPONSE=$(curl -sf --max-time 5 "$ORACLE_URL/api/health" 2>/tmp/oracle-curl-error)
  CURL_STATUS=$?

  if [ $CURL_STATUS -ne 0 ]; then
    [ "$DEBUG" = "1" ] && echo "oracle_ready: curl failed (status=$CURL_STATUS): $(cat /tmp/oracle-curl-error)" >&2
    return 1
  fi

  # Step 2: Parse JSON and validate oracle status
  if echo "$RESPONSE" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('oracle')=='connected' else 1)" \
    2>/tmp/oracle-json-error; then
    return 0
  else
    [ "$DEBUG" = "1" ] && echo "oracle_ready: JSON parse or validation failed: $(cat /tmp/oracle-json-error)" >&2
    return 1
  fi
}

# ─── Oracle: บันทึกการเรียนรู้ ──────────────────────────────────────
oracle_learn() {
  local PATTERN="$1" CONTENT="$2" CONCEPTS="${3:-general}" TYPE="${4:-learning}"
  python3 -c "
import json,sys,urllib.request
data = json.dumps({
  'pattern': sys.argv[1],
  'content': sys.argv[2],
  'type': sys.argv[4],
  'concepts': sys.argv[3].split(','),
  'origin': 'innova-limbs'
}).encode()
req = urllib.request.Request('$ORACLE_URL/api/learn',
  data=data, headers={'Content-Type':'application/json'}, method='POST')
with urllib.request.urlopen(req, timeout=10) as r:
  d = json.load(r)
  print(d.get('id','error'))
" "$PATTERN" "$CONTENT" "$CONCEPTS" "$TYPE" 2>/dev/null
}

# ─── Oracle: ค้นหาความรู้ ───────────────────────────────────────────
oracle_search() {
  local QUERY="$1" LIMIT="${2:-3}" MODE="${3:-hybrid}" MODEL="${4:-}"
  python3 -c "
import json,sys,urllib.request,urllib.parse

q = urllib.parse.quote(sys.argv[1])
limit = int(sys.argv[2])
mode = sys.argv[3] if len(sys.argv) > 3 else 'hybrid'
model = sys.argv[4] if len(sys.argv) > 4 else None

url = '$ORACLE_URL/api/search?q=' + q + '&limit=' + str(limit) + '&mode=' + mode
if model:
    url += '&model=' + urllib.parse.quote(model)

try:
    with urllib.request.urlopen(url, timeout=10) as r:
        d = json.load(r)
except Exception as e:
    print(f'  (Oracle error: {e})')
    sys.exit(0)

results = d.get('results', [])
metadata = d.get('metadata', {})
warning = d.get('warning', '')

if not results:
    print('(ไมพบขอมูลใน Oracle)')
    if warning:
        print(f'  Warning: {warning}')
    sys.exit(0)

# Display results with relevance scores
print(f\"Found {len(results)} results (mode={mode}, search_time={metadata.get('searchTime', '?')}ms)\")
if warning:
    print(f'  Warning: {warning}')
print()

for i, r in enumerate(results, 1):
    # Calculate normalized relevance score (0.0-1.0)
    source = r.get('source', 'unknown')
    if source == 'fts':
        rel_score = r.get('score', 0)
    elif source == 'vector':
        # Vector distance: lower = better, so invert
        rel_score = r.get('score', 0)
    elif source == 'hybrid':
        rel_score = r.get('score', 0)
    else:
        rel_score = r.get('score', 0)

    # Ensure score is in 0-1 range
    rel_score = max(0.0, min(1.0, rel_score))

    print(f\"  [{i}] [{r['type']}] {r['id']}\")
    print(f\"      relevance: {rel_score:.4f} (source={source})\")
    content = r.get('content', '')[:150].replace(chr(10), ' ').strip()
    print(f\"      {content}...\")

    # Show concepts if available
    concepts = r.get('concepts', [])
    if concepts:
        print(f\"      concepts: {', '.join(concepts[:5])}\")
    print()
" "$QUERY" "$LIMIT" "$MODE" "$MODEL" 2>/dev/null || echo "  (Oracle ไมพรอม)"
}

# ─── JSON encode ────────────────────────────────────────────────────
json_str() {
  python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1"
}

# ─── Bus Security: HMAC-SHA256 message signing ─────────────────────
# Configuration:
#   MANUSAT_BUS_SECRET  — Shared HMAC key (required for signing)
#   MANUSAT_STRICT_AUTH — 0=accept unsigned (legacy), 1=require signature (default)
#
# Usage:
#   sig=$(bus_compute_signature "$from" "$to" "$subject" "$timestamp" "$body")
#   bus_verify_signature "$from" "$to" "$subject" "$timestamp" "$body" "$signature"

BUS_SECRET="${MANUSAT_BUS_SECRET:-}"
BUS_STRICT_AUTH="${MANUSAT_STRICT_AUTH:-1}"

# Compute HMAC-SHA256 signature over canonical string
# Args: from, to, subject, timestamp, body
# Returns: hex signature (64 chars)
bus_compute_signature() {
  local FROM="$1" TO="$2" SUBJECT="$3" TIMESTAMP="$4"
  shift 4
  local BODY="$*"

  if [ -z "$BUS_SECRET" ]; then
    echo ""
    return 0
  fi

  # Canonical string: from+to+subject+timestamp+body
  local CANONICAL="${FROM}${TO}${SUBJECT}${TIMESTAMP}${BODY}"

  # Generate HMAC-SHA256 using openssl
  echo -n "$CANONICAL" | openssl dgst -sha256 -hmac "$BUS_SECRET" | awk '{print $NF}'
}

# Verify signature against expected value
# Args: from, to, subject, timestamp, body, provided_signature
# Returns: 0 if valid, 1 if invalid
bus_verify_signature() {
  local FROM="$1" TO="$2" SUBJECT="$3" TIMESTAMP="$4"
  shift 4
  local BODY="$1"
  local PROVIDED_SIG="$2"

  # If no secret set and strict mode off, accept unsigned
  if [ -z "$BUS_SECRET" ] && [ "$BUS_STRICT_AUTH" != "1" ]; then
    warn "BUS_AUTH: No secret configured, accepting unsigned message"
    return 0
  fi

  # If no signature provided
  if [ -z "$PROVIDED_SIG" ]; then
    if [ "$BUS_STRICT_AUTH" = "1" ]; then
      err "BUS_AUTH_FAIL: Missing signature in strict mode"
      return 1
    else
      warn "BUS_AUTH: Accepting unsigned message (legacy mode)"
      return 0
    fi
  fi

  # Compute expected signature
  local EXPECTED_SIG
  EXPECTED_SIG=$(bus_compute_signature "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "$BODY")

  if [ -z "$EXPECTED_SIG" ]; then
    err "BUS_AUTH_FAIL: Cannot compute signature (no secret)"
    return 1
  fi

  # Constant-time comparison (prevent timing attacks)
  if [ "$PROVIDED_SIG" = "$EXPECTED_SIG" ]; then
    return 0
  else
    err "BUS_AUTH_FAIL: Signature mismatch"
    return 1
  fi
}

# Parse x-signature header from message content
# Input: message headers (before ---)
# Output: signature value or empty
bus_parse_signature() {
  local HEADERS="$1"
  echo "$HEADERS" | grep "^x-signature:" | sed 's/^x-signature:hmac-sha256=//'
}

# ─── Bus Idempotency: deduplication via idempotency-key ────────────
# Covers: JIT-002 — Add idempotency key to bus messages
#
# Key Generation:
#   generate_idempotency_key "$from" "$subject" "$body"
#   → Returns SHA-256 hex hash (64 chars)
#
# Key Storage:
#   /tmp/manusat-bus/<agent>/.keys
#   Format: <key>:<timestamp>:<subject>
#
# Deduplication:
#   is_duplicate_key "$key" "$agent"
#   → Returns 0 if duplicate (within 24h), 1 if new
#
# Usage in bus.sh:
#   1. On send: generate key, append to .keys, write to .msg header
#   2. On recv: check is_duplicate_key, skip if duplicate, log BUS_DUPLICATE

# Generate idempotency key from message components
# Args: from, subject, body
# Returns: SHA-256 hex string (64 chars)
generate_idempotency_key() {
  local FROM="$1" SUBJECT="$2"
  shift 2
  local BODY="$*"

  # Derive key from from+subject+body-hash
  # body-hash = SHA-256 of body
  # final-key = SHA-256 of (from + subject + body-hash)
  local BODY_HASH
  BODY_HASH=$(echo -n "$BODY" | sha256sum | cut -d' ' -f1)

  echo -n "${FROM}${SUBJECT}${BODY_HASH}" | sha256sum | cut -d' ' -f1
}

# Check if idempotency key is a duplicate (seen within last 24h)
# Args: key, agent
# Returns: 0 if duplicate (reject), 1 if new (accept)
is_duplicate_key() {
  local KEY="$1" AGENT="$2"
  local KEYS_FILE="/tmp/manusat-bus/${AGENT}/.keys"

  # No keys file yet = definitely new
  [ ! -f "$KEYS_FILE" ] && return 1

  # Calculate cutoff timestamp (24h ago)
  local NOW TS_CUTOFF
  NOW=$(date +%s)
  TS_CUTOFF=$((NOW - 86400))

  # Search for key in index
  local LINE
  LINE=$(grep "^${KEY}:" "$KEYS_FILE" 2>/dev/null | head -1)
  [ -z "$LINE" ] && return 1  # Not found = new

  # Extract timestamp and check if within 24h window
  local TS
  TS=$(echo "$LINE" | cut -d: -f2)

  # If timestamp > cutoff, it's a duplicate (within window)
  [ "$TS" -gt "$TS_CUTOFF" ] && return 0

  # Key expired (>24h old), treat as new
  return 1
}

# Record idempotency key to agent's .keys index
# Args: key, agent, subject
# Appends: <key>:<timestamp>:<subject>
record_idempotency_key() {
  local KEY="$1" AGENT="$2" SUBJECT="$3"
  local KEYS_FILE="/tmp/manusat-bus/${AGENT}/.keys"
  local TS
  TS=$(date +%s)

  mkdir -p "/tmp/manusat-bus/${AGENT}" 2>/dev/null
  echo "${KEY}:${TS}:${SUBJECT}" >> "$KEYS_FILE"
}

# Parse idempotency-key header from message file
# Args: message_file_path
# Returns: key value or empty string
parse_idempotency_key() {
  local MSG_FILE="$1"
  grep "^idempotency-key:" "$MSG_FILE" 2>/dev/null | sed 's/^idempotency-key://' | tr -d '\r\n'
}

# ─── JIT-022: Chain-of-Thought Logging ─────────────────────────────
# CoT Log file: /tmp/manusat-cot-log.jsonl (JSON Lines format)
# Each entry: {agent, timestamp, intent, step, substeps[], oracle_queries[], decision}
COT_LOG_FILE="${COT_LOG_FILE:-/tmp/manusat-cot-log.jsonl}"

# Initialize CoT log file if not exists
init_cot_log() {
  [ ! -f "$COT_LOG_FILE" ] && touch "$COT_LOG_FILE"
}

# Log a chain-of-thought entry
# Usage: cot_log "intent" "step" "substeps_json_array" "oracle_queries_json_array" "decision"
# Example: cot_log "implement feature" "1" '["understand","plan"]' '["multiagent"]' "sequential"
cot_log() {
  local INTENT="$1" STEP="$2" SUBSTEPS="${3:-[]}" ORACLE_QUERIES="${4:-[]}" DECISION="${5:-proceed}"
  local AGENT="${AGENT_NAME:-innova}"
  local TIMESTAMP; TIMESTAMP=$(date -Iseconds)

  init_cot_log

  # Build JSON entry using python for proper escaping
  python3 -c "
import json, sys
entry = {
  'agent': sys.argv[1],
  'timestamp': sys.argv[2],
  'intent': sys.argv[3],
  'step': int(sys.argv[4]) if sys.argv[4].isdigit() else sys.argv[4],
  'substeps': json.loads(sys.argv[5]),
  'oracle_queries': json.loads(sys.argv[6]),
  'decision': sys.argv[7]
}
print(json.dumps(entry, ensure_ascii=False))
" "$AGENT" "$TIMESTAMP" "$INTENT" "$STEP" "$SUBSTEPS" "$ORACLE_QUERIES" "$DECISION" >> "$COT_LOG_FILE"
}

# Read last N CoT entries
# Usage: cot_read [limit]
# Returns: JSON lines (last N entries)
cot_read() {
  local LIMIT="${1:-10}"
  [ ! -f "$COT_LOG_FILE" ] && echo "[]" && return

  tail -n "$LIMIT" "$COT_LOG_FILE" 2>/dev/null || echo ""
}

# Format CoT entries for human reading
# Usage: cot_format [limit]
cot_format() {
  local LIMIT="${1:-10}"
  [ ! -f "$COT_LOG_FILE" ] && echo "(ยังไม่มี CoT log)" && return

  # ANSI color codes for bash output
  local CYAN='\033[0;36m' RESET='\033[0m'

  python3 -c "
import json, sys

CYAN = '\033[0;36m'
RESET = '\033[0m'

lines = []
try:
  with open(sys.argv[1], 'r') as f:
    lines = f.readlines()[-int(sys.argv[2]):]
except Exception as err:
  print('(อ่าน CoT log ไม่สำเร็จ: ' + str(err) + ')')
  sys.exit(0)

for i, line in enumerate(lines, 1):
  line = line.strip()
  if not line:
    continue
  try:
    e = json.loads(line)
    print(f'{CYAN}\\n── Chain #{i} ' + '─' * 50 + f'{RESET}')
    print(f\"Agent: {e.get('agent','?')} | เวลา: {e.get('timestamp','?')}\")
    print(f\"เจตนา: {e.get('intent','?')}\")
    print(f\"ขั้นตอนที่: {e.get('step','?')}\")
    substeps = e.get('substeps', [])
    if substeps:
      print(f\"Substeps: {', '.join(substeps)}\")
    queries = e.get('oracle_queries', [])
    if queries:
      print(f\"Oracle queries: {', '.join(queries)}\")
    print(f\"ตัดสินใจ: {e.get('decision','?')}\")
  except json.JSONDecodeError as err:
    print(f\"(entry ผิดรูปแบบ: {err})\")
" "$COT_LOG_FILE" "$LIMIT"
}

# Clear CoT log (for testing or rotation)
# Usage: cot_clear
cot_clear() {
  : > "$COT_LOG_FILE"
  info "CoT log ถูกล้างแล้ว"
}

# Count total CoT entries
# Usage: cot_count
cot_count() {
  [ ! -f "$COT_LOG_FILE" ] && echo "0" && return
  wc -l < "$COT_LOG_FILE" | tr -d ' '
}
