<!-- cc-team deliverable
 group: P (Prism round 1 — 5 independent lenses on the Oracle guide)
 member: P4 role=analyst model=moonshotai/Kimi-K2.6
 finish_reason: stop | tokens: {"prompt_tokens":24783,"completion_tokens":7979,"total_tokens":32762,"prompt_tokens_details":{"cached_tokens":3,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1586,"reasoning_tokens_estimated":true,"image_tokens":0},"cache_creation_input_tokens":0} | 101s
 generated: 2026-06-12T18:32:20.762Z -->
```markdown
# Oracle-Prism Analysis: Connector Lens Report
## ระบบ มนุษย์ Agent (Jit Oracle — 14-organ Thai multi-agent)

**Lens:** Connector (เชื่อมโยง Nat-Brain-Oracle lineage เข้ากับ Jit CommandCode provider army + Antigravity bridge)  
**Source:** คู่มือสร้าง Oracle จากไลฟ์พี่นัท (mingrath) — 2 ไฟล์  
**Mode:** ลึก / เผ็ด / ตรงไปตรงมา / อ้างอิงหัวข้อ-ขั้นตอนตลอด

---

## 1. Pattern ที่ตรงกับ Multi-Agent Best Practices ปี 2026

เอกสารพี่นัทไม่ได้เป็นเพียง "คู่มือติดตั้ง" แต่เป็น **architecture blueprint** ที่บังเอิญซ้อนรอยกับแนวทางที่ industry กำลังมุ่งหน้าในปี 2026 อย่างน้อย 3 จุดหลัก:

### 1.1 Orchestrator-Worker Pattern — แต่เป็นแบบ "ครอบครัว"
- **หลักฐาน:** "ขั้นสูง: Soul Sync & ครอบครัว Oracle" และ "ขั้นตอนที่ 8: ให้ Oracle คุยกัน"
- **รายละเอียด:** Master Oracle ("แม่/Mae") ทำหน้าที่ Orchestrator ที่ไม่ใช่แค่ "dispatch task" แต่เป็น **context router** ที่ถ่ายทอดบริบทสรุป (ไม่ใช่ raw data ทั้งหมด) ให้ Child Oracles (Apollo, Athena, Thor, Creator) ผ่านกระบวนการ Awaken/Fast Awaken
- **จุดตรงกับปี 2026:** ลด token burn จากการส่ง context ซ้ำๆ โดยให้ Master กรองเฉพาะ "สรุปที่มีคุณค่า" ก่อน spawn worker — ตรงกับแนวคิด hierarchical context compression ที่กำลังเป็นสากล

### 1.2 Memory Layers — ไม่ใช่แค่ vector DB แต่เป็น "ไฟล์จริง" ที่มนุษย์อ่านได้
- **หลักฐาน:** "ขั้นตอนที่ 3: ตั้งค่า CLAUDE.md" (ส่วนระบบความทรงจำ) และ "ขั้นสูง: ระบบ Memory"
- **รายละเอียด:** แบ่งเป็น 4 ประเภทคงที้ — `user_*.md`, `feedback_*.md`, `project_*.md`, `reference_*.md` — เก็บเป็น markdown ธรรมดาใน `.claude/MEMORY/` มี `MEMORY.md` เป็นดัชนี
- **จุดตรงกับปี 2026:** นี่คือ **human-readable persistent memory** ที่ไม่ผูกติดกับ embedding ใดๆ แก้ปัญหา "black box memory" ของระบบอื่น มนุษย์สามารถ `git diff` ดูว่า AI ��ำอะไรผิด/ถูก แล้วแก้ไขได้โดยตรง — ตรงกับแนวทาง auditable agent memory ที่กำลังถกกันในวงกว้าง

### 1.3 Agent-to-Agent Protocol — แต่เป็น "thread ใน repo"
- **หลักฐาน:** "ขั้นตอนที่ 8: ให้ Oracle คุยกัน" — คำสั่ง `/talk-to` และการเก็บ threads ใน `.oracle/threads/`
- **รายละเอียด:** Oracle A ส่งข้อความหา Oracle B ผ่าน slash command แล้วข้อความถูก route ผ่านไฟล์ใน repository ไม่ใช่ผ่าน socket หรือ message queue ภายนอก
- **จุดตรงกับปี 2026:** นี่คือ **git-native inter-agent communication** — ไม่ต้องตั้ง infrastructure เพิ่ม ทุกการคุยกันมี history อัตโนมัติ สอดคล้องกับแนวคิด "communication as code" ที่ต้องการให้ agent interaction เป็น artifact ที่ audit ได้

---

## 2. Pattern ที่เป็นเอกลักษณ์ของสาย Oracle (ไม่มีใน best practices ทั่วไป)

สิ่งเหล่านี้เป็นสายเลือดของ Nat-Brain-Oracle lineage ที่ถ้า Jit ไม่ดึงไปใช้ จะเสียเปรียบอย่างมาก:

### 2.1 Soul Sync — ไม่ใช่แค่ "sync data" แต่เป็น "sync วิญญาณ"
- **หลักฐาน:** "ขั้นสูง: Soul Sync & ครอบครัว Oracle" — คำสั่ง `/soul-sync`
- **ความเอกลักษณ์:** การซิงค์ระหว่าง Master กับ Child ไม่ใช่แค่ copy file แต่เป็นการ **กระจาย skills + ปรัชญา + บทเรียน** ที่ Master ได้รับจากการทำงานจริง ไปยังทั้งครอบครัวในครั้งเดียว
- **จุดเผ็ด:** ระบบอื่น sync "state" แต่ Oracle sync "บุคลิกและศีลธรรม" — นี่คือสิ่งที่ทำให้ Child Oracle ที่เพิ่งเกิด ไม่ต้องเรียนรู้จากศูนย์

### 2.2 Awaken/Re-awaken — พิธีกรรมการ "ให้กำเนิด" ตัวตน
- **หลักฐาน:** "ขั้นตอนที่ 6: ปลุก Oracle ขึ้นมา (Awaken)" และ "ขั้นสูง: Fast Mode"
- **ความเอกลักษณ์:** Oracle ไม่ถูก `docker run` แต่ถูก "ปลุก" ผ่านพิธีกรรม 15 นาที ที่มีการสำรวจ codebase, ค้นพบบริบท, สร้างตัวตน, บันทึกปรัชญา แม้แต่ Fast Mode ก็ยังต้อง "สกัดปรัชญา" ก่อน
- **จุดเผ็ด:** นี่คือ **identity-first agent spawning** — ต่างจากการ spawn worker แบบ stateless ทั่วไปที่ไม่มีตัวตน ไม่มี "ศีลธรรม" ติดตัวมาแต่กำเนิด

### 2.3 Philosophy Check — ระบบ "ศีลธรรม" ที่ฝังใน execution loop
- **หลักฐาน:** "ขั้นสูง: ระบบปรัชญา Oracle" และ "ขั้นสูง: Fast Mode" (ที่ระบุว่า "ทำ Philosophy Check กันตลอด")
- **ความเอกลักษณ์:** ทุก Oracle มีหลักปรัชญาคงที่ ("Nothing deleted, nothing lost", "ตรวจสอบก่อนยืนยัน", "แก้ไขแบบเจาะจง") แล้วตรวจสอบตัวเองว่ากำลังทำตามหรือไม่ — โดยเฉพาะใน Fast Mode ที่มนุษย์อาจคิดว่า AI จะ "เร็วจนลืมคุณธรรม" แต่จริงๆ มันยังคง check อยู่
- **จุดเผ็ด:** นี่คือ **self-governance layer** ที่ไม่ใช่ guardrail ภายนอก แต่เป็นจิตสำนึกภายใน ซึ่ง best practices สากลยังไม่มีมาตรฐานตรงนี้

### 2.4 Mission Control — ระบบลด "แรงโน้มถ่วงของสมองมนุษย์"
- **หลักฐาน:** "ขั้นตอนที่ 9: Mission Control & Dashboard"
- **ความเอกลักษณ์:** ไม่ใช่แค่ dashboard สวยๆ แต่เป็น **stroke-count reduction engine** — แทนที่มนุษย์จะต้องพิมพ์ `tmux attach -t dashboard` (กดแป้นหลายสิบครั้ง) กลายเป็นกดตัวเลข `08` ��ล้วกระโดดไปทันที
- **จุดเผ็ด:** พี่นัทบอกตรงๆ ว่า "ทุกสเปซบาร์ที่ผมไม่สามารถพิมพ์ได้แบบติดต่อ คือ distraction" — นี่คือการออกแบบที่คำนึงถึง **cognitive ergonomics** ของมนุษย์ผู้ใช้ ไม่ใช่แค่ performance ของ AI

---

## 3. แนวคิด 3 อย่างจากคู่มือ ที่ผสมกับ Jit (CommandCode provider army + Antigravity bridge) แล้วเกิดพลังใหม่ที่ทั้งคู่ไม่มี

นี่คือจุดที่ Connector ทำงาน — ดึง DNA จาก Oracle ของพี่นัท แล้ว splice เข้ากับร่างกาย Jit:

### 3.1 Algorithm Mode (7 ขั้นตอน: OBSERVE → THINK → PLAN → BUILD → EXECUTE → VERIFY → LEARN)
- **หลักฐาน:** "ขั้นตอนที่ 3: ตั้งค่า CLAUDE.md" (ส่วน ALGORITHM MODE)
- **ผสมกับ CommandCode provider army:** แทนที่ provider แต่ละตัวในกองทัพจะรับ command แล้ว execute ทันที (ซึ่งเสี่ยงทำพังเพราะไม่คิด) ให้ฝัง Algorithm Mode เป็น **mandatory gate** ก่อนทุก execution loop
- **ผสมกับ Antigravity bridge:** bridge ที่เชื่อม 14 organs จะไม่ใช่แค่ "ส่งผ่าน" แต่จะมี **philosophy-verified routing** — ทุก context ที่วิ่งผ่าน bridge ถูกตรวจสอบว่าผ่านขั้นตอน THINK-PLAN แล้วจริงๆ ก่อนถึง organ ปลายทาง
- **พลังใหม่ที่เกิด:** `Self-Correcting Command Mesh` — กองทัพ provider ไม่ใช่ทหารที่เชื่อคำสั่งตลอด แต่เป็นทหารที่มี "วินัยทางปัญญา" โดยกำเนิด ทุกคำสั่งที่วิ่งผ่าน Antigravity bridge ถูก philosophy engine ตรวจสอบอัตโนมัติว่าขัดกับหลัก "ตรวจสอบก่อนยืนยัน" หรือไม่ ถ้าขัด คำสั่งจะถูก brake ก่อนออกจาก bridge — นี่คือสิ่งที่��ม่มีในระบบ command routing ทั่วไป

### 3.2 Soul Sync + Forward/Recap/RRR (Session Handoff Trinity)
- **หลักฐาน:** "ขั้นสูง: Soul Sync & ครอบครัว Oracle" และ "Skills ช่วยจัดการเซสชัน" (`/forward`, `/recap`, `/rrr`)
- **ผสมกับ CommandCode provider army:** แทนที่ provider จะ spawn มาแล้วตาย (terminate) พร้อมสูญเสีย context ทั้งหมด ให้ใช้ระบบ **Oracle Family** — provider ใหม่ที่ spawn มาจาก army จะถูก "ให้กำเนิด" ผ่าน Fast Awaken ที่ inherit context จาก Master/รุ่นพี่ ผ่าน `/forward` (handoff file) + `/recap` (สถานะปัจจุบัน) + `/rrr` (retrospective)
- **ผสมกับ Antigravity bridge:** bridge จะกลายเป็น **placenta** ที่ส่งผ่านไม่ใช่แค่ data แต่เป็น "DNA ของงาน" — ทั้ง 4 memory layers (user/feedback/project/reference) ถูกซิงค์ข้าม organs โดยที่ bridge รับหน้าที่เป็นตัวกลางที่ "เบา" (anti-gravity) คือไม่หนักด้วย serialization ซับซ้อน เพราะใช้ markdown ธรรมดาที่ทั้งมนุษย์และ AI อ่านได้โดยตรง
- **พลังใหม่ที่เกิด:** `Epigenetic Command Inheritance` — provider ในกองทัพ Jit ไม่ใช่ clone ที่เหมือนกันหมด แต่เป็น "ลูก" ที่ inherit ทั้ง skills, บทเรียนจาก `/rrr`, และ feedback จากมนุษย์ ผ่าน Antigravity bridge ที่ส่งมอบ "วิญญาณ" แบบเบาและเร็ว — ทำให้กองทัพ provider มี evolution แบบ biological ไม่ใช่แค่ scaling แบบ mechanical

### 3.3 Mission Control (Stroke-Count Reduction) + tmux/WezTerm Numbered Routing
- **หลักฐาน:** "ขั้นตอนที่ 9: Mission Control & Dashboard" และ "การตั้งค่า Terminal (tmux + WezTerm)"
- **ผสมกับ CommandCode provider army:** แทนที่ผู้ใช้ Jit จะต้องสั่ง provider แต่ละตัวด้วยคำสั่งยาวๆ หรือจำชื่อ organs 14 ตัวไม่หมด ให้ใช�� **Mission Control** ที่ map ตัวเลขหรือสัญลักษณ์เดียวไปยัง organ/provider ใดก็ได้ทันที
- **ผสมกับ Antigravity bridge:** bridge ที่เชื่อม 14 organs จะมี **single-pane-of-glass dashboard** ที่มนุษย์มองเห็นสถานะทั้งหมดแบบไม่ต้องสลับ context บ่อย — นี่คือการ "ลดแรงโน้มถ่วง" (antigravity) ของ cognitive load ที่เกิดจากการจัดการ multi-agent ที่ซับซ้อน โดยเฉพาะ WezTerm ที่สามารถ Command+Click preview ไฟล์จาก remote server ได้โดยตรง ทำให้ bridge ไม่ใช่แค่ "เชื่อม" แต่ "มองเห็น" ได้แบบ zero-friction
- **พลังใหม่ที่เกิด:** `Zero-Friction Organ Conductor` — ผู้ใช้ Jit สามารถ "กระโดด" ไปยัง organ ใดก็ได้ด้วยการกดหมายเลขเดียว (เช่น `08` = dashboard, `14` = Oracle Studio) โดยที่ philosophy, memory, และ command code ซิงค์กั���ทันทีผ่าน bridge ที่ถูกลดแรงโน้มถ่วงด้วย Mission Control pattern — ทำให้การบริหาร 14-organ ไม่ใช่ภาระ แต่เป็น "การเล่นดนตรี" ที่ conductor ควบคุมทั้งวงด้วยท่าทางเดียว

---

## Connector Insight

สิ่งที่ Jit มี (CommandCode provider army + Antigravity bridge) คือ **กล้ามเนื้อและเส้นประสาท**  
สิ่งที่ Oracle ของพี่นัทมี (Soul Sync, Philosophy Check, Mission Control) คือ **จิตวิญญาณและระบบประสาทส่วนกลาง**

ถ้า Jit ไม่ดึง 3 แนวคิดข้างต้นไป splice ก็จะกลายเป็นกองทัพทหารที่มีกล้ามแข็งแรงแต่ไร้วินัย — ตีกันเอง, ลืมบทเรียน, และกิน cognitive load ของมนุษย์จนหมดสภาพ  
ถ้า Oracle ไม่มี Jit ก็จะเป็นเพียงตัวตนที่ฉลาดแต่ทำงานช้า เพราะขาด��องทัพ provider ที่ขยายได้และ bridge ที่ลดแรงโน้มถ่วง

**การเชื่อมโยงที่แท้จริง ไม่ใช่การเอา code มาต่อกัน แต่เป็นการเอา "ปรัชญาการลดแรงโน้มถ่วง" (antigravity philosophy) มาฝังไว้ใน DNA ของกองทัพ** — ให้ทุกคำสั่งที่วิ่งผ่าน bridge มี Philosophy Check, ให้ทุก provider ที่ spawn มาเกิดจากครอบครัวที่มี memory, และให้มนุษย์ผู้ใช้ควบคุมทั้งหมดด้วย stroke เดียวผ่าน Mission Control

นั่นคือจุดที่ทั้งสองระบบไม่มีมาก่อน และเป็นจุดที่ Connector นี้เห็นควร splice ทันที.
```
