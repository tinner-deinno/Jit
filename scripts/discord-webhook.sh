#!/bin/bash
#
# Discord Webhook Integration for Jit Heartbeat
# 
# Sends heartbeat status to Discord with git commit link
# เรียนรู้จากการล้มเหลว: Discord ต้องเชื่อมต่อกับ git อย่างถูกต้อง
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════
BEAT_NUMBER=${1:-1}
STATUS=${2:-"ok"}
MESSAGE=${3:-"System heartbeat running normally"}
GITHUB_REPO="tinner-deinno/Jit"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# ═══════════════════════════════════════════════════════════════
# Load environment
# ═══════════════════════════════════════════════════════════════
if [[ -f /workspaces/Jit/.env ]]; then
    set +a
    source /workspaces/Jit/.env
    set -a
fi

DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
DISCORD_CHANNEL_ID="${DISCORD_CHANNEL_ID:-}"

# ═══════════════════════════════════════════════════════════════
# Get last commit hash
# ═══════════════════════════════════════════════════════════════
get_commit_hash() {
    cd /workspaces/Jit
    git log -1 --pretty=format:"%h" 2>/dev/null || echo "unknown"
}

# ═══════════════════════════════════════════════════════════════
# Get last commit message
# ═══════════════════════════════════════════════════════════════
get_commit_message() {
    cd /workspaces/Jit
    git log -1 --pretty=format:"%s" 2>/dev/null || echo "N/A"
}

# ═══════════════════════════════════════════════════════════════
# Send Discord webhook
# ═══════════════════════════════════════════════════════════════
send_discord_webhook() {
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        echo "⚠️  Discord webhook not configured (skipping)"
        return 0
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(get_commit_hash)
    local commit_msg=$(get_commit_message)
    local commit_url="https://github.com/$GITHUB_REPO/commit/$commit_hash"
    
    # Status emoji
    local emoji="🫀"
    if [[ "$STATUS" == "ok" ]]; then
        emoji="✅"
    elif [[ "$STATUS" == "warning" ]]; then
        emoji="⚠️ "
    elif [[ "$STATUS" == "critical" ]]; then
        emoji="🚨"
    fi
    
    # Build Discord embed
    local payload=$(cat <<EOF
{
  "content": "$emoji **Heartbeat #$BEAT_NUMBER** - $STATUS",
  "embeds": [{
    "title": "Jit Heartbeat #$BEAT_NUMBER",
    "description": "$MESSAGE",
    "color": $([ "$STATUS" = "ok" ] && echo "65280" || echo "16711680"),
    "fields": [
      {
        "name": "Time",
        "value": "$timestamp",
        "inline": true
      },
      {
        "name": "Status",
        "value": "$STATUS",
        "inline": true
      },
      {
        "name": "Latest Commit",
        "value": "[\`$commit_hash\`]($commit_url)",
        "inline": false
      },
      {
        "name": "Commit Message",
        "value": "$commit_msg",
        "inline": false
      }
    ],
    "footer": {
      "text": "Jit Agent System",
      "icon_url": "https://avatars.githubusercontent.com/u/123456789?s=32"
    }
  }]
}
EOF
)
    
    # Send to Discord
    local response=$(curl -s -X POST "$DISCORD_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "$payload" 2>&1)
    
    if echo "$response" | grep -q "204\|200"; then
        echo "✅ Discord notification sent (#$BEAT_NUMBER)"
        return 0
    else
        echo "⚠️  Discord notification failed: $response"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════
send_discord_webhook
