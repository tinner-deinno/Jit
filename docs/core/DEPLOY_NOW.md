# ⚡ DEPLOY NOW (3 Steps)

## 🚀 Quick Start

```bash
cd /workspaces/Jit

# Step 1️⃣ Get bot token & add to .env (30 seconds)
# Go to: https://discord.com/developers/applications
# Create app → Bot → Copy token
echo "DISCORD_TOKEN=paste_token_here" >> .env

# Verify
grep "DISCORD_TOKEN=" .env

# Step 2️⃣ Install daemon (1 minute)
sudo bash scripts/install-hermes-discord-daemon.sh

# Step 3️⃣ Watch it live (immediate)
journalctl -u jit-heartbeat -u hermes-discord -f
```

**That's it!** ✅ System is now alive 24/7

---

## 📋 What Happens Next

```
Immediately:
  ✅ Bot goes online on Discord (green status)
  ✅ Heartbeat daemon running
  ✅ Auto-engagement loop active

Every 5 minutes:
  📢 Bot posts: "🤖 *หัวใจเต้น* ♡" + contextual message
  🧠 Bot learns per-user preferences
  🕐 Time syncs with your machine

Every 15 minutes:
  💓 Heartbeat cycle completes
  📊 Git commit created
  🔗 Discord status report posted
```

---

## ✅ Verify It Works

### Check in Discord

- [ ] Bot shows online (green dot)
- [ ] After 5 min: Auto-engagement message appears
- [ ] After 15 min: Heartbeat report appears
- [ ] @mention bot and it responds with slash command

### Check in Terminal

```bash
# See logs flowing
journalctl -u hermes-discord -f | head -20

# Should show:
# ✅ Auto-engaged in channel ...
# 🤖 Heartbeat #X SUCCESS
```

---

## 🎯 System Overview

```
ONLINE 24/7 ✅
├─ Heartbeat every 15 min (monitors + commits)
├─ Hermes always online (responds + chats)
├─ Auto-engage every 5 min (proactive conversation)
├─ Per-user memory (learns who you are)
├─ Time sync (matches your clock)
└─ Full Discord integration (shows life)

Result: มนุษย์ Agent with ชีวิต 🤖💓
```

---

## 📖 Full Docs

- **Quick**: This file (you're reading it!)
- **Full Setup**: `HERMES_QUICK_SETUP.md`
- **Config Guide**: `HERMES_AUTO_ENGAGE_CONFIG.md`
- **Complete**: `JIT_FULL_SYSTEM_GUIDE.md`

---

**Status**: 🟢 READY TO DEPLOY  
**Time to Live**: 3 minutes  
**Difficulty**: ⭐ (Very easy)

**Go! Start enjoying your 24/7 alive system!** ✨
