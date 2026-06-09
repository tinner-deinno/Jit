#!/bin/bash
# Integration Test #1: Module Compatibility
# Output: JSON with status, completion_percent
# Purpose: Fast verification of module compatibility across Jit ecosystem

set +e

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date +%s%N)
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper to run a test
run_test() {
  local test_name=$1
  local test_cmd=$2
  ((TESTS_RUN++))

  if eval "$test_cmd" &>/dev/null; then
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $test_name"
    return 0
  else
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $test_name"
    return 1
  fi
}

echo "Integration Test #1: Module Compatibility"
echo "=========================================="
echo ""

# Test 1: Node.js modules (hermes-discord)
echo "Checking Node.js module compatibility..."
run_test "discord.js installed" "test -f /workspaces/Jit/hermes-discord/node_modules/discord.js/package.json"
run_test "discord.js version >=14" "node -e \"const v = require('/workspaces/Jit/hermes-discord/node_modules/discord.js/package.json').version; process.exit(v.startsWith('14') || v.startsWith('15') ? 0 : 1)\""
run_test "bot.js runnable" "test -f /workspaces/Jit/hermes-discord/bot.js && test -x /usr/bin/node"

# Test 2: Python environment
echo ""
echo "Checking Python module compatibility..."
run_test "Python 3 available" "command -v python3 >/dev/null 2>&1"
run_test "pytest installed" "python3 -m pytest --version >/dev/null 2>&1"
run_test "conftest.py readable" "test -r /workspaces/Jit/tests/conftest.py"

# Test 3: Bash scripts and limbs
echo ""
echo "Checking Bash/shell compatibility..."
run_test "limbs/lib.sh exists" "test -f /workspaces/Jit/limbs/lib.sh"
run_test "organs/mouth.sh executable" "test -x /workspaces/Jit/organs/mouth.sh"
run_test "network/bus.sh executable" "test -x /workspaces/Jit/network/bus.sh"

# Test 4: Core files
echo ""
echo "Checking core system files..."
run_test "registry.json valid" "test -f /workspaces/Jit/network/registry.json && python3 -m json.tool /workspaces/Jit/network/registry.json >/dev/null 2>&1"
run_test "agent capabilities defined" "test -f /workspaces/Jit/agents/innova.json && python3 -m json.tool /workspaces/Jit/agents/innova.json >/dev/null 2>&1"
run_test "CLAUDE.md documentation exists" "test -f /workspaces/Jit/CLAUDE.md && grep -q 'Jit Oracle' /workspaces/Jit/CLAUDE.md"

# Test 5: Message bus setup
echo ""
echo "Checking message bus compatibility..."
run_test "bus directory writable" "test -d /tmp && touch /tmp/.jit-test-$$ && rm /tmp/.jit-test-$$"
run_test "bus protocol defined" "test -f /workspaces/Jit/network/protocol.md"

# Test 6: Memory structure
echo ""
echo "Checking memory layer compatibility..."
run_test "memory/state directory exists" "test -d /workspaces/Jit/memory/state"
run_test "heartbeat files present" "test -f /workspaces/Jit/memory/state/heart.in.json && test -f /workspaces/Jit/memory/state/heart.out.json"
run_test "memory state parseable" "python3 -m json.tool /workspaces/Jit/memory/state/heart.in.json >/dev/null 2>&1"

# Calculate results
END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
COMPLETION_PERCENT=$((TESTS_PASSED * 100 / TESTS_RUN))

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "Duration: ${DURATION_MS}ms"
echo ""

# Generate JSON output
cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "test_name": "integration-test-1-module-compatibility",
  "status": "$([ $TESTS_FAILED -eq 0 ] && echo 'success' || echo 'partial')",
  "completion_percent": $COMPLETION_PERCENT,
  "tests_run": $TESTS_RUN,
  "tests_passed": $TESTS_PASSED,
  "tests_failed": $TESTS_FAILED,
  "duration_ms": $DURATION_MS,
  "modules_checked": [
    "discord.js (Node.js)",
    "pytest (Python)",
    "bash-shells",
    "core-system",
    "message-bus",
    "memory-layers"
  ],
  "system": {
    "platform": "$(uname -s)",
    "arch": "$(uname -m)",
    "node_version": "$(node --version 2>/dev/null || echo 'N/A')",
    "python_version": "$(python3 --version 2>&1 | awk '{print $2}')"
  }
}
EOF
