---
name: loop-discipline-and-qa-patterns
description: บทเรียนจาก management loop + chat-reqs loop — discipline ในการ run tests แทน doc, Opus QA pattern, concurrent Map bug
metadata:
  type: feedback
---

## Rule: Run tests before writing docs in any loop

เวลา loop iteration ต้อง output ที่จับต้องได้ทุกรอบ (commit หรือ test run) ไม่ใช่ doc plan

**Why:** iteration 3-4 เสียไปกับ doc writing แทนที่จะ run regression tests จริง
Advisor ต้องบอกถึงเปลี่ยน — ต้องรู้เองก่อน

**How to apply:** ถ้า loop iteration ไม่มี diff หรือ test output → หยุดและถามตัวเองว่าทำงานจริงไหม

---

## Rule: Opus QA บน security-adjacent code ทุก change

Pattern ที่เจอ: agent เขียน `pendingApprovals.set(command, Date.now())` — keyed by raw string
→ race condition เมื่อ 2 requests ใช้ command เดียวกัน

**Why:** bugs แบบนี้ไม่ถูกจับด้วย unit test ปกติ ต้องการ adversarial review

**How to apply:** ทุก Map/Set ที่ใช้ user input เป็น key → Opus QA บังคับ

---

## Rule: Validate routing key non-empty ก่อน save golden files

`_routingKey(string)` returns `""` → golden files corrupt → ทุก test ดูเหมือนผ่านแต่ผิด

**Why:** empty key เป็น valid input ทำให้ pickBackendByKey return BACKEND_ORDER[0] (fallback)
แต่ไม่ใช่ค่าจริงที่ควรได้ ถ้าไม่มี assertion จะไม่รู้จนกว่า production จะเจอ asymmetry

**How to apply:** ก่อน saveGolden(backend, data) ให้ assert ว่า entries มี routingKey !== ""

---

## Rule: Check push/PR access ก่อนเริ่ม loop

ทำงาน 9 ชั่วโมง แต่ `gh pr create` ไม่ได้เพราะ auth scope

**Why:** ถ้า deliverable คือ PR ต้อง verify ก่อนว่า push ได้และ repo ใช่

**How to apply:** ก่อนเริ่ม implementation loop → `git remote -v && gh repo view` verify access
