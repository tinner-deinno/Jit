#!/usr/bin/env bash
# limbs/validate-task.sh — Task wrapper for secure validation functions
# Provides JSON output for development task #5: Write secure validation function
# Output format: JSON with status, completion_percent, and test results

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${SCRIPT_DIR}/lib.sh"
source "${SCRIPT_DIR}/validate.sh"

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Run single validation test
run_test() {
  local TEST_NAME="$1"
  local VALIDATION_TYPE="$2"
  local VALUE="$3"
  local EXPECTED="$4"  # "pass" or "fail"

  ((TESTS_TOTAL++))

  if validate "$VALIDATION_TYPE" "$VALUE" 2>/dev/null; then
    local ACTUAL="pass"
  else
    local ACTUAL="fail"
  fi

  if [ "$ACTUAL" = "$EXPECTED" ]; then
    ((TESTS_PASSED++))
  else
    ((TESTS_FAILED++))
  fi
}

# Execute test suite
echo "Running secure validation function tests..." >&2

run_test "valid_email" "email" "user@example.com" "pass"
run_test "invalid_email_injection" "email" "user@example.com';DROP TABLE--" "fail"
run_test "valid_alphanum" "alphanum" "valid-name_123" "pass"
run_test "invalid_alphanum_injection" "alphanum" "invalid; rm -rf /" "fail"
run_test "valid_agent_name" "agent_name" "jit" "pass"
run_test "valid_url_https" "url" "https://example.com/api" "pass"
run_test "invalid_url_javascript" "url" "javascript:alert('xss')" "fail"
run_test "valid_filename" "filename" "config/settings.json" "pass"
run_test "invalid_filename_traversal" "filename" "../../../etc/passwd" "fail"
run_test "valid_json" "json" '{"status": "ok"}' "pass"
run_test "invalid_json" "json" '{invalid json}' "fail"
run_test "valid_integer_positive" "integer" "42" "pass"
run_test "invalid_integer_string" "integer" "not-a-number" "fail"

# Calculate completion percentage
COMPLETION=$((TESTS_PASSED * 100 / TESTS_TOTAL))
STATUS="success"
[ $TESTS_FAILED -gt 0 ] && STATUS="partial"

# Output JSON result
cat << EOF
{
  "status": "$STATUS",
  "completion_percent": $COMPLETION,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests": {
    "total": $TESTS_TOTAL,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED
  },
  "implementation": {
    "file": "/workspaces/Jit/limbs/validate.sh",
    "functions": 9,
    "coverage": [
      "email",
      "url",
      "alphanum",
      "filename",
      "json",
      "command",
      "agent_name",
      "path",
      "integer"
    ]
  }
}
EOF

# Return appropriate exit code (success if all tests pass)
exit $([ $TESTS_FAILED -eq 0 ] && echo 0 || echo 1)
