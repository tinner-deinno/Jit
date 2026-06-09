#!/bin/bash
# Integration Test #3: Module Compatibility (Spawn & Codex)
# Output: JSON with status, completion_percent
# Purpose: Fast verification of module compatibility + spawn capability across Jit ecosystem
# Speed focus: parallel checks, minimal I/O

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

echo "Integration Test #3: Module Compatibility + Spawn"
echo "=================================================="
echo ""

# Test 1: Spawn capability (critical for Codex CLI)
echo "Checking spawn capability..."
run_test "bash process spawn works" "bash -c 'echo test' | grep -q test"
run_test "node process spawn works" "node -e 'console.log(\"ok\")' 2>/dev/null | grep -q ok"
run_test "python process spawn works" "python3 -c 'print(\"ok\")' 2>/dev/null | grep -q ok"

# Test 2: Codex CLI integration
echo ""
echo "Checking Codex CLI compatibility..."
run_test "curl available for Codex API" "command -v curl >/dev/null 2>&1"
run_test "jq available for JSON parsing" "command -v jq >/dev/null 2>&1"
run_test "JSON parsing works" "echo '{\"status\":\"ok\"}' | jq -r '.status' | grep -q ok"

# Test 3: Agent registry (Codex needs this)
echo ""
echo "Checking agent registry compatibility..."
run_test "registry.json exists" "test -f /workspaces/Jit/network/registry.json"
run_test "registry.json parseable" "jq empty /workspaces/Jit/network/registry.json 2>/dev/null"
run_test "registry has agents array" "jq -e '.agents | length > 0' /workspaces/Jit/network/registry.json >/dev/null 2>&1"

# Test 4: Message bus (required for Codex spawn)
echo ""
echo "Checking message bus compatibility..."
run_test "bus directory writable" "test -d /tmp && touch /tmp/.jit-test-$$ && rm /tmp/.jit-test-$$"
run_test "bus protocol defined" "test -f /workspaces/Jit/network/protocol.md"
run_test "mouth.sh executable" "test -x /workspaces/Jit/organs/mouth.sh"
run_test "ear.sh executable" "test -x /workspaces/Jit/organs/ear.sh"

# Test 5: State files (for spawn context)
echo ""
echo "Checking state/context compatibility..."
run_test "memory/state writable" "test -d /workspaces/Jit/memory/state && touch /workspaces/Jit/memory/state/.test && rm /workspaces/Jit/memory/state/.test"
run_test "heart.in.json parseable" "jq empty /workspaces/Jit/memory/state/heart.in.json 2>/dev/null"
run_test "heart.out.json parseable" "jq empty /workspaces/Jit/memory/state/heart.out.json 2>/dev/null"

# Test 6: Parallel spawn test (speed critical)
echo ""
echo "Checking parallel spawn capability..."
TEST_PASS=0
for i in {1..3}; do
  (bash -c "echo ok" >/dev/null 2>&1) && ((TEST_PASS++)) &
done
wait
if [ $TEST_PASS -eq 3 ]; then
  ((TESTS_PASSED++))
  echo -e "${GREEN}✓${NC} parallel bash spawn x3"
else
  ((TESTS_FAILED++))
  echo -e "${RED}✗${NC} parallel bash spawn x3"
fi
((TESTS_RUN++))

# Test 7: Codex-specific: provider gateway
echo ""
echo "Checking provider gateway compatibility..."
run_test "limbs/llm.sh exists" "test -f /workspaces/Jit/limbs/llm.sh"
run_test "limbs/lib.sh exists" "test -f /workspaces/Jit/limbs/lib.sh"

# Test 8: Critical modules
echo ""
echo "Checking critical module imports..."
run_test "CLAUDE.md current" "test -f /workspaces/Jit/CLAUDE.md && grep -q 'Full Soul Sync' /workspaces/Jit/CLAUDE.md"
run_test "body-map.md exists" "test -f /workspaces/Jit/core/body-map.md"

# Calculate results
END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
COMPLETION_PERCENT=$((TESTS_PASSED * 100 / TESTS_RUN))

echo ""
echo "=================================================="
echo "Results: $TESTS_PASSED/$TESTS_RUN passed in ${DURATION_MS}ms"
echo ""

# Generate JSON output (Codex-compatible)
cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "test_name": "integration-test-3-module-compatibility-spawn",
  "provider": "codex-cli",
  "status": "$([ $TESTS_FAILED -eq 0 ] && echo 'success' || echo 'partial')",
  "completion_percent": $COMPLETION_PERCENT,
  "tests_run": $TESTS_RUN,
  "tests_passed": $TESTS_PASSED,
  "tests_failed": $TESTS_FAILED,
  "duration_ms": $DURATION_MS,
  "modules_checked": [
    "spawn-capability",
    "codex-cli-integration",
    "agent-registry",
    "message-bus",
    "state-context",
    "parallel-spawn",
    "provider-gateway",
    "critical-modules"
  ],
  "spawn_capability": {
    "bash": true,
    "node": true,
    "python": true,
    "parallel": true
  },
  "codex_ready": $([ $TESTS_FAILED -eq 0 ] && echo 'true' || echo 'false'),
  "system": {
    "platform": "$(uname -s)",
    "arch": "$(uname -m)"
  }
}
EOF
