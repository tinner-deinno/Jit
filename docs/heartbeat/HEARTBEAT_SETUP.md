# 🫀 Enhanced Heartbeat System - Setup Guide

## Overview

The enhanced heartbeat system provides 24/7 monitoring with:
- ✅ MDES Ollama agent spawning for system analysis
- ✅ Discord integration via hermes bot
- ✅ Auto-commit/push on each heartbeat
- ✅ Failure detection and recovery logging

## Configuration

### 1. Set Discord Webhook (Required)

Add to `.env`:
```bash
# Discord webhook for heartbeat notifications
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
DISCORD_STATUS_CHANNEL_ID="YOUR_CHANNEL_ID"
DISCORD_TOKEN="YOUR_BOT_TOKEN"
```

### 2. Verify MDES Ollama Token

Check in `.env`:
```bash
OLLAMA_TOKEN="your_token_here"
OLLAMA_BASE_URL="https://ollama.mdes-innova.online"
```

### 3. Configure Heartbeat Interval

```bash
# In seconds (default 900 = 15 minutes)
PULSE_INTERVAL=900

# Or for testing: 60 seconds
PULSE_INTERVAL=60
```

## Usage

### Single Heartbeat Test
```bash
bash /workspaces/Jit/scripts/heartbeat-enhanced.sh once
```

### Check Status
```bash
bash /workspaces/Jit/scripts/heartbeat-enhanced.sh status
```

### Start 24/7 Monitor (Daemon)
```bash
bash /workspaces/Jit/scripts/heartbeat-enhanced.sh daemon &
```

### View Logs
```bash
tail -f /tmp/innova-heartbeat-enhanced.log
```

### View Failures
```bash
cat /tmp/innova-heartbeat-failed.log
```

## Heartbeat Lifecycle

```
Beat #N:
  1. IN (Diastole) ── Spawn MDES Ollama agent
                    ── Gather system state
                    ── Save results
  2. OUT (Systole) ── Send to Discord via hermes
                    ── Auto-commit to heartbeat-N branch
                    ── Auto-push to remote
  3. Sleep ───────── Wait for PULSE_INTERVAL seconds
  4. Repeat
```

## Files Generated

- `/tmp/innova-heartbeat-enhanced.log` - Main activity log
- `/tmp/innova-heartbeat-failed.log` - Failure events
- `/tmp/innova-heartbeat-state.json` - State persistence
- `/tmp/heartbeat-results/beat-N-in.txt` - Results per beat
- `/workspaces/Jit/memory/heartbeats/beat-N.md` - Git-tracked heartbeats

## Monitoring

### System Health Check
```bash
bash /workspaces/Jit/eval/body-check.sh
```

### Agent Status
```bash
bash /workspaces/Jit/eval/soul-check.sh
```

### Heart Rate Adjustment
To change heartbeat interval from agent:
```bash
echo "fast" > /tmp/heart-rate-request.txt
```

Valid modes: `sprint` (5m), `fast` (10m), `normal` (15m), `slow` (30m), `rest` (1h)

## Failure Recovery

If heartbeat fails 3+ consecutive times:
1. ❌ Heartbeat marked as DYING
2. 🚨 Critical alert sent to Discord
3. 📝 Failure reason logged with timestamp
4. ⚠️ Next beat analyzes root cause

### Common Failures

| Error | Cause | Solution |
|-------|-------|----------|
| `OLLAMA_TOKEN missing` | Token not in .env | Set OLLAMA_TOKEN in .env |
| `Ollama connection timeout` | API unreachable | Check OLLAMA_BASE_URL |
| `Discord webhook failed` | Invalid webhook | Regenerate Discord webhook |
| `Git push failed` | No internet | Check network connectivity |
| `Missing result file` | IN phase failed | Check MDES Ollama status |

## Systemd Integration (Optional)

Create `/etc/systemd/user/innova-heartbeat.service`:
```ini
[Unit]
Description=innova Heartbeat Monitor
After=network-online.target

[Service]
Type=simple
WorkingDirectory=/workspaces/Jit
ExecStart=/bin/bash /workspaces/Jit/scripts/heartbeat-enhanced.sh daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

Enable:
```bash
systemctl --user enable innova-heartbeat.service
systemctl --user start innova-heartbeat.service
```

## Discord Message Format

Each heartbeat sends an embed with:
- **Title**: 💓 Heartbeat #N
- **Description**: System status from Ollama
- **Color**: Green (success), Red (failure), Yellow (warning)
- **Timestamp**: UTC timestamp
- **Footer**: innova-bot attribution

## Customization

Edit `/workspaces/Jit/scripts/heartbeat-enhanced.sh` to:
- Change Ollama prompt
- Add custom Discord fields
- Modify commit messages
- Add pre/post-beat hooks

---

**Status**: Ready for 24/7 deployment ✅
