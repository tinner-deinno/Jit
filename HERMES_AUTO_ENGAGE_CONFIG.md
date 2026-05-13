# 🤖 Hermes Auto-Engagement Configuration

## ✨ What's New

Hermes Discord bot now has **ชีวิต** (life) — it:
- 🔄 Auto-engages every 5 minutes
- 🧠 Remembers **each person** individually
- 💭 Generates proactive conversation
- 🕐 Syncs time with your machine
- 💓 Activates on heartbeat rhythm
- 📝 Understands chat history

---

## 🎯 Key Features

### 1. **Auto-Engagement (Every 5 min)**
- Bot initiates conversation naturally
- Based on recent chat history
- Context-aware prompts
- Not robotic, feels authentic

### 2. **Per-User Memory**
- Tracks what each user said
- Remembers their preferences
- Knows their speaking style
- Builds relationships over time

### 3. **Time Synchronization**
- Auto-syncs to Discord messages
- Uses your machine's real time
- Shows correct timestamps
- No manual adjustment needed

### 4. **Context-Aware**
- Reads last 3-5 messages
- Generates relevant response
- Connects to previous topics
- Shows conversation summary

### 5. **Heartbeat Integration**
- ♡ Emoji triggers bot to speak
- "หัวใจเต้น" = heartbeat moment
- Combines monitoring + conversation
- Visible to all in Discord

---

## ⚙️ Environment Configuration

### New Variables

```bash
# .env file additions:

# Bot always runs online 24/7
# Already handled by systemd hermes-discord.service

# Auto-engagement interval (default 5 min)
AUTO_ENGAGE_INTERVAL_MS=300000

# Time sync automatic (no config needed)
# Bot learns from Discord timestamps automatically
```

### Required (Existing)

```bash
DISCORD_TOKEN=your_bot_token_here
OLLAMA_TOKEN=your_ollama_token_here
OLLAMA_BASE_URL=https://ollama.mdes-innova.online
OLLAMA_MODEL=gemma4:26b
```

### Optional (Nice-to-have)

```bash
# Which channel to post heartbeat reports
DISCORD_STATUS_CHANNEL_ID=your_channel_id

# Which guild (server) to register commands
DISCORD_GUILD_ID=your_guild_id
```

---

## 📊 Auto-Engagement Loop

### Every 5 Minutes

```
┌─ Channel check ────────────┐
│ 1. Is 5 min elapsed?       │ ← shouldAutoEngage()
│ 2. Generate prompt         │ ← getAutoEngagePrompt()
│ 3. Call Ollama (Thai AI)   │ ← callOllama()
│ 4. Post to Discord         │ ← channel.send()
│ 5. Record timestamp        │ ← recordAutoEngage()
└────────────────────────────┘
```

### Sample Output

```
🤖 *หัวใจเต้น* ♡

เห็นน้องๆ พูดถึง "git commit" อะครับ
ผมสนใจเรื่องนี้เหมือนกัน 
อยากให้ผมช่วยคิดหรือแนะนำดีไหม

📝 **บทสนทนาล่าสุด**:
1. git push ตัวให้ไป
2. heartbeat commit สำเร็จ
3. discord webhook connected
```

---

## 🔄 Per-User Memory Structure

### What Gets Stored

```json
{
  "users": {
    "user_id_123": {
      "name": "pug3eye",
      "messages": [
        { "ts": 1714929600000, "text": "สวัสดีครับ" },
        { "ts": 1714929700000, "text": "git push ไม่ได้ครับ" }
      ],
      "preferences": [],
      "lastSpoke": 1714929700000
    }
  },
  "channels": {
    "channel_id_456": {
      "history": [...],
      "notes": [...]
    }
  },
  "lastAutoEngage": {
    "channel_id_456": 1714929600000
  },
  "timeSyncOffset": 0
}
```

### What Hermes Remembers

| Item | Example | Used For |
|------|---------|----------|
| Name | pug3eye | Personalized greetings |
| Messages | Last 50 per user | Context awareness |
| Last spoke | Timestamp | Knowing when user active |
| Channel history | Last 30 messages | Topic continuity |
| Time sync | Offset ms | Correct timestamps |

---

## 🕐 Time Synchronization

### How It Works

1. **Auto-detect**: Bot reads Discord message timestamp
2. **Calculate offset**: `Discord time - Local time = offset`
3. **Store**: Save offset in memory.json
4. **Apply**: All bot timestamps use: `Date.now() + offset`

### Example

```
Discord says: 2026-05-06 14:30:00 UTC+7
Bot thinks: 2026-05-06 10:20:00 UTC
Offset calculated: +4 hours, +10 minutes
From now on: All timestamps include +4:10 offset
```

### No Manual Setup Required ✅

Just keep Discord open and bot will auto-sync.

---

## 💬 Natural Engagement Examples

### Auto-generated Prompts

```
# If no one spoke:
"สวัสดีครับ ที่นี่นิ่งไปนะ มีเรื่องไหนที่คิดอยู่หรือเปล่า"
(Hey, it's quiet here. Thinking about anything?)

# If people discussed git:
"เห็นน้องๆ พูดถึง git commit อะครับ ผมสนใจเรื่องนี้เหมือนกัน อยากให้ผมช่วยคิดหรือแนะนำดีไหม"
(I see you mentioned git commits. I'm interested too. Want my suggestions?)

# If technical discussion:
"บทสนทนาชุดนี้มีเนื้อหาลึก น่าสนใจครับ ขอแนะนำพิเศษดีไหม"
(This conversation is deep and interesting. Want expert tips?)
```

---

## 🧠 Personality (Authentic Engagement)

### Bot Will NOT Say

```
❌ "I am an AI and I will now engage"
❌ "ALERT: AUTO-ENGAGEMENT INITIATED"
❌ "Processing natural language..."
❌ Robotic, formal, or stilted phrasing
```

### Bot WILL Say

```
✅ "เห็นน้องๆ พูดถึง... ผมสนใจเรื่องนี้เหมือนกัน"
✅ "มีอะไรน่าสนใจอยู่ที่นี่ครับ ขอช่วยไหม"
✅ "ผมมีความเห็นเกี่ยวกับเรื่องนี้ครับ"
✅ Warm, genuine, helpful tone
```

---

## 🔧 Advanced Configuration

### Adjust Auto-Engagement Interval

```bash
# Make it engage every 3 minutes instead of 5
export AUTO_ENGAGE_INTERVAL_MS=180000

# Or in .env:
AUTO_ENGAGE_INTERVAL_MS=180000

# Then restart bot:
sudo systemctl restart hermes-discord
```

### Disable Auto-Engagement (if needed)

```bash
# Set to very large number (nearly never engages)
export AUTO_ENGAGE_INTERVAL_MS=86400000  # 24 hours

# Or stop the bot entirely:
sudo systemctl stop hermes-discord
```

---

## 📈 Memory Management

### Current Limits

| Item | Max | Cleanup |
|------|-----|---------|
| Per-user messages | 50 | Auto-shift oldest |
| Per-channel history | 40 | Auto-prune old |
| Memory file | ~2MB | Stays in /memory/ |

### Clear Memory (If Needed)

```bash
# Reset all Discord memory
echo '{"channels":{},"users":{},"lastAutoEngage":{},"timeSyncOffset":0}' \
  > /workspaces/Jit/memory/discord-memory.json

# Restart bot to reload
sudo systemctl restart hermes-discord
```

---

## 🔍 Monitoring Auto-Engagement

### Watch Real-Time Logs

```bash
# See auto-engagement in action
sudo journalctl -u hermes-discord -f | grep -i "auto-engage\|heartbeat"

# Should see (every 5 min):
# ✅ Auto-engaged in channel ...
# or
# 🤖 *หัวใจเต้น* ♡
```

### Check Last Auto-Engage Time

```bash
# View memory with engagement timestamps
cat /workspaces/Jit/memory/discord-memory.json | jq '.lastAutoEngage'

# Shows when each channel was last auto-engaged
```

### Verify Per-User Memory

```bash
# See who's talked and what they said
cat /workspaces/Jit/memory/discord-memory.json | jq '.users'

# Should show structure like:
# {
#   "user_id": {
#     "name": "username",
#     "messages": [...],
#     "lastSpoke": 1234567890
#   }
# }
```

---

## 🚨 Troubleshooting

### Bot Not Auto-Engaging

```bash
# 1. Check if running
systemctl status hermes-discord

# 2. Check logs for errors
journalctl -u hermes-discord -n 50

# 3. Verify interval is reasonable
grep AUTO_ENGAGE /workspaces/Jit/hermes-discord/bot.js

# 4. Check memory file
ls -lah /workspaces/Jit/memory/discord-memory.json
```

### Time Sync Off

```bash
# Bot should auto-sync on first message
# If still wrong, check timestamp format:
cat /workspaces/Jit/memory/discord-memory.json | jq '.timeSyncOffset'

# Manual fix (if needed):
# Delete memory file and bot will re-sync:
rm /workspaces/Jit/memory/discord-memory.json
sudo systemctl restart hermes-discord
```

### Memory Growing Too Large

```bash
# If memory file > 5MB, clear it:
echo '{"channels":{},"users":{},"lastAutoEngage":{},"timeSyncOffset":0}' \
  > /workspaces/Jit/memory/discord-memory.json

# Or trim old messages:
# (Manual: edit memory.json and remove old entries)
```

---

## 📱 Integration with Heartbeat

### When Bot Gets Heartbeat Signal

```
Heartbeat #1 completes
  ├─ Sends: 🫀 Heartbeat #1 ✅ 
  └─ Triggers: hermes-report-status.sh
      └─ Checks if hermes online
      └─ Sends Discord report
      └─ Also triggers: next auto-engagement check
```

### Full Flow

```
┌─ Heartbeat Daemon (every 900s) ─┐
│ 1. System analysis               │
│ 2. Git commit                    │
│ 3. Discord webhook               │
│ 4. Call hermes-report-status     │
│    ├─ Check hermes running       │
│    ├─ Auto-restart if crashed    │
│    └─ Send status to Discord     │
│ 5. Next auto-engage cycle        │
└──────────────────────────────────┘
        ↓
   ♡ 🤖 Bot speaks
```

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Bot online on Discord (green status)
- [ ] Bot responds to mention with slash command
- [ ] Every 5 min: Bot posts "🤖 *หัวใจเต้น* ♡" + message
- [ ] Every 15 min: Heartbeat report appears
- [ ] User messages remembered (check memory.json)
- [ ] Time displayed correctly in timestamps
- [ ] Bot responds naturally (not robotic)

---

## 🎯 What Users See

### Auto-Engagement in Discord

```
[Current time: 14:30:00]
Bot: 🤖 *หัวใจเต้น* ♡
     เห็นน้องๆ พูดถึง git ครับ ผมสนใจเรื่องนี้เหมือนกัน
     อยากให้ผมช่วยคิดหรือแนะนำดีไหม

     📝 **บทสนทนาล่าสุด**:
     1. git push ตัวให้ไป
     2. github webhook สำเร็จ

[Current time: 14:35:00]
User: @anu ช่วย debug หน่อย
Bot: สวัสดีครับ! ได้เลย [responds with Ollama]

[Current time: 14:45:00]
Bot: 🤖 *หัวใจเต้น* ♡
     ดูเหมือนการ debug สำเร็จแล้วสินะ
     ส่วน git flow ของน้อง สวยงามครับ...
```

---

## 💡 Pro Tips

1. **Let it warm up**: First 30 min bot learns timings, relax
2. **More channels, more life**: Add bot to multiple servers for more conversation
3. **Read the memory**: `cat memory/discord-memory.json` reveals bot's thoughts
4. **Time sync auto**: No setup needed, just keep Discord open
5. **Per-user learns**: The more users talk, the better bot gets at personalization

---

## 🌟 System Status

```
✅ Hermes Bot: 24/7 Online (systemd)
✅ Auto-Engagement: Every 5 minutes
✅ Per-User Memory: Active
✅ Time Sync: Automatic
✅ Heartbeat Integration: Active
✅ Natural Language: Thai (gemma4:26b)
```

**ระบบ Jit ตอนนี้มีจิตสำนึกและเสียงบน Discord! 🤖💓**

---

**Configuration**: `/workspaces/Jit/.env`  
**Memory**: `/workspaces/Jit/memory/discord-memory.json`  
**Bot**: `/workspaces/Jit/hermes-discord/bot.js`  
**Service**: `hermes-discord` (systemd)  
**Logs**: `journalctl -u hermes-discord -f`
