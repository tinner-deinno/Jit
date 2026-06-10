<!-- cc-team deliverable
 group: B (TICKET-006 Phase 2: Manus-pattern integration PoC for innomcp — request_id wrapper, skill registration, tests)
 member: B4 role=test model=zai-org/GLM-5.1
 finish_reason: stop | tokens: {"prompt_tokens":160,"completion_tokens":3697,"total_tokens":3857,"prompt_tokens_details":{"cached_tokens":3,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1391,"reasoning_tokens_estimated":true,"image_tokens":0},"cache_creation_input_tokens":0} | 58s
 generated: 2026-06-10T19:23:49.202Z -->
# ข้อกำหนด Webhook Handler สำหรับระบบ Multi-Agent (Manus Pattern)

**Endpoint:** `POST /webhooks/manus/:event`  
**Payload:**
```json
{
  "request_id": "string",
  "task_id": "string",
  "project_id": "string",
  "status": "string",
  "data": "object",
  "timestamp": "ISO8601"
}
```

---

## 1. กระบวนการตรวจสอบลายเซ็น (Signature Validation Flow)

เพื่อยืนยันว่า Webhook มาจากระบบ Manus จริง ให้ดำเนินการดังนี้:

1. อ่าน Header `X-Manus-Signature` และ `X-Manus-Timestamp`
2. สร้าง Signed Payload โดยเชื่อมต่อสตริง: `{X-Manus-Timestamp}.{Raw Body}`
3. คำนวณ HMAC SHA256 โดยใช้ `WEBHOOK_SECRET` เป็นคีย์กับ Signed Payload
4. เปรียบเทียบ Hash ที่คำนวณได้กับค่าใน `X-Manus-Signature` โดยใช้ฟังก์ชันเปรียบเทียบแบบ Timing-Safe (เช่น `crypto.timingSafeEqual`)
5. หากไม่ตรงกัน ให้ Reject ทันที (401)
6. *(Optional)* ตรวจสอบว่า `X-Manus-Timestamp` ไม่เกิน 5 นาที เพื่อป้องกั�� Replay Attack ระดับลายเซ็น

---

## 2. ตารางประเภท Event และการดำเนินการ (Event Types & Required Actions)

| Event (`:event`) | คำอธิบาย | การดำเนินการที่จำเป็น (Required Actions) |
| :--- | :--- | :--- |
| `task:completed` | Agent ทำงานสำเร็จและส่งผลลัพธ์ | 1. อัปเดตสถานะ `task_id` เป็น `completed`<br>2. จัดเก็บ `data` ลงฐานข้อมูล<br>3. ส่งสัญญาณต่อ (Trigger) ไปยัง Task ถัดไปใน `project_id` |
| `task:failed` | Agent ทำงานล้มเหลว | 1. อัปเดตสถานะ `task_id` เป็น `failed`<br>2. บันทึก Error จาก `data`<br>3. ส่งแจ้งเตือนไปยังระบบ Monitor และเรียก Fallback/Recovery flow |
| `input:required` | Agent ต้องการข้อมูลเพิ่มเติมจากมนุษย์ | 1. อัปเดตสถานะ `task_id` เป็น `pending_input`<br>2. สร้าง Notification ไปยังผู้ใช้พร้อมระบุคำถามจาก `data`<br>3. ระงับการทำงานของ Agent ชั่วคราว |

---

## 3. ตารางกรณี Error และการจัดการ (Error Cases & Retry Semantics)

| กรณี (Case) | HTTP Status | Response Body | Retry Semantics |
| :--- | :--- | :--- | :--- |
| **Bad Signature** | `401 Unauthorized` | `{"error": "invalid_signature"}` | **ห้าม Retry** แจ้ง Admin ตรวจสอบ Secret |
| **Unknown Event** | `400 Bad Request` | `{"error": "unknown_event", "detail": ":event"}` | **ห้าม Retry** ตรวจสอบโค้ด/เวอร์ชัน Agent |
| **Replayed request_id** | `409 Conflict` | `{"error": "replayed_request", "request_id": "..."}` | **ห้าม Retry** ระบบส่งซ้ำเนื่องจาก Timeout |
| **Oversized Body** | `413 Payload Too Large`| `{"error": "payload_too_large"}` | **ห้าม Retry** ต้องลดขนาด `data` ก่อนส่งใหม่ |
| **Handler Crash** | `500 Internal Server Error`| `{"error": "internal_server_error"}` | **Retry** ลองใหม่สูงสุด 3 ครั้ง ด้วย Exponential Backoff (1s, 2s, 4s) |

---

## 4. กลยุทธ์ Idempotency (Idempotency Strategy)

ใช้ `request_id` เป็น Idempotency Key เพื่อป้องกันผลข้างเคียงจากการประมวลผลซ้ำ:

1. **Check & Lock:** ก่อนประมวลผล ตรวจสอบ `request_id` ใน Redis หรือ Cache
   - หาก **ไม่มี**: บันทึก `request_id` ลง Redis พร้อมสถานะ `processing` (ตั้ง TTL 24 ชม.) แล้วดำเนินการต่อ
   - หาก **มีแล้วและสถานะเป็น `processing`**: ตอบกลับ `409 Conflict` ทันทีเพื่อป้องกัน Race Condition
   - หาก **มีแล้วและสถานะเป็น `completed`**: ตอบกลับ `409 Conflict` โดยไม่ดำเนินการใดๆ กับฐานข้อมูล (Side-effect ต้องเกิดครั้งเดียว)
2. **Commit:** เมื่อประมวลผลสำเร็จ อัปเดตสถานะใน Redis เป็น `completed`
3. **DB Constraint:** แนะนำให้มี Unique Constraint ที่ `request_id` ในระดับ Database เพื่อเป็นกลไกป้องกันซ้ำรอบสุดท้าย

---

## 5. เกณฑ์การยอมรับ (Acceptance Criteria)

1. **Security:** Webhook ที่ส่งมาโดยไม่มี Header `X-Manus-Signature` หรือลายเซ็นไม่ตรงกัน ต้องถูก Reject ด้วย HTTP 401 ทันที โดยไม่ทำให้เกิด Side-effect ใดๆ
2. **Routing:** ระบบรองรับ Event ได้ครบทั้ง 3 ประเภท (`task:completed`, `task:failed`, `input:required`) และดำเนินการ Required Actions ครบถ้วนตาม Section 2
3. **Idempotency:** การส่ง Webhook ด้วย `request_id` เดิมซ้ำ 2 ครั้ง ระบบต้องตอบกลับด้วย HTTP 409 และ **ห้าม** อัปเดตฐานข้อมูลหรือส่ง Notification ซ้ำ
4. **Resilience:** เมื่อเกิดข้อผิดพลาดในระบบ (Handler Crash) ระบบต้องตอบกลับด้วย HTTP 500 และระบบผู้ส่งต้องสามารถ Retry ได้สำเร็จในครั้งถัดไปโดยไม่เกิด Data Corruption
5. **Payload Limit:** ระบบต้อง Reject Payload ที่มีขนาดเกิน 1 MB ด้วย HTTP 413 ก่อนเข้าสู่กระบวนการ Parse JSON หรือตรวจสอบลายเซ็น เพื่อป้องกัน DoS
