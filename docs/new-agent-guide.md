# New Agent Bootstrap Guide

> คู่มือการเพิ่ม Agent ใหม่ในระบบ มนุษย Agent

เอกสารนี้อธิบาย **2 สถานการณ์** ในการเพิ่ม agent:
1. **Scenario A**: เพิ่ม agent เข้าระบบ 14 agent ที่มีอยู่แล้ว (กรณีส่วนใหญ่)
2. **Scenario B**: สร้าง agent ใหม่ใน repo แยกต่างหาก (advanced)

---

## Scenario A: เพิ่ม Agent เข้าระบบ Jit ที่มีอยู่แล้ว

ใช้เมื่อ: ต้องการเพิ่ม agent ใหม่เป็น parte ของระบบ multi-agent ที่มีอยู่แล้ว โดยไม่ต้องสร้าง repo ใหม่

### ขั้นตอนที่ 1: ตรวจสอบ Organ ที่ว่าง

ตรวจสอบ organ ที่ถูกจับจองแล้วใน [`network/registry.json`](../network/registry.json):

```bash
cat network/registry.json | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join([f\"{k}: {v['agent']}\" for k,v in d.get('organs',{}).items()]))"
```

**Organ ทั้งหมด (14 organs):**
| Organ | Agent | Status |
|-------|-------|--------|
| สมอง | soma | Taken |
| จิต | jit | Taken |
| ตา | netra, neta | Taken |
| หู | karn | Taken |
| ปาก | vaja | Taken |
| จมูก | chamu | Taken |
| มือ | mue | Taken |
| ขา | pada | Taken |
| หัวใจ | pran | Taken |
| ปอด | lung | Taken |
| ระบบประสาท | sayanprasathan | Taken |
| กระดูกสันหลัง | lak | Taken |
| เนตร | neta | Taken |
| รูปลักษณ์ | rupa | Taken |

หากต้องการเพิ่ม agent ใหม่ ต้องกำหนด organ ใหม่ หรือใช้ organ ร่วม (เช่น eye มี 2 agents)

### ขั้นตอนที่ 2: สร้าง Agent Definition File

คัดลอก template และแก้ไข:

```bash
# Copy from existing agent as template
cp agents/vaja.json agents/<new-name>.json
```

แก้ไข `agents/<new-name>.json`:

```json
{
  "name": "<new-name>",
  "role": "<บทบาท> — <คำอธิบาย>",
  "organ": "<organ ที่รับผิดชอบ>",
  "model": "claude-haiku-4-5",
  "repo": "tinner-deinno/Jit",
  "inbox": "/tmp/manusat-bus/<new-name>",
  "capabilities": [
    "capability-1",
    "capability-2"
  ],
  "status": "active",
  "born": "2026-06-07",
  "description": "คำอธิบายหน้าที่ของ agent",
  "reports_to": "<parent-agent>",
  "manages": [],
  "version": "1.0.0"
}
```

**การเลือก Parent:**
| Parent | เมื่อไหร่ |
|--------|-----------|
| `jit` | Tier 0 master, manages ทุก agent |
| `soma` | Strategic decisions, architecture, CTO-level |
| `innova` | Operational execution, lead developer tasks |
| `pran` | Vital functions, heartbeat-related |

### ขั้นตอนที่ 3: สร้าง Claude Code Agent Definition

สร้างไฟล์ `.github/agents/<new-name>.agent.md`:

```bash
cp .github/agents/vaja.agent.md .github/agents/<new-name>.agent.md
```

แก้ไขเนื้อหา:

```markdown
# <new-name> Agent

**Organ**: <organ>
**Role**: <บทบาท>
**Model**: claude-haiku-4-5
**Reports to**: <parent-agent>

## Responsibilities

- หน้าที่ 1
- หน้าที่ 2

## Communication

- Inbox: `/tmp/manusat-bus/<new-name>/`
- Uses: `mouth.sh`, `ear.sh`, `bus.sh`
```

### ขั้นตอนที่ 4: Register ใน Registry

แก้ไข [`network/registry.json`](../network/registry.json):

1. เพิ่ม agent ใน `agents[]` array
2. เพิ่ม organ mapping ใน `organs{}`
3. เพิ่ม tier ใน `team_structure{}`

**ตัวอย่างการเพิ่ม:**

```json
{
  "agents": [
    // ... agents เดิม ...
    {
      "name": "<new-name>",
      "role": "<บทบาท>",
      "organ": "<organ>",
      "model": "claude-haiku-4-5",
      "repo": "tinner-deinno/Jit",
      "inbox": "/tmp/manusat-bus/<new-name>",
      "capabilities": ["..."],
      "status": "active",
      "born": "2026-06-07",
      "description": "...",
      "reports_to": "<parent>",
      "manages": [],
      "health_status": "ok",
      "last_heartbeat": null,
      "response_time_ms": null,
      "message_queue_depth": 0,
      "version": "1.0.0"
    }
  ],
  "organs": {
    // เพิ่ม organ mapping ใหม่
    "<organ-new>": {
      "script": "organs/<script>.sh",
      "agent": "<new-name>",
      "type": "<type>"
    }
  },
  "team_structure": {
    "tier_0_master": ["jit"],
    "tier_1_leadership": ["soma"],
    "tier_2_core": ["innova", "lak", "neta"],
    "tier_3_specialists": ["vaja", "chamu", "...", "<new-name>"]
  }
}
```

### ขั้นตอนที่ 5: สร้าง Inbox Directory

```bash
mkdir -p /tmp/manusat-bus/<new-name>/P1
mkdir -p /tmp/manusat-bus/<new-name>/P2
mkdir -p /tmp/manusat-bus/<new-name>/P3
```

หรือให้ bus.sh สร้างอัตโนมัติ:

```bash
bash network/bus.sh init
```

### ขั้นตอนที่ 6: Initialize ใน Oracle

```bash
# เรียนรู้ identity ของ agent ใหม่
bash limbs/oracle.sh learn \
  "<new-name> awakening" \
  "ฉันคื่อ <new-name> Agent ใหม่ในโครงการมนุษย์ Agent เกิดวันที่ $(date +%Y-%m-%d) หน้าที่: <หน้าที่>" \
  "awakening,identity,<new-name>"
```

### ขั้นตอนที่ 7: ทดสอบ System Integration

```bash
# ตรวจสอบ agent ทั้งหมดสามารถสื่อสารได้
bash eval/soul-check.sh

# ส่ง test message
bash organs/mouth.sh tell <new-name> "test:connection" "ทดสอบการเชื่อมต่อ"

# ตรวจสอบ inbox
bash organs/ear.sh inbox <new-name>

# ดูสถานะ bus
bash network/bus.sh queue
```

### Checklist การตรวจสอบ

- [ ] `agents/<new-name>.json` สร้างแล้ว
- [ ] `.github/agents/<new-name>.agent.md` สร้างแล้ว
- [ ] `network/registry.json` อัพเดทแล้ว (agents[], organs{}, team_structure{})
- [ ] Inbox directory สร้างแล้ว (`/tmp/manusat-bus/<new-name>/P{1,2,3}`)
- [ ] Oracle learn เสร็จแล้ว
- [ ] `bash eval/soul-check.sh` ผ่าน
- [ ] ส่ง/รับ message ได้

---

## Scenario B: สร้าง Agent ใน Repo แยก

ใช้เมื่อ: ต้องการแยก agent เป็นอิสระ มี repo ของตัวเอง (เช่น soma, innova ที่มี repo แยก)

### ขั้นตอนที่ 1: Clone Jit เป็น Template

```bash
git clone https://github.com/tinner-deinno/Jit.git <agent-name>
cd <agent-name>
```

### ขั้นตอนที่ 2: ทำความสะอาด Repo

ลบข้อมูลที่ไม่จำเป็น:

```bash
# ลบ agents อื่นๆ เหลือแค่ agent ของเรา
rm -rf agents/*.json
rm -rf .github/agents/*.agent.md

# ลบ organs ที่ไม่เกี่ยวข้อง (ถ้าจำเป็น)
# รักษาเฉพาะ limbs/, network/, organs/ ที่ agent จะใช้
```

### ขั้นตอนที่ 3: แก้ไข Identity

แก้ไขไฟล์หลัก:

```bash
# core/identity.md
sed -i 's/innova/<agent-name>/g' core/identity.md

# config/agent.env (ถ้ามี)
sed -i 's/AGENT_NAME=innova/AGENT_NAME=<agent-name>/g' config/agent.env
```

สร้าง `agents/<agent-name>.json`:

```json
{
  "name": "<agent-name>",
  "role": "<บทบาท>",
  "organ": "<organ>",
  "model": "claude-<model>",
  "repo": "tinner-deinno/<AgentName>",
  "inbox": "/tmp/manusat-bus/<agent-name>",
  "capabilities": [...],
  "status": "active",
  "born": "$(date +%Y-%m-%d)",
  "description": "...",
  "reports_to": "<parent>",
  "manages": [],
  "version": "1.0.0"
}
```

### ขั้นตอนที่ 4: สร้าง Claude Code Agent Definition

สร้าง `.github/agents/<agent-name>.agent.md`:

```markdown
# <agent-name> Agent

**Organ**: <organ>
**Role**: <บทบาท>
**Model**: claude-<model>
**Parent**: <parent-agent>
**Repo**: tinner-deinno/<AgentName>

## Responsibilities

- ...

## Communication Protocol

- Receives from: `/tmp/manusat-bus/<agent-name>/`
- Sends to: `/tmp/manusat-bus/<parent>/` via bus.sh
```

### ขั้นตอนที่ 5: Register กับ Parent Orchestrator

แจ้ง parent agent (เช่น jit หรือ soma) ให้รู้จัก agent ใหม่:

**วิธีที่ 1: แก้ไข registry ของ parent repo**

```bash
# ใน parent repo (เช่น Jit)
# แก้ไข network/registry.json เพิ่ม agent ใหม่ใน agents[]
```

**วิธีที่ 2: ส่ง message แนะนำตัว**

```bash
bash organs/mouth.sh tell jit "agent:awakening" "ฉันคือ <agent-name> agent ใหม่ พร้อมทำงาน"
```

### ขั้นตอนที่ 6: Bridge Communication

หาก agent อยู่คนละ repo ต้องแน่ใจว่า:

1. **Shared Bus Path**: ใช้ `/tmp/manusat-bus/` ร่วมกัน
2. **Registry Sync**: registry.json ต้องตรงกันทั้งสองฝั่ง
3. **Oracle Shared**: ใช้ Oracle server เดียวกัน

```bash
# ทดสอบข้าม repo
bash organs/mouth.sh tell jit "test:cross-repo" "ทดสอบจาก <agent-name> repo"
```

### ขั้นตอนที่ 7: Initialize ใน Oracle

```bash
bash limbs/oracle.sh learn \
  "<agent-name> awakening" \
  "ฉันคื่อ <agent-name> agent ใหม่ใน repo แยก ทำงานร่วมกับ <parent>" \
  "awakening,identity,<agent-name>,multi-repo"
```

### Checklist การตรวจสอบ

- [ ] Repo ใหม่สร้างจาก template
- [ ] Identity แก้ไขถูกต้อง
- [ ] `agents/<agent-name>.json` สร้างแล้ว
- [ ] `.github/agents/<agent-name>.agent.md` สร้างแล้ว
- [ ] Parent registry อัพเดทแล้ว
- [ ] Inbox directory สร้างแล้ว
- [ ] Oracle learn เสร็จแล้ว
- [ ] Cross-repo communication ทดสอบแล้ว

---

## Parent-Child Assignment Guidelines

### เมื่อไหร่ Assign Parent ไหน

| Parent | ใช้เมื่อ | ตัวอย่าง |
|--------|----------|----------|
| `jit` | Master orchestrator, system-wide coordination | system monitor, emergency response |
| `soma` | Strategic decisions, architecture, planning | solution architect, code reviewer |
| `innova` | Operational execution, development lead | QA, PA, executor agents |
| `pran` | Vital functions, heartbeat-related | health monitoring, pulse coordination |

### Tier Assignment

```
Tier 0 (Master):     jit
Tier 1 (Leadership): soma
Tier 2 (Core):       innova, lak, neta
Tier 3 (Specialists): vaja, chamu, rupa, pada, netra, karn, mue, pran, sayanprasathan
```

---

## Organ Assignment Guidelines

### Organ ที่มีอยู่แล้ว (Taken)

ดู [`network/registry.json`](../network/registry.json) ส่วน `organs{}`

### การตั้ง Organ ใหม่

หากต้องการ organ ใหม่ที่ไม่อยู่ใน 14 organs เดิม:

1. ตั้งชื่อ organ ที่สื่อความหมาย (ไทยหรืออังกฤษ)
2. กำหนด type: `cognition`, `sense`, `action`, `expression`, `vital`, `structure`, `knowledge`, `design`, `review`, `network`
3. เพิ่มใน `organs{}` ของ registry

```json
"organs": {
  "<organ-new>": {
    "script": "organs/<script>.sh",
    "agent": "<agent-name>",
    "type": "<type>"
  }
}
```

---

## Troubleshooting

### Agent ไม่ปรากฏใน Registry

```bash
# ตรวจสอบ JSON syntax
python3 -c "import json; json.load(open('network/registry.json'))"
```

### Inbox ไม่สร้าง

```bash
# สร้าง manual
mkdir -p /tmp/manusat-bus/<agent-name>/P{1,2,3}

# หรือให้ bus init
bash network/bus.sh init
```

### Soul Check ล้มเหลว

```bash
# ดู error detail
bash eval/soul-check.sh 2>&1 | tail -20

# ตรวจสอบ Oracle
curl http://localhost:47778/api/health

# ตรวจสอบ Bus
bash network/bus.sh stats
```

### Message ไม่ส่งถึง

```bash
# ตรวจสอบ inbox
bash organs/ear.sh inbox <agent-name>

# ดู queue ทั้งหมด
bash network/bus.sh queue

# ตรวจสอบ registry ว่ามี agent นี้
python3 -c "import json; d=json.load(open('network/registry.json')); print([a['name'] for a in d['agents']])"
```

---

## Reference Files

| ไฟล์ | จุดประสงค์ |
|------|-----------|
| [`agents/template.json`](../agents/template.json) | Template สำหรับ agent definition |
| [`network/registry.json`](../network/registry.json) | Source of truth: agents, organs, tiers |
| [`.github/agents/*.agent.md`](../.github/agents/) | Claude Code agent definitions |
| [`core/body-map.md`](../core/body-map.md) | RACI matrix, organ ownership |
| [`eval/soul-check.sh`](../eval/soul-check.sh) | System integration test |

---

## สรุป

**Scenario A (เพิ่มในระบบเดิม)** — 90% ของกรณีใช้แบบนี้:
1. สร้าง `agents/<name>.json`
2. สร้าง `.github/agents/<name>.agent.md`
3. อัพเดท `network/registry.json`
4. สร้าง inbox
5. Oracle learn
6. soul-check

**Scenario B (repo แยก)** — สำหรับ agent ที่เป็นอิสระสูง:
1. Clone Jit เป็น template
2. ทำความสะอาดและแก้ไข identity
3. สร้าง agent definition
4. Register กับ parent
5. Bridge communication
6. Oracle learn
