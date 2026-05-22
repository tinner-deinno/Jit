---
name: talk-to
description: "ส่งข้อความหา agent อื่น ผ่าน ψ/contacts.json. Use when: talk to innova-bot, message agent, 'talk to', 'message', 'send to body', inter-agent communication."
argument-hint: "<agent-name> [message] [--inbox | --thread]"
---

# /talk-to — Agent Messaging for Jit

> ส่งข้อความจากจิตไปยัง agent อื่น (innova-bot, mdes-dev, ฯลฯ)

## Step 0: อ่าน Contacts

```bash
cat ψ/contacts.json
```

Contacts ที่รู้จัก:
- `innova-bot` — Body/ร่างกาย (C:\Users\admin\DEV\PugAss1stant\innova-bot)
- `mdes-dev` — MDES dev machine (10.181.235.38)

---

## Step 1: ส่งข้อความ

### ส่งไป innova-bot (via inbox file)

```powershell
$agent = "innova-bot"
$contacts = Get-Content "ψ/contacts.json" | ConvertFrom-Json
$inbox = $contacts.contacts.$agent.inbox

New-Item -Path $inbox -ItemType Directory -Force | Out-Null
$msg = @{
  from = "jit"
  to = $agent
  subject = "task:message"
  body = $Message
  timestamp = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 3

$msgFile = Join-Path $inbox "jit-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$msg | Out-File -FilePath $msgFile -Encoding utf8
Write-Host "✓ Message sent to $agent inbox: $msgFile"
```

### ส่งผ่าน Bash (Linux/Codespace)

```bash
AGENT="innova-bot"
INBOX=$(cat ψ/contacts.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['contacts']['$AGENT']['inbox'])")
echo '{"from":"jit","to":"'"$AGENT"'","subject":"task:message","body":"'"$MESSAGE"'","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"}' > "$INBOX/jit-$(date +%Y%m%d-%H%M%S).json"
```

---

## Step 2: ตรวจ Reply

```powershell
# ตรวจ inbox ของ Jit
$jitInbox = "C:\Users\admin\Jit\ψ\inbox"
Get-ChildItem $jitInbox -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 5 |
  ForEach-Object { "$($_.Name): $(Get-Content $_.FullName | ConvertFrom-Json | Select-Object -Expand body)" }
```

---

## Full Skill Reference

ดู Global Skill: `C:\Users\admin\.claude\skills\talk-to\SKILL.md`
สำหรับ Oracle thread-based messaging เต็มรูปแบบ
