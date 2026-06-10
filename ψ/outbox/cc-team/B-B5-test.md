<!-- cc-team deliverable
 group: B (TICKET-006 Phase 2: Manus-pattern integration PoC for innomcp — request_id wrapper, skill registration, tests)
 member: B5 role=test model=MiniMaxAI/MiniMax-M3
 finish_reason: stop | tokens: {"prompt_tokens":285,"completion_tokens":4095,"total_tokens":4380,"prompt_tokens_details":{"cached_tokens":114,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":0,"image_tokens":0},"cache_creation_input_tokens":0} | 76s
 generated: 2026-06-10T19:24:27.301Z -->
# แผนทดสอบ Integration แบบ End-to-End: Agent Task → Skill → Mouth Broadcast → Webhook

## 1. การเตรียมสภาพแวดล้อมการทดสอบ (Test Environment Setup)

```bash
# 1.1 สร้าง working directory
mkdir -p /tmp/manusat-bus /tmp/manusat-test-logs
cd /tmp/manusat-test-logs

# 1.2 ตรวจสอบ/สร้างโครงสร้าง bus directory (ต่อ agent)
for agent in alpha bravo charlie; do
  mkdir -p /tmp/manusat-bus/$agent
done

# 1.3 Start webhook receiver (Python) — ฟัง port 9999, log payloads
cat > /tmp/manusat-test-logs/webhook_receiver.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
import json, datetime
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length','0'))
        body = self.rfile.read(n).decode('utf-8','replace')
        with open('/tmp/manusat-test-logs/webhook.log','a') as f:
            f.write(f"{datetime.datetime.utcnow().isoformat()}Z {self.path} {body}\n")
        self.send_response(200); self.end_headers(); self.wfile.write(b'{"ok":true}')
    def log_message(self, *a): pass
HTTPServer(('127.0.0.1', 9999), H).serve_forever()
PY
nohup python3 /tmp/manusat-test-logs/webhook_receiver.py >/tmp/manusat-test-logs/webhook.stderr 2>&1 &
echo $! > /tmp/manusat-test-logs/webhook.pid

# 1.4 ยืนยัน webhook พร้อมรับ
curl -sf -X POST http://127.0.0.1:9999/health -d '{"ping":1}' && echo " OK"

# 1.5 ตัวแปรสภาพแวดล้อมที่ใช้ร่วม
export BUS_DIR=/tmp/manusat-bus
export WEBHOOK_URL=http://127.0.0.1:9999/notifications
export AGENT_ID=test-runner
export SKILL_CMD="echo {\"status\":\"ok\",\"agent\":\"\$AGENT_ID\",\"request_id\":\"\$REQUEST_ID\"}"
```

**Prerequisites**
- Python 3.8+, `curl`, `jq`
- Mouth/skill executor service ติดตั้งและรันอยู่ (เช่น systemd unit `manusat-skill-executor`)
- ไฟล์ fixture: `/tmp/manusat-test-logs/payloads/` มี JSON payload ตัวอย่าง 1 ไฟล์
- Agent-to-agent routing table ตั้งค่า `alpha → AGENT_ID` สำหรับ notification

---

## 2. สถานการณ์ทดสอบ E2E (6 Scenarios)

### Scenario 1: Happy Path — งานเสร็จและ webhook ถูกส่ง

**Given**
- bus directory `/tmp/manusat-bus/alpha` มีอยู่และเขียนได้
- webhook receiver ทำงานที่ `http://127.0.0.1:9999`
- skill `echo` รันสำเร็จใน < 2 วินาที
- มี request `submit_task` จาก agent `alpha` ไปยัง `bravo` พร้อม `request_id=req-001`

**When**
- ส่งคำสั่ง `submit_task` ผ่าน CLI/API ของ skill executor:
  ```bash
  curl -s -X POST http://127.0.0.1:8080/tasks \
    -H "Content-Type: application/json" \
    -d '{"request_id":"req-001","from":"alpha","to":"bravo","skill":"echo","payload":{"msg":"hi"}}'
  ```

**Then**
- ไฟล�� broadcast ถูกเขียนที่ `/tmp/manusat-bus/alpha/req-001.json` ภายใน 3 วินาที
- ไฟล์มี `status:"ok"` และ `agent:"alpha"`
- webhook log บรรทัดสุดท้ายมี path `/notifications` และ body มี `request_id="req-001"`
- HTTP response ของ task submit = `202 Accepted`

---

### Scenario 2: Skill Error — skill exit non-zero

**Given**
- request_id=`req-002`, skill=`false` (รับประกัน exit 1)
- bus directory พร้อม, webhook receiver ทำงาน

**When**
- submit task ที่เรียก skill `false`:
  ```bash
  curl -s -X POST http://127.0.0.1:8080/tasks \
    -d '{"request_id":"req-002","from":"alpha","to":"bravo","skill":"false","payload":{}}'
  ```

**Then**
- ไฟล์ broadcast ถูกเขียนที่ `/tmp/manusat-bus/alpha/req-002.json` ภายใน 5 วินาที
- เนื้อหาไฟล์มี `status:"error"`, `exit_code:1`, `error_message` (ไม่ว่าง)
- webhook ถูกเรียก **1 ครั้ง** พร้อม `status:"error"`
- request ไม่ถูก retry เกิน max_attempts (ตรวจจาก log)

---

### Scenario 3: Webhook Endpoint Down

**Given**
- หยุด webhook receiver: `kill $(cat /tmp/manusat-test-logs/webhook.pid)`
- request_id=`req-003`, skill=`echo` (รันสำเร็จ)
- bus directory พร้อม

**When**
- submit task; skill ทำงานสำเร็จและพยายามส่ง webhook

**Then**
- ไฟล์ broadcast ถูกเขียนที่ `/tmp/manusat-bus/alpha/req-003.json` ปกติ (skill ไม่ขึ้นกับ webhook)
- log ของ executor แสดง webhook delivery attempt ล้มเหลว (HTTP error หรือ connection refused)
- มี retry อย่างน้อย 1 ครั้งตาม backoff config
- งานไม่ถูก mark เป็น failed (broadcast สำเร็จแล้ว)
- เมื่อ restart webhook receiver แล้ว trigger reconcile/flush → ได้รับ notification ที่ค้าง

---

### Scenario 4: Duplicate Request ID (Idempotency)

**Given**
- request_id=`req-004` ถูกส่งและเสร็จสมบูรณ์แล้ว (ไฟล์ broadcast มีอยู่)
- bus directory, webhook receiver ทำงานปกติ

**When**
- ส่ง task เดียวกันซ้ำ 2 ครั้งติดกัน:
  ```bash
  for i in 1 2; do
    curl -s -X POST http://127.0.0.1:8080/tasks \
      -d '{"request_id":"req-004","from":"alpha","to":"bravo","skill":"echo","payload":{"n":'$i'}}'
  done
  ```

**Then**
- HTTP response แรก = `202`; response ที่สอง = `409 Conflict` หรือ `200` พร้อม `deduplicated:true`
- ไฟล์ `/tmp/manusat-bus/alpha/req-004.json` มี **อยู่ไฟล์เดียว** (ไม่ถูก overwrite)
- webhook ถูกเรียก**รวมไม่เกิน 1 ครั้ง**สำหรับ request_id นี้ (ตรวจจาก `webhook.log`)

---

### Scenario 5: Concurrent 10 Tasks

**Given**
- request_id `req-005` ถึง `req-014` (10 งาน), skill `echo` (เพิ่ม `sleep 0.2` เพื่อให้เห็น concurrency)
- bus directory พร้อม, webhook receiver ทำงาน

**When**
- submit 10 งานพร้อมกันด้วย parallel curl:
  ```bash
  seq 5 14 | xargs -P 10 -I{} curl -s -X POST http://127.0.0.1:8080/tasks \
    -d '{"request_id":"req-0{}","from":"alpha","to":"bravo","skill":"sleep_echo","payload":{}}'
  ```

**Then**
- ไฟล์ broadcast ครบ **10 ไฟล์** (`req-005.json` … `req-014.json`) ภายใน 10 วินาที
- ไม่มี 2 ไฟล์ที่มี request_id ซ้ำก��น (atomic write, ไม่มี partial file)
- webhook ได้รับ **10 notifications** (ตามด้วย request_id ครบทุกตัว ไม่ซ้ำ ไม่หาย)
- response codes ทั้ง 10 = `202`
- ไม่มี race condition ใน `/tmp/manusat-bus/alpha/` (เช็ค `ls -la` แสดงขนาดไฟล์ > 0 ทุกไฟล์)

---

### Scenario 6: Bus Directory Missing

**Given**
- ลบ bus directory: `rm -rf /tmp/manusat-bus/alpha`
- request_id=`req-006`, skill=`echo`
- webhook receiver ทำงาน

**When**
- submit task; executor พยายามเขียน broadcast

**Then**
- HTTP response = `500` หรือ `507 Insufficient Storage` พร้อม error code `BUS_DIR_MISSING`
- ไฟล์ broadcast ไม่ถูกสร้าง (เพราะ dir หาย)
- executor log มีข้อความ `EACCES` หรือ `ENOENT` ระบุ path `/tmp/manusat-bus/alpha`
- webhook **ไม่ถูกเรียก** (เพราะ broadcast ล้มเหลวก่อนถึงขั้น notify)
- เมื่อ `mkdir -p /tmp/manusat-bus/alpha` แล้ว submit ใหม่ → สำเร็จปกติ (recovery ทำงาน)

---

## 3. คำสั่งตรวจสอบ (Verification Commands)

```bash
# V1 — ตรวจไฟล์ broadcast ถูกสร้างและมี content
for f in /tmp/manusat-bus/alpha/*.json; do
  [ -s "$f" ] && echo "OK $f" || echo "MISSING/EMPTY $f"
done

# V2 — ตรวจ JSON validity และ field ที่จำเป็น
jq -e '.request_id, .status, .agent' /tmp/manusat-bus/alpha/req-001.json

# V3 — ตรวจ webhook log มี request_id ที่ต้องการ
grep -c '"request_id":"req-001"' /tmp/manusat-test-logs/webhook.log

# V4 — ตรวจว่าไม่มี duplicate webhook (Scenario 4)
test "$(grep -c '"request_id":"req-004"' /tmp/manusat-test-logs/webhook.log)" -le 1 && echo "PASS: no dup"

# V5 — ตรวจจำนวนไฟล์ = 10 และ request_id ครบ (Scenario 5)
test "$(ls /tmp/manusat-bus/alpha/req-0[0-9][0-9].json | wc -l)" -eq 10 && echo "PASS: 10 files"
jq -r .request_id /tmp/manusat-bus/alpha/req-0[0-9][0-9].json | sort -u | wc -l

# V6 — ตรวจ webhook ได้รับครบ 10 ตัว (Scenario 5)
test "$(wc -l < /tmp/manusat-test-logs/webhook.log)" -ge 10 && echo "PASS: 10 webhooks"

# V7 — ตรวจ error handling ใน Scenario 2
jq -e '.status=="error" and .exit_code==1' /tmp/manusat-bus/alpha/req-002.json

# V8 — ตรวจ Scenario 3: log มี retry attempt
grep -E "webhook.*(failed|retry|attempt)" /var/log/manusat/executor.log | tail -5

# V9 — ตรวจ Scenario 6: response 5xx และไม่มีไฟล์
test ! -f /tmp/manusat-bus/alpha/req-006.json && echo "PASS: no file created"

# V10 — Atomic write: ไม่มี partial/temp file ค้าง
find /tmp/manusat-bus -name '*.tmp' -o -name '.*.swp' | wc -l
```

---

## 4. เกณฑ์ผ่าน (Pass Criteria)

| # | เกณฑ์ | วิธีวัด |
|---|-------|---------|
| **PC-1** | ทุก scenario ทำซ้ำได้ 3 รอบ ผลลัพธ์เหมือนเดิม (deterministic) | run-all script × 3 |
| **PC-2** | Happy path latency (submit → webhook received) **p95 ≤ 5 วินาที** | timestamp diff ใน log |
| **PC-3** | ไฟล์ broadcast ทุกไฟล์ valid JSON, non-empty, มี `request_id`, `status`, `agent` | V1 + V2 ผ่าน 100% |
| **PC-4** | Concurrent 10 tasks: ไม่มี lost request, ไม่มี duplicate, ไม่มี partial file | V5 + V6 ผ่าน |
| **PC-5** | Idempotency: duplicate `request_id` ไม่ก่อให้เกิด duplicate webhook หรือ file overwrite | V4 ผ่าน |
| **PC-6** | Skill error: งานถูก report กลับด้วย `status:error` และ webhook ถูกเรียก 1 ครั้ง | V7 + log inspection |
| **PC-7** | Webhook down: broadcast สำเร็จ, executor log retry, ไม่ mark task failed | V8 ผ่าน |
| **PC-8** | Bus dir missing: fail-fast พร้อม error code ชัดเจน, ไม่เงียบ, recovery ทำงาน | V9 + recovery run |
| **PC-9** | ไม่มี partial/temp file ค้างใน bus directory หลังรัน scenario ทั้งหมด | V10 = 0 |
| **PC-10** | ไม่มีไฟล์ log ใดมี `FATAL` หรือ unhandled exception ที่ไม่คาดคิด | `grep -ri FATAL executor.log` = 0 |

**Definition of Done**: ทุก scenario (1–6) ผ่าน 3/3 รอบ และเกณฑ์ PC-1 ถึง PC-10 ผ่านครบทั้ง 10 ข้อ จึงถือว่า integration พร้อม release.
