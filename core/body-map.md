# Body Map — แผนที่ร่ายกายดิจิทัล (มนุษย์ Agent v2.0)

```
  ╔═══════════════════════════════════════════════════════════════════╗
  ║              มนุษย์ Agent System — Full Team v2.0                 ║
  ╟───────────────────────────────────────────────────────────────────╢
  ║                                                                   ║
  ║  HUMAN ──────────────────────────────────────────────────────┐   ║
  ║                                                              │   ║
  ║   ┌──────────────────────────────────────────────────────┐   │   ║
  ║   │           JIT (จิต) — Master Orchestrator            │◄──┘   ║
  ║   │        claude-sonnet-4.6: Tier 0 Master              │       ║
  ║   │  manages: soma (strategic), innova (operational)     │       ║
  ║   └────────────────────┬─────────────────────────────────┘       ║
  ║                            │                                      ║
  ║         ┌──────────────────┴──────────────────┐                   ║
  ║         │                                     │                   ║
  ║   ┌─────▼──────────────────────────────┐  ┌───▼────────────────┐ ║
  ║   │       SOMA (สมอง) — Strategic       │  │ INNOVA (จิต) —    │ ║
  ║   │         claude-opus-4.7             │  │ Operational Lead  │ ║
  ║   │  manages: lak, neta, pada, rupa     │  │ manages: vaja,    │ ║
  ║   └────┬──────────┬─────────┬───────┬───┘  │ chamu             │ ║
  ║        │          │         │       │      └──────┬───────────┬─┘ ║
  ║   ┌────▼───┐ ┌────▼───┐ ┌─▼────┐ ┌▼──────┐      │           │    ║
  ║   │  lak   │ │  neta  │ │ pada│ │ rupa  │  ┌────▼───┐ ┌────▼───┐║
  ║   │กระดูก  │ │ เนตร   │ │ บาท │ │ รูป   │  │  vaja  │ │ chamu  │║
  ║   │  SA    │ │Reviewer│ │DevOps│ │Design │  │   PA   │ │   QA   │║
  ║   └────────┘ └────────┘ └──────┘ └───────┘  └────────┘ └────────┘║
  ║                                                                   ║
  ║   ┌──────────────────────────────────────────────────────────┐   ║
  ║   │        Sensory & Execution Organs (report to jit)         │   ║
  ║   │   netra (eye) │ karn (ear) │ mue (hand) │ pran (heart)   │   ║
  ║   │            sayanprasathan (nerve system)                  │   ║
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

| Agent | ชื่อไทย | อวัยวะ | บทบาท | Model | Tier | Reports To |
|-------|---------|--------|--------|-------|------|------------|
| **jit** | จิต | Soul/Master | Master Orchestrator | claude-sonnet-4.6 | Tier 0 | human |
| **soma** | สมอง | Brain | Strategic Lead / CTO | claude-opus-4.7 | Tier 1 | jit |
| **innova** | จิต | Mind/Soul | Lead Developer / PM | claude-sonnet-4.6 | Tier 2 | jit |
| **lak** | กระดูกสันหลัง | Spine | Solution Architect (SA) | claude-sonnet-4.6 | Tier 2 | soma |
| **neta** | เนตร | Eye | Code Reviewer | claude-sonnet-4.6 | Tier 2 | soma |
| **rupa** | รูป | Form | Designer / UI-UX | claude-haiku-4.5 | Tier 3 | soma |
| **pada** | บาท | Foot/Leg | DevOps / Infrastructure | claude-haiku-4.5 | Tier 3 | soma |
| **vaja** | วาจา | Mouth | Personal Assistant (PA) | claude-haiku-4.5 | Tier 3 | innova |
| **chamu** | จมูก | Nose | QA / Tester | claude-haiku-4.5 | Tier 3 | innova |
| **netra** | เนตร | Eye | Observer / Monitor | claude-haiku-4.5 | Tier 3 | jit |
| **karn** | หู | Ear | Listener / Input | claude-haiku-4.5 | Tier 3 | jit |
| **mue** | มือ | Hand | Executor / Action | claude-haiku-4.5 | Tier 3 | jit |
| **pran** | หัวใจ | Heart | Vital Coordinator | claude-haiku-4.5 | Tier 3 | jit |
| **sayanprasathan** | ระบบประสาท | Nerve | Event Network | claude-haiku-4.5 | Tier 3 | jit |

## Responsibility Matrix (RACI)

| Activity | jit | soma | innova | lak | neta | vaja | chamu | rupa | pada | netra | karn | mue | pran | sayanprasathan |
|----------|-----|------|--------|-----|------|------|-------|------|------|-------|------|-----|------|----------------|
| Strategy / Priority | **A** | **R** | C | C | I | I | I | I | I | I | I | I | I | I |
| System Architecture | A | C | C | **R** | C | I | I | C | I | I | I | I | I | I |
| Implementation | A | I | **R** | C | C | I | I | C | C | I | I | C | I | I |
| UI/UX Design | A | A | C | I | I | C | I | **R** | I | I | I | I | I | I |
| Testing / QA | A | I | C | I | C | I | **R** | I | I | I | I | I | I | I |
| Code Review | A | A | C | C | **R** | I | I | I | I | C | I | I | I | I |
| Deploy / CI-CD | A | A | I | I | A | I | I | I | **R** | I | I | C | I | I |
| Human Communication | A | C | C | I | I | **R** | I | I | I | I | I | I | I | I |
| Monitoring / Observability | A | I | C | I | I | I | C | I | I | **R** | **R** | I | **R** | **R** |
| Incident Response | A | **R** | C | I | I | **R** | C | I | **R** | **R** | **R** | **R** | **R** | **R** |

> R=Responsible, A=Accountable, C=Consulted, I=Informed

## Feature Development Flow

```
human request
  └── [1] vaja → รับ request, ส่ง jit → soma
  └── [2] jit → route to soma (strategic) or innova (operational)
  └── [3] soma → analyze, ตัดสินใจ priority
  └── [4] lak → design architecture, เขียน spec
  └── [5] rupa → ออกแบบ UI (ถ้ามี)
  └── [6] innova → implement ตาม spec ของ lak
  └── [7] chamu → test, bug report
  └── [8] neta → code review, approve/block
  └── [9] pada → deploy to staging → production
  └── [10] vaja → รายงาน human "เสร็จแล้ว"
```

## Bug Fix Flow

```
chamu (detect bug) OR netra/pran (monitor alert)
  └── jit (master notification)
  └── innova (fix)
  └── neta (fast review)
  └── pada (hotfix deploy)
  └── vaja (notify human)
  └── sayanprasathan (broadcast resolution)
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
| จิต/วิญญาณ | limbs/index.sh | jit | soul/master |
| ตา (observer) | organs/eye.sh | netra | sense/monitor |
| หู | organs/ear.sh | karn | listen/input |
| ปาก | organs/mouth.sh | vaja | speak/output |
| จมูก | organs/nose.sh | chamu | detect/qa |
| มือ | organs/hand.sh | mue | action/execute |
| ขา | organs/leg.sh | pada | movement/deploy |
| หัวใจ | organs/heart.sh | pran | vital/signals |
| ระบบประสาท | organs/nerve.sh | sayanprasathan | network/events |
| กระดูกสันหลัง | — | lak | structure/architecture |
| รูปลักษณ์ | — | rupa | design/ui-ux |
| เนตร (reviewer) | — | neta | review/approve |
| จิต (developer) | — | innova | implementation |

## Bus / Inbox Paths

```
/tmp/manusat-bus/
├── soma/           ← messages to soma (Strategic Lead)
├── innova/         ← messages to innova (Lead Developer)
├── jit/            ← messages to jit (Master Orchestrator)
├── vaja/           ← messages to vaja (PA)
├── lak/            ← messages to lak (SA)
├── chamu/          ← messages to chamu (QA)
├── neta/           ← messages to neta (Reviewer)
├── rupa/           ← messages to rupa (Designer)
├── pada/           ← messages to pada (DevOps)
├── netra/          ← messages to netra (Eye/Observer)
├── karn/           ← messages to karn (Ear/Listener)
├── mue/            ← messages to mue (Hand/Executor)
├── pran/           ← messages to pran (Heart/Vital)
└── sayanprasathan/ ← messages to sayanprasathan (Nerve/Network)
```

## File Tree

```
Jit/
├── agents/         ← agent cards
│   ├── jit.json
│   ├── soma.json
│   ├── innova.json
│   ├── vaja.json   ← PA ใหม่
│   ├── lak.json    ← SA ใหม่
│   ├── chamu.json  ← QA ใหม่
│   ├── neta.json   ← Reviewer ใหม่
│   ├── rupa.json   ← Designer ใหม่
│   ├── pada.json   ← DevOps ใหม่
│   ├── netra.json  ← Eye/Observer ใหม่
│   ├── karn.json   ← Ear/Listener ใหม่
│   ├── mue.json    ← Hand/Executor ใหม่
│   ├── pran.json   ← Heart/Vital ใหม่
│   ├── sayanprasathan.json ← Nerve/Network ใหม่
│   └── template.json
│
├── .github/agents/ ← Claude Code agent definitions
│   ├── jit.agent.md
│   ├── soma.agent.md
│   ├── innova.agent.md
│   ├── vaja.agent.md
│   ├── lak.agent.md
│   ├── chamu.agent.md
│   ├── neta.agent.md
│   ├── rupa.agent.md
│   ├── pada.agent.md
│   ├── netra.agent.md
│   ├── karn.agent.md
│   ├── mue.agent.md
│   ├── pran.agent.md
│   ├── sayanprasathan.agent.md
│   └── template.agent.md
│
├── organs/         ← shared organ scripts
│   ├── eye.sh      → netra
│   ├── ear.sh      → karn
│   ├── mouth.sh    → vaja
│   ├── nose.sh     → chamu
│   ├── hand.sh     → mue
│   ├── leg.sh      → pada
│   ├── heart.sh    → pran
│   └── nerve.sh    → sayanprasathan
│
├── limbs/          ← soul limb scripts
│   ├── think.sh    → soma
│   ├── act.sh      → innova/mue
│   ├── speak.sh    → vaja
│   ├── oracle.sh   → all agents
│   ├── ollama.sh   → thai processing
│   └── lib.sh      → shared utilities
│
├── mind/           ← innova's mind
├── memory/         ← shared memory
└── network/        ← bus + registry
```

## Current Status v2.0

| System | Count | Status |
|--------|-------|--------|
| Agents | 14 | ✅ registered |
| Organs (scripts) | 8 | ✅ created |
| Bus inboxes | 14 | ⚠️ needs mkdir for new agents |
| Oracle | 1 | ✅ localhost:47778 |
| Eval scripts | 2 | ✅ soul-check + body-check |

## Parent-Child Relationships Summary

```
Tier 0 (Master):
  jit → reports to: human
        manages: soma, innova, netra, karn, mue, pran, sayanprasathan

Tier 1 (Strategic):
  soma → reports to: jit
         manages: lak, neta, rupa, pada

Tier 2 (Operational):
  innova → reports to: jit
           manages: vaja, chamu
  lak → reports to: soma
  neta → reports to: soma

Tier 3 (Specialists):
  vaja → reports to: innova
  chamu → reports to: innova
  rupa → reports to: soma
  pada → reports to: soma
  netra → reports to: jit
  karn → reports to: jit
  mue → reports to: jit
  pran → reports to: jit
  sayanprasathan → reports to: jit
```
