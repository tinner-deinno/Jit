# /oracle-prism — Quick Reference

**Learned**: 2026-06-11 14:33

## Usage

```
/oracle-prism                          # วิเคราะห์ session ปัจจุบัน (default)
/oracle-prism "the rename migration"   # วิเคราะห์หัวข้อเฉพาะ
/oracle-prism --lenses 3               # ใช้ 3 lenses แทน 5
/oracle-prism --preset retro|design|incident
/oracle-prism --custom "Security Auditor,Performance Engineer,UX Designer"
```

## Output Format (ต้องตาม)

```markdown
## 🔍 Lens 1: Archaeologist — "What happened?"
[Timeline table]
---
## 🐛 Lens 2: Bug Hunter — "What broke?"
[Problems + evidence]
---
## 💀 Lens 3: Skeptic — "What went wrong?"
[Mistakes + what should have been done]
---
## 🏗️ Lens 4: Architect — "What changed?"
[Before/after]
---
## 📋 Lens 5: Auditor — "What's left?"
[Pending items table + urgency]
---
**Cross-lens summary:** [2-3 ประโยค จุดที่หลาย lens เห็นตรงกัน]
```

## 8 Rules

1. No subagents — ทุก lens รันใน main agent ตามลำดับ
2. แต่ละ lens มี section + emoji + คำถามนำ
3. Evidence required — อ้าง files/commits/timestamps เสมอ
4. Lens ขัดแย้งกันได้ — แสดงทั้งคู่ ห้าม harmonize
5. Cross-lens summary ปิดท้าย
6. Tables over prose
7. ไม่ระบุหัวข้อ = วิเคราะห์ session ปัจจุบัน
8. 3-7 lenses (default 5)

## เมื่อไหร่ควรใช้

| สถานการณ์ | ทำไม |
|---|---|
| จบ session | จับสิ่งที่พลาดก่อนปิด |
| หลัง migration/rename | หาความไม่สอดคล้อง |
| ตัดสินใจ design | เห็น tradeoffs จากมุม user/maintainer/breaker |
| post-incident | หลายมุมแบบไม่กล่าวโทษ |
| "พลาดอะไรไหม?" | Auditor lens มีไว้เพื่อสิ่งนี้ |
