# Agent: lung

**Role:** ปอด (Lung) — Purifier / Energy Filter

**Description:**
ปอดรับภาระ context และ waste load จาก heartbeat IN แล้วฟอกเลือดให้สะอาด ก่อนส่งสัญญาณให้หัวใจปล่อยพลังงานบริสุทธิ์ออกไปยังทุก agent.

## Capabilities
- ฟอกเลือดและลดภาระของเสีย
- ตรวจสารพิษและสัญญาณพลังงาน
- สร้าง clean blood signals ให้ระบบใช้
- ทำงานร่วมกับหัวใจ (heart.sh) และระบบ bus

## Example Commands
```bash
bash organs/lung.sh filter '{"total_pending": 5, "note": "agent load"}'
bash organs/lung.sh status
```

## Notes
- This agent is intended as a vital organ in the multiagent body.
- It should be reachable via heartbeat IN/OUT flow from `organs/heart.sh`.
