#!/usr/bin/env bash
# network/webhook-safe.sh — Safe JSON encoding helpers for webhook payloads
#
# JIT-019: Prevents JSON injection via commit messages and other user-controlled
# strings by routing all string values through jq --arg (automatic escaping).
#
# Usage (source this file to get helpers):
#   source network/webhook-safe.sh
#   payload=$(webhook_safe_payload "1" "ok" "System running" "abc1234" "Fix: \"quoted\"")
#
# Direct CLI:
#   ./webhook-safe.sh encode "string with \"quotes\" and\nnewlines"
#   ./webhook-safe.sh build-heartbeat <beat> <status> <msg> <hash> <url> <commit_msg>
#   ./webhook-safe.sh validate <json_string>

set -euo pipefail

# ── Dependency check ───────────────────────────────────────────────────
_require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed. Install with: apt-get install -y jq" >&2
    exit 1
  fi
  local jq_ver
  jq_ver=$(jq --version 2>&1 | sed 's/jq-//')
  # Require jq >= 1.5 (--arg support)
  if [[ "$(printf '%s\n' "1.5" "$jq_ver" | sort -V | head -1)" != "1.5" ]]; then
    echo "WARNING: jq version $jq_ver may be too old; 1.5+ recommended" >&2
  fi
}

# ── Safe JSON string encode ─────────────────────────────────────────────
# Encodes a single string value to a JSON string (including the surrounding quotes).
# Input:  raw string (may contain quotes, newlines, backslashes, unicode, etc.)
# Output: JSON-encoded string, e.g.: "He said \"hello\"\n"
#
# Usage: encoded=$(webhook_encode_string "raw value")
webhook_encode_string() {
  local raw="$1"
  printf '%s' "$raw" | jq -Rs .
}

# ── Build Discord heartbeat payload (safe) ─────────────────────────────
# All string arguments are passed via jq --arg, which guarantees proper
# JSON escaping. No variable is interpolated into a JSON heredoc.
#
# Args:
#   $1 beat_number   — heartbeat sequence number
#   $2 status        — "ok" | "warning" | "critical"
#   $3 message       — human-readable status message
#   $4 commit_hash   — short git hash (e.g. "abc1234")
#   $5 commit_url    — full GitHub commit URL
#   $6 commit_msg    — git commit subject line (UNTRUSTED — may contain injection payload)
#
# Returns: valid JSON string on stdout; exits 1 on jq error
webhook_build_heartbeat_payload() {
  local beat_number="$1"
  local status="$2"
  local message="$3"
  local commit_hash="$4"
  local commit_url="$5"
  local commit_msg="$6"

  _require_jq

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Map status to emoji and color
  local emoji color_code
  case "$status" in
    ok)       emoji="✅";  color_code="65280"   ;;
    warning)  emoji="⚠️ "; color_code="16776960" ;;
    critical) emoji="🚨";  color_code="16711680" ;;
    *)        emoji="🫀";  color_code="8421504"  ;;
  esac

  # jq --arg passes every value as a safe JSON string; no shell-level
  # interpolation of user data occurs inside the jq filter.
  jq -n \
    --arg emoji       "$emoji"       \
    --arg beat        "$beat_number" \
    --arg status      "$status"      \
    --arg msg         "$message"     \
    --arg ts          "$timestamp"   \
    --arg hash        "$commit_hash" \
    --arg url         "$commit_url"  \
    --arg commit_msg  "$commit_msg"  \
    --arg color       "$color_code"  \
  '{
    content: "\($emoji) **Heartbeat #\($beat)** - \($status)",
    embeds: [{
      title: "Jit Heartbeat #\($beat)",
      description: $msg,
      color: ($color | tonumber),
      fields: [
        { name: "Time",           value: $ts,         inline: true  },
        { name: "Status",         value: $status,     inline: true  },
        { name: "Latest Commit",  value: "[`\($hash)`](\($url))",
                                                      inline: false },
        { name: "Commit Message", value: $commit_msg, inline: false }
      ],
      footer: {
        text:     "Jit Agent System",
        icon_url: "https://avatars.githubusercontent.com/u/123456789?s=32"
      }
    }]
  }'
}

# ── Validate JSON ───────────────────────────────────────────────────────
# Returns 0 if input is valid JSON, 1 otherwise.
# Usage: webhook_validate_json "$payload" && echo "ok" || echo "invalid"
webhook_validate_json() {
  local json_input="$1"
  echo "$json_input" | jq empty 2>/dev/null
}

# ── CLI entry point ─────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  CMD="${1:-help}"
  shift || true

  case "$CMD" in

    encode)
      # Encode a raw string to a JSON string value
      # Usage: ./webhook-safe.sh encode "raw string"
      RAW="${1:-}"
      if [[ -z "$RAW" ]]; then
        echo "Usage: webhook-safe.sh encode <raw_string>" >&2
        exit 1
      fi
      webhook_encode_string "$RAW"
      ;;

    build-heartbeat)
      # Build full heartbeat payload
      # Usage: ./webhook-safe.sh build-heartbeat <beat> <status> <msg> <hash> <url> <commit_msg>
      if [[ $# -lt 6 ]]; then
        echo "Usage: webhook-safe.sh build-heartbeat <beat> <status> <msg> <hash> <url> <commit_msg>" >&2
        exit 1
      fi
      webhook_build_heartbeat_payload "$1" "$2" "$3" "$4" "$5" "$6"
      ;;

    validate)
      # Validate a JSON string
      # Usage: ./webhook-safe.sh validate '{"key":"value"}'
      JSON="${1:-}"
      if [[ -z "$JSON" ]]; then
        echo "Usage: webhook-safe.sh validate <json_string>" >&2
        exit 1
      fi
      if webhook_validate_json "$JSON"; then
        echo "valid JSON"
        exit 0
      else
        echo "INVALID JSON" >&2
        exit 1
      fi
      ;;

    help|*)
      cat <<'HELP'
network/webhook-safe.sh — Safe JSON encoding for Discord webhook payloads

Commands:
  encode <raw_string>
      JSON-encode a single string value (safe for user-controlled input).

  build-heartbeat <beat> <status> <msg> <hash> <url> <commit_msg>
      Build a complete Discord heartbeat payload using jq --arg encoding.
      All string values are automatically escaped; no JSON injection possible.

  validate <json_string>
      Verify that a JSON string parses without error.

Source this file to use webhook_build_heartbeat_payload() and
webhook_encode_string() in other scripts.

Security note (JIT-019):
  All user-controlled strings (commit messages, status, message body) are
  passed via jq --arg, which handles: double quotes, newlines, backslashes,
  tab characters, Unicode, and embedded JSON payloads safely.
HELP
      ;;
  esac
fi
