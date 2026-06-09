#!/usr/bin/env bash
# 🤖 Sonnet 4.6
# cmdteam.sh — Multi-Provider LLM Gateway entry point
# Usage:
#   cmdteam call 'prompt' --agent NAME [--provider P] [--model M] [--no-fallback] [--system S]
#   cmdteam status
#   cmdteam self-improve
#   cmdteam route 'prompt' --agent NAME
#   cmdteam log
set -euo pipefail

# ---------- Paths & config ----------
CMDTEAM_HOME="${CMDTEAM_HOME:-/workspaces/Jit}"
CMDTEAM_LOG_DIR="/tmp/cmdteam"
CMDTEAM_LOG_FILE="${CMDTEAM_LOG_DIR}/usage.jsonl"
CMDTEAM_ENV_FILE="${CMDTEAM_ENV_FILE:-${CMDTEAM_HOME}/.env}"
LLM_SH="${LLM_SH:-${CMDTEAM_HOME}/limbs/llm.sh}"

# ---------- Default provider endpoints (CommandCode proxy) ----------
# cmdteam interprets for the CommandCode proxy — all 3 providers point there
: "${CMDTEAM_ANTHROPIC_BASE_URL:=https://api.commandcode.ai/provider/v1}"
: "${CMDTEAM_OPENAI_BASE_URL:=https://api.commandcode.ai/provider/v1}"
: "${CMDTEAM_OLLAMA_BASE_URL:=${OLLAMA_BASE_URL:-https://ollama.mdes-innova.online}}"
: "${COMMANDCODE_API_KEY:=${COMMANDCODE_API_KEY:-}}"

mkdir -p "${CMDTEAM_LOG_DIR}"

# ---------- Helpers ----------
log_jsonl() {
  # log_jsonl <event_json>
  printf '%s\n' "$1" | jq -c . >> "${CMDTEAM_LOG_FILE}" 2>/dev/null
}

now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
ts_ms()   { date +%s%3N 2>/dev/null || date +%s; }

have() { command -v "$1" >/dev/null 2>&1; }

require_jq() {
  if ! have jq; then
    echo "❌ jq is required but not installed" >&2
    exit 1
  fi
}

# ---------- (1) Source .env automatically ----------
if [[ -f "${CMDTEAM_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${CMDTEAM_ENV_FILE}"
  set +a
fi

# ---------- (2) Health check providers ----------
health_check() {
  require_jq
  local results="[]"
  local providers
  if [[ -n "${CMDTEAM_PROVIDERS:-}" ]]; then
    # shellcheck disable=SC2206
    providers=(${CMDTEAM_PROVIDERS})
  else
    providers=(anthropic openai ollama)
  fi
  local p
  for p in "${providers[@]}"; do
    local endpoint_var="CMDTEAM_${p^^}_BASE_URL"
    local endpoint="${!endpoint_var:-}"
    local ok="false"
    local detail="no-endpoint"
    if [[ -n "${endpoint}" ]] && have curl; then
      # Try provider root first (works for CommandCode proxy /api)
      local code
      code=$(curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "${endpoint%/}" 2>/dev/null || echo "000")
      if [[ "$code" =~ ^(200|301|302|307|404)$ ]]; then
        ok="true"; detail="reachable (HTTP $code)"
      else
        detail="unreachable (HTTP $code)"
      fi
    fi
    results=$(jq --arg p "$p" --arg e "${endpoint:-}" --arg o "$ok" --arg d "$detail" \
      '. + [{provider:$p, endpoint:$e, ok:($o=="true"), detail:$d}]' <<<"$results")
  done
  jq -n --arg ts "$(now_iso)" --argjson providers "$results" \
    '{event:"health-check", ts:$ts, providers:$providers}'
}

# ---------- (3) Log JSONL wrapper ----------
# Usage: log_call <agent> <provider> <model> <prompt> <response> <status> <extra_json>
log_call() {
  local agent="$1" provider="$2" model="$3" prompt="$4" response="$5" status="$6" extra="${7:-}"
  # If extra is empty, use literal JSON null
  [[ -z "$extra" ]] && extra="null"
  local ts; ts="$(now_iso)"
  local latency_ms="${CMDTEAM_LAST_LATENCY_MS:-0}"
  local prompt_tokens response_tokens total_tokens
  if have jq; then
    # Try to extract tokens from extra.usage (set by provider adapters)
    prompt_tokens=$(echo "$extra" | jq -r '.usage.prompt_tokens // .usage.input_tokens // 0' 2>/dev/null | tr -d '[:space:]' || echo "0")
    response_tokens=$(echo "$extra" | jq -r '.usage.completion_tokens // .usage.output_tokens // 0' 2>/dev/null | tr -d '[:space:]' || echo "0")
    total_tokens=$(echo "$extra" | jq -r '.usage.total_tokens // 0' 2>/dev/null | tr -d '[:space:]' || echo "0")
    [[ -z "$prompt_tokens" || ! "$prompt_tokens" =~ ^[0-9]+$ ]] && prompt_tokens=0
    [[ -z "$response_tokens" || ! "$response_tokens" =~ ^[0-9]+$ ]] && response_tokens=0
    [[ -z "$total_tokens" || ! "$total_tokens" =~ ^[0-9]+$ ]] && total_tokens=0
  else
    prompt_tokens=0; response_tokens=0; total_tokens=0
  fi
  # Ensure latency_ms is numeric too
  local latency_clean="${CMDTEAM_LAST_LATENCY_MS:-0}"
  [[ ! "$latency_clean" =~ ^[0-9]+$ ]] && latency_clean=0
  jq -n \
    --arg ts "$ts" \
    --arg event "call" \
    --arg agent "$agent" \
    --arg provider "$provider" \
    --arg model "$model" \
    --arg status "$status" \
    --argjson latency_ms "$latency_clean" \
    --argjson prompt_tokens "$prompt_tokens" \
    --argjson response_tokens "$response_tokens" \
    --argjson total_tokens "$total_tokens" \
    --arg prompt "${prompt:0:2000}" \
    --argjson extra "$extra" \
    '{event:$event, ts:$ts, agent:$agent, provider:$provider, model:$model,
      status:$status, latency_ms:$latency_ms,
      tokens:{prompt:$prompt_tokens, response:$response_tokens, total:$total_tokens},
      prompt_preview:$prompt, extra:$extra}' | jq -c . >> "${CMDTEAM_LOG_FILE}"
}

# ---------- (4) Default model routing (decision tree) ----------
# Maps agent name → (provider, model). Used when caller doesn't specify --provider/--model.
# ---------- (4) Default model routing (decision tree with rotation) ----------
# Maps agent name → (provider, model). Used when caller doesn't specify --provider/--model.
# Goal: spread load across 28 models in CommandCode plan. Avoid burning Claude/Ollama first.
# Rotation: CMDTEAM_ROTATE=1 (default) → random pick from 3-4 model pool per agent.
default_route() {
  # default_route <agent>
  local agent="${1:-default}"

  if [[ "${CMDTEAM_ROTATE:-1}" == "1" ]]; then
    # Cheap-tier agents: rotate across 4 budget models
    case "$agent" in
      vaja|chamu|mue|pada|netra|karn|pran|lung|sayanprasathan)
        # Cheap tier — rotate across 6 budget models (ollama MDES unlimited but log it)
        local cheap_pool=(
          "claude|claude-haiku-4-5-20251001"
          "openai|gpt-5.4-mini"
          "openai|deepseek/deepseek-v4-flash"
          "openai|google/gemini-3.5-flash"
          "ollama|gemma4:e4b"
          "ollama|gemma4:26b"
        )
        printf '%s' "${cheap_pool[$((RANDOM % 6))]}"
        return
        ;;
      neta)
        # Code review → rotate across strong code-tuned models (4 strong + codex)
        local review_pool=(
          "openai|gpt-5.4"
          "openai|gpt-5.3-codex"
          "openai|zai-org/GLM-5.1"
          "openai|gpt-5.4-codex"
        )
        printf '%s' "${review_pool[$((RANDOM % 4))]}"
        return
        ;;
      lak|rupa)
        # Architects/designers → strong but cost-aware (4 models)
        local arch_pool=(
          "claude|claude-sonnet-4-6"
          "openai|moonshotai/Kimi-K2.6"
          "openai|Qwen/Qwen3.7-Plus"
          "ollama|gemma4:26b"
        )
        printf '%s' "${arch_pool[$((RANDOM % 4))]}"
        return
        ;;
    esac
  fi

  # Deterministic default (rotation disabled or no pool match)
  case "$agent" in
    jit)    printf 'claude|claude-sonnet-4-6' ;;
    soma)   printf 'claude|claude-sonnet-4-6' ;;
    innova) printf 'claude|claude-sonnet-4-6' ;;
    lak)    printf 'claude|claude-sonnet-4-6' ;;
    neta)   printf 'openai|gpt-5.4' ;;
    vaja|chamu|mue|pada|netra|karn|pran|lung|sayanprasathan)
      printf 'claude|claude-haiku-4-5-20251001' ;;
    rupa)   printf 'claude|claude-sonnet-4-6' ;;
    *)      printf 'claude|claude-sonnet-4-6' ;;
  esac
}

# ---------- (5) Direct CommandCode call (replaces limbs/llm.sh fallback) ----------
llm_call() {
  # llm_call <agent> <prompt> [provider] [model] [no_fallback] [system]
  local agent="$1" prompt="$2" provider="${3:-}" model="${4:-}" no_fallback="${5:-false}" system="${6:-}"

  # If provider or model missing → resolve from default_route
  if [[ -z "$provider" || -z "$model" ]]; then
    local route
    route=$(default_route "$agent")
    provider="${provider:-${route%%|*}}"
    model="${model:-${route##*|}}"
  fi

  local t0 t1 response
  t0=$(ts_ms)

  # Direct CommandCode path — no llm.sh fallback (avoids openai.com direct calls)
  case "$provider" in
    openai|codex)
      response=$(
        PROVIDER_API_KEY="${COMMANDCODE_API_KEY}" \
        PROVIDER_BASE_URL="https://api.commandcode.ai/provider/v1" \
        PROVIDER_TIMEOUT="${CMDTEAM_PROVIDER_TIMEOUT:-120}" \
        bash "${CMDTEAM_HOME}/limbs/providers/openai.sh" call "$model" "$system" "$prompt" 2>&1
      ) || true
      ;;
    anthropic|claude)
      response=$(
        PROVIDER_API_KEY="${COMMANDCODE_API_KEY}" \
        PROVIDER_BASE_URL="https://api.commandcode.ai/provider/v1" \
        PROVIDER_TIMEOUT="${CMDTEAM_PROVIDER_TIMEOUT:-120}" \
        bash "${CMDTEAM_HOME}/limbs/providers/claude.sh" call "$model" "$system" "$prompt" 2>&1
      ) || true
      ;;
    ollama)
      # Ollama uses its own adapter (not through CommandCode proxy)
      response=$(
        bash "${CMDTEAM_HOME}/limbs/providers/ollama.sh" call "$model" "$system" "$prompt" 2>&1
      ) || true
      ;;
    *)
      # Unknown provider — try openai adapter (handles gpt-* and deepseek via CommandCode)
      response=$(
        PROVIDER_API_KEY="${COMMANDCODE_API_KEY}" \
        PROVIDER_BASE_URL="https://api.commandcode.ai/provider/v1" \
        PROVIDER_TIMEOUT="${CMDTEAM_PROVIDER_TIMEOUT:-120}" \
        bash "${CMDTEAM_HOME}/limbs/providers/openai.sh" call "$model" "$system" "$prompt" 2>&1
      ) || true
      ;;
  esac

  t1=$(ts_ms)
  CMDTEAM_LAST_LATENCY_MS=$((t1 - t0))
  printf '%s' "$response"
}

# ---------- Subcommands ----------

cmd_status() {
  require_jq
  health_check
  if [[ -f "${CMDTEAM_LOG_FILE}" ]]; then
    local calls total_errors
    calls=$(wc -l < "${CMDTEAM_LOG_FILE}" | tr -d ' ')
    total_errors=$(grep -c '"status":"error"' "${CMDTEAM_LOG_FILE}" 2>/dev/null || echo 0)
    jq -n --arg ts "$(now_iso)" --argjson calls "$calls" --argjson errors "$total_errors" \
      '{event:"status", ts:$ts, total_calls:$calls, total_errors:$errors, log:$ENV.CMDTEAM_LOG_FILE}' \
      | jq --arg lf "${CMDTEAM_LOG_FILE}" '. + {log:$lf}'
  fi
}

cmd_log() {
  # cmd_log [n]  — show last n entries (default 20)
  local n="${1:-20}"
  if [[ ! -f "${CMDTEAM_LOG_FILE}" ]]; then
    echo "📭 no log file yet at ${CMDTEAM_LOG_FILE}"
    return 0
  fi
  tail -n "$n" "${CMDTEAM_LOG_FILE}" | (have jq && jq -c . || cat)
}

cmd_self_improve() {
  require_jq
  if [[ ! -f "${CMDTEAM_LOG_FILE}" ]]; then
    echo "📭 no usage data to learn from"
    return 0
  fi
  local summary
  summary=$(jq -s '
    {
      total: length,
      by_agent: (group_by(.agent) | map({(.[0].agent): {calls: length, avg_latency_ms: (map(.latency_ms // 0) | add / length)}})),
      by_provider: (group_by(.provider) | map({(.[0].provider): length})),
      error_rate: ((map(select(.status=="error")) | length) / length)
    }' "${CMDTEAM_LOG_FILE}")
  echo "📊 self-improve summary:"
  echo "$summary" | jq .
  echo "💡 suggestion: prefer providers with lowest avg_latency_ms and error_rate == 0"
}

cmd_route() {
  # cmd_route 'prompt' --agent NAME  — pick best provider from logs
  require_jq
  local prompt="" agent="" rest=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2;;
      *)       prompt="$1"; shift;;
    esac
  done
  if [[ -z "$prompt" || -z "$agent" ]]; then
    echo "usage: cmdteam route 'prompt' --agent NAME" >&2
    return 2
  fi
  local provider=""
  if [[ -f "${CMDTEAM_LOG_FILE}" ]]; then
    provider=$(jq -r --arg a "$agent" '
      map(select(.agent==$a and .status=="ok"))
      | group_by(.provider)
      | map({provider: .[0].provider, avg: (map(.latency_ms // 0) | add / length)})
      | sort_by(.avg) | .[0].provider // empty' "${CMDTEAM_LOG_FILE}")
  fi
  echo "🧭 routing agent=${agent} → provider=${provider:-auto}" >&2
  exec "$0" call "$prompt" --agent "$agent" ${provider:+--provider "$provider"}
}

cmd_call() {
  # cmdteam call 'prompt' --agent NAME [--provider P] [--model M] [--no-fallback] [--system S]
  require_jq
  local prompt="" agent="" provider="" model="" no_fallback="false" system=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent)      agent="$2"; shift 2;;
      --provider)   provider="$2"; shift 2;;
      --model)      model="$2"; shift 2;;
      --no-fallback) no_fallback="true"; shift;;
      --system)     system="$2"; shift 2;;
      -h|--help)    sed -n '2,8p' "$0"; return 0;;
      *)            prompt="${prompt:+$prompt }$1"; shift;;
    esac
  done
  if [[ -z "$prompt" || -z "$agent" ]]; then
    echo "usage: cmdteam call 'prompt' --agent NAME [--provider P] [--model M] [--no-fallback] [--system S]" >&2
    return 2
  fi

  log_jsonl "$(jq -n --arg ts "$(now_iso)" --arg agent "$agent" --arg provider "${provider:-auto}" --arg model "${model:-default}" \
    --arg event "start" '{event:$event, ts:$ts, agent:$agent, provider:$provider, model:$model}')"

  # Resolve provider/model via default_route when not specified (so logs show actual route)
  if [[ -z "$provider" || -z "$model" ]]; then
    local route
    route=$(default_route "$agent")
    provider="${provider:-${route%%|*}}"
    model="${model:-${route##*|}}"
  fi

  local response status="ok" usage_json="null"
  if ! response=$(llm_call "$agent" "$prompt" "$provider" "$model" "$no_fallback" "$system"); then
    status="error"
  fi
  # Treat as error only if response looks like a failure (specific signatures)
  if [[ -z "$response" \
        || "$response" == *"call failed"* \
        || "$response" == *"claude: call failed"* \
        || "$response" == *"openai: call failed"* \
        || "$response" == *"ollama: call failed"* \
        || "$response" == *"ERR "* \
        || "$response" == *": not found"* ]]; then
    status="error"
  fi
  # Extract __USAGE__:...JSON trailer from response (added by provider adapters)
  if [[ "$response" == *__USAGE__:* ]]; then
    usage_json="${response##*__USAGE__:}"
    # Strip the trailer from the visible response
    response="${response%__USAGE__:*}"
  fi
  # Capture latency (set by llm_call via env propagation)
  local latency_ms="${CMDTEAM_LAST_LATENCY_MS:-0}"
  log_call "$agent" "$provider" "$model" "$prompt" "$response" "$status" "$(jq -n --arg nf "$no_fallback" --arg sys "$system" --argjson lat "$latency_ms" --argjson usage "$usage_json" '{no_fallback:$nf, system:$sys, latency_ms:$lat, usage:$usage}')"
  printf '%s\n' "$response"
}

# ---------- Entrypoint ----------
case "${1:-}" in
  call)          shift; cmd_call "$@" ;;
  status)        shift; cmd_status ;;
  self-improve)  shift; cmd_self_improve ;;
  route)         shift; cmd_route "$@" ;;
  log)           shift; cmd_log "${1:-20}" ;;
  -h|--help|"")
    sed -n '2,8p' "$0"
    ;;
  *)
  echo "unknown subcommand: $1" >&2
  sed -n '2,8p' "$0" >&2
  exit 2
  ;;
esac