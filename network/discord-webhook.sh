#!/usr/bin/env bash
# network/discord-webhook.sh — Discord webhook sender for Jit system events
#
# JIT-019 FIX: JSON injection via commit messages
#
# VULNERABILITY (original): JSON payloads were constructed by interpolating
# bash variables directly into a heredoc (cat <<EOF ... $commit_msg ... EOF).
# A commit message containing '"', '\n', '\', or embedded JSON objects would:
#   1. Break the JSON structure (silent Discord failure)
#   2. Allow injection of additional JSON fields into the embed
#
# FIX: All user-controlled strings are passed via jq --arg, which provides
# automatic, guaranteed JSON escaping for every value. No string interpolation
# inside JSON templates.
#
# Uses: network/webhook-safe.sh (sourced for webhook_build_heartbeat_payload)
#
# Usage:
#   ./network/discord-webhook.sh <beat_number> <status> <message>
#   DISCORD_WEBHOOK=https://... ./network/discord-webhook.sh 1 ok "System running"
#
# Environment:
#   DISCORD_WEBHOOK   — Discord incoming webhook URL (required to send)
#   GITHUB_REPO       — owner/repo for commit links (default: tinner-deinno/Jit)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source safe encoding helpers (JIT-019)
# shellcheck source=network/webhook-safe.sh
source "$SCRIPT_DIR/webhook-safe.sh"

# ── Parameters ──────────────────────────────────────────────────────────
BEAT_NUMBER="${1:-1}"
STATUS="${2:-ok}"
MESSAGE="${3:-System heartbeat running normally}"
GITHUB_REPO="${GITHUB_REPO:-tinner-deinno/Jit}"

# ── Load optional .env ─────────────────────────────────────────────────
JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
if [[ -f "$JIT_ROOT/.env" ]]; then
  set +a
  # shellcheck source=/dev/null
  source "$JIT_ROOT/.env"
  set -a
fi

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

# ── Git helpers ─────────────────────────────────────────────────────────
_get_commit_hash() {
  git -C "$JIT_ROOT" log -1 --pretty=format:"%h" 2>/dev/null || echo "unknown"
}

_get_commit_message() {
  # NOTE: This value is UNTRUSTED — it comes from user-authored git commits.
  # It is passed to webhook_build_heartbeat_payload which uses jq --arg to
  # safely encode it. Never interpolate this value directly into JSON.
  git -C "$JIT_ROOT" log -1 --pretty=format:"%s" 2>/dev/null || echo "N/A"
}

# ── Main send function ──────────────────────────────────────────────────
send_discord_webhook() {
  if [[ -z "$DISCORD_WEBHOOK" ]]; then
    echo "Warning: Discord webhook not configured (DISCORD_WEBHOOK is unset) — skipping"
    return 0
  fi

  local commit_hash commit_msg commit_url
  commit_hash=$(_get_commit_hash)
  commit_msg=$(_get_commit_message)     # UNTRUSTED user content
  commit_url="https://github.com/$GITHUB_REPO/commit/$commit_hash"

  # ── SECURE JSON CONSTRUCTION (JIT-019 fix) ────────────────────────
  # webhook_build_heartbeat_payload uses jq --arg for every string value.
  # This eliminates JSON injection regardless of what $commit_msg contains.
  local payload
  payload=$(webhook_build_heartbeat_payload \
    "$BEAT_NUMBER" \
    "$STATUS"      \
    "$MESSAGE"     \
    "$commit_hash" \
    "$commit_url"  \
    "$commit_msg"  \
  )

  # Sanity-check: ensure we have valid JSON before sending
  if ! webhook_validate_json "$payload" 2>/dev/null; then
    echo "ERROR: Generated payload is not valid JSON — aborting send" >&2
    return 1
  fi

  # ── Send to Discord ────────────────────────────────────────────────
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    2>&1)

  case "$http_code" in
    200|204)
      echo "Discord notification sent (beat #$BEAT_NUMBER, status: $STATUS, HTTP: $http_code)"
      return 0
      ;;
    *)
      echo "Warning: Discord notification failed (HTTP $http_code, beat #$BEAT_NUMBER)" >&2
      return 1
      ;;
  esac
}

# ── Entry point ─────────────────────────────────────────────────────────
send_discord_webhook
