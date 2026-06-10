# SA-REVIEW: CC-Team Deliverables — TICKET-007b

**ผู้ตรวจสอบ:** SA (claude-sonnet-4-6)  
**วันที่ตรวจสอบ:** 2026-06-11  
**แผน:** CC-TEAM-2026-06-11  
**ผลรวม:** 8/10 ผ่าน (2 ต้องแก้ไขใหม่)

---

## ตารางสรุปผล (Verdict Table)

| ชิ้นงาน | สถานะ | หมายเหตุ |
|---------|--------|----------|
| A-A1-dev | **PASS** | JSON 24 รายการ ครบ spec ทุกฟิลด์ |
| A-A2-dev | **PASS** | 5 failure modes + mitigations + 3 CI invariants ครบ |
| A-A3-test | **PASS** | JS syntax OK; route-lane.js ยังไม่มี (noted) |
| A-A4-test | **FAIL** | ถูกตัดกลาง (finish_reason: length) ได้ 7/12 รายการ |
| A-A5-test | **PASS** | 6 sections ครบ implementation-ready |
| B-B1-dev | **PASS** | CJS module syntax OK, JSDoc ครบ |
| B-B2-dev | **PASS** | JSON 3 skills ครบ fields ตามสเปค |
| B-B3-test | **PASS-WITH-FIXES** | 5 bugs แก้ไขแล้ว, 7/7 tests PASS |
| B-B4-test | **PASS** | 5 sections ครบ, implementation-ready |
| B-B5-test | **PASS** | 6 scenarios + verification commands + pass criteria |

---

## รายละเอียดต่อชิ้นงาน

### A-A1-dev — PASS
**Model:** deepseek/deepseek-v4-pro  
**ตรวจสอบ:** JSON parse OK, count=24, IDs T01–T24 ครบ, fields: id/prompt/expected_lane/rationale ครบ  
**Lane distribution:** innova=8, chamu=4, rupa=4, pada=4, netra=4 — ตรงตาม spec (8/4/4/4/4)  
**Enum check:** ทุก expected_lane อยู่ใน [innova, chamu, rupa, pada, netra]  
**คุณภาพ:** prompts เป็นภาษาไทยจริง ครอบคลุม formal/casual  
**Integration:** เขียนไปยัง `eval/thai-routing-prompts.json` แล้ว

---

### A-A2-dev — PASS
**Model:** Qwen/Qwen3.7-Max  
**ตรวจสอบ:** มี section ครบทั้ง 3 ตามสเปค  
- Section 1: 5 failure modes (Syllable Splitter Non-determinism, Circuit Breaker Fallback, Concurrency Spillover, Silent Fallback on Empty Keys, Config Inconsistency) — ครบ 5 โหมด  
- Section 2: mitigation ต่อโหมดครบ implementation-ready (NFC normalization, fail-fast 503, bounded semaphore, gateway validation, etcd/config hash)  
- Section 3: 3 CI invariants (Golden Dataset Hash Stability, Determinism Under Stress, Property-Based Fuzzing) — ครบ 3 invariants  
**คุณภาพ:** ระดับ senior architect จริง — อ้างอิง `commandcode` weight=18, concurrency=2, 60s cooldown ถูกต้องตาม system context

---

### A-A3-test — PASS
**Model:** deepseek/deepseek-v4-flash  
**ตรวจสอบ:** Worker ละเมิด "no fences" (ส่งมาใน ```javascript fence) — แก้ไขโดย SA แล้ว  
**Syntax check:** `node --check` → exit 0  
**ฟังก์ชันครบ:** (1) โหลด corpus, (2) เรียก routeLane() 5 ครั้ง/prompt, (3) assert determinism, (4) assert non-empty key, (5) print summary table  
**หมายเหตุสำคัญ:** ใช้ ESM import (`import { routeLane } from '../limbs/route-lane.js'`) แต่ `limbs/route-lane.js` **ยังไม่มีในโปรเจกต์** — test จะรันได้ก็ต่อเมื่อสร้าง route-lane.js แล้ว  
**Integration:** เขียนไปยัง `eval/thai-routing-audit.test.js` แล้ว (ไม่รันตาม spec)

---

### A-A4-test — FAIL
**Model:** zai-org/GLM-5.1  
**ปัญหา:** `finish_reason: length` — response ถูกตัดกลางข้อมูล  
**ผลการตรวจ:** parse error — JSON ไม่ครบ, ได้แค่ 7 entries (E01–E07 โดย E07 ยังไม่สมบูรณ์) จากที่ต้องการ 12 entries (E01–E12)  
**Category ที่หายไป:** transliterated English in Thai script (2), very long prompt 500+ chars (1), whitespace/zero-width chars (1), empty-adjacent single space (1)  
**ไม่ได้เขียนไปยัง eval/thai-routing-edge-cases.json**  
**Action ที่ต้องการ:** ส่งงานใหม่ให้ worker รุ่นที่มี context window ใหญ่กว่า หรือแบ่ง task เป็น 2 ชุด (E01-E06, E07-E12)

---

### A-A5-test — PASS
**Model:** moonshotai/Kimi-K2.6  
**ตรวจสอบ:** ครบ 6 sections ตามสเปค  
1. Prompt Injection → routing lane change  
2. Empty/Null Routing Keys  
3. Path Traversal in agent names  
4. Oversized Payloads  
5. Unicode Normalization Attacks (homoglyph Cyrillic)  
6. Concurrent Write Races on Inbox Files  
**คุณภาพ:** แต่ละ section มี attack scenario / expected safe behavior / test idea — implementation-ready จริง  
**ภาษา:** Thai ตลอด ตามสเปค

---

### B-B1-dev — PASS
**Model:** deepseek/deepseek-v4-pro  
**ตรวจสอบ:** Worker ส่งมาโดยไม่มี fence (ถูกต้อง)  
**Syntax check:** `node --check` → exit 0  
**Export ครบ:** generateRequestId, wrapOk, wrapErr, withRequestId  
**JSDoc:** ครบทุกฟังก์ชัน  
**API ที่ตรวจสอบ:**
- `generateRequestId()` → `req_<timestamp>_<random>`  
- `wrapOk(request_id, data)` → `{ok:true, request_id, data}`  
- `wrapErr(request_id, code, message)` → `{ok:false, request_id, error:{code,message}}`  
- `withRequestId(fn)` → async HOF ที่ inject request_id เป็น first arg ของ fn  
**Integration:** เขียนไปยัง `limbs/manus-wrapper.js` แล้ว

---

### B-B2-dev — PASS
**Model:** Qwen/Qwen3.7-Max  
**ตรวจสอบ:** JSON parse OK, `skills` array มี 3 items  
**Skill 1 — mouth_broadcast:** inputs: agent(req), message(req), prefix(opt, default=""), outputs: message_id, delivered_at, inbox_size  
**Skill 2 — oracle_knowledge_search:** inputs: query(req), limit(opt, default=5), outputs: results[], search_time_ms  
**Skill 3 — verifier_test_runner:** inputs: test_suite(req), tests[](opt, default=[]), outputs: passed, failed, total, pass_rate, failures[]  
**คุณภาพ:** fields ตรง spec ครบ, errors ผ่านสมเหตุสมผล

---

### B-B3-test — PASS-WITH-FIXES
**Model:** deepseek/deepseek-v4-flash  
**ปัญหาก่อนแก้:** Worker ส่งมาใน ````javascript` fence (ผิด spec) + มี 5 bugs ด้าน API mismatch กับ B1  

**Bugs ที่พบและแก้ไขโดย SA:**

| # | Bug | B3 original | B1 API จริง | Fix |
|---|-----|-------------|-------------|-----|
| 1 | wrapOk arg order | `wrapOk(data, requestId)` | `wrapOk(request_id, data)` | สลับ argument |
| 2 | wrapErr arg order | `wrapErr(msg, id)` | `wrapErr(id, code, msg)` | เพิ่ม code, สลับ order |
| 3 | wrapErr result shape | ตรวจ `result.error === string` | B1 returns `{error:{code,message}}` | เปลี่ยนเป็น `.error.message` |
| 4 | withRequestId signature | `withRequestId(id, fn)` | `withRequestId(fn)` (auto-generate id) | เอา id param ออก, ปรับ fn signature |
| 5 | sync tests missing await | ไม่มี `await` บน withRequestId | B1 returns async fn เสมอ | เพิ่ม `async/await` |

**ผลหลังแก้ไข:** 7/7 tests PASS  
```
ℹ tests 7
ℹ pass 7
ℹ fail 0
ℹ duration_ms 84.4006ms
```

**Integration test file:** `test/manus-wrapper.test.js`

---

### B-B4-test — PASS
**Model:** zai-org/GLM-5.1  
**ตรวจสอบ:** ครบ 5 sections ตามสเปค  
1. Signature validation flow — HMAC SHA256, timing-safe compare, 5-minute timestamp window  
2. Event types table — task:completed, task:failed, input:required + required actions  
3. Error cases table — 401/400/409/413/500 + retry semantics ครบ  
4. Idempotency strategy — Redis + check-lock-commit pattern + DB unique constraint  
5. 5 acceptance criteria — security, routing, idempotency, resilience, payload limit  
**คุณภาพ:** ระดับ implementation-ready จริง, ภาษาไทยชัดเจน  
**ข้อสังเกต minor:** Section 5 ระบุ payload limit = 1 MB (ต่างจาก section 3 ที่ไม่ระบุ threshold) — ควร align ตัวเลขในทั้งสอง sections

---

### B-B5-test — PASS
**Model:** MiniMaxAI/MiniMax-M3  
**ตรวจสอบ:** ครบ 4 sections ตามสเปค  
1. Test environment setup — mkdir bus/logs, Python webhook receiver, env vars  
2. 6 E2E scenarios — happy path, skill error, webhook down, duplicate request_id, concurrent 10, bus dir missing — ทุก scenario มี given/when/then  
3. Verification commands — V1-V10 bash one-liners ครบ  
4. Pass criteria — PC-1 ถึง PC-10 พร้อม definition of done  
**คุณภาพ:** implementation-ready, bash commands ใช้งานได้จริง

---

## Integration Test Results (B group)

```
Test file: test/manus-wrapper.test.js
Module:    limbs/manus-wrapper.js

ℹ tests 7
ℹ suites 7
ℹ pass 7
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 84.4006
```

**PASS 7/7** หลังจาก SA แก้ไข 5 bugs ใน B3 test file

---

## Fixes Applied โดย SA

1. **A-A3-test:** stripped markdown fence (worker ส่งมาใน ```javascript block)
2. **B-B3-test (Fix 1):** `wrapOk(data, requestId)` → `wrapOk(requestId, data)`
3. **B-B3-test (Fix 2):** `wrapErr(msg, id)` → `wrapErr(id, 'TEST_CODE', msg)`
4. **B-B3-test (Fix 3):** `result.error === string` → `result.error.message === string`
5. **B-B3-test (Fix 4):** `withRequestId(id, fn)` → `withRequestId(fn)` + ปรับ fn signature เป็น `(req_id, ...args)`
6. **B-B3-test (Fix 5):** เพิ่ม `async/await` ใน sync test cases (เนื่องจาก B1 returns Promise เสมอ)

---

## Artifacts ที่ integrate แล้ว

| File | Source | สถานะ |
|------|--------|--------|
| `eval/thai-routing-prompts.json` | A-A1 | เขียนแล้ว |
| `eval/thai-routing-audit.test.js` | A-A3 | เขียนแล้ว (ต้องรอ route-lane.js) |
| `limbs/manus-wrapper.js` | B-B1 | เขียนแล้ว |
| `test/manus-wrapper.test.js` | B-B3 + SA fixes | เขียนแล้ว, 7/7 PASS |

## Artifacts ที่ไม่ integrate (FAIL)

| File | Source | เหตุผล |
|------|--------|--------|
| `eval/thai-routing-edge-cases.json` | A-A4 | truncated — ไม่เขียน |

---

## สิ่งที่ต้องส่งงานใหม่ให้ CommandCode Team

### A-A4 (FAIL — ต้อง re-request)
**ปัญหา:** Worker (zai-org/GLM-5.1) ถูกตัดกลาง (finish_reason: length) ส่งมาแค่ 7/12 entries  
**Action:**  
- เพิ่ม max_tokens หรือเปลี่ยนเป็น model ที่มี output window ใหญ่กว่า  
- หรือแบ่งเป็น 2 tasks: E01-E06 + E07-E12  
- ต้องการ categories ที่ยังขาด: transliterated English in Thai script (2), very long 500+ chars (1), whitespace/zero-width (1), empty-adjacent (1)

### หมายเหตุสำหรับ Team

- **route-lane.js** ยังไม่มีในโปรเจกต์ — ต้องสร้างก่อน A-A3 test จะรันได้  
- **B-B3 worker (deepseek-v4-flash)** มี API comprehension ต่ำ — ควรให้ B1 spec เป็น context ก่อน generate B3  
- **B-B4 minor:** ควร align payload size limit (1 MB) ให้ตรงกันระหว่าง Section 3 และ Section 5

---

*SA Review completed by claude-sonnet-4-6 — 2026-06-11*
