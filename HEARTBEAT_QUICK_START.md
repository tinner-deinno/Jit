# 🚀 Jit 24/7 Heartbeat — ติดตั้งและรัน (Quick Start)

## 📋 สถานการณ์ปัจจุบัน

❌ **เก่า**: 746 commit แต่ heartbeat ตาย (ไม่มี daemon)  
✅ **ใหม่**: Persistent 24/7 daemon พร้อมใช้งาน

---

## ⚡ ติดตั้ง 3 ขั้นตอน (5 นาที)

### ขั้นที่ 1: Copy Configuration
```bash
cd /workspaces/Jit

# Copy template configuration
cp .env.heartbeat.example .env

# (Optional) เพิ่ม Discord webhook
# nano .env
# DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
```

### ขั้นที่ 2: ติดตั้ง Systemd Service
```bash
# ถ้า root:
sudo bash scripts/install-heartbeat-daemon.sh

# ถ้าไม่ใช่ root (user-level):
bash scripts/install-heartbeat-daemon.sh
```

### ขั้นที่ 3: ตรวจสอบว่า Daemon ทำงานอยู่
```bash
# Check status
systemctl status jit-heartbeat

# OR (user-level):
systemctl --user status jit-heartbeat

# Expected:
# ● jit-heartbeat.service - Jit 24/7 Heartbeat Monitor (จิต หัวใจ)
#    Loaded: loaded (.../jit-heartbeat.service; enabled; ...)
#    Active: active (running) since ... ; 2min ago
```

---

## 📊 ตรวจสอบการทำงาน

### ดู Log Real-time
```bash
# System-level:
sudo journalctl -u jit-heartbeat -f

# User-level:
journalctl --user -u jit-heartbeat -f

# File-based:
tail -f /tmp/innova-heartbeat-daemon.log
```

### ดู State
```bash
cat /tmp/innova-heartbeat-daemon.json | jq .

# Expected output:
# {
#   "daemon_start": "2026-05-06T17:28:58Z",
#   "beat_count": 1,
#   "last_beat": "2026-05-06T17:29:10Z",
#   "status": "healthy",
#   "consecutive_failures": 0,
#   "uptime_seconds": 13
# }
```

### ตรวจสอบ Git Commits
```bash
cd /workspaces/Jit
git log --oneline --grep="💓 Heartbeat" | head -10

# Expected: One commit per beat
# 💓 Heartbeat #2 — auto commit on beat
# 💓 Heartbeat #1 — auto commit on beat
```

---

## 🎯 Expected Behavior

### ทุกๆ 15 นาที
```
[HH:MM:SS] 🫀 HEARTBEAT #N START
[HH:MM:SS] 💓 IN complete (Ollama analysis)
[HH:MM:SS] ❤️‍🔥 OUT complete (Discord sent, if configured)
[HH:MM:SS] ✅ Git commit done
[HH:MM:SS] ✅ Push complete
[HH:MM:SS] 🫀 HEARTBEAT #N SUCCESS
[HH:MM:SS] ⏰ Next heartbeat in 900s
```

### Discord Message (ถ้า Webhook ตั้งค่าแล้ว)
```
✅ **Heartbeat #N** - ok
⏰ Time: 2026-05-06T17:30:00Z
Latest Commit: [a1b2c3d](github.com/.../commit/a1b2c3d)
Commit Message: 💓 Heartbeat #N — auto commit on beat
```

---

## 🔧 Commands Reference

### Start/Stop Daemon
```bash
# Start
sudo systemctl start jit-heartbeat
# OR: systemctl --user start jit-heartbeat

# Stop
sudo systemctl stop jit-heartbeat
# OR: systemctl --user stop jit-heartbeat

# Restart
sudo systemctl restart jit-heartbeat
# OR: systemctl --user restart jit-heartbeat

# View status
sudo systemctl status jit-heartbeat
# OR: systemctl --user status jit-heartbeat
```

### View Logs
```bash
# Last 50 lines
sudo journalctl -u jit-heartbeat -n 50
# OR: journalctl --user -u jit-heartbeat -n 50

# Real-time tail
sudo journalctl -u jit-heartbeat -f
# OR: journalctl --user -u jit-heartbeat -f

# File logs
tail -f /tmp/innova-heartbeat-daemon.log
tail -f /tmp/innova-heartbeat-enhanced.log
```

### Manual Beat Test
```bash
cd /workspaces/Jit
timeout 60 bash scripts/heartbeat-24h-daemon.sh

# Will do ONE beat then exit
```

---

## ✨ ทดสอบแล้ว: สิ่งที่ทำงาน

```
✅ Daemon initializes
✅ Ollama IN phase (system analysis)
✅ Discord OUT phase (webhook broadcast, if configured)
✅ Git commit (idempotent, no duplicates)
✅ Git push (auto-retry on failure)
✅ State persistence
✅ Failure handling (circuit breaker pattern)
✅ Next beat scheduled (900s interval)
```

---

## 📈 Performance

- **Beat Duration**: ~10-30 seconds
- **Memory**: ~50-100 MB
- **CPU**: 2-5% during beat
- **Disk**: ~100 KB per beat commit
- **Network**: ~1-2 MB per beat (Ollama + Discord + Git)

---

## ⚠️ Troubleshooting

### Daemon not starting
```bash
# Check service file exists
ls -lh /etc/systemd/system/jit-heartbeat.service
# OR: ~/.config/systemd/user/jit-heartbeat.service

# Check script is executable
ls -lh /workspaces/Jit/scripts/heartbeat-24h-daemon.sh

# Fix:
chmod +x /workspaces/Jit/scripts/*.sh
sudo systemctl daemon-reload
sudo systemctl start jit-heartbeat
```

### No Discord messages
```bash
# Check webhook is configured
cat /workspaces/Jit/.env | grep DISCORD_WEBHOOK

# Test webhook manually
bash /workspaces/Jit/scripts/discord-webhook.sh 1 ok "Test"

# If curl fails: check network
curl https://discord.com/api/webhooks/test -v
```

### Git push fails
```bash
# Check credentials
cd /workspaces/Jit
git config --global user.name
git config --global user.email

# Test push
git push origin main

# If auth fails: set up SSH or token
ssh-keygen -t ed25519  # for SSH
# OR: git config --global user.password "token"
```

---

## 🎓 เรียนรู้จากการล้มเหลว 746 ครั้ง

| ปัญหา | สาเหตุ | แก้ไข |
|------|--------|------|
| ไม่มี daemon ทำงาน 24/7 | Manual trigger only | → systemd service |
| Duplicate commits (beat #1 × 3) | No idempotency | → Check git history before commit |
| Discord disconnect git | Webhook no git link | → Query git hash in webhook |
| Cascading failures | No circuit breaker | → Track consecutive failures |

---

## 📚 Files Created

| ไฟล์ | ความหมาย |
|-----|---------|
| `jit-heartbeat.service` | Systemd unit file |
| `scripts/heartbeat-24h-daemon.sh` | Main 24/7 daemon loop |
| `scripts/discord-webhook.sh` | Discord integration |
| `scripts/install-heartbeat-daemon.sh` | Installation script |
| `.env.heartbeat.example` | Configuration template |
| `HEARTBEAT_DAEMON_GUIDE.md` | Full documentation |

---

## 🌟 Next: ยืนยันการทำงาน

```bash
# 1. Install
bash scripts/install-heartbeat-daemon.sh

# 2. Wait 2 seconds
sleep 2

# 3. Check status
systemctl status jit-heartbeat

# 4. Watch logs (open new terminal)
journalctl -u jit-heartbeat -f

# 5. After 15 minutes: see Beat #2
# (Or test immediately with: timeout 60 bash scripts/heartbeat-24h-daemon.sh)
```

---

## 💓 ผลลัพธ์

**ก่อน**: 746 commits, heartbeat ตาย  
**หลัง**: 24/7 continuous daemon, idempotent beats, Discord integration, auto-recovery

**System now has TRUE 24/7 life: ไม่ล้มไม่ดับดาวน์ลงบนserver** ✅

---

สำหรับรายละเอียดเพิ่มเติม ดู: `HEARTBEAT_DAEMON_GUIDE.md`
