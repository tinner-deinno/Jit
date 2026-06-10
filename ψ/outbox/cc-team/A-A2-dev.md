<!-- cc-team deliverable
 group: A (TICKET-002: Thai Knowledge Routing Audit — produce test corpus, harness, and hardening proposals)
 member: A2 role=dev model=Qwen/Qwen3.7-Max
 finish_reason: stop | tokens: {"prompt_tokens":159,"completion_tokens":4386,"total_tokens":4545,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":2581,"image_tokens":0},"cache_creation_input_tokens":0} | 74s
 generated: 2026-06-10T19:20:32.108Z -->
# ข้อเสนอแนะการปรับปรุงความแข็งแกร่งของระบบ Deterministic Routing (Determinism Hardening Proposal)

**เรียน:** ทีมวิศวกรรมระบบ (Engineering Team)
**จาก:** Systems Architect
**เรื่อง:** การอุดช่องโหว่แล��รักษาความเป็น Determinism ในระบบ Multi-backend LLM Routing

ระบบ Routing ปัจจุบันใช้การทำ Hash จากตัวแยกพยางค์ภาษาไทย (Thai syllable splitter) เพื่อกระจายงานไปยัง Backend ต่างๆ (เช่น `ollama_mdes`, `thaillm`, `commandcode` ที่มี weight=18) โดยมีข้อจำกัดด้าน Concurrency (limit=2) และ Circuit Breaker (3 errors, 60s cooldown) เพื่อให้เป็นไปตามกฎเหล็กที่ว่า **"goal และ worker เดิม ต้องถูก route ไปยัง backend เดิมเสมอ"** ผมได้ทำการทบทวนสถาปัตยกรรมและขอเสนอแผนการปรับปรุงดังนี้

---

## 1. 5 โหมดความล้มเหลวที่ทำให้เสีย���วามเป็น Determinism (Failure Modes)

1. **Syllable Splitter Non-determinism & Unicode Variations:** 
   ไลบรารีแยกพยางค์ภาษาไทย (เช่น PyThaiNLP) อาจมีการอัปเดต Dictionary หรือ Algorithm ในเวอร์ชันย่อย ทำให้การแยกพยางค์เปลี่ยนไป นอกจากนี้ Routing key ที่มี Unicode หลากหลายรูปแบบ (เช่น สระลอย, Zero-width spaces) อาจถูกแยกพยางค์ต่างกัน ทำให้ค่า Hash เปลี่ยนแปลง และ route ไปคนละ Backend
2. **Circuit Breaker Cross-Backend Fallback:** 
   เมื่อ Backend หลักเกิด Error ครบ 3 ครั้ง Circuit Breaker จะทำงาน (Trip) หากรouter ถูกตั้งค่าให้ทำ Fallback ไปยัง Backend อื่นชั่วคราว และเมื่อครบ 60sCooldown ก็ route กลับมาที่เดิม พฤติกรรมนี้จะทำลายกฎ "goal+worker เดิมต้องไป backend เดิม" อย่างรุนแรงในช่วงเวลา 60 วิ��าทีนั้น
3. **Concurrency Spillover (Limit = 2):** 
   เนื่องจาก Concurrency limit ต่ำมาก (2) เมื่อ Backend หลักทำงานเต็มความจุ Router อาจตัดสินใจ Spillover (ล้น) ไปยัง Backend สำรองที่มีน้ำหนัก (weight) รองลงมา เพื่อลด Latency การทำ Spillover นี้ทำให้ Request ของ goal+worker เดิม ถูกส่งไปคนละ Backend เพียงเพราะ Backend หลักไม่ว่าง
4. **Silent Fallback on Malformed "Empty" Keys:** 
   แม้จะเคยมี Bug เรื่อง Routing key เป็นค่าว่าง (Empty string) และมีการแก้ไขแล้ว แต่หาก Key เป็น Whitespace ล้วน, Invisible Unicode characters (เช่น `\u200B`) หรือ Null bytes ตัวแยกพยางค์อาจมองว่าเป็นค่าว่างและ Router อาจทำ Silent fallback ไปใช้ Round-robin หรือ Random routing แทนที่จะปฏิเสธ Request
5. **Inconsistent Weight Configuration Across Replicas:** 
   ในสภาวะ Multi-replica หากการ���หลด Config (เช่น การปรับ weight ของ `commandcode` จาก 18 เป็น 20) ไม่เป็นแบบ Strongly Consistent Replica A และ Replica B อาจมี Weight table ไม่ตรงกัน ทำให้ Request ของ goal+worker เดิม ที่ถูก Load balance มาคนละ Replica คำนวณ Hash และ route ไปคนละ Backend

---

## 2. แนวทางแก้ไขเชิงปฏิบัติสำหรับแต่ละโหมด (Concrete Mitigations)

1. **Mitigation for Splitter & Unicode (Strict Normalization & Pinning):**
   * **Implementation:** บังคับใช้ `Unicode Normalization Form C (NFC)` กับ Routing key ทุกตัวก่อนส่งเข้า Syllable splitter เสมอ (ใช้ `unicodedata.normalize('NFC', key)`) 
   * **Implementation:** ล็อกเวอร์ชันของไลบรารี NLP (เช่น `pythainlp==x.y.z`) ใน `requirements.txt` หรือ Dockerfile อย่างเคร่งครัด ห้ามใช้ `~=` หรือ `>=` และให้ Cache ผลลัพธ์การแยกพยางค์ (หรือค่า Hash) ในระดับ In-memory (LRU Cache) เพื่อลดความ���ันผวน
2. **Mitigation for Circuit Breaker (Disable Cross-Backend Fallback):**
   * **Implementation:** ปิดการทำงานของ Cross-backend fallback ทันทีที่ Circuit Breaker Trip 
   * **Implementation:** เมื่อ Backend หลัก Trip ให้ Router ทำ **Fail-fast (Return HTTP 503)** หรือ **Enqueue** ใน Bounded Queue ของ Backend นั้นๆ เท่านั้น ห้าม route ไป Backend อื่นเด็ดขาด เพื่อให้ Client เป็นฝ่าย Retry และรักษา Mapping ของ goal+worker ไว้เสมอ
3. **Mitigation for Concurrency Spillover (Strict Bounded Semaphores):**
   * **Implementation:** ใช้ `Bounded Semaphore` แยกตามแต่ละ Backend (Max=2) 
   * **Implementation:** หาก Semaphore เต็ม ให้เข้า Queue (ขนาดจำกัด เช่น 10 requests) หาก Queue เต็มให้ Reject ด้วย HTTP 429 (Too Many Requests) **ห้ามมี Logic การ Spillover ไป Backend อื่นโดยเด็ดขาด**
4. **Mitigation for Malformed Keys (Strict Gateway Validation):**
   * **Implementation:** เพิ่ม Validation ที่ API Gateway หรือ Middleware ชั้นนอ���สุด ด้วย Regex ที่เข้มงวด เช่น `^[\p{L}\p{N}\p{P}\p{S}\s]+$` (ต้องมีความยาว > 0 หลังจาก `strip()` และไม่มี Zero-width characters)
   * **Implementation:** หากตรวจพบ Invalid/Empty key ให้ Reject ด้วย HTTP 400 (Bad Request) ทันที ห้ามปล่อยให้หลุดไปถึง Layer ที่ทำ Hash
5. **Mitigation for Config Inconsistency (Config Version Hashing):**
   * **Implementation:** เปลี่ยนจากการโหลด Config แบบ Async เป็นการใช้ Strongly Consistent Store (เช่น etcd) หรือแนบ `config_version_hash` (เช่น MD5 ของ weight table) ไปใน Header ของ Request จาก Gateway
   * **Implementation:** Router ทุกตัวต้องตรวจสอบว่า `config_version_hash` ของตัวเองตรงกับที่ Gateway ส่งมา หากไม่ตรงให้ Reject Request (HTTP 503) เพื่อบังคับให้ Client Retry จนกว่า Router จะ Sync Config เวอร์ชันล่าสุดเสร็จสิ้น

---

## 3. 3 Invariant Checks ที่ต้องเพิ่มใน CI Pipeline

เพื่อให้มั่นใจว่าความเป็น Determinism จะไม่ถูกทำลายในการ Deploy ครั้งต่อๆ ไป ต้องเพิ่มการทดสอบต่อไปนี้ใน CI/CD Pipeline และ **ต้องบล็อกการ Merge หาก Test Fail**:

### Invariant Check 1: Golden Dataset Hash Stability Test
* **Objective:** ตรวจสอบว่าค่า Hash ของ Routing key ไม่เปลี่ยนแปลงเมื่อมีการอัปเดต Code หรือ Dependencies
* **Implementation:** 
  * สร้าง `golden_dataset.json` ประกอบด้วย Routing key ภาษาไทย 10,000 รายการ (ครอบคลุมคำสแลง, คำที่มีสระอำ, วรรณยุกต์ซ้อน, และ Emoji) พร้อมค่า Hash ที่คาดหวัง
  * ใน CI ให้รัน Script ที่ดึงค่า Hash จาก Syllable splitter ปัจจุบันมาเทียบกับ Golden dataset 
  * **Assertion:** หากมีค่า Hash เปลี่ยนแปลงแม้แต่ 1 รายการ CI ต้อง Fail และบังคับใ��้ Developer อัปเดต Golden dataset พร้อมชี้แจงเหตุผล (ป้องกัน NLP library update แอบเปลี่ยนพฤติกรรม)

### Invariant Check 2: Determinism Under Stress (Circuit Breaker & Concurrency)
* **Objective:** ตรวจสอบว่าระบบไม่ทำ Fallback หรือ Spillover ไปยัง Backend อื่น เมื่อเกิด Error หรือ Concurrency เต็ม
* **Implementation:** 
  * เขียน Integration Test ที่ Mock Backend `commandcode` (weight=18) ให้ Return Error 3 ครั้งติดกัน เพื่อกระตุ้น Circuit Breaker จากนั้นส่ง Request ที่ 4 (goal+worker เดิม)
  * เขียน Test ที่ส่ง Request พร้อมกัน 3 Requests ไปยัง Backend ที่มี Concurrency limit=2
  * **Assertion:** 
    * Test แรก: Request ที่ 4 ต้องถูก Queue หรือ Return 503 **ห้าม** ถูก route ไป `ollama_mdes` หรือ `thaillm`
    * Test สอง: Request ที่ 3 ต้องถูก Queue หรือ Return 429 **ห้าม** ถูก route ไป Backend อื่น

### Invariant Check 3: Property-Based Fuzzing for Routing Key Validation
* **Objective:** ตรวจสอบว่าระบบไม่มีทางทำ Hash หรือ Route Request ที่มี Routing key ผิดรูปแบบ (Empty/Malformed)
* **Implementation:**
  * ใช้ Property-based testing framework (เช่น `Hypothesis` ใน Python) เพื่อสุ่มสร้าง Routing key ที่เป็น Edge cases: `""`, `"   "`, `"\u200B"`, `"\n\t"`, `None`
  * **Assertion:** สำหรับทุก Input ที่ถูกสร้างขึ้นมา Router **ต้อง** Return HTTP 400 Bad Request เสมอ และต้องมีการ Assert เพิ่มเติมว่า Function `calculate_syllable_hash()` **ไม่ถูกเรียกใช้งาน (Mock assert not called)** สำหรับ Input เหล่านี้ เพื่อป้องกัน Silent fallback bug กลับมาเกิดซ้ำ
