# /oracle-prism — Architecture & Design Philosophy

**Source**: gist.github.com/nazt/ce8065ae5da53371287ca92bd1a3b2ab (SKILL.md, 130 lines)
**Learned**: 2026-06-11 14:33

## แนวคิดหลัก

> "แสงเดียวผ่านปริซึม แตกเป็นหลายสี — เรื่องเดียวกัน มองจากหลายมุม เห็นต่างกัน"

**Prismatic analysis** — agent เดียว แปลงร่างเป็น 5 มุมมอง (lens) ตามลำดับ **ไม่ spawn subagent เลย**
ต่างจาก adversarial analysis: ไม่ได้พยายามหักล้าง แต่มองข้อเท็จจริงชุดเดียวกันด้วยคำถามต่างกัน

## โครงสร้างการทำงาน

```
Input (session/topic)
   │
   ▼
Main agent transforms inline ตามลำดับ:
   🔍 Archaeologist  → "เกิดอะไรขึ้นจริง? timeline, facts"
   🐛 Bug Hunter     → "เจอปัญหาอะไร? อะไรยังพัง?"
   💀 Skeptic        → "เราทำอะไรพลาด? ควร redo อะไร?"
   🏗️ Architect      → "โครงสร้างเปลี่ยนยังไง? before/after"
   📋 Auditor        → "อะไรยังค้าง? อะไรไม่สอดคล้อง?"
   │
   ▼
Cross-lens summary (จุดที่หลาย lens เห็นตรงกัน)
```

## Design Decisions สำคัญ

| Decision | เหตุผล |
|---|---|
| No subagents | เบาที่สุด — ไม่มี coordination overhead, ไม่เปลือง token |
| Sequential transform | แต่ละ lens เห็น output ของ lens ก่อนหน้า → ลึกขึ้น |
| Lenses disagree allowed | ห้าม harmonize — ถ้า Architect บอก "clean" แต่ Auditor บอก "incomplete" ให้แสดงทั้งคู่ |
| Evidence required | ต้องอ้าง files, commits, timestamps — ห้าม vague |
| 3-7 lenses | ต่ำกว่า 3 = มุมไม่พอ, เกิน 7 = ซ้ำซ้อน |

## Preset Lens Sets

1. **default** — Archaeologist, Bug Hunter, Skeptic, Architect, Auditor (วิเคราะห์ session)
2. **retro** — Historian, Critic, Cheerleader, Connector, Planner (retrospective)
3. **design** — User, Maintainer, Breaker, Simplifier, Integrator (design review)
4. **incident** — Firefighter, Detective, Defender, Forecaster, Builder (post-incident)

## ตำแหน่งใน Skill Ecosystem

| Skill | Pattern | Agents |
|---|---|---|
| `/oracle-prism` | multi-perspective เดียวกัน | **0** (inline) |
| `/adversarial-analysis` | พยายามหักล้าง | 5 subagents |
| `/rrr` | retrospective | 0 (หรือ 5 ใน --deep) |
| `/roundtable` | persona discussion | 0 (inline) |

**Prism = เครื่องมือ multi-perspective ที่เบาที่สุด** — ใช้เมื่อต้องการ "มุมมอง" ไม่ใช่ "ศัตรู"
