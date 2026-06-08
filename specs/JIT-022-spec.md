# JIT-022: Chain-of-Thought Logging Specification

## Overview

เพิ่มระบบบันทึก reasoning chain (CoT - Chain of Thought) ลงใน `think.sh` เพื่อให้:
- Agents สามารถติดตามการตัดสินใจของตนเอง
- soma ใช้ในการ retrospective วิเคราะห์ pattern การตัดสินใจ
- สร้างความโปร่งใสในกระบวนการคิดของ agents

## Implementation Details

### Log File Location

```
/tmp/manusat-cot-log.jsonl
```

JSON Lines format — แต่ละบรรทัดคือ 1 JSON object

### Entry Format

```json
{
  "agent": "innova",
  "timestamp": "2026-06-08T04:13:42+00:00",
  "intent": "วางแผน: implement feature X",
  "step": 1,
  "substeps": ["understand", "search_oracle", "plan_approach"],
  "oracle_queries": ["task_analysis"],
  "decision": "proceed_with_plan"
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `agent` | string | Agent name (จาก AGENT_NAME env var) |
| `timestamp` | ISO 8601 | เวลาที่บันทึก |
| `intent` | string | เจตนา/จุดประสงค์ของการคิด |
| `step` | integer | ลำดับขั้นตอนใน reasoning chain |
| `substeps` | string[] | รายละเอียดย่อยของขั้นตอน |
| `oracle_queries` | string[] | คำค้นหาที่ใช้กับ Oracle |
| `decision` | string | ผลการตัดสินใจ |

### API Functions (lib.sh)

| Function | Description |
|----------|-------------|
| `cot_log "$intent" "$step" "$substeps" "$queries" "$decision"` | บันทึก CoT entry |
| `cot_read [limit]` | อ่าน last N entries (raw JSONL) |
| `cot_format [limit]` | แสดง formatted output พร้อมสี |
| `cot_count` | นับจำนวน entries ทั้งหมด |
| `cot_clear` | ล้าง log file |

### Usage

```bash
# Agent วางแผนงาน — อัตโนมัติ log CoT
bash limbs/think.sh plan "implement feature" "context here"

# ดู CoT log ล่าสุด 10 chains
bash limbs/think.sh log --cot

# ดูเฉพาะ 5 chains
bash limbs/think.sh log --cot 5

# ล้าง log (สำหรับ testing)
bash limbs/think.sh log --clear
```

### Soma Retrospective Integration

soma สามารถอ่าน CoT log โดยตรงด้วย Python:

```python
import json

with open('/tmp/manusat-cot-log.jsonl') as f:
    entries = [json.loads(line) for line in f if line.strip()]

# วิเคราะห์ decision patterns
decisions = [e['decision'] for e in entries]
agent_counts = {}
for e in entries:
    agent = e['agent']
    agent_counts[agent] = agent_counts.get(agent, 0) + 1
```

## Acceptance Criteria

- [x] `think.sh plan` logs to `/tmp/manusat-cot-log.jsonl`
- [x] Entry format มี intent, step, substeps, queries, decision
- [x] `log --cot` แสดง last 10 chains ในรูปแบบที่อ่านง่าย
- [x] JSONL format ง่ายแก่การ parse โดยโปรแกรม
- [x] ทดสอบแล้วกับหลาย agents (innova, soma)

## Related Tickets

- JIT-021: bus message tracing
- JIT-023: memory vector embeddings

## History

- **2026-06-08**: Implemented by innova
  - Added `cot_log()`, `cot_format()`, `cot_read()`, `cot_count()`, `cot_clear()` to `limbs/lib.sh`
  - Modified `limbs/think.sh` plan mode to auto-log CoT
  - Added `log --cot` and `log --clear` subcommands
