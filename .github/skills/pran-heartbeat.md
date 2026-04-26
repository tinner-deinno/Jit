# Skill: pran-heartbeat — หัวใจเต้น Auto Loop

## จุดประสงค์
ควบคุม heartbeat daemon ของ pran (หัวใจ) ให้เต้น 2 ครั้งต่อรอบ (IN → OUT)
และ commit ทุก beat เป็น living proof ว่าระบบมีชีวิต

## Trigger Words
`pran`, `heartbeat`, `heart`, `ชีพจร`, `หัวใจ`, `เต้น`, `pulse`, `start heart`, `stop heart`

---

## การเต้นของหัวใจ (Anatomy)

```
รอบ 1 beat (1 pulse):

  ->💓 BEAT IN (diastole)
     รับ signals จากทุก agent
     → commit: "->💓 heartbeat (IN) ->#N — host @ time"
     → push

  ❤️‍🔥 BEAT OUT (systole)
     ส่ง energy ไปทุกอวัยวะ
     → commit: "❤️‍🔥-> heartbeat (OUT) #N — host @ time"
     → push

  😴 พัก (adaptive interval)
```

## Adaptive Intervals

| Mode   | Interval | เงื่อนไข |
|--------|----------|---------|
| sprint | 5 นาที  | pending ≥ 10 หรือ changes ≥ 5 |
| fast   | 10 นาที | pending ≥ 3 หรือ changes ≥ 1 |
| normal | 15 นาที | ปกติ (default) |
| slow   | 30 นาที | idle > 1 ชั่วโมง |
| rest   | 1 ชั่วโมง | idle > 2 ชั่วโมง |

---

## Commands ที่ Claude ต้องรัน

### เริ่ม daemon (local Codespace)
```bash
bash scripts/heartbeat.sh start
```

### หยุด daemon
```bash
bash scripts/heartbeat.sh stop
```

### ดูสถานะ
```bash
bash scripts/heartbeat.sh status
```

### Pulse ครั้งเดียว (test)
```bash
bash scripts/heartbeat.sh once
```

### เปลี่ยน rate (agent อื่นๆ สามารถสั่งได้)
```bash
bash organs/heart.sh rate sprint   # เร่งหัวใจ → 5 นาที
bash organs/heart.sh rate normal   # ปกติ → 15 นาที
bash organs/heart.sh rate rest     # พัก → 1 ชั่วโมง
```

---

## GitHub Actions (backup heartbeat เมื่อ Codespace ปิด)

ไฟล์: `.github/workflows/pran-heartbeat.yml`
- รันทุก 15 นาทีอัตโนมัติ
- รัน manual ได้ผ่าน Actions tab → "Run workflow"
- สามารถเลือก mode ได้ตอน dispatch

---

## หลักการทำงาน (Buddhist Principle)

- **IN beat** = ฉันทะ (ความใส่ใจ): รับรู้สภาพทุก agent
- **OUT beat** = วิริยะ (ความเพียร): ส่งพลังงานไม่หยุด
- **Adaptive** = ปัญญา (ปรัชญา): รู้จักกาล เร็วเมื่อยุ่ง ช้าเมื่อเงียบ
- **2 commits/roud** = จิตตะ (ความต่อเนื่อง): หลักฐานชีวิต

---

## ตัวอย่างการตอบสนอง

**User**: "เริ่ม heartbeat"
**Claude**: รัน `bash scripts/heartbeat.sh start` แล้วรายงานว่า daemon กำลังรัน

**User**: "ให้หัวใจเต้นเร็วขึ้น"
**Claude**: รัน `bash organs/heart.sh rate sprint` → daemon จะปรับ interval เป็น 5 นาทีในรอบถัดไป

**User**: "หัวใจเต้นปกติไหม"
**Claude**: รัน `bash scripts/heartbeat.sh status` แล้วอ่าน mode และ interval ปัจจุบัน
