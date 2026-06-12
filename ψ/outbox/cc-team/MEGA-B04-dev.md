<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: B04 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":101,"completion_tokens":3380,"total_tokens":3481} | 34s
 generated: 2026-06-12T19:33:40.640Z -->
#!/bin/bash

# -----------------------------------------------------------------------------
# INNOMCP Smoke Test Script
# Tests health endpoints, web title, and WebSocket port reachability.
# Prints PASS/FAIL summary table; exits non-zero on any failure.
# -----------------------------------------------------------------------------

set -o pipefail

# ---------- helper functions ----------
pass_count=0
fail_count=0
declare -a test_names
declare -a test_results

record_result() {
    local description="$1"
    local result="$2"   # "PASS" or "FAIL"
    test_names+=("$description")
    test_results+=("$result")
    if [[ "$result" == "PASS" ]]; then
        ((pass_count++))
    else
        ((fail_count++))
    fi
}

run_test() {
    local description="$1"
    shift
    local cmd_output
    cmd_output=$(eval "$@" 2>&1)
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        record_result "$description" "PASS"
    else
        record_result "$description" "FAIL"
        [[ -n "$cmd_output" ]] && echo "  -> $cmd_output" >&2
    fi
}

check_http_status() {
    local url="$1"
    local expected_http="$2"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" --connect-timeout 5 --max-time 10 2>/dev/null)
    if [[ "$http_code" -eq "$expected_http" ]]; then
        return 0
    else
        echo "Expected HTTP $expected_http, got $http_code from $url"
        return 1
    fi
}

check_json_status() {
    local url="$1"
    local json
    json=$(curl -s "$url" --connect-timeout 5 --max-time 10 2>/dev/null)
    if echo "$json" | jq -e '.status == "ok"' >/dev/null 2>&1; then
        return 0
    else
        echo "JSON status field missing or not 'ok' in response from $url"
        return 1
    fi
}

extract_title() {
    local url="$1"
    local html
    html=$(curl -s "$url" --connect-timeout 5 --max-time 10 2>/dev/null)
    local title
    title=$(echo "$html" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p')
    if echo "$title" | grep -q "INNOMCP"; then
        return 0
    else
        echo "Web title does not contain 'INNOMCP' (found: '$title')"
        return 1
    fi
}

check_port() {
    local host="$1"
    local port="$2"
    timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        return 0
    else
        echo "Port $host:$port not reachable"
        return 1
    fi
}

# ---------- Test: health endpoint on :3015 ----------
echo "Running tests..."
run_test "Health endpoint HTTP 200" \
    "check_http_status http://localhost:3015/api/health 200"

run_test "Health endpoint JSON status field" \
    "check_json_status http://localhost:3015/api/health"

# ---------- Test: web endpoint on :3000 ----------
run_test "Web endpoint HTTP 200" \
    "check_http_status http://localhost:3000 200"

run_test "Web title contains INNOMCP" \
    "extract_title http://localhost:3000"

# ---------- Test: WS port reachability (assuming port 3015) ----------
run_test "WS port 3015 reachable" \
    "check_port localhost 3015"

# ---------- Summary table ----------
echo ""
echo "Summary"
echo "-------"
printf "%-45s %s\n" "Test" "Result"
printf "%-45s %s\n" "----" "------"
for i in "${!test_names[@]}"; do
    printf "%-45s %s\n" "${test_names[$i]}" "${test_results[$i]}"
done
echo ""
echo "TOTAL PASS: $pass_count  FAIL: $fail_count"

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
