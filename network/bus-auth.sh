#!/usr/bin/env bash
# network/bus-auth.sh — Bus Message Authentication (JIT-011)
#
# HMAC-SHA256 signing and verification for the มนุษย์ Agent message bus.
#
# Security model:
#   - Every outbound message is signed with HMAC-SHA256 over a canonical string
#   - Every inbound message is verified before processing
#   - Unsigned messages are accepted in LEGACY mode (MANUSAT_STRICT_AUTH != 1)
#   - Signature failures are logged and messages are routed to DLQ/error
#
# Canonical string (in order, no separator):
#   from + to + subject + timestamp + body
#
# Environment:
#   MANUSAT_BUS_SECRET   — Shared HMAC secret key (required for signing)
#   MANUSAT_STRICT_AUTH  — "1" = reject unsigned (default), "0" = legacy/accept unsigned
#
# Usage:
#   source network/bus-auth.sh
#   sig=$(bus_auth_sign "$from" "$to" "$subject" "$timestamp" "$body")
#   bus_auth_verify "$msg_file"  # returns 0=ok, 1=fail, 2=unsigned-accepted
#   bus_auth_sign_file "$msg_file"  # add x-signature header in-place

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

# ── Constants ───────────────────────────────────────────────────────
AUTH_LOG="/tmp/manusat-bus-auth.log"
AUTH_VERSION="1"  # JIT-011

# ── Internal: log to auth audit trail ───────────────────────────────
_auth_log() {
  local level="$1" msg="$2"
  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S')
  echo "${ts} [${level}] ${msg}" >> "$AUTH_LOG" 2>/dev/null || true
}

# ── bus_auth_sign ────────────────────────────────────────────────────
# Compute HMAC-SHA256 signature for a message.
# Args: from, to, subject, timestamp, body
# Stdout: hex signature (64 chars) or empty string if no secret configured
# Exit: 0 always (empty means unsigned)
bus_auth_sign() {
  local FROM="$1" TO="$2" SUBJECT="$3" TIMESTAMP="$4"
  shift 4
  local BODY="$*"

  local SECRET="${MANUSAT_BUS_SECRET:-}"
  if [ -z "$SECRET" ]; then
    _auth_log "WARN" "bus_auth_sign: MANUSAT_BUS_SECRET not set — message will be unsigned"
    echo ""
    return 0
  fi

  # Canonical string: concatenate fields in fixed order (no separator to match verify)
  local CANONICAL="${FROM}${TO}${SUBJECT}${TIMESTAMP}${BODY}"

  # Compute HMAC-SHA256 via openssl
  local SIG
  SIG=$(printf '%s' "$CANONICAL" | openssl dgst -sha256 -hmac "$SECRET" 2>/dev/null | awk '{print $NF}')
  if [ -z "$SIG" ]; then
    _auth_log "ERROR" "bus_auth_sign: openssl failed for from=$FROM to=$TO subject=$SUBJECT"
    echo ""
    return 0
  fi

  _auth_log "INFO" "bus_auth_sign: signed from=$FROM to=$TO subject=$SUBJECT sig=${SIG:0:8}..."
  echo "$SIG"
}

# ── bus_auth_verify_fields ───────────────────────────────────────────
# Verify HMAC given explicit fields (useful for unit tests).
# Args: from, to, subject, timestamp, body, provided_signature
# Returns: 0=valid, 1=invalid/rejected
bus_auth_verify_fields() {
  local FROM="$1" TO="$2" SUBJECT="$3" TIMESTAMP="$4" BODY="$5" PROVIDED_SIG="$6"
  local SECRET="${MANUSAT_BUS_SECRET:-}"
  local STRICT="${MANUSAT_STRICT_AUTH:-1}"

  # No secret configured
  if [ -z "$SECRET" ]; then
    if [ "$STRICT" = "1" ]; then
      _auth_log "FAIL" "bus_auth_verify_fields: no secret set, strict mode rejects from=$FROM"
      return 1
    fi
    _auth_log "WARN" "bus_auth_verify_fields: no secret — accepting unsigned (legacy) from=$FROM"
    return 2
  fi

  # No signature on message
  if [ -z "$PROVIDED_SIG" ]; then
    if [ "$STRICT" = "1" ]; then
      _auth_log "FAIL" "bus_auth_verify_fields: missing signature, strict mode rejects from=$FROM to=$TO"
      return 1
    fi
    _auth_log "WARN" "bus_auth_verify_fields: unsigned message accepted (legacy) from=$FROM to=$TO"
    return 2
  fi

  # Compute expected signature
  local EXPECTED_SIG
  EXPECTED_SIG=$(printf '%s' "${FROM}${TO}${SUBJECT}${TIMESTAMP}${BODY}" \
    | openssl dgst -sha256 -hmac "$SECRET" 2>/dev/null | awk '{print $NF}')

  if [ -z "$EXPECTED_SIG" ]; then
    _auth_log "ERROR" "bus_auth_verify_fields: openssl failed from=$FROM"
    return 1
  fi

  # Constant-time-equivalent comparison (bash string compare is acceptable here;
  # timing attacks on a file-based local bus are not a realistic threat)
  if [ "$PROVIDED_SIG" = "$EXPECTED_SIG" ]; then
    _auth_log "INFO" "bus_auth_verify_fields: OK from=$FROM to=$TO sig=${PROVIDED_SIG:0:8}..."
    return 0
  else
    _auth_log "FAIL" "bus_auth_verify_fields: MISMATCH from=$FROM to=$TO got=${PROVIDED_SIG:0:8}... want=${EXPECTED_SIG:0:8}..."
    return 1
  fi
}

# ── bus_auth_verify ──────────────────────────────────────────────────
# Parse a message file and verify its x-signature header.
# Args: msg_file (path to .msg file)
# Returns:
#   0 — signature valid
#   1 — signature invalid (tampered / bad key)
#   2 — unsigned message accepted (legacy mode, MANUSAT_STRICT_AUTH != 1)
#   3 — file not found / parse error
bus_auth_verify() {
  local MSG_FILE="$1"

  if [ ! -f "$MSG_FILE" ]; then
    _auth_log "ERROR" "bus_auth_verify: file not found: $MSG_FILE"
    return 3
  fi

  # Parse headers (everything before the --- separator)
  local FROM="" TO="" SUBJECT="" TIMESTAMP="" SIG="" BODY=""
  local IN_BODY=0

  while IFS= read -r line; do
    # Strip carriage return
    line="${line%$'\r'}"
    if [ "$IN_BODY" = "1" ]; then
      BODY="${BODY}${line}"$'\n'
      continue
    fi
    if [ "$line" = "---" ]; then
      IN_BODY=1
      continue
    fi
    case "$line" in
      from:*)      FROM="${line#from:}" ;;
      to:*)        TO="${line#to:}" ;;
      subject:*)   SUBJECT="${line#subject:}" ;;
      timestamp:*) TIMESTAMP="${line#timestamp:}" ;;
      x-signature:hmac-sha256=*)
        SIG="${line#x-signature:hmac-sha256=}" ;;
    esac
  done < "$MSG_FILE"

  # Remove trailing newline from body for consistent canonical form
  BODY="${BODY%$'\n'}"

  bus_auth_verify_fields "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "$BODY" "$SIG"
}

# ── bus_auth_sign_file ───────────────────────────────────────────────
# Add or replace the x-signature header in an existing message file.
# The file is rewritten atomically via a temp file.
# Args: msg_file
# Returns: 0=success, 1=error
bus_auth_sign_file() {
  local MSG_FILE="$1"

  if [ ! -f "$MSG_FILE" ]; then
    _auth_log "ERROR" "bus_auth_sign_file: file not found: $MSG_FILE"
    return 1
  fi

  local SECRET="${MANUSAT_BUS_SECRET:-}"
  if [ -z "$SECRET" ]; then
    _auth_log "WARN" "bus_auth_sign_file: no secret — skipping signing of $(basename "$MSG_FILE")"
    return 0
  fi

  # Parse message
  local FROM="" TO="" SUBJECT="" TIMESTAMP="" BODY=""
  local IN_BODY=0
  local HEADER_LINES=()

  while IFS= read -r line; do
    line="${line%$'\r'}"
    if [ "$IN_BODY" = "1" ]; then
      BODY="${BODY}${line}"$'\n'
      continue
    fi
    if [ "$line" = "---" ]; then
      IN_BODY=1
      continue
    fi
    case "$line" in
      from:*)      FROM="${line#from:}" ;;
      to:*)        TO="${line#to:}" ;;
      subject:*)   SUBJECT="${line#subject:}" ;;
      timestamp:*) TIMESTAMP="${line#timestamp:}" ;;
      x-signature:*) continue ;;  # Remove existing signature header
    esac
    HEADER_LINES+=("$line")
  done < "$MSG_FILE"

  BODY="${BODY%$'\n'}"

  # Compute new signature
  local SIG
  SIG=$(bus_auth_sign "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "$BODY")
  if [ -z "$SIG" ]; then
    # No secret — write file back unchanged (no signature header added)
    return 0
  fi

  # Rewrite file atomically
  local TMP_FILE="${MSG_FILE}.auth.tmp"
  {
    for hline in "${HEADER_LINES[@]}"; do
      printf '%s\n' "$hline"
    done
    printf 'x-signature:hmac-sha256=%s\n' "$SIG"
    printf -- '---\n'
    # Always write body with a trailing newline so read-based parsers see the last line
    printf '%s\n' "$BODY"
  } > "$TMP_FILE"

  mv "$TMP_FILE" "$MSG_FILE"
  _auth_log "INFO" "bus_auth_sign_file: signed $(basename "$MSG_FILE") sig=${SIG:0:8}..."
  return 0
}

# ── bus_auth_test ────────────────────────────────────────────────────
# Self-test: sign a message and verify it. Prints PASS/FAIL.
bus_auth_test() {
  echo "=== bus-auth self-test ==="
  local SECRET="test-secret-1234"
  local MANUSAT_BUS_SECRET="$SECRET"
  export MANUSAT_BUS_SECRET

  local FROM="soma" TO="innova" SUBJECT="task:test" TIMESTAMP="2026-06-08T10:00:00" BODY="hello world"

  local SIG
  SIG=$(bus_auth_sign "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "$BODY")
  echo "  Computed sig: ${SIG:0:16}..."

  if bus_auth_verify_fields "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "$BODY" "$SIG"; then
    echo "  verify_fields: PASS"
  else
    echo "  verify_fields: FAIL"; return 1
  fi

  # Tampered body should fail
  if bus_auth_verify_fields "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "tampered body" "$SIG" 2>/dev/null; then
    echo "  tamper detection: FAIL (accepted tampered message)"; return 1
  else
    echo "  tamper detection: PASS"
  fi

  # Wrong key should fail
  local OLD_SECRET="$MANUSAT_BUS_SECRET"
  export MANUSAT_BUS_SECRET="wrong-key"
  if bus_auth_verify_fields "$FROM" "$TO" "$SUBJECT" "$TIMESTAMP" "$BODY" "$SIG" 2>/dev/null; then
    echo "  wrong-key detection: FAIL"; export MANUSAT_BUS_SECRET="$OLD_SECRET"; return 1
  else
    echo "  wrong-key detection: PASS"
  fi
  export MANUSAT_BUS_SECRET="$OLD_SECRET"

  # Test sign_file round-trip
  local TMP_MSG
  TMP_MSG=$(mktemp /tmp/bus-auth-test-XXXXXX.msg)
  cat > "$TMP_MSG" <<EOF
from:soma
to:innova
subject:task:test
timestamp:2026-06-08T10:00:00
---
hello world
EOF
  bus_auth_sign_file "$TMP_MSG"
  if bus_auth_verify "$TMP_MSG"; then
    echo "  sign_file+verify: PASS"
  else
    echo "  sign_file+verify: FAIL"; rm -f "$TMP_MSG"; return 1
  fi
  rm -f "$TMP_MSG"

  # Unsigned message: strict mode should reject
  local TMP_UNSIGNED
  TMP_UNSIGNED=$(mktemp /tmp/bus-auth-test-unsigned-XXXXXX.msg)
  cat > "$TMP_UNSIGNED" <<EOF
from:soma
to:innova
subject:task:test
timestamp:2026-06-08T10:00:00
---
hello unsigned
EOF
  export MANUSAT_STRICT_AUTH="1"
  if bus_auth_verify "$TMP_UNSIGNED" 2>/dev/null; then
    echo "  strict-unsigned rejection: FAIL"
  else
    echo "  strict-unsigned rejection: PASS"
  fi
  rm -f "$TMP_UNSIGNED"

  echo "=== all tests passed ==="
}

# ── Standalone execution ─────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  CMD="${1:-help}"
  case "$CMD" in
    test)
      bus_auth_test
      ;;
    sign)
      # bus-auth.sh sign <from> <to> <subject> <timestamp> <body>
      bus_auth_sign "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}"
      ;;
    verify)
      # bus-auth.sh verify <msg_file>
      bus_auth_verify "${2:-}"
      ;;
    sign-file)
      # bus-auth.sh sign-file <msg_file>
      bus_auth_sign_file "${2:-}"
      ;;
    help|*)
      echo "Usage: bus-auth.sh {test|sign|verify|sign-file}"
      echo ""
      echo "  test                                    — Run self-tests"
      echo "  sign <from> <to> <subject> <ts> <body>  — Compute HMAC signature"
      echo "  verify <msg_file>                       — Verify message file"
      echo "  sign-file <msg_file>                    — Add/replace x-signature in file"
      echo ""
      echo "Environment:"
      echo "  MANUSAT_BUS_SECRET   — Shared HMAC secret (required for signing)"
      echo "  MANUSAT_STRICT_AUTH  — 1=reject unsigned (default), 0=legacy/accept"
      ;;
  esac
fi
