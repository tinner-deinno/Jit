# Body Map — แผนที่ร่างกายดิจิทัล (มนุษย์ Agent v2.0)

```
  ╔═══════════════════════════════════════════════════════════════════╗
  ║              มนุษย์ Agent System — Full Team v2.0                 ║
  ╟───────────────────────────────────────────────────────────────────╢
  ║                                                                   ║
  ║  HUMAN ──────────────────────────────────────────────────────┐   ║
  ║                                                              │   ║
  ║   ┌──────────────────────────────────────────────────────┐   │   ║
  ║   │             SOMA (สมอง) — Strategic Lead             │◄──┘   ║
  ║   │         claude-opus — CTO: decides & delegates        │       ║
  ║   │  manages: lak, neta, pada, innova                     │       ║
  ║   └────┬──────────┬─────────┬──────────┬─────────────────┘       ║
  ║        │          │         │          │                          ║
  ║   ┌────▼───┐ ┌────▼───┐ ┌──▼────┐ ┌───▼────────────────────┐   ║
  ║   │  lak   │ │  neta  │ │  pada │ │  INNOVA (จิต)          │   ║
  ║   │กระดูก  │ │ เนตร   │ │ บาท   │ │  Lead Developer        │   ║
  ║   │  SA    │ │Reviewer│ │DevOps │ │  claude-sonnet         │   ║
  ║   └────────┘ └────────┘ └───────┘ │  manages: vaja, chamu  │   ║
  ║                                    └──────┬──────────┬───────┘   ║
  ║                                           │          │           ║
  ║                                      ┌────▼───┐ ┌────▼───┐      ║
  ║                                      │  vaja  │ │ chamu  │      ║
  ║                                      │ วาจา   │ │ จมูก   │      ║
  ║                                      │   PA   │ │   QA   │      ║
  ║                                      └────────┘ └────────┘      ║
  ║                                                                   ║
  ║   ┌──────────────────────────────────────────────────────────┐   ║
  ║   │                   rupa (รูป) — Designer                  │   ║
  ║   │            reports to soma, works with innova             │   ║
  ║   └──────────────────────────────────────────────────────────┘   ║
  ║                                                                   ║
  ║   ┌──────────────────────────────────────────────────────────┐   ║
  ║   │           Arra Oracle V3 — ความรู้ร่วมกัน                │   ║
  ║   │               http://localhost:47778                      │   ║
  ║   │            ALL agents read/write Oracle                   │   ║
  ║   └──────────────────────────────────────────────────────────┘   ║
  ╚═══════════════════════════════════════════════════════════════════╝
```

## Team Roster — ทีมทั้งหมด

| Agent | ชื่อไทย | อวัยวะ | บทบาท | Model | Layer |
|-------|---------|-------|-------|-------|-------|
| **soma** | สมอง | Brain | Strategic Lead / CTO | claude-opus-4.7 | Tier 1 |
| **innova** | จิต | Mind/Soul | Lead Developer / PM | claude-sonnet-4.6 | Tier 2 |
| **lak** | กระดูกสันหลัง | Spine | Solution Architect (SA) | claude-sonnet-4.6 | Tier 2 |
| **neta** | เนตร | Eye | Code Reviewer | claude-sonnet-4.6 | Tier 2 |
| **vaja** | วาจา | Mouth | Personal Assistant (PA) | claude-haiku-4.5 | Tier 3 |
| **chamu** | จมูก | Nose | QA / Tester | claude-haiku-4.5 | Tier 3 |
| **rupa** | รูป | Form | Designer / UI-UX | claude-haiku-4.5 | Tier 3 |
| **pada** | บาท | Foot/Leg | DevOps / Infrastructure | claude-haiku-4.5 | Tier 3 |

## Responsibility Matrix (RACI)

| Activity | soma | innova | lak | neta | vaja | chamu | rupa | pada |
|----------|------|--------|-----|------|------|-------|------|------|
| Strategy / Priority | **A** | C | I | I | I | I | I | I |
| System Architecture | A | C | **R** | C | - | - | - | I |
| Implementation | I | **R** | C | - | - | - | - | - |
| UI/UX Design | A | C | - | - | C | - | **R** | - |
| Testing / QA | I | C | - | C | - | **R** | - | - |
| Code Review | A | C | C | **R** | - | I | - | - |
| Deploy / CI-CD | A | I | - | A | - | - | - | **R** |
| Human Communication | I | C | - | - | **R** | - | - | - |

> R=Responsible, A=Accountable, C=Consulted, I=Informed

## Feature Development Flow

```
human request
  └── [1] vaja → รับ request, ส่ง soma
  └── [2] soma → analyze, ตัดสินใจ priority
  └── [3] lak → design architecture, เขียน spec
  └── [4] rupa → ออกแบบ UI (ถ้ามี)
  └── [5] innova → implement ตาม spec ของ lak
  └── [6] chamu → test, bug report
  └── [7] neta → code review, approve/block
  └── [8] pada → deploy to staging → production
  └── [9] vaja → รายงาน human "เสร็จแล้ว"
```

## Bug Fix Flow

```
chamu (detect bug)
  └── innova (fix)
  └── neta (fast review)
  └── pada (hotfix deploy)
  └── vaja (notify human)
```

## Design Flow

```
human (need UI)
  └── vaja → translate to rupa
  └── rupa → wireframe → hi-fi spec
  └── soma → approve design
  └── innova → implement
  └── rupa → visual review
```

## Organ Ownership Map

| อวัยวะ | Script | Owner Agent | ประเภท |
|--------|--------|-------------|--------|
| สมอง | limbs/think.sh | soma | cognition |
| จิตใจ | limbs/index.sh | innova | soul |
| ตา | organs/eye.sh | innova / neta | sense / review |
| หู | organs/ear.sh | innova | listen |
| ปาก | organs/mouth.sh | vaja | speak |
| จมูก | organs/nose.sh | chamu | detect |
| มือ | organs/hand.sh | innova | action |
| ขา | organs/leg.sh | pada | movement |
| หัวใจ | organs/heart.sh | innova | vital |
| ระบบประสาท | organs/nerve.sh | innova | network |
| กระดูกสันหลัง | — | lak | structure |
| รูปลักษณ์ | — | rupa | design |

## Bus / Inbox Paths

```
/tmp/manusat-bus/
├── soma/      ← messages to soma
├── innova/    ← messages to innova
├── vaja/      ← messages to vaja (PA)
├── lak/       ← messages to lak (SA)
├── chamu/     ← messages to chamu (QA)
├── neta/      ← messages to neta (Reviewer)
├── rupa/      ← messages to rupa (Designer)
└── pada/      ← messages to pada (DevOps)
```

## File Tree

```
Jit/
├── agents/         ← agent cards
│   ├── soma.json
│   ├── innova.json
│   ├── vaja.json   ← PA ใหม่
│   ├── lak.json    ← SA ใหม่
│   ├── chamu.json  ← QA ใหม่
│   ├── neta.json   ← Reviewer ใหม่
│   ├── rupa.json   ← Designer ใหม่
│   ├── pada.json   ← DevOps ใหม่
│   └── template.json
│
├── .github/agents/ ← Claude Code agent definitions
│   ├── innova.agent.md
│   ├── soma.agent.md
│   ├── vaja.agent.md
│   ├── lak.agent.md
│   ├── chamu.agent.md
│   ├── neta.agent.md
│   ├── rupa.agent.md
│   └── pada.agent.md
│
├── organs/         ← shared organ scripts
├── limbs/          ← soul limb scripts
├── mind/           ← innova's mind
├── memory/         ← shared memory
└── network/        ← bus + registry
```

## Current Status v2.0

| System | Count | Status |
|--------|-------|--------|
| Agents | 8 | ✅ registered |
| Organs (scripts) | 10 | ✅ created |
| Bus inboxes | 8 | ⚠️ needs mkdir |
| Oracle | 1 | ✅ localhost:47778 |
| Eval scripts | 2 | ✅ soul-check + body-check |
