#!/bin/bash
#
# Install Jit 24/7 Heartbeat as systemd service
#
# Usage:
#   sudo bash scripts/install-heartbeat-daemon.sh
#   OR
#   bash scripts/install-heartbeat-daemon.sh (user-level)
#

set -euo pipefail

echo "🫀 Installing Jit 24/7 Heartbeat Daemon..."

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
# Make scripts executable
# ═══════════════════════════════════════════════════════════════
chmod +x /workspaces/Jit/scripts/heartbeat-24h-daemon.sh
chmod +x /workspaces/Jit/scripts/heartbeat-enhanced.sh
echo "✅ Scripts are executable"

# ═══════════════════════════════════════════════════════════════
# Install systemd service
# ═══════════════════════════════════════════════════════════════
echo "📝 Installing systemd service file..."
sudo cp /workspaces/Jit/jit-heartbeat.service "$SERVICE_DIR/jit-heartbeat.service"
echo "✅ Service file installed to $SERVICE_DIR/jit-heartbeat.service"

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
    sudo systemctl enable jit-heartbeat.service
else
    systemctl --user enable jit-heartbeat.service
fi
echo "✅ Service enabled"

# ═══════════════════════════════════════════════════════════════
# Start service
# ═══════════════════════════════════════════════════════════════
echo "🚀 Starting heartbeat daemon..."
if [[ "$SCOPE" == "system" ]]; then
    sudo systemctl start jit-heartbeat.service
else
    systemctl --user start jit-heartbeat.service
fi
echo "✅ Service started"

# ═══════════════════════════════════════════════════════════════
# Show status
# ═══════════════════════════════════════════════════════════════
sleep 2
echo ""
echo "📊 Service Status:"
if [[ "$SCOPE" == "system" ]]; then
    sudo systemctl status jit-heartbeat.service --no-pager
else
    systemctl --user status jit-heartbeat.service --no-pager
fi

echo ""
echo "🫀 Heartbeat daemon installed and running!"
echo ""
echo "Commands:"
if [[ "$SCOPE" == "system" ]]; then
    echo "  systemctl status jit-heartbeat     - Show status"
    echo "  systemctl restart jit-heartbeat    - Restart"
    echo "  systemctl stop jit-heartbeat       - Stop"
    echo "  journalctl -u jit-heartbeat -f     - Watch logs"
else
    echo "  systemctl --user status jit-heartbeat     - Show status"
    echo "  systemctl --user restart jit-heartbeat    - Restart"
    echo "  systemctl --user stop jit-heartbeat       - Stop"
    echo "  journalctl --user -u jit-heartbeat -f     - Watch logs"
fi
