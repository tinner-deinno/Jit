---
name: management-talk
description: "เขียน/เขียนใหม่ content engineer-to-engineer สำหรับ engineering-org leadership และปรับให้เหมาะกับ channel — JIRA comment, Slack post, async standup, email, meeting talking-points Trigger เมื่อ user ขอเขียนสำหรับ management/exec/VP/director/PM, ขอ 'executive summary', 'leadership update', 'status update', 'ทำให้ไม่ technical', หรือ Slack/email/standup version ของงาน engineer"
---

# Management Talk (แปลภาษาวิศวกรเป็นภาษาผู้บริหาร)

Content เดิม แต่ **ปรับรูปแบบตาม channel** — JIRA comment, Slack post, async standup, email, หรือ meeting talking-points

Audience อ่าน product/framework names ได้ แต่ไม่อ่านโค้ด

---

## Trigger เมื่อ

- "เขียนสำหรับ management / exec / VP / director / PM / release manager"
- "เขียนใหม่สำหรับ [non-eng audience]"
- "ทำให้ไม่ technical" / "ลด jargon"
- "ส่ง Slack update / standup note / email" เกี่ยวกับงาน engineering
- "executive summary" / "leadership update" / "status update"
- "talking points สำหรับ [meeting]"

ถ้า channel ยังไม่ชัด → ถาม 1 คำถาม: *"JIRA, Slack, standup, หรือ email?"* แล้วหยุดรอ

---

## Audience — "Engineering-org leadership" คือใคร

Engineering-savvy non-engineers: VPs, directors, PMs, release managers, execs ในบริษัทที่ ship technical products พวกเขาอ่าน product/framework names ได้ cross-reference JIRA/PRs ได้ **แต่ไม่อ่านโค้ด**

ต้องการ: *สถานะคืออะไร ส่งผลต่อ customer ยังไง ใครรับผิดชอบ ต่อไปคืออะไร*

---

## Tone Rules

**เก็บไว้:** Product names, framework names, component names, JIRA keys, PR numbers, customer/workload identifiers (`innova-bot`, `jit`, `Oracle`, `JIRA-123`, `PR #51`)

**ตัดออก:** Function names, file paths, struct fields, commit SHAs, code expressions, env var names, line numbers, data-structure jargon (`organs/mouth.sh`, `bus.sh`, `heartbeat.log`, `0e0a6bac`)

**แปล:** Mechanism → plain-English cause-and-effect ไม่ใช่ *"bus.sh routes via /tmp/manusat-bus"* แต่เป็น *"agents communicate through a file-based message bus"* แปลแต่ห้ามโกหก

**ห้าม:**
- Hedging ที่ไม่จำเป็น (*"we believe," "appears to"*) — พูดตรงหรืออย่าพูด
- Re-state obvious (*"innova-bot คือ body ของ มนุษย์ Agent ซึ่งเป็นระบบ multi-agent ซึ่งใช้..."*)
- บอก leadership ว่าต้องทำอะไร — ให้ facts พวกเขาตัดสินเอง
- Engineering process minutiae: debug iterations, commit SHAs ยกเว้นถ้า process เองคือ story

---

## Channel Shapes

### JIRA comment / written report

Full structured block สร้าง building blocks ที่เหมาะ:

- **Status / TL;DR.** 1 บรรทัด bold *"Fixed pending merge."* / *"Root cause unknown — investigating."*
- **What broke.** Symptom ใน user/workload terms ไม่ใช่ code terms
- **Root cause / explanation.** 1–2 ประโยค plain English
- **Fix.** อะไรเปลี่ยน, PR/branch, ETA
- **Impact.** ใครได้รับผลกระทบ, ระยะเวลา, severity
- **Next step.** Action item ต่อไปพร้อม owner และ date

### Slack post

กระชับกว่า JIRA ใช้ bullets ไม่ใช่ headers bold ใช้เฉพาะ status line/key terms ไม่เกิน 2–3 ย่อหน้า

### Async standup

เดิน 3 บรรทัด: **Done** (yesterday) / **Doing** (today) / **Blocked** (if any) ย่อ action มาก อ่านได้ใน 10 วินาที

### Email

Subject line บอกสรุปจบใน 1 ประโยค Body: 3–4 ย่อหน้า TL;DR → context → details → next steps ปิดด้วย action item ชัดเจน

### Meeting talking-points

Bullet-first เรียงตาม priority คนพูดไม่ต้องอ่านทุกบรรทัด เตรียม 2–3 follow-up answers สำหรับคำถามที่คาดได้

---

## Jit Integration

เมื่อ management-talk ใน Jit context → ส่งผ่าน vaja (Personal Assistant agent):

```bash
# ส่งให้ vaja เตรียม report
bash organs/mouth.sh tell vaja "report:prepare:<audience>:<topic>"

# ดู vaja response
bash organs/ear.sh inbox vaja
```

---

## See Also

- `/post-mortem` — เขียน engineering record ก่อน แล้วส่งมาให้ management-talk แปล
- `/scrutinize` — review change ก่อนเขียน status update
