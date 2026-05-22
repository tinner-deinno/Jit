---
name: mind-body-bridge
description: "เชื่อม Jit (จิต/mind) กับ innova-bot (ร่างกาย/body) ผ่าน MCP หรือ ψ/inbox. Use when: syncing Jit with innova-bot, publishing events, checking bridge status, sending commands to body, receiving body status, or doing end-of-phase rituals."
argument-hint: "[status|publish <event> <data>|sync|send <message>|read]"
---

# SKILL: mind-body-bridge — จิตนำกาย Bridge

> **จิตนำกาย** — Mind leads body. Jit is the soul; innova-bot is the body.

## สถาปัตยกรรมการเชื่อมต่อ

```
┌─ JIT (จิต) ──────────────────────┐      ┌─ INNOVA-BOT (ร่างกาย) ──────┐
│  C:\Users\admin\Jit              │      │  C:\Users\admin\DEV\...\     │
│  ψ/outbox/ ──── publish ────────►│─────►│  ψ/inbox/                   │
│  ψ/inbox/  ◄──── receive ────────│◄─────│  ψ/outbox/                  │
│                                  │      │  MCP port: 7010              │
│  MASTER_PLAN tracking            │      │  API: http://127.0.0.1:7010  │
└──────────────────────────────────┘      └──────────────────────────────┘
```

## วิธีใช้

```
mind-body-bridge status          # check connection status
mind-body-bridge publish <event> <data>   # send event to innova-bot
mind-body-bridge send "<message>"         # message to innova-bot ψ/inbox
mind-body-bridge read            # read innova-bot replies from ψ/inbox
mind-body-bridge sync            # sync phase state Jit ↔ innova-bot
```

---

## Step 1: ตรวจสถานะ Bridge

```powershell
# Windows:
$ProgressPreference = 'SilentlyContinue'
try {
  $r = Invoke-WebRequest -Uri "http://127.0.0.1:7010/health" -UseBasicParsing -TimeoutSec 3
  "innova-bot MCP: ONLINE (port 7010)"
} catch {
  "innova-bot MCP: OFFLINE"
}

# ตรวจ inbox
$inbox = "C:\Users\admin\DEV\PugAss1stant\innova-bot\ψ\inbox"
if (Test-Path $inbox) {
  $msgs = Get-ChildItem $inbox -File | Sort-Object LastWriteTime -Descending | Select-Object -First 5
  if ($msgs) { $msgs | ForEach-Object { Write-Host "📬 $_" } } else { "📭 Inbox empty" }
} else { "⚠️ innova-bot inbox not found" }
```

```bash
# Linux/Codespace:
curl -s http://127.0.0.1:7010/health || echo "innova-bot MCP: OFFLINE"
ls -la /workspaces/innova-bot/ψ/inbox/ 2>/dev/null || echo "inbox not found"
```

---

## Step 2: ส่ง Event จากจิตไปร่างกาย

```bash
# Via ψ/inbox file (always works)
INBOX="C:\Users\admin\DEV\PugAss1stant\innova-bot\ψ\inbox"
MSG_FILE="${INBOX}/jit-$(date +%Y%m%d-%H%M%S).json"
cat > "$MSG_FILE" << EOF
{
  "from": "jit",
  "to": "innova-bot",
  "subject": "$EVENT",
  "body": "$DATA",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
echo "✓ Event published to innova-bot inbox: $MSG_FILE"
```

```powershell
# PowerShell version:
$inbox = "C:\Users\admin\DEV\PugAss1stant\innova-bot\ψ\inbox"
New-Item -Path $inbox -ItemType Directory -Force | Out-Null
$msg = @{
  from = "jit"
  to = "innova-bot"
  subject = $Event
  body = $Data
  timestamp = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json
$msgFile = Join-Path $inbox "jit-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$msg | Out-File -FilePath $msgFile -Encoding utf8
Write-Host "✓ Event published: $msgFile"
```

---

## Step 3: รับ Reply จากร่างกาย

```powershell
$jitInbox = "C:\Users\admin\Jit\ψ\inbox"
Get-ChildItem $jitInbox -Filter "innova-bot-*.json" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 10 |
  ForEach-Object {
    $msg = Get-Content $_.FullName | ConvertFrom-Json
    Write-Host "📬 [$($msg.timestamp)] $($msg.subject): $($msg.body)"
  }
```

---

## Step 4: Sync Phase State

Jit อัปเดต MASTER_PLAN → innova-bot รู้ว่า phase ไหนเสร็จแล้ว:

```bash
# Check MASTER_PLAN
cat .planning/ROADMAP.md 2>/dev/null | grep -E "^\- \[" | head -20

# Publish phase completion event
EVENT="phase:complete" DATA='{"phase":"P1","title":"Skill Alignment","result":"done"}' \
  bash -c 'source mind-body-bridge; bridge_publish "$EVENT" "$DATA"'
```

---

## Common Events

| Event | ความหมาย |
|-------|---------|
| `phase:complete` | Phase เสร็จแล้ว |
| `heartbeat:pulse` | จิตยังมีชีวิต |
| `alert:critical` | ปัญหาด่วน |
| `oracle:learned` | บันทึกความรู้ใหม่ |
| `task:assign` | มอบหมายงาน |
| `vitality:update` | อัปเดต % vitality |
| `system:awake` | จิตตื่นรู้แล้ว |

---

## Integration กับ jit-master Lifecycle

ใช้ใน Step 6 (OBSERVE + LEARN):
```bash
# หลังทุก task สำเร็จ
bash mind-body-bridge publish "task:complete" '{"task":"...", "result":"success"}'
bash limbs/oracle.sh learn "bridge-pattern" "..." "jit,innova-bot,bridge"
```
