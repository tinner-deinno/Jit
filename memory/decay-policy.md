# Knowledge Decay & Archival Policy (JIT-028)

## Overview

ระบบความทรงจำของ Jit มีกลไก "knowledge decay" เพื่อจัดการกับความล้าสมัยของความรู้อัตโนมัติ

## Metadata Fields

ทุก memory entry มี metadata:

| Field | Type | Description |
|-------|------|-------------|
| `access_count` | integer | จำนวนครั้งที่ถูกเรียกใช้ |
| `last_accessed` | timestamp | ครั้งล่าสุดที่ถูกเข้าถึง |
| `created_date` | timestamp | วันที่สร้าง |
| `expiry_date` | timestamp | วันหมดอายุ (ถ้าตั้ง) |
| `archived` | boolean | ถูก archive แล้วหรือไม่ |
| `decay_score` | float | คะแนนความเกี่ยวข้อง (0-1) |

## Decay Scoring Formula

```
relevance = (recency_weight * recency_score) + 
            (access_weight * access_score) + 
            (semantic_weight * semantic_relevance)
```

โดยที่:
- `recency_score = 1 / (1 + days_since_access / 30)` — ลดลงตามกาลเวลา
- `access_score = min(1, log10(access_count + 1) / 3)` — เพิ่มตามการใช้งาน
- `semantic_relevance` — จาก vector similarity (0-1)
- weights: recency=0.4, access=0.3, semantic=0.3 (ปรับได้)

## Archival Policy

- **Archive threshold**: 60 วันที่ไม่ถูกเข้าถึง
- **Archive location**: `/workspaces/Jit/memory/archive/`
- **Archived entries**: ยังค้นหาได้ผ่าน `recall --archived` แต่ไม่แสดงในผลปกติ
- **Restoration**: ย้ายกลับจาก archive → active ได้

## Commands

### oracle.sh learn-expires

```bash
./limbs/oracle.sh learn-expires "pattern name" "content" "concepts" 30
# expiry = now + 30 days
```

### memory/shared.sh recall

```bash
./memory/shared.sh recall "query"           # ค้นหา active memories (recent+high-access ก่อน)
./memory/shared.sh recall --archived "query" # ค้นหา archived memories
```

### Heartbeat Archive Task

```bash
./mind/heartbeat.sh --archive
# ย้าย entries >60 วันที่ไม่ถูกเข้าถึงไป /memory/archive/
```

## Implementation Status

- [x] Memory metadata structure
- [x] learn-expires command
- [x] Decay scoring formula
- [x] recall prioritization
- [ ] Archive background task
- [ ] --archived flag implementation
