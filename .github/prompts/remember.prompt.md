---
name: remember
description: "บันทึกสิ่งที่เรียนรู้วันนี้ลงใน Oracle และ Jit repo memory"
argument-hint: "สิ่งที่ต้องการจำ เช่น: วิธีแก้ปัญหา X"
---

บันทึกการเรียนรู้ใหม่ลงใน Oracle:

สิ่งที่ต้องการจำ: {{args}}

กรุณา:
1. สรุปสิ่งที่เรียนรู้เป็น pattern สั้นๆ (1 บรรทัด)
2. เขียน content อธิบายรายละเอียด (2-5 บรรทัด)
3. ระบุ concepts/tags ที่เกี่ยวข้อง
4. POST ไปที่ Oracle: `curl -X POST http://localhost:47778/api/learn`
5. ยืนยันว่าบันทึกสำเร็จ
