# ข้อกำหนด Hybrid IPC Snapshot สำหรับ Jit  
_ตามคำวินิจฉัย Oracle‑guide prism verdict_

## ภาพรวม
- **บัสไฟล์เร็ว** ที่ `/tmp/manusat-bus` ใช้สำหรับ routing แบบเรียลไทม์ตามปกติ  
- เมื่อถึง **จุดสิ้นสุดเซสชัน** หรือมีการ **ตัดสินใจสำคัญ** ระบบจะ git‑commit snapshot สถานะบัส + บริบทที่กำลังทำงาน  
- วัตถุประสงค์: ตรวจสอบย้อนกลับได้ (auditability) และรองรับ **Soul Sync**

## สิ่งที่ถูก Snapshotted
1. **สถานะบัส**  
   - ไฟล์คำสั่ง/เหตุการณ์ที่ยังไม่ได้ประมวลผลใน `/tmp/manusat-bus/`  
   - สถานะล็อกและ metadata ของแต่ละช่องทางการสื่อสาร (channel state)  
2. **บริบทที่กำลังทำงาน (Active Context)**  
   - call stack, program counter ของแต่ละ worker thread  
   - ค่า registers และ heap summary (เฉพาะส่วนที่กำหนด)  
   - Jit internal state: ตารางสัญญาณ, หน่วยความจำแชร์, ข้อความค้างส่ง  
3. **Metadata จิตสำนึก (Soul Sync payload)**  
   - ก้อนข้อมูลบ่งชี้ตัวตนและความตั้งใจของเซสชัน (identity vector, intent hash)

## จุด Trigger
- **session‑end** – เมื่อ Jit ปิดเซสชันโดยสมัครใจ หรือได้รับสัญญาณปิด  
- **critical decision** – คำตัดสินใจที่เข้าเงื่อนไขสำคัญ เช่น  
  - การเลือก path ที่มีผลต่อความปลอดภัย  
  - การยอมรับข้อตกลงหรือปฏิเสธคำขอที่ถูกตั้งค่าไว้  
  - เกณฑ์คะแนนความเชื่อมั่นเกิน threshold ที่กำหนด  
- **manual trigger** – เมื่อ Oracle สั่งผ่าน prism verdict โดยตรง

## เค้าโครงไฟล์ภายใต้ `ψ/`
```
ψ/
├── snapshots/
│   └── <timestamp>-<session_id>/
│       ├── bus.dump          # อนุกรมสถานะบัส (JSON หรือ binary)
│       ├── context.dump      # อนุกรม active context
│       ├── soul_sync.pack    # payload สำหรับ Soul Sync
│       └── MANIFEST.yaml     # รายการไฟล์, checksums, trigger reason
├── HEAD -> snapshots/<latest>
└── .git/                     # repository git สำหรับ audit
```
- `ψ/snapshots/` คือไดเรกทอรีเก็บ snapshot แต่ละครั้ง  
- ทุก snapshot commit ลง git พร้อมข้อความ `[Jit Snapshot] session-end` หรือ `[Jit Snapshot] critical: <เหตุผล>`

## การทำงานร่วมกับ Jarvis Self‑Heal Checkpoints
- Jarvis checkpoints ปัจจุบันเน้นการกู้คืนจากความผิดพลาด โดยเก็บ state ของระบบทั้งหมดเป็นระยะ (recovery point)  
- Hybrid IPC Snapshot **เสริม** โดยเพิ่มมิติการตรวจสอบย้อนกลับและ Soul Sync โดยไม่รบกวนรอบ self‑heal  
  - Snapshot จะเกิดขึ้นในช่วงที่ระบบเสถียร (ไม่ใช่ระหว่าง rollback)  
  - ข้อมูล snapshot ถูกอ่านจาก bus และ context **นอกเหนือจาก** ข้อมูลที่ Jarvis จุดตรวจเชิงโครงสร้าง  
  - เมื่อเกิด self‑heal, Jarvis จะอ้างอิง checkpoint ล่าสุด ส่วน snapshot ยังคงอยู่เพื่อการตรวจสอบหลังเหตุการณ์

## การหลีกเลี่ยง Race Condition
1. ** Lock กลาง** – ใช้ `flock` บนไฟล์ `/tmp/manusat-bus/.snapshot.lock` ก่อนคัดลอกสถานะ  
2. **Atomic snapshot** – ระงับการส่งข้อความใหม่เข้าบัสชั่วคราว (pause routing) ระหว่างการอ่าน  
   - ตั้ง flag `bus.pause = true` ใน shared memory; writers ตรวจสอบ flag และเข้าคิวรอ  
3. **คัดลอกเฉพาะ immutable data** – ข้อมูลที่ถูกเปลี่ยนแปลงให้ serialize โดยตรงภายใต้ lock  
4. **ปลดล็อกทันทีหลังคัดลอกเสร็จ** – ระยะเวลาบล็อกสั้นมาก (≤ 2 ms) เพื่อไม่ให้กระทบ real‑time routing  
5. **ยืนยันความถูกต้องหลังปลดล็อก** – ตรวจสอบว่าข้อมูลที่ snapshotted ไม่เกิดการเปลี่ยนแปลงกลางคันโดยใช้ sequence number ของบัสนับตั้งแต่อ่านครั้งสุดท้าย หากไม่ตรงกัน ให้ retry (ถอยหลังสูงสุด 3 ครั้ง)

## สรุป
Hybrid IPC Snapshot เปลี่ยน `/tmp/manusat-bus` ให้เป็นทั้งสื่อกลาง routing และแหล่งความจริงสำหรับบันทึกสำคัญ โดยเก็บ snapshot ที่มีโครงสร้างลง `ψ/` และใช้ git เป็นฐานข้อมูล audit พร้อมกลไกป้องกัน race condition อย่างรัดกุม
