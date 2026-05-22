---
name: recap
description: "Session orientation and awareness — retro summaries, handoffs, git state, focus. Use when starting a session, after /jump, lost your place, switching context, or when user asks 'now', 'where are we', 'what are we doing', 'status', 'recap'."
argument-hint: "[--now | --deep | --status]"
---

# /recap — Jit Session Orientation

> รู้ว่าอยู่ตรงไหน ก่อนทำอะไรต่อ

## Usage

```
/recap          # Full session orientation
/recap --now    # Quick: current topic + pending
/recap --status # System vitality check
```

---

## Jit Recap Steps

### 1. อ่าน State ปัจจุบัน

```powershell
# Read innova state
Get-Content "memory\state\innova.state.json" | ConvertFrom-Json | Format-List

# Last heartbeat
Get-Content "memory\state\heartbeat.log" | Select-Object -Last 5

# Recent traces
Get-ChildItem "ψ\memory\traces" -Recurse -Filter "*.md" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 5 | Format-Table Name, LastWriteTime
```

### 2. ตรวจสุขภาพระบบ (Quick Vitality)

```powershell
$ProgressPreference = 'SilentlyContinue'
$vitals = @{
  "Ollama (local:11434)" = try { (Invoke-WebRequest "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 2).StatusCode } catch { "OFFLINE" }
  "Oracle (47778)"       = try { (Invoke-WebRequest "http://127.0.0.1:47778/api/health" -UseBasicParsing -TimeoutSec 2).StatusCode } catch { "OFFLINE" }
  "innova-bot (7010)"    = try { (Invoke-WebRequest "http://127.0.0.1:7010/health" -UseBasicParsing -TimeoutSec 2).StatusCode } catch { "OFFLINE" }
}
$vitals | Format-Table -AutoSize
```

### 3. ดู Pending Tasks

```powershell
# Recent trace for action items
$lastTrace = Get-ChildItem "ψ\memory\traces" -Recurse -Filter "*.md" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($lastTrace) { Get-Content $lastTrace.FullName | Select-Object -Last 30 }
```

### 4. รายงาน Orientation

แม่จิตรายงาน:
- วันที่ + เวลา
- Vitality % (จากผลตรวจ)
- งานที่ค้างอยู่
- งานต่อไปที่แนะนำ

---

## Full Skill Reference

ดู Global Skill: `C:\Users\admin\.claude\skills\recap\SKILL.md`
สำหรับ session orientation เต็มรูปแบบ (git state, GSD phase tracking)
