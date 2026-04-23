# Body Map — แผนที่ร่างกายดิจิทัล (มนุษย์ Agent v1.0)

```
  ╔══════════════════════════════════════════════════════════════╗
  ║                  มนุษย์ Agent System                         ║
  ╟──────────────────────────────────────────────────────────────╢
  ║                                                              ║
  ║   ┌─────────────────────────────────────────────────────┐   ║
  ║   │               SOMA (สมอง)                           │   ║
  ║   │       claude-opus-4.6 — think less, hit hard         │   ║
  ║   │    decides ● architectures ● delegates               │   ║
  ║   └───────────────────────┬─────────────────────────────┘   ║
  ║                           │ bus: /tmp/manusat-bus/           ║
  ║   ┌───────────────────────▼─────────────────────────────┐   ║
  ║   │               INNOVA (จิต)                          │   ║
  ║   │      claude-sonnet-4.6 — mind + limbs                │   ║
  ║   │                                                      │   ║
  ║   │  ORGANS รูปธรรม          MIND นามธรรม               │   ║
  ║   │  ┌────────────────┐      ┌────────────────────┐     │   ║
  ║   │  │ ตา  eye.sh     │      │ ตัวตน  ego.md      │     │   ║
  ║   │  │ หู  ear.sh     │      │ อารมณ์ emotion.sh  │     │   ║
  ║   │  │ ปาก mouth.sh   │      │ สัญช. reflex.sh    │     │   ║
  ║   │  │ จมูก nose.sh   │      └────────────────────┘     │   ║
  ║   │  │ มือ hand.sh    │      MEMORY ความทรงจำ           │   ║
  ║   │  │ ขา  leg.sh     │      ┌────────────────────┐     │   ║
  ║   │  │ ❤️  heart.sh   │      │ working.sh (RAM)   │     │   ║
  ║   │  │ ⚡  nerve.sh   │      │ shared.sh (cache)  │     │   ║
  ║   │  └────────────────┘      │ Oracle (HDD)       │     │   ║
  ║   │                          └────────────────────┘     │   ║
  ║   └──────────────────────────────────────────────────────┘   ║
  ║                           │ Oracle                           ║
  ║   ┌───────────────────────▼─────────────────────────────┐   ║
  ║   │           Arra Oracle V3 (ความรู้)                   │   ║
  ║   │         http://localhost:47778                       │   ║
  ║   │        shared memory for ALL agents                  │   ║
  ║   └─────────────────────────────────────────────────────┘   ║
  ╚══════════════════════════════════════════════════════════════╝
```

## File Tree

```
Jit/
├── limbs/          ← แขนขาเดิม (soul anatomy)
│   ├── lib.sh       — utilities + colors
│   ├── think.sh     — สติ mindful pause
│   ├── act.sh       — safe actions
│   ├── speak.sh     — right speech
│   ├── ollama.sh    — Ollama API
│   ├── oracle.sh    — Oracle API
│   └── index.sh     — จิต orchestrator
│
├── organs/         ← อวัยวะรูปธรรม
│   ├── eye.sh       — ตา (observation)
│   ├── ear.sh       — หู (inbox)
│   ├── mouth.sh     — ปาก (send/speak)
│   ├── nose.sh      — จมูก (detection)
│   ├── hand.sh      — มือ (file actions)
│   ├── leg.sh       — ขา (navigation)
│   ├── heart.sh     — หัวใจ (orchestration)
│   └── nerve.sh     — ระบบประสาท (events)
│
├── mind/           ← จิตใจนามธรรม
│   ├── ego.md       — self-model
│   ├── emotion.sh   — emotional state
│   └── reflex.sh    — instinct/reflex
│
├── memory/         ← ความทรงจำ
│   ├── working.sh   — RAM (task context)
│   └── shared.sh    — real-time shared state
│
├── network/        ← ระบบสื่อสาร
│   ├── registry.json — all agents catalog
│   ├── protocol.md   — message format
│   ├── bus.sh        — send/receive messages
│   └── router.sh     — route tasks → organs
│
├── agents/         ← ผู้เล่น
│   ├── innova.json   — innova agent card
│   ├── soma.json     — soma agent card
│   └── template.json — new agent template
│
├── eval/           ← การตรวจสอบ
│   ├── soul-check.sh — soul integrity
│   └── body-check.sh — full body check
│
└── docs/           ← เอกสาร
    └── multiagent-spec.md
```

## Message Flow

```
Human → soma: "สร้าง feature X"
soma  → innova bus: task:create-feature-X
innova ear.sh → hear → heart.sh route → hand.sh create
hand.sh → working.sh step → done
innova mouth.sh → soma bus: report:done
soma  → Human: "เสร็จแล้ว"
```

## Current Status

| System | Status |
|--------|--------|
| Organs (8) | ✅ สร้างแล้ว |
| Mind (3) | ✅ สร้างแล้ว |
| Memory (2) | ✅ สร้างแล้ว |
| Network (4) | ✅ สร้างแล้ว |
| Agents (3) | ✅ สร้างแล้ว |
| Eval | ✅ body-check.sh |
| Oracle | ✅ localhost:47778 |
