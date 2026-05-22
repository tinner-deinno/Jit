---
name: debug-mantra
description: "วินัยการ debug แบบ 4 มนตรา — reproduce → trace the fail path → falsify hypothesis → cross-reference every breadcrumb. ท่องมนตราก่อนเริ่ม debug ทุกครั้ง ใช้เมื่อ: user รายงาน bug, พูดว่า broken/failing/throwing, ถาม debug/diagnose/investigate, หรือวาง stack trace / error log. Trigger on /debug-mantra"
---

# Debug Mantra (ศีล 4 ประการของนักดีบัก)

วินัย 4 ขั้นตอนสำหรับทุก debug session — ท่องมนตราก่อน แล้วปฏิบัติตามลำดับ

## ท่องก่อนเสมอ — verbatim

> **มนตรา:**
> 1. **First is reproducibility.** ปัญหาสามารถ reproduce ได้หรือไม่?
> 2. **Know the fail path.** Debugger ก่อน; แล้ว source trace + knob enumeration; แล้ว in-code instrumentation
> 3. **Question your hypothesis.** อะไรจะ disprove มันได้?
> 4. **Every run is a breadcrumb.** Cross-reference ทุก run เสมอ

จากนั้นเริ่มงาน

---

## 1. Reproduce reliably

สร้าง repro ก่อนทำอะไรทั้งนั้น

- **Reliable repro** → บันทึก exact steps, inputs, environment เป็น runnable artifact: failing test, curl script, CLI invocation
- **Flaky repro** → bug ยัง debug ไม่ได้ ต้องเพิ่มอัตรา flake ก่อน: loop, stress, narrow timing, inject sleep. 50% flake = debuggable; 1% = ยังไม่ได้
- **No repro** → หยุด บอก user ตรงๆ อย่า hypothesize ต่อ

Target: สัญญาณ pass/fail ที่เร็ว (1–5s) และ deterministic

## 2. Know the fail path

เมื่อ reproduce ได้แล้ว หา *ว่าโค้ดพังที่ไหน* และ *อะไรที่ทำให้พัง* — ลอง escalate ทีละขั้น:

1. **Attach debugger** ถ้า env รองรับ ใส่ breakpoint ที่จุดพัง ดีกว่า log 10 บรรทัด
2. **Source trace + knob enumeration** ถ้าไม่มี debugger ให้ trace code path ทั้งหมดและ list ทุก knob ที่ส่งผลต่อ outcome:
   - config flags, env vars, feature toggles
   - branch conditions, input shape
   - timing, concurrency, build options
3. **In-code instrumentation** ถ้า knobs ภายนอกยังหาไม่เจอ เพิ่ม `printf`/log ภายใน tag ด้วย unique prefix เช่น `[DBG-a4f2]`

## 3. Falsify the hypothesis

เมื่อเจอ root cause candidate — ตรวจสอบก่อนทดสอบ:

- มัน explain symptom ได้ทั้งหมดหรือเปล่า?
- อะไรคือ proof ที่ง่ายที่สุด? อะไรคือ disproof ที่ชัดที่สุด?
- **รัน disproof ก่อน** ถ้า hypothesis รอดก็ real ถ้าตายก็ประหยัดเวลา
- สร้าง 3–5 hypotheses ไม่ใช่แค่ 1

## 4. Every run is a breadcrumb

เก็บ **ledger** ของทุก experiment ใน session:
- อะไรเปลี่ยน, อะไรเกิดขึ้น, rule in/out อะไรได้
- เมื่อ hypothesis ใหม่เกิดขึ้น ตรวจว่า **ทุก** past run ยังสอดคล้องหรือไม่
- ถ้าไม่แน่ใจ ออกแบบ **experiment เดียว** ที่ให้คำตอบชัดเจน แล้วรันนั้น
- อัปเดต ledger หลังทุก run

---

## Jit Integration

เมื่อ debug ใน Jit context:
```bash
# ดู shared state ก่อน debug
cat /tmp/manusat-shared.json | jq .

# ตรวจ agent inbox ที่เกี่ยวข้อง
bash organs/ear.sh inbox <agent-name>

# ดู system health
bash eval/body-check.sh
```

ทุก debug session ควร learn ผลลัพธ์เข้า Oracle หลังแก้ไขแล้ว:
```bash
bash limbs/oracle.sh learn "bug-pattern" "<root-cause-summary>" "debug,bug,<component>"
```
