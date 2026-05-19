#!/usr/bin/env bash
# limbs/innova-bridge.sh — Mind-Body Bridge: Jit → innova-bot
#
# Connects Jit (mind) to innova-bot (body) via shared file system + optional MCP HTTP.
# Source this file then call the functions:
#   source limbs/innova-bridge.sh
#   bridge_publish_event "phase-3" "complete"
#   bridge_remember "architecture" "Use hexagonal ports/adapters"
#   bridge_search "phase"
#   bridge_status
#
# Environment variables:
#   INNOVA_BOT_ROOT   — path to innova-bot repo (auto-detected if not set)
#   INNOVA_BOT_SSE    — SSE endpoint (default: http://localhost:7010)
#   BRIDGE_DEBUG      — set to 1 for verbose output

# ── Auto-detect innova-bot root ──────────────────────────────────────────────
if [[ -z "$INNOVA_BOT_ROOT" ]]; then
  # Try Windows path via Git Bash / WSL
  if [[ -d "/c/Users/admin/DEV/PugAss1stant/innova-bot" ]]; then
    INNOVA_BOT_ROOT="/c/Users/admin/DEV/PugAss1stant/innova-bot"
  elif [[ -d "/mnt/c/Users/admin/DEV/PugAss1stant/innova-bot" ]]; then
    INNOVA_BOT_ROOT="/mnt/c/Users/admin/DEV/PugAss1stant/innova-bot"
  elif [[ -d "C:/Users/admin/DEV/PugAss1stant/innova-bot" ]]; then
    INNOVA_BOT_ROOT="C:/Users/admin/DEV/PugAss1stant/innova-bot"
  else
    INNOVA_BOT_ROOT="${HOME}/DEV/PugAss1stant/innova-bot"
  fi
fi
export INNOVA_BOT_ROOT
INNOVA_BOT_SSE="${INNOVA_BOT_SSE:-http://localhost:7010}"
BRIDGE_VERSION="1.0"

_bridge_log() { echo "[BRIDGE] $*"; }
_bridge_debug() { [[ "$BRIDGE_DEBUG" == "1" ]] && echo "[BRIDGE:DEBUG] $*"; }
_bridge_err()  { echo "[BRIDGE:ERR] $*" >&2; }

# ── bridge_publish_event <phase> <status> [message] ─────────────────────────
# Writes a JSON event file to innova-bot/events/
# Also tries MCP HTTP endpoint if innova-bot SSE is reachable
bridge_publish_event() {
  local phase="${1:?Usage: bridge_publish_event <phase> <status> [message]}"
  local status="${2:?}"
  local message="${3:-}"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "$(date)")

  local events_dir="${INNOVA_BOT_ROOT}/events"
  mkdir -p "$events_dir" || { _bridge_err "Cannot create $events_dir"; return 1; }

  local filename="${events_dir}/bridge-phase${phase}-${status}.json"
  cat > "$filename" <<EOF
{
  "phase": "$phase",
  "status": "$status",
  "message": "$message",
  "timestamp": "$ts",
  "from": "jit",
  "bridge_version": "$BRIDGE_VERSION"
}
EOF

  _bridge_log "event published → $(basename "$filename")"
  _bridge_debug "full path: $filename"

  # Optional: try MCP HTTP publish (non-fatal if down)
  if command -v curl &>/dev/null; then
    curl -s --max-time 3 -X POST "${INNOVA_BOT_SSE}/mcp/publish_event" \
      -H "Content-Type: application/json" \
      -d "{\"phase\":\"$phase\",\"status\":\"$status\",\"from\":\"jit\"}" \
      &>/dev/null && _bridge_debug "MCP HTTP event also sent" || true
  fi
}

# ── bridge_remember <topic> <content> ───────────────────────────────────────
# Writes a knowledge entry to innova-bot/workspace/
bridge_remember() {
  local topic="${1:?Usage: bridge_remember <topic> <content>}"
  local content="${2:?}"

  local workspace_dir="${INNOVA_BOT_ROOT}/workspace"
  mkdir -p "$workspace_dir" || { _bridge_err "Cannot create $workspace_dir"; return 1; }

  local filename="${workspace_dir}/jit-${topic}.txt"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "$(date)")

  cat > "$filename" <<EOF
# Jit Memory: $topic
# Written: $ts

$content
EOF

  _bridge_log "remembered → $(basename "$filename")"
}

# ── bridge_search <query> ────────────────────────────────────────────────────
# Searches events/ and workspace/ for query string
bridge_search() {
  local query="${1:?Usage: bridge_search <query>}"
  local found=0

  _bridge_log "searching for: '$query'"

  if [[ -d "${INNOVA_BOT_ROOT}/events" ]]; then
    local event_hits
    event_hits=$(grep -rl "$query" "${INNOVA_BOT_ROOT}/events/" 2>/dev/null)
    if [[ -n "$event_hits" ]]; then
      echo "  [events/]"
      echo "$event_hits" | while read -r f; do
        echo "    $(basename "$f"): $(grep -m1 "$query" "$f" 2>/dev/null | head -c 120)"
      done
      found=1
    fi
  fi

  if [[ -d "${INNOVA_BOT_ROOT}/workspace" ]]; then
    local ws_hits
    ws_hits=$(grep -rl "$query" "${INNOVA_BOT_ROOT}/workspace/" 2>/dev/null)
    if [[ -n "$ws_hits" ]]; then
      echo "  [workspace/]"
      echo "$ws_hits" | while read -r f; do
        echo "    $(basename "$f"): $(grep -m1 "$query" "$f" 2>/dev/null | head -c 120)"
      done
      found=1
    fi
  fi

  [[ $found -eq 0 ]] && _bridge_log "no matches found for '$query'"
  return 0
}

# ── bridge_status ────────────────────────────────────────────────────────────
# Shows innova-bot connection status and recent events
bridge_status() {
  _bridge_log "=== innova-bot bridge status ==="
  _bridge_log "INNOVA_BOT_ROOT: $INNOVA_BOT_ROOT"
  _bridge_log "INNOVA_BOT_SSE:  $INNOVA_BOT_SSE"
  _bridge_log "Bridge version:  $BRIDGE_VERSION"

  # Root exists?
  if [[ -d "$INNOVA_BOT_ROOT" ]]; then
    _bridge_log "repo: FOUND"
  else
    _bridge_err "repo: NOT FOUND at $INNOVA_BOT_ROOT"
    return 1
  fi

  # Events
  local events_dir="${INNOVA_BOT_ROOT}/events"
  if [[ -d "$events_dir" ]]; then
    local count
    count=$(find "$events_dir" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    _bridge_log "events: $count JSON files"
    find "$events_dir" -name "*.json" 2>/dev/null | sort | tail -5 | while read -r f; do
      echo "    $(basename "$f")"
    done
  else
    _bridge_log "events: dir not yet created"
  fi

  # Workspace
  local ws_dir="${INNOVA_BOT_ROOT}/workspace"
  if [[ -d "$ws_dir" ]]; then
    local wcount
    wcount=$(find "$ws_dir" -name "jit-*.txt" 2>/dev/null | wc -l | tr -d ' ')
    _bridge_log "workspace: $wcount jit-*.txt entries"
  else
    _bridge_log "workspace: dir not yet created"
  fi

  # Optional SSE reachability
  if command -v curl &>/dev/null; then
    local sse_status
    sse_status=$(curl -s --max-time 3 "${INNOVA_BOT_SSE}/health" 2>/dev/null | head -c 50)
    if [[ -n "$sse_status" ]]; then
      _bridge_log "SSE endpoint: UP ($sse_status)"
    else
      _bridge_log "SSE endpoint: DOWN (file-only mode active)"
    fi
  fi
}

# ── Auto-announce if run directly (not sourced) ──────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  CMD="${1:-status}"
  shift || true
  case "$CMD" in
    publish_event) bridge_publish_event "$@" ;;
    remember)      bridge_remember "$@" ;;
    search)        bridge_search "$@" ;;
    status)        bridge_status ;;
    *)
      echo "Usage: bash limbs/innova-bridge.sh <command> [args]"
      echo "  publish_event <phase> <status> [message]"
      echo "  remember <topic> <content>"
      echo "  search <query>"
      echo "  status"
      ;;
  esac
fi
