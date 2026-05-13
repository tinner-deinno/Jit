#!/bin/bash
#
# Hermes Discord Status Reporter
# 
# Sends heartbeat status + system summary to Discord
# Called by heartbeat daemon on each beat
#
# Usage:
#   bash scripts/hermes-report-status.sh <beat_number> <status> <message>
#

set -euo pipefail

source /workspaces/Jit/limbs/lib.sh

# ═══════════════════════════════════════════════════════════════
# Parameters
# ═══════════════════════════════════════════════════════════════
BEAT_NUMBER=${1:-1}
STATUS=${2:-"ok"}
MESSAGE=${3:-"System heartbeat running normally"}
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
JITPID=$(cat /tmp/innova-heartbeat-daemon.json 2>/dev/null | jq -r '.daemon_pid // "unknown"' 2>/dev/null || echo "unknown")

# ═══════════════════════════════════════════════════════════════
# Load environment
# ═══════════════════════════════════════════════════════════════
if [[ -f /workspaces/Jit/.env ]]; then
    set +a
    source /workspaces/Jit/.env
    set -a
fi

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
HERMES_STATUS_CHANNEL="${DISCORD_STATUS_CHANNEL_ID:-}"

# ═══════════════════════════════════════════════════════════════
# Get system summary (for hermes to report)
# ═══════════════════════════════════════════════════════════════
get_system_summary() {
    local output=""
    
    # Agent status
    output+="📊 **Jit System Summary**\n"
    output+="⏰ Time: $TIMESTAMP\n"
    output+="💓 Heartbeat #$BEAT_NUMBER\n"
    
    # Check running services
    if pgrep -f "heartbeat-24h-daemon" >/dev/null 2>&1; then
        output+="✅ Heartbeat daemon: running\n"
    else
        output+="❌ Heartbeat daemon: NOT running\n"
    fi
    
    if pgrep -f "hermes-discord.*bot.js" >/dev/null 2>&1; then
        output+="✅ Hermes discord bot: running\n"
    else
        output+="⚠️  Hermes discord bot: NOT running\n"
    fi
    
    # Get git info
    local last_commit=$(cd /workspaces/Jit && git log -1 --pretty=format:"%h — %s" 2>/dev/null || echo "unknown")
    output+="📝 Latest commit: $last_commit\n"
    
    # Get uptime
    if [[ -f /tmp/innova-heartbeat-daemon.json ]]; then
        local uptime=$(cat /tmp/innova-heartbeat-daemon.json | jq -r '.uptime_seconds // "unknown"' 2>/dev/null || echo "unknown")
        output+="⏱️  Heartbeat uptime: ${uptime}s\n"
    fi
    
    echo -e "$output"
}

# ═══════════════════════════════════════════════════════════════
# Send to Discord via webhook
# ═══════════════════════════════════════════════════════════════
send_discord_report() {
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        return 0  # Silent fail if no webhook
    fi
    
    local summary=$(get_system_summary)
    
    # Status color
    local color="65280"  # green
    if [[ "$STATUS" == "warning" ]]; then
        color="16776960"  # yellow
    elif [[ "$STATUS" == "critical" ]]; then
        color="16711680"  # red
    fi
    
    local payload=$(cat <<EOF
{
  "content": "🤖 **Hermes Status Report** — Heartbeat #$BEAT_NUMBER",
  "embeds": [{
    "title": "Jit System Status",
    "description": "$MESSAGE",
    "color": $color,
    "fields": [
      {
        "name": "Status",
        "value": "$STATUS",
        "inline": true
      },
      {
        "name": "Time",
        "value": "$TIMESTAMP",
        "inline": true
      },
      {
        "name": "System Summary",
        "value": "$summary",
        "inline": false
      }
    ],
    "footer": {
      "text": "อนุ — innova's child on Discord"
    }
  }]
}
EOF
)
    
    curl -s -X POST "$DISCORD_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "$payload" >/dev/null 2>&1 || true
}

# ═══════════════════════════════════════════════════════════════
# Check hermes discord bot health
# ═══════════════════════════════════════════════════════════════
check_hermes_health() {
    if pgrep -f "hermes-discord.*bot.js" >/dev/null 2>&1; then
        return 0  # healthy
    else
        # Try to restart
        if command -v systemctl &>/dev/null; then
            if systemctl is-active --quiet hermes-discord 2>/dev/null; then
                return 0
            else
                systemctl restart hermes-discord 2>/dev/null || true
            fi
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
main() {
    # Check and restart hermes if needed
    check_hermes_health
    
    # Send report to Discord
    send_discord_report
}

main "$@"
