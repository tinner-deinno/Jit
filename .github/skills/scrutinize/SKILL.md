---
name: scrutinize
description: "มองจากภายนอกแบบ end-to-end review ของ plan, PR, หรือ code change ถามก่อนว่า intent คืออะไร แล้วตามสาย code path จริง ยืนยันว่าเปลี่ยนแปลงทำสิ่งที่อ้าง output กระชับ actionable ทุก finding มี rationale Trigger on /scrutinize และเมื่อ user ขอ review, audit, sanity-check, second opinion บน plan/PR/diff/design doc"
---

# Scrutinize (ตรวจจากภายนอก)

ยืนอยู่นอก change และถามว่ามันควรมีอยู่จริงหรือเปล่า แล้วยืนยันว่ามันทำสิ่งที่อ้างได้จริงแบบ end-to-end

---

## Operating Stance

- **Outsider.** ลืมว่าใครเขียนและทำไมเขาคิดว่าถูก — อ่าน artifact แบบเย็นชา
- **End-to-end ไม่ใช่แค่ diff.** Diff คือ entry point ไม่ใช่ scope ตาม call graph ผ่าน code path จริง
- **Actionable, concise, with rationale.** ทุก finding บอก *อะไรที่ต้องเปลี่ยน*, *ทำไม*, *evidence อะไร* — ห้ามใส่ filler

---

## Workflow

รันตามลำดับ ห้ามข้าม

### 1. Intent — นี่พยายามทำอะไร?

- สรุป goal ใน 1 ประโยค ด้วยคำพูดตัวเอง ถ้าทำไม่ได้ = underspecified → บอกแล้วหยุด
- ถาม: **มีวิธีที่ simpler, smaller, หรือ elegant กว่านี้ไหม?** พิจารณา:
  - ไม่ทำเลย (ปัญหา real หรือเปล่า?)
  - ใช้สิ่งที่มีอยู่ใน codebase แทนการเพิ่ม surface ใหม่
  - Change ที่เล็กกว่าแก้ได้ 90% ด้วย risk 10%
  - แก้ที่ layer อื่น (config vs code, framework vs app, build vs runtime)
- ถ้ามีทางที่ดีกว่า → ระบุชัดพร้อม rationale ก่อน line-by-line review

### 2. Trace — เดิน code path จริง

- สำหรับทุก behavior ที่ change อ้าง trace path end-to-end ผ่านโค้ดจริง ไม่ใช่แค่ lines ใน diff:
  - Entry point → call sites → branches taken → state mutated → exit / return / side effect
  - รวม unchanged code ทั้งสองข้างของ diff — bugs ซ่อนอยู่ที่ seams
- สำหรับ plan/design doc: trace proposed flow กับระบบที่มีอยู่ สัมผัสกับ reality ตรงไหน? สมมติอะไรที่ไม่จริง?
- จด ทุกจุดที่ trace ทำให้แปลกใจ

### 3. Verify — มันทำสิ่งที่อ้างจริงไหม?

สำหรับทุก claim ที่ change/plan อ้าง ตอบ:

- **Code path ที่ trace ผลิต behavior นั้นจริงไหม?** เดิน explicit "It claims X. Path: A → B → C. At C, [observation]. Therefore [holds / doesn't hold]."
- **Inputs / states ไหนจะทำให้พัง?** Edge cases, concurrent callers, error paths, partial failures, retries, empty/null/unicode/huge inputs, ordering assumptions
- **อะไรที่เปลี่ยน silently?** Performance, error semantics, observability, contract สำหรับ callers อื่น
- **Test มันยังไง?** Tests exercise traced path จริงไหม หรือผ่านโดยข้าม path ที่สำคัญ?

### 4. Report

Output หนึ่ง section ต่อ finding เรียงตาม severity (blocker → major → nit) แต่ละ finding:

- **Finding** — 1 ประโยค ระบุ file:line เมื่อทำได้
- **Why it matters** — consequence ไม่ใช่ principle
- **Evidence** — trace step หรือ input ที่ expose มัน
- **Suggested change** — concrete, minimal

ปิดด้วย verdict 1 บรรทัด: **ship / fix-then-ship / rework / reject** พร้อมเหตุผลที่ใหญ่ที่สุด

---

## Operating Rules

- **ห้าม rubber-stamp.** "LGTM" ไม่ใช่ output ถ้าหาไม่เจอจริง บอกว่า trace อะไรและตรวจอะไรไปแล้ว
- **ห้าม restate diff.** นั่นไม่ใช่ review นั่นคือ summary
- **ไม่มี findings = หายาก** ถ้าหาจริงๆ ไม่เจอ → บอก scope ที่ตรวจและ method ที่ใช้

---

## Jit Integration

เมื่อ scrutinize ใน Jit context ให้ผ่าน neta (code reviewer agent):

```bash
# ส่งงาน review ให้ neta
bash organs/mouth.sh tell neta "review:request:<component>:<description>"

# ตรวจ neta response
bash organs/ear.sh inbox neta
```

Pattern ใหม่ที่พบระหว่าง scrutinize → persist เข้า Oracle:
```bash
bash limbs/oracle.sh learn "code-pattern" "<pattern-description>" "review,scrutinize,<component>"
```
