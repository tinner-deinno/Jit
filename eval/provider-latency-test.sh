#!/usr/bin/env bash
# eval/provider-latency-test.sh — CHAMU latency probe for all working providers
#
# Sends minimal test prompt to each provider and measures response time.
# Returns JSON with: tests (array), fastest (string), slowest (string)
#
# Usage:
#   bash eval/provider-latency-test.sh
#   bash eval/provider-latency-test.sh --verbose
#   bash eval/provider-latency-test.sh --json > results.json

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="${JIT_ROOT:-$SCRIPT_DIR/..}"

# Load environment
if [ -f "$JIT_ROOT/.env" ]; then
  set -a
  source "$JIT_ROOT/.env"
  set +a
fi

# Flags
VERBOSE="${VERBOSE:-0}"
if [[ "${1:-}" == "--verbose" ]]; then VERBOSE=1; fi
if [[ "${1:-}" == "--json" ]]; then VERBOSE=0; fi

# ─── Test configuration ──────────────────────────────────────────────────────
TEST_PROMPT="Hello, respond with 'ok'"
TEST_SYSTEM="You are a helpful assistant. Be brief."

# Provider definitions: provider_name | adapter_path | model_id | api_key_env | base_url_env | base_url_default | timeout_sec
declare -a PROVIDERS=(
  "claude|limbs/providers/claude.sh|claude-haiku-4-5-20251001|COMMANDCODE_API_KEY|ANTHROPIC_BASE_URL||120"
  "openai|limbs/providers/openai.sh|gpt-4o-mini|OPENAI_API_KEY|OPENAI_BASE_URL|https://api.openai.com/v1|60"
  "ollama|limbs/providers/ollama.sh|gemma4:26b|OLLAMA_TOKEN|OLLAMA_BASE_URL|https://ollama.mdes-innova.online|90"
)

# ─── Helper functions ────────────────────────────────────────────────────────
log_verbose() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "[DEBUG] $*" >&2
  fi
}

log_info() {
  echo "[INFO] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}

# Test if provider adapter is available
provider_available() {
  local adapter="$1" api_key_env="$2" base_url_env="$3" base_url_default="$4"

  # Check adapter file exists
  [ -f "$JIT_ROOT/$adapter" ] || return 1

  # Check API key is set
  local api_key_var="${!api_key_env:-}"
  [ -n "$api_key_var" ] || return 1

  # Run availability check via adapter
  local base_url="${!base_url_env:-$base_url_default}"
  PROVIDER_API_KEY="$api_key_var" \
    PROVIDER_BASE_URL="$base_url" \
    bash "$JIT_ROOT/$adapter" available >/dev/null 2>&1
}

# Call provider with timeout and measure latency
call_provider() {
  local adapter="$1" model="$2" system="$3" user="$4" api_key_env="$5" base_url_env="$6" base_url_default="$7" timeout="$8"

  local api_key="${!api_key_env:-}"
  local base_url="${!base_url_env:-$base_url_default}"

  # Measure time in milliseconds
  local start_ms=$(($(date +%s%N) / 1000000))

  local result
  result=$(PROVIDER_API_KEY="$api_key" \
    PROVIDER_BASE_URL="$base_url" \
    PROVIDER_TIMEOUT="$timeout" \
    timeout "$((timeout + 5))" \
    bash "$JIT_ROOT/$adapter" call "$model" "$system" "$user" 2>/dev/null)
  local rc=$?

  local end_ms=$(($(date +%s%N) / 1000000))
  local latency=$((end_ms - start_ms))

  # Return: latency_ms|success_code|result_snippet
  if [ $rc -eq 0 ] && [ -n "$result" ]; then
    echo "$latency|0|${result:0:50}"
  else
    echo "$latency|$rc|error"
  fi
}

# Grade latency by speed
grade_speed() {
  local latency=$1
  if [ "$latency" -lt 500 ]; then
    echo "fast"
  elif [ "$latency" -lt 2000 ]; then
    echo "ok"
  else
    echo "slow"
  fi
}

# ─── Main test loop ──────────────────────────────────────────────────────────
declare -a test_results=()
declare -i fastest_latency=999999
fastest_provider=""
declare -i slowest_latency=0
slowest_provider=""

log_info "Starting provider latency test..."
log_info "Test prompt: '$TEST_PROMPT'"

for provider_spec in "${PROVIDERS[@]}"; do
  IFS='|' read -r provider adapter model api_key_env base_url_env base_url_default timeout <<<"$provider_spec"

  log_verbose "Testing provider: $provider"

  # Check availability
  if ! provider_available "$adapter" "$api_key_env" "$base_url_env" "$base_url_default"; then
    log_info "SKIP: $provider (unavailable or missing API key)"
    continue
  fi

  log_info "Probing: $provider (model: $model, timeout: ${timeout}s)"

  # Run test call
  call_output=$(call_provider "$adapter" "$model" "$TEST_SYSTEM" "$TEST_PROMPT" "$api_key_env" "$base_url_env" "$base_url_default" "$timeout")

  IFS='|' read -r latency success result <<<"$call_output"

  speed=$(grade_speed "$latency")

  if [ "$success" = "0" ]; then
    log_info "✓ $provider: ${latency}ms ($speed) → ${result:0:40}..."

    # Record result
    test_results+=("${provider}|${latency}|0|${speed}")

    # Track fastest/slowest
    if [ "$latency" -lt "$fastest_latency" ]; then
      fastest_latency=$latency
      fastest_provider="$provider"
    fi
    if [ "$latency" -gt "$slowest_latency" ]; then
      slowest_latency=$latency
      slowest_provider="$provider"
    fi
  else
    log_info "✗ $provider: FAILED (exit=$success, latency=${latency}ms)"
    # Don't add failures to the passed results, just track skipped
  fi
done

# ─── Output results as JSON ──────────────────────────────────────────────────
if [ ${#test_results[@]} -eq 0 ]; then
  log_error "No providers passed availability check. Check API keys in .env"
  exit 1
fi

# Build JSON
{
  echo "{"
  echo '  "tests": ['

  first=true
  for result_entry in "${test_results[@]}"; do
    IFS='|' read -r prov latency success grade <<<"$result_entry"

    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi

    printf '    {"provider": "%s", "latency_ms": %d, "success": %d, "speed": "%s"}' "$prov" "$latency" "$success" "$grade"
  done

  echo ""
  echo "  ],"
  printf '  "fastest": "%s"' "$fastest_provider"
  echo ","
  printf '  "slowest": "%s"' "$slowest_provider"
  echo ""
  echo "}"
}
