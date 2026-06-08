#!/usr/bin/env bash
# limbs/providers/claude.sh — Provider adapter: Anthropic Claude (via claude CLI / CommandCode proxy)
#
# Contract (shared by every adapter in limbs/providers/):
#   available                         → exit 0 if this provider can serve a call now
#   call <model_id> <system> <user>   → print completion to stdout; non-zero exit on failure
#
# Config is injected by the gateway (limbs/llm.sh) via environment:
#   PROVIDER_API_KEY   — Anthropic key (here: $COMMANDCODE_API_KEY — burns CommandCode tokens)
#   PROVIDER_CLI       — CLI binary name (default: claude)
#   PROVIDER_BASE_URL  — optional ANTHROPIC_BASE_URL override
#   PROVIDER_TIMEOUT   — seconds (default 120)
#
# Run standalone for debugging:
#   PROVIDER_API_KEY=$COMMANDCODE_API_KEY bash claude.sh call claude-haiku-4-5-20251001 "You are helpful" "Say hi"

set -uo pipefail

CLI="${PROVIDER_CLI:-claude}"
TIMEOUT="${PROVIDER_TIMEOUT:-120}"

case "${1:-}" in
  available)
    command -v "$CLI" >/dev/null 2>&1 || { echo "claude: CLI '$CLI' not found" >&2; exit 1; }
    [ -n "${PROVIDER_API_KEY:-}" ] || { echo "claude: PROVIDER_API_KEY empty (set COMMANDCODE_API_KEY)" >&2; exit 1; }
    exit 0
    ;;

  call)
    MODEL="${2:?model required}"
    SYSTEM="${3:-}"
    USER_PROMPT="${4:-}"

    # claude -p takes a single prompt string; fold the system prompt in as a header.
    FULL_PROMPT="$(printf '%s\n\n---\n\n%s' "$SYSTEM" "$USER_PROMPT")"

    # Build env for the call. COMMANDCODE_API_KEY is used as ANTHROPIC_API_KEY so the
    # call burns CommandCode proxy tokens, not the host's interactive session.
    declare -a ENVV=( "ANTHROPIC_API_KEY=$PROVIDER_API_KEY" )
    [ -n "${PROVIDER_BASE_URL:-}" ] && ENVV+=( "ANTHROPIC_BASE_URL=$PROVIDER_BASE_URL" )

    RESULT="$(timeout "$TIMEOUT" env "${ENVV[@]}" \
      "$CLI" -p --model "$MODEL" "$FULL_PROMPT" 2>/dev/null)"
    RC=$?

    if [ $RC -ne 0 ] || [ -z "$RESULT" ]; then
      echo "claude: call failed (exit=$RC model=$MODEL)" >&2
      exit 1
    fi
    printf '%s' "$RESULT"
    ;;

  *)
    echo "Usage: claude.sh {available|call <model> <system> <user>}" >&2
    exit 2
    ;;
esac
