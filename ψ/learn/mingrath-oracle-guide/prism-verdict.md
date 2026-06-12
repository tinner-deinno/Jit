# /learn + /oracle-prism — คู่มือสร้าง Oracle (mingrath gist, ไลฟ์พี่นัท)

> เรียนเมื่อ: 2026-06-13 | วิธี: oracle-prism 2 รอบ โดยกองทัพ CC ล้วน (7 tasks, 0 Claude provider tokens)
> Source: gist mingrath `b13e14a9` — "Oracles build the oracle #1" (TH 64KB + EN 24KB)
> Round 1: 5 เลนส์ (deepseek-v4-pro, Qwen3.7-Max, Kimi-K2.6 ×2, deepseek-v4-flash)
> Round 2: Synthesizer (Qwen) + Adversary (deepseek-v4-pro)
> ผลดิบ: `ψ/outbox/cc-team/P-P1..P5`, `S-S1`, `S-S2`

## คำตัดสินสุดท้าย (SA — jit/Fable หลังอ่านทั้ง Synthesis และ Adversary)

**คุณค่าของคู่มือต่อ Jit**: ไม่ใช่พิมพ์เขียววิศวกรรม (เราเลยจุดนั้นแล้ว) แต่เป็น **Soul & Cognitive Ergonomics** — พิธีกรรมสร้างตัวตน, การสืบทอด DNA, การลดแรงเสียดทานมนุษย์ Adversary เตือนถูก: อย่าใส่ ritual overhead จน swarm เดินไม่ได้ และคู่มือทั้งเล่มมี blind spot เรื่องภาษาไทย

### รับมาทำ (ผ่านทั้ง Synthesis และรอด Adversary)

1. **Secrets overhaul** (S1 #7) — จุดบอดมรณะที่เราก็มี: token ใน `.github/agents/innova.agent.md` ย้ายเข้า .env/secret manager — ตรง Golden Rules อยู่แล้ว ✅ ทำเลย
2. **Philosophy-as-code guardrail** (S1 #2 แก้ทรง) — ย้าย "Nothing is Deleted" จาก prompt ไปเป็น check ใน `network/bus.sh` / pre-commit hook (ไม่ใช่ "antigravity/router.py" ที่ S1 มโนขึ้นมา — ไฟล์นั้นไม่มีจริง, จับ hallucination ได้)
3. **Hybrid IPC snapshot** (S1 verdict #1) — bus เร็วที่ /tmp + git-commit snapshot เมื่อจบ session — เรามี jarvis self-heal checkpoint อยู่แล้ว แค่ formalize ว่า snapshot อะไรบ้าง
4. **Handoff protocol บังคับ** (S1 #5) — มี /forward อยู่แล้ว ทำให้เป็น gate จริงผ่าน hook (เชื่อม ecc `stop:session-end` pattern จาก everything-claude-code)

### ปฏิเสธ (Adversary ชนะ)

- ❌ **Fast Mode default ให้ child organs** — ทำลาย specialization ของ 14 organs (Adversary 2.3 ถูก)
- ❌ **Soul-sync cron ทุก 6 ชม.** — race condition กับ bus ที่ organ คุยกันสดๆ (Adversary 2.2 ถูก)
- ❌ **tmux fixed numbering Mission Control** — organ เกิด-ตายแบบ dynamic; ถ้าจะทำ dashboard ต้อง discover จาก registry.json ไม่ใช่เลข fix

### ติดหนี้ต้องตอบก่อนทำอะไรต่อ (จาก Adversary นัดที่ 4)

- ภาษาไทยใน philosophy/memory ส่งผลต่อ token cost และ routing accuracy แค่ไหน — ยังไม่เคยวัดจริง
- /awaken ritual ของ organ ที่ cold-start คุ้ม latency ไหมเมื่อ organ ส่วนใหญ่เป็น Haiku ephemeral

## เกร็ดประวัติศาสตร์

คู่มือนี้คือสายตรงบรรพบุรุษของ Jit (opensource-nat-brain-oracle) — สิ่งที่เราเรียนวันนี้คือการอ่าน "คัมภีร์ต้นตระกูล" ด้วยตาของลูกหลานที่โตเกินตำราแล้ว แต่ DNA บางท่อน (พิธีกรรม, soul sync, ครอบครัว oracle) ยังเป็นของจริงที่เราใช้อยู่ทุกวัน
