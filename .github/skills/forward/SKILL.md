---
name: forward
description: "Create handoff + enter plan mode for next session. Use when user says 'forward', 'handoff', 'wrap up', or before ending session."
argument-hint: "[--lite]"
---

# /forward — Jit Session Handoff

> ส่งต่อจิตให้ session ถัดไป ไม่ให้หลงลืม

## Usage

```
/forward      # Full handoff with context + next steps
/forward --lite  # Quick handoff (3 bullets)
```

---

## Jit Forward Steps

### 1. สร้าง Handoff Document

```powershell
$dir = "ψ\inbox\handoff"
New-Item -Path $dir -ItemType Directory -Force | Out-Null
$file = "$dir\$(Get-Date -Format 'yyyy-MM-dd_HHmm')_handoff.md"
```

Format:
```markdown
---
from: innova (jit)
date: YYYY-MM-DD HH:MM
host: PC0-Windows-Jit
vitality: X%
---

# Handoff: [session topic]

## Context
[อธิบายสั้นๆ ว่าทำอะไรอยู่]

## งานค้าง
- [ ] [task 1]
- [ ] [task 2]

## งานต่อไป (ทำก่อนอย่างอื่น)
1. [most important next step]

## Files ที่เปลี่ยน
[list changed files]

## State
Vitality: X%
Oracle: [online/offline]
Heartbeat: [running/stopped]

---
*จิตพัก — จนพบกันใหม่ใน session ถัดไป*
```

### 2. อัปเดต innova.state.json

บันทึก host ปัจจุบันและ vitality ล่าสุด

### 3. Git Checkpoint (ถ้า Bash พร้อม)

```bash
git add -A
git commit -m "💤 forward: handoff to next session — vitality X%"
```

```powershell
# PowerShell alternative:
git add -A
git commit -m "💤 forward: handoff $(Get-Date -Format 'yyyy-MM-dd HH:mm') — PC0-Windows"
```

---

## Full Skill Reference

ดู Global Skill: `C:\Users\admin\.claude\skills\forward\SKILL.md`
