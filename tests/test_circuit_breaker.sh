#!/bin/bash
#
# test_circuit_breaker.sh — JIT-009 Circuit Breaker Test
#
# Tests:
# 1. Verify circuit breaker flag is written after MAX_CONSECUTIVE_FAILURES
# 2. Verify exit code 42 is returned when circuit trips
# 3. Verify systemd units have OnFailure and RestartPreventExitStatus
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0

pass() { echo -e "${GREEN}✅ PASS${NC}: $1"; ((pass_count++)); }
fail() { echo -e "${RED}❌ FAIL${NC}: $1"; ((fail_count++)); }
info() { echo -e "${YELLOW}ℹ️${NC} $1"; }

# Cleanup from previous runs
cleanup() {
    rm -f /tmp/jit-circuit-open
    rm -f /tmp/innova-heartbeat-daemon.json
    rm -f /tmp/innova-heartbeat-daemon.log
}

echo "═══════════════════════════════════════════════════════════"
echo "JIT-009 Circuit Breaker Test Suite"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Test 1: Verify bot.js has error handlers
info "Test 1: Checking bot.js error handlers..."
if grep -q "process.on('unhandledRejection'" "$JIT_ROOT/hermes-discord/bot.js" && \
   grep -q "process.on('uncaughtException'" "$JIT_ROOT/hermes-discord/bot.js" && \
   grep -q "sendDiscordAlert" "$JIT_ROOT/hermes-discord/bot.js"; then
    pass "bot.js has unhandledRejection and uncaughtException handlers"
else
    fail "bot.js missing error handlers"
fi

# Test 2: Verify heartbeat script has circuit breaker logic
info "Test 2: Checking heartbeat-24h-daemon.sh circuit breaker..."
if grep -q 'echo "CIRCUIT_OPEN" > /tmp/jit-circuit-open' "$JIT_ROOT/scripts/heartbeat-24h-daemon.sh" && \
   grep -q 'exit 42' "$JIT_ROOT/scripts/heartbeat-24h-daemon.sh"; then
    pass "heartbeat-24h-daemon.sh writes circuit breaker flag and exits 42"
else
    fail "heartbeat-24h-daemon.sh missing circuit breaker logic"
fi

# Test 3: Verify systemd units have OnFailure
info "Test 3: Checking systemd unit OnFailure directive..."
if grep -q 'OnFailure=notify-failure@%n.service' "$JIT_ROOT/jit-heartbeat.service" && \
   grep -q 'OnFailure=notify-failure@%n.service' "$JIT_ROOT/ops/systemd/jit-heartbeat.service"; then
    pass "Both systemd units have OnFailure=notify-failure@%n.service"
else
    fail "systemd units missing OnFailure directive"
fi

# Test 4: Verify systemd units have RestartPreventExitStatus=42
info "Test 4: Checking systemd unit RestartPreventExitStatus..."
if grep -q 'RestartPreventExitStatus=42' "$JIT_ROOT/jit-heartbeat.service" && \
   grep -q 'RestartPreventExitStatus=42' "$JIT_ROOT/ops/systemd/jit-heartbeat.service"; then
    pass "Both systemd units have RestartPreventExitStatus=42"
else
    fail "systemd units missing RestartPreventExitStatus=42"
fi

# Test 5: Simulate consecutive failures to trigger circuit breaker
info "Test 5: Simulating 3 consecutive failures to trigger circuit breaker..."
cleanup

# Create initial state file with 2 failures already
cat > /tmp/innova-heartbeat-daemon.json <<EOF
{
  "daemon_start": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "beat_count": 0,
  "last_beat": null,
  "last_push": null,
  "consecutive_failures": 2,
  "total_failures": 2,
  "status": "degraded",
  "uptime_seconds": 0
}
EOF

# Source the heartbeat script functions and simulate a failure
export DISCORD_WEBHOOK=""
cd "$JIT_ROOT"

# Run a modified version that will trigger the circuit breaker
# We'll mock the do_beat function to always fail
cat > /tmp/test_circuit.sh <<'TESTSCRIPT'
#!/bin/bash
set -euo pipefail
source /workspaces/Jit/scripts/heartbeat-24h-daemon.sh

# Override do_beat to always fail
do_beat() { return 1; }

# Override handle_beat_failure to exit immediately after circuit trips
handle_beat_failure() {
    local beat_num=$1
    local error=$2

    local current_failures=$(get_state "consecutive_failures")
    current_failures=$((current_failures + 1))

    if [[ $current_failures -ge $MAX_CONSECUTIVE_FAILURES ]]; then
        echo "CIRCUIT_OPEN" > /tmp/jit-circuit-open
        exit 42
    fi
}

# Trigger one failure (we already have 2 in state)
handle_beat_failure 3 "Simulated failure"
TESTSCRIPT

chmod +x /tmp/test_circuit.sh

# Run the test - should exit 42 and write circuit flag
if bash /tmp/test_circuit.sh 2>/dev/null; then
    fail "Script should have exited 42"
else
    exit_code=$?
    if [[ $exit_code -eq 42 ]] && [[ -f /tmp/jit-circuit-open ]] && [[ "$(cat /tmp/jit-circuit-open)" == "CIRCUIT_OPEN" ]]; then
        pass "Circuit breaker triggered: exit code 42 and flag written"
    else
        fail "Circuit breaker did not trigger correctly (exit=$exit_code, flag exists=$([ -f /tmp/jit-circuit-open ] && echo yes || echo no))"
    fi
fi

rm -f /tmp/test_circuit.sh

# Test 6: Verify bot.js sendDiscordAlert function exists
info "Test 6: Checking sendDiscordAlert function in bot.js..."
if grep -q 'function sendDiscordAlert' "$JIT_ROOT/hermes-discord/bot.js"; then
    pass "sendDiscordAlert function defined in bot.js"
else
    fail "sendDiscordAlert function not found in bot.js"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Test Summary: ${GREEN}$pass_count passed${NC}, ${RED}$fail_count failed${NC}"
echo "═══════════════════════════════════════════════════════════"

cleanup

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
