#!/usr/bin/env bash
# limbs/llm.sh — ปัญญากลาง: Unified multi-provider LLM Gateway for มนุษย์ Agent
#
# หลักพุทธ: สัมมาทิฏฐิ (Right View) — เห็นทางที่ถูก เลือกเครื่องมือให้เหมาะกับงาน
#
# ONE entrypoint that every agent uses to reach ANY model on ANY provider.
# Solves the old split where prompt_proxy.sh could only reach Claude and
# ollama.sh could only reach MDES — with no bridge, no per-agent routing,
# and no failover between them.
#
# Pattern (proven on GitHub):
#   • LiteLLM (BerriAI/litellm)  — one interface, `provider/model` strings, fallback lists
#   • OpenRouter                 — provider routing + automatic failover
#   • Claude Code subagents      — per-agent model override
#
# Resolution order for every call:
#   1. explicit  --provider P  [--model M]
#   2. a `provider/model` string as the model arg   (e.g. claude/sonnet, ollama/gemma4:26b)
#   3. per-agent entry in config/providers.json `agents`   (via --agent NAME)
#   4. `default_agent`
# If the chosen provider is unavailable or errors, the gateway walks the
# agent's `fallback` chain automatically (unless --no-fallback).
#
# Usage:
#   llm.sh call "prompt" [--agent NAME] [--provider P] [--model M] [--no-fallback] [--system "..."]
#   llm.sh route "prompt" [--agent NAME] [--provider P] [--model M]   # dry-run: show the plan
#   llm.sh providers                 # list providers + live availability
#   llm.sh agents                    # show the per-agent provider/model map
#   llm.sh chain <agent>             # show an agent's full candidate chain
#   llm.sh status                    # health-probe every provider
#
# Examples:
#   bash limbs/llm.sh call "สรุป repo นี้" --agent soma
#   bash limbs/llm.sh call "hello" --model ollama/gemma4:26b
#   bash limbs/llm.sh call "fix this bug" --provider claude --model haiku

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
source "$SCRIPT_DIR/agent_filter.sh" 2>/dev/null || true

JIT_ROOT="${JIT_ROOT:-$SCRIPT_DIR/..}"
PROVIDERS_JSON="${PROVIDERS_JSON:-$JIT_ROOT/config/providers.json}"

# Load .env so provider key envs (COMMANDCODE_API_KEY, OLLAMA_TOKEN, OPENAI_API_KEY...) are present.
if [ -f "$JIT_ROOT/.env" ]; then set -a; source "$JIT_ROOT/.env"; set +a; fi

[ -f "$PROVIDERS_JSON" ] || { err "ไม่พบ config: $PROVIDERS_JSON"; exit 1; }

# ─── _resolve: emit ordered candidate rows (TSV) for a request ──────────────
# Columns: rank \t role \t provider \t model_id \t adapter \t key_env \t base_url \t base_url_env \t cli \t timeout \t enabled
_resolve() {
  local agent="$1" flag_provider="$2" flag_model="$3" model_string="$4" no_fallback="$5"
  CFG="$PROVIDERS_JSON" AGENT="$agent" FLAG_PROVIDER="$flag_provider" \
  FLAG_MODEL="$flag_model" MODEL_STRING="$model_string" NO_FALLBACK="$no_fallback" \
  python3 - <<'PY'
import json, os, sys

cfg = json.load(open(os.environ["CFG"]))
providers = cfg.get("providers", {})
agents = cfg.get("agents", {})
default_agent = cfg.get("default_agent", {"provider": "claude", "model": "default", "fallback": []})
default_chain = cfg.get("default_chain", [])

agent         = os.environ.get("AGENT", "")
flag_provider = os.environ.get("FLAG_PROVIDER", "")
flag_model    = os.environ.get("FLAG_MODEL", "")
model_string  = os.environ.get("MODEL_STRING", "")
no_fallback   = os.environ.get("NO_FALLBACK", "") == "1"

PREFIX = [("claude-", "claude"), ("gpt-", "openai"), ("o3", "openai"),
          ("o1", "openai"), ("gemma", "ollama"), ("llama", "ollama"), ("qwen", "ollama")]

def infer_provider(model_id):
    for pre, prov in PREFIX:
        if model_id.startswith(pre):
            return prov
    return None

def model_id_for(provider, alias):
    block = providers.get(provider, {})
    models = block.get("models", {})
    if not alias:
        return models.get("default", alias or "default")
    return models.get(alias, alias)  # known alias → id; else treat alias as concrete id

# ── pick primary (provider, alias) and a fallback spec list ──
primary_provider, primary_alias = None, None
fallback_specs = []

if flag_provider:
    primary_provider, primary_alias = flag_provider, (flag_model or None)
elif model_string:
    if "/" in model_string:
        p, m = model_string.split("/", 1)
        primary_provider, primary_alias = p, m
    elif model_string in providers:
        primary_provider, primary_alias = model_string, None
    else:
        prov = infer_provider(model_string)
        primary_provider = prov or default_agent.get("provider", "claude")
        primary_alias = model_string  # concrete id passthrough
elif agent and agent in agents:
    a = agents[agent]
    primary_provider, primary_alias = a.get("provider"), a.get("model")
    fallback_specs = list(a.get("fallback", []))
else:
    primary_provider = default_agent.get("provider", "claude")
    primary_alias = default_agent.get("model")
    fallback_specs = list(default_agent.get("fallback", []))

# If primary came from a flag/string (no agent), still give resilience from default_chain.
if not fallback_specs and not no_fallback:
    fallback_specs = [p for p in default_chain if p != primary_provider]

if no_fallback:
    fallback_specs = []

# ── build ordered candidate list ──
def spec_to_pair(spec):
    # "provider" or "provider:model"
    if ":" in spec:
        p, m = spec.split(":", 1)
        return p, m
    return spec, None

candidates = [("PRIMARY", primary_provider, primary_alias)]
for i, spec in enumerate(fallback_specs):
    p, m = spec_to_pair(spec)
    candidates.append((f"fallback#{i+1}", p, m))

seen = set()
rank = 0
for role, prov, alias in candidates:
    block = providers.get(prov)
    if block is None:
        continue
    mid = model_id_for(prov, alias)
    key = (prov, mid)
    if key in seen:
        continue
    seen.add(key)
    rank += 1
    row = [
        str(rank), role, prov, mid,
        block.get("adapter", ""),
        block.get("api_key_env", ""),
        block.get("base_url", ""),
        block.get("base_url_env", ""),
        block.get("cli", ""),
        str(block.get("timeout", "")),
        "1" if block.get("enabled", True) else "0",
    ]
    print("\x1f".join(row))
PY
}

# ─── _build_system: agent role filter (if any) as the system prompt ─────────
_build_system() {
  local agent="$1" explicit="$2"
  if [ -n "$explicit" ]; then printf '%s' "$explicit"; return; fi
  if [ -n "$agent" ] && declare -f get_agent_filter >/dev/null 2>&1; then
    get_agent_filter "$agent" 2>/dev/null
  else
    printf '%s' "คุณคือผู้ช่วย AI ของระบบ มนุษย์ Agent (Jit) โดย MDES-Innova. ตอบอย่างชัดเจน มีโครงสร้าง สรุปผลเป็นภาษาไทย."
  fi
}

# ─── _provider_available: check one candidate row's provider ────────────────
# Args: adapter key_env base_url base_url_env cli timeout
_provider_available() {
  local adapter="$1" key_env="$2" base_url="$3" base_url_env="$4" cli="$5" timeout="$6"
  local key="" bu="$base_url"
  [ -n "$key_env" ] && key="${!key_env:-}"
  [ -n "$base_url_env" ] && bu="${!base_url_env:-$base_url}"
  PROVIDER_API_KEY="$key" PROVIDER_BASE_URL="$bu" PROVIDER_CLI="$cli" \
    PROVIDER_TIMEOUT="${timeout:-}" \
    bash "$JIT_ROOT/$adapter" available 2>/dev/null
}

# ─── _provider_call: invoke one candidate ───────────────────────────────────
# Args: adapter key_env base_url base_url_env cli timeout model system user
_provider_call() {
  local adapter="$1" key_env="$2" base_url="$3" base_url_env="$4" cli="$5" timeout="$6"
  local model="$7" system="$8" user="$9"
  local key="" bu="$base_url"
  [ -n "$key_env" ] && key="${!key_env:-}"
  [ -n "$base_url_env" ] && bu="${!base_url_env:-$base_url}"
  PROVIDER_API_KEY="$key" PROVIDER_BASE_URL="$bu" PROVIDER_CLI="$cli" \
    PROVIDER_TIMEOUT="${timeout:-120}" \
    bash "$JIT_ROOT/$adapter" call "$model" "$system" "$user"
}

# ─── _global_max: read concurrency.global_max ───────────────────────────────
_global_max() {
  CFG="$PROVIDERS_JSON" python3 -c '
import json, os
c = json.load(open(os.environ["CFG"])).get("concurrency", {})
print(int(c.get("global_max", 0)))' 2>/dev/null || echo 0
}
_lock_timeout() {
  CFG="$PROVIDERS_JSON" python3 -c '
import json, os
c = json.load(open(os.environ["CFG"])).get("concurrency", {})
print(int(c.get("lock_timeout_seconds", 30)))' 2>/dev/null || echo 30
}

# ─── _with_global_slot: cap total concurrent calls across all agents ────────
# _with_global_slot <max> <command...>
_with_global_slot() {
  local max="$1"; shift
  if [ "${max:-0}" -le 0 ] || ! command -v flock >/dev/null 2>&1; then "$@"; return $?; fi
  mkdir -p "$JIT_LOCK_DIR/slots" 2>/dev/null
  local i fd
  for ((i=0; i<max; i++)); do
    exec {fd}>"$JIT_LOCK_DIR/slots/$i.lock"
    if flock -n "$fd"; then
      "$@"; local rc=$?
      flock -u "$fd"; eval "exec ${fd}>&-"
      return $rc
    fi
    eval "exec ${fd}>&-"
  done
  # all slots busy → wait on slot 0
  exec {fd}>"$JIT_LOCK_DIR/slots/0.lock"
  flock -w 60 "$fd" 2>/dev/null || true
  "$@"; local rc=$?
  flock -u "$fd" 2>/dev/null; eval "exec ${fd}>&-"
  return $rc
}

# ─── _attempt: walk candidate rows, call first available, print result ──────
# Reads rows from global $CANDIDATES; uses $SYSTEM, $USER_PROMPT, $LOG_AGENT.
_attempt() {
  local tried=0 row
  while IFS=$'\x1f' read -r rank role provider model adapter key_env base_url base_url_env cli timeout enabled; do
    [ -z "${provider:-}" ] && continue
    if [ "$enabled" != "1" ]; then
      warn "ข้าม $provider (disabled)" >&2; continue
    fi
    tried=$((tried+1))
    step "[$role] ลอง $provider/$model ..." >&2
    if ! _provider_available "$adapter" "$key_env" "$base_url" "$base_url_env" "$cli" "$timeout"; then
      warn "$provider ไม่พร้อม → fallback" >&2
      log_action "LLM_SKIP" "agent=$LOG_AGENT provider=$provider model=$model reason=unavailable"
      continue
    fi
    local out
    out="$(_provider_call "$adapter" "$key_env" "$base_url" "$base_url_env" "$cli" "$timeout" "$model" "$SYSTEM" "$USER_PROMPT")"
    if [ $? -eq 0 ] && [ -n "$out" ]; then
      printf '%s' "$out"
      log_action "LLM_OK" "agent=$LOG_AGENT provider=$provider model=$model role=$role chars=${#out}"
      return 0
    fi
    warn "$provider ตอบไม่สำเร็จ → fallback" >&2
    log_action "LLM_FAIL" "agent=$LOG_AGENT provider=$provider model=$model role=$role"
  done <<< "$CANDIDATES"
  err "ทุก provider ล้มเหลว (ลองไป $tried ตัว) — agent=$LOG_AGENT"
  log_action "LLM_EXHAUSTED" "agent=$LOG_AGENT tried=$tried"
  return 1
}

# ════════════════════════════════════════════════════════════════════════════
#  CLI
# ════════════════════════════════════════════════════════════════════════════
CMD="${1:-help}"; shift || true

# shared flag parser → AGENT PROVIDER MODEL MODEL_STRING NO_FALLBACK SYSTEM PROMPT
_parse_flags() {
  AGENT=""; FPROVIDER=""; FMODEL=""; MSTRING=""; NOFB="0"; SYS=""; PROMPT=""
  local positional=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --agent)        AGENT="${2:-}"; shift 2 ;;
      --provider|-p)  FPROVIDER="${2:-}"; shift 2 ;;
      --model|-m)
        # accept "provider/model" here too
        if [[ "${2:-}" == */* ]]; then MSTRING="${2:-}"; else FMODEL="${2:-}"; fi
        shift 2 ;;
      --system|-s)    SYS="${2:-}"; shift 2 ;;
      --no-fallback)  NOFB="1"; shift ;;
      --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
      *)  positional+=("$1"); shift ;;
    esac
  done
  PROMPT="${positional[*]:-}"
  # A bare --model with no --provider is a model SELECTOR, not an alias: it may be a
  # provider name, a "provider/model" string, or a bare id whose provider is inferred
  # by prefix (gpt-*→openai, claude-*→claude, gemma*→ollama). Hand it to the resolver
  # as MODEL_STRING. With --provider set, --model stays an alias for that provider.
  if [ -z "$FPROVIDER" ] && [ -n "$FMODEL" ] && [ -z "$MSTRING" ]; then
    MSTRING="$FMODEL"; FMODEL=""
  fi
}

case "$CMD" in

  call)
    _parse_flags "$@"
    [ -n "$PROMPT" ] || { err "ต้องระบุ prompt: llm.sh call \"ข้อความ\" [--agent NAME]"; exit 1; }

    CANDIDATES="$(_resolve "$AGENT" "$FPROVIDER" "$FMODEL" "$MSTRING" "$NOFB")"
    [ -n "$CANDIDATES" ] || { err "ไม่สามารถ resolve provider ได้ (ตรวจ config/providers.json)"; exit 1; }

    SYSTEM="$(_build_system "$AGENT" "$SYS")"
    USER_PROMPT="$PROMPT"
    LOG_AGENT="${AGENT:-anon}"

    GMAX="$(_global_max)"; LTO="$(_lock_timeout)"
    # per-agent lock (no collision) inside a global concurrency slot (no stampede)
    _with_global_slot "$GMAX" jit_with_lock "llm-$LOG_AGENT" "$LTO" -- _attempt
    exit $?
    ;;

  route)
    _parse_flags "$@"
    CANDIDATES="$(_resolve "$AGENT" "$FPROVIDER" "$FMODEL" "$MSTRING" "$NOFB")"
    echo ""
    echo -e "${BOLD}── Routing plan${AGENT:+ for agent '$AGENT'} ─────────────────────${RESET}"
    if [ -z "$CANDIDATES" ]; then err "no candidates"; exit 1; fi
    while IFS=$'\x1f' read -r rank role provider model adapter key_env base_url base_url_env cli timeout enabled; do
      [ -z "${provider:-}" ] && continue
      if _provider_available "$adapter" "$key_env" "$base_url" "$base_url_env" "$cli" "$timeout"; then
        avail="${GREEN}available${RESET}"
      else
        avail="${RED}unavailable${RESET}"
      fi
      printf "  %s %-9s → %-7s / %-28s [%b]\n" "$rank" "$role" "$provider" "$model" "$avail"
    done <<< "$CANDIDATES"
    echo ""
    ;;

  providers)
    echo ""
    echo -e "${BOLD}── Providers ──────────────────────────────────────────${RESET}"
    CFG="$PROVIDERS_JSON" python3 -c '
import json, os
p = json.load(open(os.environ["CFG"]))["providers"]
for name, b in p.items():
    print("\x1f".join([name, b.get("adapter",""), b.get("api_key_env",""),
                     b.get("base_url",""), b.get("base_url_env",""), b.get("cli",""),
                     "1" if b.get("enabled",True) else "0"]))' | \
    while IFS=$'\x1f' read -r name adapter key_env base_url base_url_env cli enabled; do
      if _provider_available "$adapter" "$key_env" "$base_url" "$base_url_env" "$cli" ""; then
        st="${GREEN}● ready${RESET}"
      else
        st="${YELLOW}○ not ready${RESET}"
      fi
      [ "$enabled" = "1" ] || st="${RED}✗ disabled${RESET}"
      printf "  %-8s %b  (key:%s cli:%s)\n" "$name" "$st" "${key_env:-–}" "${cli:-–}"
    done
    echo ""
    ;;

  agents)
    echo ""
    echo -e "${BOLD}── Per-agent routing (config/providers.json) ──────────${RESET}"
    CFG="$PROVIDERS_JSON" python3 -c '
import json, os
c = json.load(open(os.environ["CFG"]))
for name, a in c.get("agents", {}).items():
    fb = ",".join(a.get("fallback", [])) or "–"
    print("  %-15s → %-7s / %-7s  fallback: %s" % (name, a.get("provider"), a.get("model"), fb))
d = c.get("default_agent", {})
print("  %-15s → %-7s / %-7s  fallback: %s" % ("(default)", d.get("provider"), d.get("model"), ",".join(d.get("fallback",[])) or "–"))'
    echo ""
    ;;

  chain)
    AG="${1:-}"
    [ -n "$AG" ] || { err "ใช้: llm.sh chain <agent>"; exit 1; }
    CANDIDATES="$(_resolve "$AG" "" "" "" "0")"
    echo -e "${BOLD}Candidate chain for '$AG':${RESET}"
    while IFS=$'\x1f' read -r rank role provider model rest; do
      [ -z "${provider:-}" ] && continue
      printf "  %s. %-9s %s/%s\n" "$rank" "$role" "$provider" "$model"
    done <<< "$CANDIDATES"
    ;;

  status)
    echo -e "${BOLD}LLM Gateway — provider health${RESET}"
    bash "$0" providers
    ;;

  help|--help|-h)
    sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
    ;;

  *)
    err "คำสั่งไม่รู้จัก: '$CMD' — ลอง: llm.sh help"
    exit 1
    ;;
esac
