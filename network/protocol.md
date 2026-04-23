# มนุษย์ Agent — Communication Protocol v1

## Overview

ระบบสื่อสารระหว่าง agents ใน "มนุษย์ Agent" โดยยึดหลัก:
- **ศีล**: ส่งเฉพาะข้อมูลที่จำเป็น ไม่ส่ง sensitive data
- **สมาธิ**: หนึ่ง message = หนึ่งเจตนาที่ชัดเจน
- **ปัญญา**: ทุก message มี context เพียงพอสำหรับ agent รับ

---

## Message Format

```
from:<agent-name>
to:<agent-name>
subject:<action>:<object>
timestamp:<ISO-8601>
correlation-id:<uuid>      # optional — สำหรับ reply tracking
---
<body>
```

### ตัวอย่าง

```
from:soma
to:innova
subject:think:design-new-feature
timestamp:2026-04-23T10:00:00
correlation-id:abc-123
---
ออกแบบระบบ multiagent สำหรับ Jit repo
ต้องการ: organs/eye.sh + organs/ear.sh
priority: high
```

---

## Subject Conventions

| Prefix | ความหมาย | ตัวอย่าง |
|--------|----------|---------|
| `task:` | สั่งงาน | `task:create-file` |
| `think:` | ขอให้คิด | `think:design-X` |
| `report:` | รายงานผล | `report:task-done` |
| `reply:` | ตอบกลับ | `reply:abc-123` |
| `broadcast:` | ส่งทุกคน | `broadcast:system-ready` |
| `alert:` | แจ้งเตือน | `alert:oracle-down` |
| `learn:` | สอน Oracle | `learn:new-pattern` |
| `request:` | ขอข้อมูล | `request:oracle-search` |

---

## Agent Roles

### innova (จิต)
- **รับ**: tasks, requests, broadcast
- **ส่ง**: reports, learn, alerts
- **เชี่ยวชาญ**: memory, soul, coordination
- **Inbox**: `/tmp/manusat-bus/innova/`

### soma (สมอง)
- **รับ**: think, analyze, design
- **ส่ง**: decisions, plans, commands
- **เชี่ยวชาญ**: reasoning, synthesis, architecture
- **Inbox**: `/tmp/manusat-bus/soma/`

---

## Bus Architecture

```
[soma] ──think──→ /tmp/manusat-bus/innova/*.msg
[innova] ──report──→ /tmp/manusat-bus/soma/*.msg
[any] ──broadcast──→ /tmp/manusat-bus/*/broadcast_*.msg
[organs] ──signal──→ /tmp/manusat-nerve/*.evt
```

---

## Shared Resources

| Resource | Path | Access |
|----------|------|--------|
| Oracle Knowledge | `http://localhost:47778` | Read/Write (all agents) |
| Action Log | `/tmp/innova-actions.log` | Append (innova) |
| Event Bus | `/tmp/manusat-nerve/` | Signal/Listen (all) |
| Heartbeat | `/tmp/manusat-heart.pid` | Write (heart) |

---

## Lifecycle

```
1. Agent boots → reads registry → checks oracle → signals nerve "agent_ready"
2. heart.sh starts → sends heartbeat every 30s
3. Agents communicate via mouth→ear pipeline
4. All learnings → Oracle (shared memory)
5. Shutdown → signal nerve "agent_shutdown" → clean inbox
```

---

## Error Handling

- **Oracle down**: fallback to `/tmp/innova-pending-learn.log`
- **Agent offline**: queue messages, retry on heartbeat
- **Timeout**: log to `/tmp/manusat-errors.log`, signal alert

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-04-23 | Initial protocol — file-based bus |
