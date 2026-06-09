#!/bin/bash
#
# Install Hermes Discord Bot as systemd service
#
# Usage:
#   sudo bash scripts/install-hermes-discord-daemon.sh
#

set -euo pipefail

echo "🤖 Installing Hermes Discord Bot (อนุ) as systemd service..."

# ═══════════════════════════════════════════════════════════════
# Check permissions
# ═══════════════════════════════════════════════════════════════
if [[ "$EUID" -eq 0 ]]; then
    SERVICE_DIR="/etc/systemd/system"
    SCOPE="system"
else
    SERVICE_DIR="$HOME/.config/systemd/user"
    SCOPE="user"
    mkdir -p "$SERVICE_DIR"
fi

echo "📁 Service directory: $SERVICE_DIR ($SCOPE scope)"

# ═══════════════════════════════════════════════════════════════
# Check Discord token
# ═══════════════════════════════════════════════════════════════
if [[ -f /workspaces/Jit/.env ]]; then
    if grep -q "DISCORD_TOKEN=" /workspaces/Jit/.env; then
        echo "✅ DISCORD_TOKEN found in .env"
    else
        echo "⚠️  DISCORD_TOKEN not in .env"
        echo "    Add DISCORD_TOKEN to .env before running bot"
    fi
else
    echo "⚠️  .env not found - bot will fail without DISCORD_TOKEN"
fi

# ═══════════════════════════════════════════════════════════════
# Install hermes-discord dependencies
# ═══════════════════════════════════════════════════════════════
echo "📦 Installing Discord.js dependencies..."
cd /workspaces/Jit/hermes-discord
npm install --silent 2>/dev/null || npm install
echo "✅ Dependencies installed"

# ═══════════════════════════════════════════════════════════════
# Install systemd service
# ═══════════════════════════════════════════════════════════════
echo "📝 Installing systemd service file..."
sudo cp /workspaces/Jit/hermes-discord.service "$SERVICE_DIR/hermes-discord.service"
echo "✅ Service file installed to $SERVICE_DIR/hermes-discord.service"

# ═══════════════════════════════════════════════════════════════
# Reload systemd daemon
# ═══════════════════════════════════════════════════════════════
echo "🔄 Reloading systemd daemon..."
if [[ "$SCOPE" == "system" ]]; then
    sudo systemctl daemon-reload
else
    systemctl --user daemon-reload
fi
echo "✅ Daemon reloaded"

# ═══════════════════════════════════════════════════════════════
# Enable service (auto-start on boot)
# ═══════════════════════════════════════════════════════════════
echo "⚙️  Enabling service for auto-start..."
if [[ "$SCOPE" == "system" ]]; then
    sudo systemctl enable hermes-discord.service
else
    systemctl --user enable hermes-discord.service
fi
echo "✅ Service enabled"

# ═══════════════════════════════════════════════════════════════
# Start service
# ═══════════════════════════════════════════════════════════════
echo "🚀 Starting hermes discord bot..."
if [[ "$SCOPE" == "system" ]]; then
    sudo systemctl start hermes-discord.service
else
    systemctl --user start hermes-discord.service
fi
echo "✅ Service started"

# ═══════════════════════════════════════════════════════════════
# Show status
# ═══════════════════════════════════════════════════════════════
sleep 2
echo ""
echo "📊 Bot Status:"
if [[ "$SCOPE" == "system" ]]; then
    sudo systemctl status hermes-discord.service --no-pager || true
else
    systemctl --user status hermes-discord.service --no-pager || true
fi

echo ""
echo "🤖 Hermes Discord Bot installed and running!"
echo ""
echo "Commands:"
if [[ "$SCOPE" == "system" ]]; then
    echo "  systemctl status hermes-discord       - Show status"
    echo "  systemctl restart hermes-discord      - Restart"
    echo "  systemctl stop hermes-discord         - Stop"
    echo "  journalctl -u hermes-discord -f       - Watch logs"
else
    echo "  systemctl --user status hermes-discord       - Show status"
    echo "  systemctl --user restart hermes-discord      - Restart"
    echo "  systemctl --user stop hermes-discord         - Stop"
    echo "  journalctl --user -u hermes-discord -f       - Watch logs"
fi
