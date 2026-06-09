#!/usr/bin/env bash
# tests/test_bus_idempotency.sh — ทดสอบระบบ idempotency key (JIT-002)
#
# Tests:
#   1. Idempotency key generation (deterministic hash)
#   2. Key written to .msg and .keys index
#   3. Duplicate detection within 24h window
#   4. Expired keys (>24h) treated as new
#   5. Router aborts on duplicate with BUS_DUPLICATE log

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

BUS_SH="$SCRIPT_DIR/../network/bus.sh"
BUS_ROOT="/tmp/manusat-bus"
TEST_AGENT="test_agent_$$"

# ── Setup ───────────────────────────────────────────────────────────
setup() {
  echo "=== Setup test environment ==="
  mkdir -p "$BUS_ROOT/$TEST_AGENT"
  rm -f "$BUS_ROOT/$TEST_AGENT/.keys"
  rm -rf "$BUS_ROOT/$TEST_AGENT/.dup"
  export AGENT_NAME="test_sender"
}

# ── Teardown ────────────────────────────────────────────────────────
teardown() {
  echo "=== Cleanup ==="
  rm -rf "$BUS_ROOT/$TEST_AGENT"
  unset AGENT_NAME
}

# ── Test 1: Key generation is deterministic ─────────────────────────
test_key_generation_deterministic() {
  echo ""
  echo "--- Test 1: Key generation is deterministic ---"

  local FROM="sender1"
  local SUBJECT="task:test"
  local BODY="test message body"

  # Generate key twice with same inputs
  local KEY1 KEY2
  KEY1=$(generate_idempotency_key "$FROM" "$SUBJECT" "$BODY")
  KEY2=$(generate_idempotency_key "$FROM" "$SUBJECT" "$BODY")

  if [ "$KEY1" = "$KEY2" ]; then
    ok "Key generation is deterministic: $KEY1"
    return 0
  else
    err "Key generation NOT deterministic: $KEY1 != $KEY2"
    return 1
  fi
}

# ── Test 2: Different inputs produce different keys ─────────────────
test_key_generation_unique() {
  echo ""
  echo "--- Test 2: Different inputs produce different keys ---"

  local FROM="sender1"
  local SUBJECT="task:test"
  local BODY1="body one"
  local BODY2="body two"

  local KEY1 KEY2
  KEY1=$(generate_idempotency_key "$FROM" "$SUBJECT" "$BODY1")
  KEY2=$(generate_idempotency_key "$FROM" "$SUBJECT" "$BODY2")

  if [ "$KEY1" != "$KEY2" ]; then
    ok "Different bodies produce different keys"
    echo "  Key1: $KEY1"
    echo "  Key2: $KEY2"
    return 0
  else
    err "Different bodies produced SAME key!"
    return 1
  fi
}

# ── Test 3: bus.sh send writes idempotency-key header ───────────────
test_bus_send_writes_idempotency_key() {
  echo ""
  echo "--- Test 3: bus.sh send writes idempotency-key header ---"

  export AGENT_NAME="test_sender"
  local MSG_OUTPUT
  MSG_OUTPUT=$("$BUS_SH" send "$TEST_AGENT" "task:test" "Test body for idempotency" 2>&1)

  # Find the message file
  local MSG_FILE
  MSG_FILE=$(ls "$BUS_ROOT/$TEST_AGENT"/*.msg 2>/dev/null | head -1)

  if [ -z "$MSG_FILE" ]; then
    err "No message file created"
    return 1
  fi

  # Check for idempotency-key header
  if grep -q "^idempotency-key:" "$MSG_FILE"; then
    local IDEM_KEY
    IDEM_KEY=$(grep "^idempotency-key:" "$MSG_FILE" | cut -d: -f2)
    ok "Message contains idempotency-key: $IDEM_KEY"

    # Verify key format (64 char hex)
    if [[ "$IDEM_KEY" =~ ^[a-f0-9]{64}$ ]]; then
      ok "Key format is valid (64 char hex)"
      return 0
    else
      err "Key format invalid: $IDEM_KEY"
      return 1
    fi
  else
    err "idempotency-key header NOT found in message"
    cat "$MSG_FILE"
    return 1
  fi
}

# ── Test 4: Key recorded to .keys index ─────────────────────────────
test_key_recorded_to_index() {
  echo ""
  echo "--- Test 4: Key recorded to .keys index ---"

  local KEYS_FILE="$BUS_ROOT/$TEST_AGENT/.keys"

  if [ ! -f "$KEYS_FILE" ]; then
    err ".keys file not created"
    return 1
  fi

  # Check format: <key>:<timestamp>:<subject>
  local LINE
  LINE=$(head -1 "$KEYS_FILE")
  local KEY TS SUBJECT
  KEY=$(echo "$LINE" | cut -d: -f1)
  TS=$(echo "$LINE" | cut -d: -f2)
  SUBJECT=$(echo "$LINE" | cut -d: -f3-)

  if [[ "$KEY" =~ ^[a-f0-9]{64}$ ]] && [[ "$TS" =~ ^[0-9]+$ ]] && [ -n "$SUBJECT" ]; then
    ok ".keys index has correct format: $LINE"
    return 0
  else
    err ".keys format incorrect: $LINE"
    return 1
  fi
}

# ── Test 5: Duplicate detection within 24h ──────────────────────────
test_duplicate_detection() {
  echo ""
  echo "--- Test 5: Duplicate detection within 24h ---"

  # Send same message again
  export AGENT_NAME="test_sender"
  "$BUS_SH" send "$TEST_AGENT" "task:test" "Test body for idempotency" >/dev/null 2>&1

  # Now recv should detect duplicate
  local RECV_OUTPUT
  RECV_OUTPUT=$("$BUS_SH" recv "$TEST_AGENT" 2>&1)

  # Check if duplicate was detected
  if echo "$RECV_OUTPUT" | grep -q "BUS_DUPLICATE"; then
    ok "Duplicate detected and logged as BUS_DUPLICATE"

    # Check .dup directory
    if [ -d "$BUS_ROOT/$TEST_AGENT/.dup" ]; then
      local DUP_COUNT
      DUP_COUNT=$(ls "$BUS_ROOT/$TEST_AGENT/.dup"/*.msg 2>/dev/null | wc -l)
      ok "Duplicate moved to .dup/ directory (count: $DUP_COUNT)"
      return 0
    else
      err ".dup directory not created"
      return 1
    fi
  else
    err "Duplicate NOT detected"
    echo "Output: $RECV_OUTPUT"
    return 1
  fi
}

# ── Test 6: Expired keys (>24h) treated as new ──────────────────────
test_expired_keys_treated_as_new() {
  echo ""
  echo "--- Test 6: Expired keys (>24h) treated as new ---"

  # Manually add an expired key (timestamp = 2 days ago)
  local EXPIRED_TS
  EXPIRED_TS=$(($(date +%s) - 172800))  # 48 hours ago
  local EXPIRED_KEY="expired_key_test_1234567890abcdef"

  echo "${EXPIRED_KEY}:${EXPIRED_TS}:task:old" >> "$BUS_ROOT/$TEST_AGENT/.keys"

  # Create a message with the expired key
  local OLD_MSG="$BUS_ROOT/$TEST_AGENT/old_msg.msg"
  cat > "$OLD_MSG" << EOF
from:test_sender
to:$TEST_AGENT
subject:task:old
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
idempotency-key:$EXPIRED_KEY
---
Old message with expired key
EOF

  # is_duplicate_key should return 1 (not duplicate) for expired key
  if is_duplicate_key "$EXPIRED_KEY" "$TEST_AGENT"; then
    err "Expired key incorrectly detected as duplicate"
    return 1
  else
    ok "Expired key correctly treated as new (>24h)"
    return 0
  fi
}

# ── Test 7: Explicit IDEMPOTENCY_KEY env var ────────────────────────
test_explicit_idempotency_key() {
  echo ""
  echo "--- Test 7: Explicit IDEMPOTENCY_KEY env var ---"

  # Clean up any existing .msg files from previous tests
  rm -f "$BUS_ROOT/$TEST_AGENT"/*.msg 2>/dev/null

  local CUSTOM_KEY="custom-key-$(date +%s)"
  export IDEMPOTENCY_KEY="$CUSTOM_KEY"
  export AGENT_NAME="test_sender"

  "$BUS_SH" send "$TEST_AGENT" "task:custom" "Custom key message" >/dev/null 2>&1

  # Find the newly created message file (should be only one now)
  local MSG_FILE
  MSG_FILE=$(ls "$BUS_ROOT/$TEST_AGENT"/*.msg 2>/dev/null | head -1)

  if [ -z "$MSG_FILE" ]; then
    err "No message file created"
    unset IDEMPOTENCY_KEY
    return 1
  fi

  if grep -q "idempotency-key:$CUSTOM_KEY" "$MSG_FILE"; then
    ok "Custom IDEMPOTENCY_KEY used correctly"
    unset IDEMPOTENCY_KEY
    return 0
  else
    err "Custom IDEMPOTENCY_KEY not used"
    cat "$MSG_FILE"
    unset IDEMPOTENCY_KEY
    return 1
  fi
}

# ── Main ────────────────────────────────────────────────────────────
main() {
  echo "========================================"
  echo "  JIT-002: Bus Idempotency Key Tests"
  echo "========================================"

  setup

  local PASS=0 FAIL=0 TOTAL=0

  run_test() {
    local TEST_NAME="$1"
    local TEST_FUNC="$2"
    ((TOTAL++))
    echo ""
    echo "Running: $TEST_NAME"
    if $TEST_FUNC; then
      ((PASS++))
    else
      ((FAIL++))
    fi
  }

  run_test "Key generation deterministic" test_key_generation_deterministic
  run_test "Key generation unique" test_key_generation_unique
  run_test "bus.sh send writes idempotency-key" test_bus_send_writes_idempotency_key
  run_test "Key recorded to .keys index" test_key_recorded_to_index
  run_test "Duplicate detection within 24h" test_duplicate_detection
  run_test "Expired keys treated as new" test_expired_keys_treated_as_new
  run_test "Explicit IDEMPOTENCY_KEY env var" test_explicit_idempotency_key

  teardown

  echo ""
  echo "========================================"
  echo "  Results: $PASS/$TOTAL passed, $FAIL failed"
  echo "========================================"

  if [ "$FAIL" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main "$@"
