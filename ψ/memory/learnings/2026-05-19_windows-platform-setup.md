---
pattern: When hunting hidden config in an unknown system, start with broad filesystem grep — not narrow assumptions
date: 2026-05-19
source: rrr: Jit
concepts: [debugging, search-strategy, electron, windows, cdp]
---

# Broad Search Before Narrow: Hidden Config Hunting

เมื่อต้องหา configuration ที่ซ่อนอยู่ใน system ที่ไม่คุ้นเคย (เช่น Electron app, installed software):

## Rule

**เริ่มจาก broad filesystem grep ก่อนเสมอ** — อย่าเริ่มจาก assumption ว่ามันอยู่ที่ไหน

```bash
# ✅ Correct: broad first
grep -r "chrome-flag-you-seek" ~/AppData --include="*.js" -l

# ❌ Wrong: narrow assumption first
grep -r "flag" ~/DEV/specific-repo  # waste time if wrong
```

## Why

Session นี้เสียเวลา 2hr+ ในการหา `--remote-allow-origins=*` ใน innova-bot → npm cache → PATH
ก่อนจะพบจริงๆ ว่าอยู่ใน Antigravity Electron app ที่ `AppData/Local/Programs/Antigravity/resources/app/out/main.js`

## Bonus: Cloudflare 403

API ที่อยู่หลัง Cloudflare ต้องการ `User-Agent` header ถ้าไม่มี → `error code: 1010` ทันที
Fix: เพิ่ม `"User-Agent": "Mozilla/5.0 (compatible; ...)"` ใน request headers

## Bonus: VS Code Electron Settings

VS Code-based Electron apps เก็บ user settings ใน:
`C:\Users\<user>\AppData\Roaming\<AppName>\User\settings.json`
ตรวจสอบที่นี่ก่อนแก้ compiled binary เพราะอาจมี override mechanism อยู่แล้ว
