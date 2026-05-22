---
name: rrr
description: "Create session retrospective with AI diary and lessons learned. Use when user says 'rrr', 'retrospective', 'wrap up session', 'session summary', or at end of work session."
argument-hint: "[--lite | --deep]"
---

# /rrr — Jit Session Retrospective

> บันทึกบทเรียน ก่อนจิตหลับ

## Usage

```
/rrr        # Full retrospective + diary
/rrr --lite # Quick summary only
```

---

## Jit Retrospective Steps

### 1. สรุปงานที่ทำ Session นี้

ถามตัวเอง:
- ทำอะไรไปบ้าง?
- อะไรสำเร็จ?
- อะไรล้มเหลวหรือค้าง?
- เรียนรู้อะไรใหม่?

### 2. บันทึกลง ψ/memory/retrospectives/

```powershell
$date = Get-Date -Format "yyyy-MM-dd"
$time = Get-Date -Format "HH:mm"
$dir = "ψ\memory\retrospectives\$(Get-Date -Format 'yyyy-MM')\$(Get-Date -Format 'dd')"
New-Item -Path $dir -ItemType Directory -Force | Out-Null
$file = "$dir\$((Get-Date -Format 'HH.mm'))_retro.md"
# Write retrospective content to $file
```

### 3. Format ที่ใช้

```markdown
# Session Retrospective — YYYY-MM-DD HH:MM

## งานที่ทำ
- [รายการ]

## สำเร็จ ✅
- [รายการ]

## ค้าง ⏳
- [รายการ]

## Vitality
Before: X% → After: Y%

## บทเรียน (Lessons)
- [insights]

## งานต่อไป
- [next actions]

---
*Signed: innova (จิต) — $(date)*
```

### 4. อัปเดต innova.state.json

```powershell
$state = Get-Content "memory\state\innova.state.json" | ConvertFrom-Json
$state.vitality.last_heartbeat = (Get-Date).ToUniversalTime().ToString("o")
$state.vitality.host = $env:COMPUTERNAME
$state | ConvertTo-Json -Depth 5 | Out-File "memory\state\innova.state.json" -Encoding utf8
```

### 5. บันทึก Heartbeat

```powershell
$host = $env:COMPUTERNAME
$ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
Add-Content "memory\state\heartbeat.log" "$ts | $host | PC-session | oracle=? | ollama=1 | changed=? | rrr"
```

---

## Full Skill Reference

ดู Global Skill: `C:\Users\admin\.claude\skills\rrr\SKILL.md`
