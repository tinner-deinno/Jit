# SKILL: innova-organs — การใช้อวัยวะ (Organs) ของ innova

## เมื่อไหร่ใช้ skill นี้

ทุกครั้งที่ innova ต้องทำงาน: รับ task จาก soma, ใช้อวัยวะที่ถูกต้อง, report กลับ

---

## Organ Routing — ใช้อวัยวะไหนทำอะไร

| งาน | อวัยวะ | คำสั่ง |
|-----|--------|------|
| อ่านไฟล์, observe | **ตา** `eye.sh` | `bash organs/eye.sh read <path>` |
| รับ message, ฟัง bus | **หู** `ear.sh` | `bash organs/ear.sh receive` |
| ส่ง message, report | **ปาก** `mouth.sh` | `bash organs/mouth.sh tell soma "report:done" "..."` |
| ตรวจ service, disk, git | **จมูก** `nose.sh` | `bash organs/nose.sh sniff` |
| สร้าง/แก้/ลบไฟล์ | **มือ** `hand.sh` | `bash organs/hand.sh create <path>` |
| navigate, git, deploy | **ขา** `leg.sh` | `bash organs/leg.sh go jit` |
| orchestrate, route task | **หัวใจ** `heart.sh` | `bash organs/heart.sh pump <type> <args>` |
| ฟอกเลือด, คืนพลังงาน | **ปอด** `lung.sh` | `bash organs/lung.sh filter <context>` |
| ส่ง event, signal | **ระบบประสาท** `nerve.sh` | `bash organs/nerve.sh signal <event> <data>` |

---

## Step-by-Step: รับ task จาก soma

```bash
# 1. ฟัง inbox
AGENT_NAME=innova bash organs/ear.sh receive

# 2. บันทึก context
bash memory/working.sh focus "<task name>"

# 3. route ผ่าน heart (auto)
bash organs/heart.sh pump task:<type> <args>

# 4. ทำงาน (heart route ให้ถูก organ อัตโนมัติ)

# 5. report กลับ soma
bash organs/mouth.sh tell soma "report:done" "<summary>"

# 6. บันทึก working memory
bash memory/working.sh done "<brief summary>"
```

---

## Eye (ตา) — Observation

```bash
# อ่านไฟล์
bash organs/eye.sh read <path>

# scan directory
bash organs/eye.sh scan <dir>

# observe + บันทึก Oracle
bash organs/eye.sh observe <path>

# fetch URL
bash organs/eye.sh web <url>

# ดู git log
bash organs/eye.sh git
```

## Ear (หู) — Listening

```bash
# รับทุก message ใน inbox
AGENT_NAME=innova bash organs/ear.sh receive

# รับ message ล่าสุด
AGENT_NAME=innova bash organs/ear.sh latest

# นับ pending
AGENT_NAME=innova bash organs/ear.sh count

# block รอ message ใหม่ (daemon mode)
AGENT_NAME=innova bash organs/ear.sh listen
```

## Mouth (ปาก) — Speaking

```bash
# บอก soma
bash organs/mouth.sh tell soma "report:done" "งานเสร็จแล้ว: X"

# broadcast ทุก agent
bash organs/mouth.sh broadcast "alert:system-check" "ระบบปกติ"

# รายงานลง Oracle
bash organs/mouth.sh report "task-result" "ทำ X สำเร็จ เพราะ Y"
```

## Nose (จมูก) — Detection

```bash
# ตรวจระบบทั้งหมด
bash organs/nose.sh sniff

# ตรวจ Oracle
bash organs/nose.sh alert oracle

# monitor disk
bash organs/nose.sh alert disk

# ดู git diff
bash organs/nose.sh changes
```

## Hand (มือ) — File Actions

```bash
# สร้างไฟล์
bash organs/hand.sh create <path> "<content>"

# แก้ไฟล์ (auto backup)
bash organs/hand.sh edit <path> "<old>" "<new>"

# append
bash organs/hand.sh append <path> "<content>"

# ลบ (ต้องยืนยัน)
bash organs/hand.sh delete <path> confirm

# รัน task file
bash organs/hand.sh execute <task.sh>

# build project
bash organs/hand.sh build <dir>
```

## Leg (ขา) — Navigation

```bash
# ไป location ที่รู้จัก
bash organs/leg.sh go jit|oracle|home|tmp

# clone repo
bash organs/leg.sh climb <github-url>

# pipeline หลาย steps
bash organs/leg.sh step 3 "cmd1" "cmd2" "cmd3"

# git commit
bash organs/leg.sh git "commit message"

# deploy
bash organs/leg.sh deploy bun|docker|git
```

## Heart (หัวใจ) — Orchestration

```bash
# ตรวจชีพจร
bash organs/heart.sh beat

# route task อัตโนมัติ
bash organs/heart.sh pump task:read <file>
bash organs/heart.sh pump task:create <path>
bash organs/heart.sh pump task:git <message>

# ดู vitality
bash organs/heart.sh rhythm

# start daemon
bash organs/heart.sh start
```

## Nerve (ระบบประสาท) — Events

```bash
# ส่ง event
bash organs/nerve.sh signal <event-name> <data>

# ฟัง event
bash organs/nerve.sh listen <event-name>

# ดู pending events
bash organs/nerve.sh pending

# connect สอง agent
bash organs/nerve.sh connect innova soma
```

---

## Anti-Patterns

```
❌ ทำ file operation โดยไม่ผ่าน hand.sh (ไม่มี backup)
❌ ส่ง message โดยไม่ผ่าน mouth.sh (ไม่ log)
❌ navigate โดยไม่ผ่าน leg.sh (ไม่ track)
❌ ลืม report กลับ soma หลังงานเสร็จ
❌ ทำงานนานเกิน 2 ชั่วโมงโดยไม่ report
```

---

## Working Memory Pattern

```bash
# ทุก task ต้องมี
bash memory/working.sh focus "<task>"
bash memory/working.sh step "กำลังทำ: X"
bash memory/working.sh context "input_file" "/path/to/file"
# ... ทำงาน ...
bash memory/working.sh done "สรุป: ทำ X สำเร็จ"
```
