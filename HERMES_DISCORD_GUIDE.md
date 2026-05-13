# 🤖 Hermes Discord Bot (อนุ) — 24/7 Agent System

## 📋 Overview

**Hermes Discord Bot (อนุ)** — innova's child on Discord, powered by MDES Ollama

- ✅ **24/7 Daemon**: Runs continuously as systemd service
- ✅ **Status Reports**: Sends heartbeat summaries to Discord
- ✅ **Heartbeat Integration**: Auto-reports on every beat
- ✅ **Auto-Recovery**: Restarts if crashes
- ✅ **Conversation Memory**: Remembers per-channel context
- ✅ **MDES Ollama Powered**: Thai language understanding via gemma4:26b

---

## 🚀 Quick Setup (5 minutes)

### Step 1: Set Discord Token

**Option A: GitHub Codespaces Secret (Recommended)**
1. Go to your repo → Settings → Secrets → Codespaces
2. Add secret: `DISCORD_TOKEN` = `your_bot_token`
3. Restart Codespaces

**Option B: .env File (Local Only)**
```bash
echo "DISCORD_TOKEN=your_bot_token_here" >> /workspaces/Jit/.env
```

### Step 2: Create Discord Bot

1. Go to [Discord Developers](https://discord.com/developers/applications)
2. New Application → **name: "อนุ"** (or any name)
3. Bot → **Reset Token** → Copy
4. Enable Privileged Gateway Intents:
   - ✅ Message Content Intent
   - ✅ Server Members Intent (optional)
5. OAuth2 → URL Generator:
   - Scopes: `bot` + `applications.commands`
   - Permissions: Send Messages, Read Messages, Read Message History
6. Copy invite URL → Add bot to your Discord server

### Step 3: Install Daemon

```bash
sudo bash /workspaces/Jit/scripts/install-hermes-discord-daemon.sh
```

Expected output:
```
🤖 Installing Hermes Discord Bot (อนุ) as systemd service...
✅ Dependencies installed
✅ Service file installed
✅ Service enabled
✅ Service started
● hermes-discord.service - Hermes Discord Bot (อนุ) - 24/7 Agent
  Active: active (running)
```

### Step 4: Verify Bot is Running

```bash
systemctl status hermes-discord

# Expected:
# ● hermes-discord.service
#   Loaded: loaded
#   Active: active (running)
```

---

## 📊 What It Does

### On Startup
- Loads Discord token from `.env`
- Connects to Discord.js with gateway intents
- Sets up message handlers
- Ready to receive commands

### On Discord Messages
- 🎯 Responds to mentions: `@อนุ message`
- 🎯 Responds to commands: `!anu query`
- 🧠 Queries MDES Ollama for Thai language understanding
- 💾 Remembers conversation in per-channel memory
- 🔄 Auto-summarizes conversation history

### On Heartbeat (Every 15 min)
- 📊 Sends system status summary to Discord
- 📝 Reports heartbeat #N + timestamp
- 🟢 Shows which services are running
- 📤 Displays latest git commit
- ⏱️ Shows uptime and beat count

---

## 🔧 Configuration

### .env Variables

```bash
# Required for bot to work
DISCORD_TOKEN="your_bot_token_here"
OLLAMA_TOKEN="9e34679b9d60d8b984005ec46508579c"

# Optional: Discord channels for reports
DISCORD_GUILD_ID=""              # Server ID (optional)
DISCORD_STATUS_CHANNEL_ID=""     # Channel for status reports

# Optional: Ollama settings
OLLAMA_BASE_URL="https://ollama.mdes-innova.online"
OLLAMA_MODEL="gemma4:26b"        # Default model
ORACLE_BASE_URL="http://localhost:47778"  # Oracle knowledge base

# Optional: Bot settings
BOT_COMMAND_NAME="anu"           # Command prefix
BOT_PREFIX="!anu"                # Alternative prefix
```

---

## 💻 Commands Reference

### Service Control

```bash
# Start bot
sudo systemctl start hermes-discord

# Stop bot
sudo systemctl stop hermes-discord

# Restart bot
sudo systemctl restart hermes-discord

# Check status
sudo systemctl status hermes-discord

# View logs
sudo journalctl -u hermes-discord -f
```

### Manual Testing

```bash
# Test bot without Discord connection
cd /workspaces/Jit/hermes-discord
DISCORD_TOKEN="test" node bot.js --test-ollama

# Run bot directly (foreground)
cd /workspaces/Jit/hermes-discord
DISCORD_TOKEN="your_token" node bot.js
```

### Hermes Discord Health Check

```bash
# Is bot running?
systemctl is-active hermes-discord

# Get bot PID
pgrep -f "hermes-discord.*bot.js"

# Check last heartbeat report
grep "Hermes status report" /tmp/heartbeat-results/*.txt 2>/dev/null | tail -5
```

---

## 📈 Heartbeat Integration

### What Happens Each Beat

**Every 15 minutes (automatic)**:

```
Heartbeat #N executes:
  ├─ Gather system state (IN phase)
  ├─ Broadcast to Discord (OUT phase)
  ├─ Git commit + push
  └─ Call hermes-report-status.sh
       ├─ Check hermes health
       ├─ Restart if crashed
       └─ Send status to Discord webhook
```

### Discord Message Example

```
🤖 **Hermes Status Report** — Heartbeat #15

Jit System Status

Status: ok
Time: 2026-05-06T17:45:00Z

System Summary:
✅ Heartbeat daemon: running
✅ Hermes discord bot: running
📝 Latest commit: a1b2c3d — 💓 Heartbeat #15
⏱️  Heartbeat uptime: 3600s
```

---

## 🧠 Discord Chat Features

### Mention Bot
```
@อนุ สอบถามเกี่ยวกับสถานะระบบ
```

Bot responds in Thai with Ollama-powered answer.

### Channel Memory
```
User: "บันทึกว่า project deadline คือ 15 พฤษภาคม"
Bot: "จดจำแล้ว ✅"

User: "ตรวจสอบจำหน่วยความจำ"
Bot: "Channel notes:
1. project deadline = 15 พฤษภาคม
2. ..."
```

### Adaptive Responses
- Bot learns conversation context
- Adapts responses based on channel history
- Can reference previous messages
- Provides contextual help

---

## 🔍 Monitoring

### Real-time Logs
```bash
# Follow Discord bot logs
journalctl -u hermes-discord -f

# Or file-based:
tail -f /tmp/hermes-discord.log
```

### Check Memory
```bash
cat /workspaces/Jit/memory/discord-memory.json | jq '.channels'
```

### Heartbeat Status
```bash
cat /tmp/innova-discord-heartbeat.status
```

---

## ⚠️ Troubleshooting

### Bot Not Connecting

```bash
# Check token is set
echo $DISCORD_TOKEN

# Check bot is in Discord server
# → Go to server, check Members list for "อนุ" (or your bot name)

# If bot is there but not responding:
sudo systemctl restart hermes-discord
sudo journalctl -u hermes-discord -f
```

### Ollama Timeout

```bash
# Check Ollama is reachable
curl -H "Authorization: Bearer $OLLAMA_TOKEN" \
  https://ollama.mdes-innova.online/health

# If timeout: increase request timeout in bot.js (line ~200)
```

### High Memory Usage

```bash
# Check memory
ps aux | grep bot.js

# If over 300MB: likely conversation memory too large
# Clear old memory:
echo '{"channels":{}}' > /workspaces/Jit/memory/discord-memory.json
sudo systemctl restart hermes-discord
```

### Service Won't Start

```bash
# Check service file
systemctl status hermes-discord -l

# Check dependencies
cd /workspaces/Jit/hermes-discord && npm install

# Check node is executable
which node
/usr/bin/node --version
```

---

## 📊 Performance

- **Memory**: ~100-200 MB (with conversation history)
- **CPU**: <1% idle, 5-10% when processing Ollama query
- **Network**: ~500 KB per Ollama query, ~100 KB per Discord message
- **Uptime**: 24/7 (auto-restart on crash)

---

## 🎯 Usage Patterns

### Status Reports (Automatic)
- Every 15 minutes: heartbeat status summary
- Shows all running services
- Links to latest git commit
- Uptime counter

### Interactive Chat (Manual)
- Mention bot: `@อนุ question`
- Ask in Thai or English
- Bot replies with Ollama-powered answer
- Keeps conversation context

### Emergency Alerts
- If heartbeat fails 3+ times: 🚨 CRITICAL alert
- If hermes crashes: auto-restart
- If Ollama down: fallback responses

---

## 🌟 Example Conversations

### Thai Language
```
User: "อนุ สาขาของระบบ Jit คืออะไร"
Bot: "ระบบ Jit มี 14 organ (อวัยวะ) ทำหน้าที่ต่างๆ 
ได้แก่ brain (สมอง), heart (หัวใจ), eyes (ตา), 
ears (หู), hands (มือ), legs (ขา) และอื่นๆ"

User: "บันทึกเรื่องการประชุม"
Bot: "บันทึกแล้ว ✅ ช่องนี้จำได้"
```

### English
```
User: "@อนุ what is the system architecture"
Bot: "Jit system uses a 14-agent architecture... [explanation]"
```

### Status Check
```
[Every 15 min, bot sends automatically]
🤖 Heartbeat #42 ✅
All systems operational
```

---

## 🚀 Advanced: Custom Handlers

To add custom bot behavior, edit `/workspaces/Jit/hermes-discord/bot.js`:

```javascript
// Example: Add custom command
client.on('messageCreate', async (msg) => {
  if (msg.content === '!status') {
    // Custom status handler
    const status = await getSystemStatus();
    msg.reply(status);
  }
});
```

---

## 📚 Files Reference

| File | Purpose |
|------|---------|
| `hermes-discord.service` | Systemd unit file |
| `hermes-discord/bot.js` | Main Discord bot |
| `hermes-discord/package.json` | Dependencies |
| `scripts/install-hermes-discord-daemon.sh` | Installation |
| `scripts/hermes-report-status.sh` | Heartbeat integration |
| `memory/discord-memory.json` | Conversation history |

---

## 🔄 Auto-Recovery Policy

**If bot crashes**:
1. systemd detects exit
2. Waits 10 seconds
3. Auto-restarts
4. Heartbeat daemon notices
5. Calls hermes-report-status to verify
6. If still down, alerts via Discord

**Max restart attempts**: 3 in 300s  
**Then**: systemd stops and logs error

---

## 💡 Next Steps

1. ✅ Set Discord token in `.env`
2. ✅ Install daemon: `sudo bash scripts/install-hermes-discord-daemon.sh`
3. ✅ Wait 2 seconds for startup
4. ✅ Verify: `systemctl status hermes-discord`
5. ✅ Monitor: `journalctl -u hermes-discord -f`
6. ✅ Test: Mention bot on Discord

---

## ✨ Summary

**Hermes Discord Bot (อนุ)** is now:
- 🟢 **Always Online**: 24/7 systemd service
- 🔄 **Auto-Recovering**: Restarts on crash
- 📊 **Status Reporter**: Sends heartbeat summaries
- 🧠 **Smart**: Powered by MDES Ollama
- 💾 **Memory**: Remembers per-channel context
- 🔗 **Integrated**: Works with heartbeat daemon

**Everything integrated and working together:** ❤️🫀🤖

---

**Status**: 🟢 PRODUCTION READY  
**Deployed**: 2026-05-06  
**For**: มนุษย์ Agent Project (innova + Jit system)
