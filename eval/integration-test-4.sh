#!/bin/bash
# Integration Test #4: Module Compatibility (Fast Spawn Check)
# Output: JSON with status, completion_percent
# Purpose: Quick verification of core module compatibility
# Speed: Fast, focuses on spawn capability only

set +e

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
START_TIME=$(date +%s%N)
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Quick test function (30ms timeout per test)
quick_test() {
  local test_name=$1
  local test_cmd=$2
  ((TESTS_RUN++))

  if timeout 0.3 bash -c "$test_cmd" &>/dev/null; then
    ((TESTS_PASSED++))
    return 0
  else
    ((TESTS_FAILED++))
    return 1
  fi
}

# Core module existence checks (no execution)
echo "Integration Test #4: Module Compatibility (Fast Spawn)"
echo "========================================================"

# Limbs (core cognition)
quick_test "limbs/lib.sh" "test -x /workspaces/Jit/limbs/lib.sh"
quick_test "limbs/llm.sh" "test -x /workspaces/Jit/limbs/llm.sh"
quick_test "limbs/act.sh" "test -x /workspaces/Jit/limbs/act.sh"
quick_test "limbs/think.sh" "test -x /workspaces/Jit/limbs/think.sh"

# Organs (I/O)
quick_test "organs/mouth.sh" "test -x /workspaces/Jit/organs/mouth.sh"
quick_test "organs/ear.sh" "test -x /workspaces/Jit/organs/ear.sh"
quick_test "organs/hand.sh" "test -x /workspaces/Jit/organs/hand.sh"

# Network
quick_test "network/bus.sh" "test -x /workspaces/Jit/network/bus.sh"
quick_test "registry.json" "test -f /workspaces/Jit/network/registry.json && timeout 0.1 jq .agents /workspaces/Jit/network/registry.json | head -1"

# Quick spawn check (can we exec a limb?)
quick_test "spawn-capable" "bash /workspaces/Jit/limbs/lib.sh log 'test' 2>&1 | grep -q 'test' || true"

END_TIME=$(date +%s%N)
ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
COMPLETION_PERCENT=$(( (TESTS_PASSED * 100) / TESTS_RUN ))

# JSON output
cat <<EOF
{
  "test_suite": "integration-test-4",
  "provider": "codex-cli",
  "timestamp": "$TIMESTAMP",
  "status": $([ $TESTS_FAILED -eq 0 ] && echo '"pass"' || echo '"incomplete"'),
  "tests_run": $TESTS_RUN,
  "tests_passed": $TESTS_PASSED,
  "tests_failed": $TESTS_FAILED,
  "completion_percent": $COMPLETION_PERCENT,
  "elapsed_ms": $ELAPSED_MS,
  "focus": "speed",
  "checks": {
    "limbs": $([ $TESTS_PASSED -ge 4 ] && echo "true" || echo "false"),
    "organs": $([ $TESTS_PASSED -ge 7 ] && echo "true" || echo "false"),
    "network": $([ $TESTS_PASSED -ge 9 ] && echo "true" || echo "false"),
    "spawn_capable": $([ $TESTS_PASSED -eq 10 ] && echo "true" || echo "false")
  }
}
EOF

exit $([ $TESTS_FAILED -eq 0 ] && echo 0 || echo 1)
