# 🤖 Hermes Discord Bot — Quick Start (3 steps)

## 🎯 What It Does

- ✅ Runs 24/7 on Discord
- ✅ Reports heartbeat status every 15 min
- ✅ Responds to mentions with MDES Ollama AI
- ✅ Never crashes (auto-restart on failure)
- ✅ Integrated with heartbeat daemon

---

## ⚡ Install (5 minutes)

### Step 1: Set Discord Token

```bash
cd /workspaces/Jit

# Add Discord token to .env:
echo "DISCORD_TOKEN=your_bot_token_here" >> .env
```

**Get bot token**:
1. Go to https://discord.com/developers/applications
2. Create bot "อนุ"
3. Copy token from Bot page
4. Paste above

### Step 2: Install as Daemon

```bash
sudo bash scripts/install-hermes-discord-daemon.sh
```

This will:
- Install discord.js dependencies
- Create systemd service
- Auto-start bot
- Show status

### Step 3: Verify It's Running

```bash
systemctl status hermes-discord

# Expected:
# ● hermes-discord.service
#   Active: active (running)
```

---

## ✨ What Happens Now

### Automatic (Every 15 min)
```
Heartbeat #1 runs
  ├─ System analysis
  ├─ Git commit + push
  └─ Tell Hermes to report status
         └─ Discord message sent:
            "🤖 Heartbeat #1 ✅ All systems running"
```

### Manual (On Discord)
```
@อนุ สอบถาม
└─ Bot responds with Ollama AI (Thai language)
```

---

## 📊 Commands

### Check Status
```bash
systemctl status hermes-discord
```

### View Logs
```bash
journalctl -u hermes-discord -f
```

### Restart
```bash
sudo systemctl restart hermes-discord
```

### Stop
```bash
sudo systemctl stop hermes-discord
```

---

## 🐛 Troubleshooting

**Bot not running?**
```bash
# Check logs
journalctl -u hermes-discord -n 20

# Check token is set
cat /workspaces/Jit/.env | grep DISCORD_TOKEN

# Restart
sudo systemctl restart hermes-discord
```

**No Discord messages?**
```bash
# Check bot is in server (look at Members)
# Check bot has permissions (Send Messages, Read Message History)

# Test bot directly
cd /workspaces/Jit/hermes-discord
DISCORD_TOKEN="your_token" node bot.js
```

**High memory usage?**
```bash
# Clear old conversation memory
echo '{"channels":{}}' > /workspaces/Jit/memory/discord-memory.json
sudo systemctl restart hermes-discord
```

---

## 📚 Full Documentation

See: `HERMES_DISCORD_GUIDE.md` for complete guide

---

## 🌟 Summary

**Hermes Discord Bot is now 24/7 and integrated with heartbeat! 🤖**

- 🟢 Always running
- 🔄 Auto-recovers on crash
- 📊 Reports every 15 minutes
- 🧠 Powered by MDES Ollama
- 🔗 Connected to heartbeat

Done! ✅
