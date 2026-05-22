---
name: post-mortem
description: "เขียนบันทึกวิศวกรรมมาตรฐานของ bug ที่แก้แล้ว — root cause, mechanism, fix, validation, และที่มาของปัญหา สำหรับ engineer audience ใช้หลัง debug session แก้สำเร็จ ก่อนปิด ticket. Trigger on /post-mortem, เมื่อ user พูดว่า 'write post-mortem', 'RCA', 'root cause analysis', 'document this fix'"
---

# Post-Mortem (บันทึกหลังการต่อสู้)

บันทึกวิศวกรรมมาตรฐานของ bug fix เขียน **หลัง** debug แก้ได้จริงแล้ว **สำหรับ** engineer คนอื่น (และตัวเราใน 6 เดือน ที่จะลืมทุกอย่าง)

---

## เงื่อนไข — ห้ามร่างโดยไม่มีสิ่งเหล่านี้

ก่อนเขียนบรรทัดแรก ยืนยันครบทั้ง 4:

- [ ] **Reliable repro** มีอยู่ (ไม่ใช่ "บางทีเกิด" — เป็น deterministic หรือ high-rate-flake ที่คนอื่นรันได้)
- [ ] **Root cause รู้แล้ว** (mechanism ชัดเจน ไม่ใช่ hypothesis)
- [ ] **Fix ชัดเจน** (PR / commit / branch pointer)
- [ ] **Fix validated** (original repro ผ่าน; failing test ผ่าน)

ถ้าขาดอะไร → list สิ่งที่ขาดแล้วหยุด อย่าเขียนต่อ

---

## โครงสร้าง

เรียงตามลำดับ **Summary, Root cause, Fix, Validation บังคับ** ส่วนอื่น conditional

### 1. Summary _(บังคับ)_
หนึ่งย่อหน้า อะไรพัง ใน user/workload terms แก้ยังไงใน 1 ประโยค จุด issue/PR/owner คนที่อ่านแค่นี้ต้องได้คำตอบถูกต้อง

### 2. Symptom
สิ่งที่สังเกตได้จริง test output, error message, log line, perf number อย่า paraphrase — ใส่ identifier จริง

### 3. Root cause _(บังคับ)_
Bug mechanism จริง **ยินดีให้ใส่ code identifier** — function names, file paths, struct fields, branch conditions, commit SHAs เดิน cause chain ทั้งหมด นี่คือส่วนที่มีคุณค่ามากที่สุด

### 4. Why it produced the symptom
เชื่อม root cause กับ symptom หลายครั้งไม่ obvious — เดินสาย chain ให้คนอ่านตามทัน

### 5. Fix _(บังคับ)_
อะไรที่เปลี่ยน และ **ทำไม** change นี้แก้ root cause ไม่ใช่แค่ซ่อน symptom link PR/commit

### 6. How it was found
สั้น path การ debug:
- repro ทำ deterministic ยังไง
- tools ที่ใช้ (debugger, source tracing, knob enumeration, instrumentation)
- hypotheses ที่ลองแล้ว reject พร้อมเหตุผล 1 บรรทัด
- experiment เดียวที่ยืนยัน cause

### 7. Validation _(บังคับ)_
Evidence ที่พิสูจน์ fix ทำงาน original repro pass, regression tests pass ไม่ใช่แค่ "it works on my machine"

### 8. How it slipped through (optional, แต่สำคัญ)
ช่องว่างใน process ที่ปล่อยให้ bug เข้ามา ถ้าชัดเจน — ใส่ proposal หรือ action item ป้องกัน ระวัง: อย่า manufacture blame ที่ไม่มีมูล

---

## Jit Context

หลัง post-mortem สรุปแล้ว → persist เข้า Oracle เสมอ:

```bash
# บันทึก bug pattern เข้า Oracle
bash limbs/oracle.sh learn "bug-pattern" \
  "Component: <x>. Root cause: <y>. Fix: <z>. Prevention: <w>" \
  "post-mortem,bug,<component>"
```

ถ้าเกี่ยวกับ agent หรือ organ → แจ้ง jit:
```bash
bash organs/mouth.sh tell jit "post-mortem:complete:<component>:<one-line-summary>"
```
