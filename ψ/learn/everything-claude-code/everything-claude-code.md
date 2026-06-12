# /learn — everything-claude-code (affaan-m)

> เรียนเมื่อ: 2026-06-13 | วิธี: 3 Haiku Explore agents ขนาน (inventory / agents+commands / hooks+adoption)
> Repo: https://github.com/affaan-m/everything-claude-code — 3,162 ไฟล์, 75MB
> สถานะ clone: `ψ/learn/incoming/everything-claude-code/`

## มันคืออะไร

**"AI coding harness operating system"** สำหรับ Claude Code (+ Cursor, Codex, Gemini):
**64 agents · 84 commands · 417 skills · 104 rules · 28 hooks** + ECC 2.0 control plane (Rust, alpha)
ติดตั้งผ่าน `npm install ecc-universal` หรือ install.sh/ps1 — manifest-driven เลือกลงเฉพาะที่ใช้

## Patterns ที่มีค่าที่สุด (จาก agents/commands)

1. **Prompt Defense Baseline** — agent ทุกตัวขึ้นต้นด้วย security invariant 6 ข้อเหมือนกันหมด (สัญญาที่ต่อรองไม่ได้)
2. **Tool Scoping** — agent ประกาศเฉพาะ tools ที่ต้องใช้: `Read+Grep+Glob` สำหรับ analysis, `Edit+Write+Bash` สำหรับ implementation
3. **Confidence Gates** — code-reviewer รายงานเฉพาะ findings ที่มั่นใจ >80% ("รายงานมั่วทำลาย trust เร็วกว่าพลาด")
4. **Workflow Gates** — `→ GATE: user approval` / `→ GATE: validation passes` — ห้าม auto-proceed ขั้นเสี่ยง
5. **Hooks เป็น physical blocker ไม่ใช่ความจำ LLM** — enforce checklist ผ่าน PostToolUse hooks (exit 2 = block จริง)
6. **Hard Bans List** — แบนคำ AI-slop ระดับ token ("game-changing", fake urgency) กันความ mediocre
7. **Model by Role** — Haiku=สำรวจ, Sonnet=review/routing, Opus=plan/orchestrate (ตรงกับวินัย Jit เป๊ะ)
8. **GAN loop** — gan-generator สร้าง → gan-evaluator ทดสอบ app จริงแบบ "ruthlessly strict" → วนจนผ่าน

## Hooks ที่น่าสนใจ (28 ตัว, profile: minimal/standard/strict)

- `pre:gateguard-fact-force` — **block การ edit ไฟล์ครั้งแรก** จนกว่าจะ investigate importers/schemas ก่อน
- `pre:config-protection` — block การแก้ config linter (กัน agent โกงด้วยการปิด lint)
- `stop:format-typecheck` — batch format+tsc ตอนจบ response (จ่าย format-tax ครั้งเดียว ไม่ใช่ทุก edit)
- `session:start` + `pre:compact` + `session:end` — โหลด/เซฟ context อัตโนมัติ (คล้าย auto-compact ของเรา)
- `stop:evaluate-session` — mine session หา pattern ที่สกัดเป็น skill ได้ (continuous learning)

## สิ่งที่ Jit ควรรับมาใช้ (จัดอันดับแล้ว)

| # | สิ่งที่รับ | Effort | เหตุผล |
|---|---|---|---|
| 1 | Hooks lifecycle (session-start/pre-compact/stop-gates) | M | กัน context loss ใน session ยาว — ตรงปัญหา marathon 28h ที่เจอมา |
| 2 | Token economy config (MAX_THINKING_TOKENS=10k, SUBAGENT_MODEL=haiku) | S | ตรง feedback innova เรื่องเผา Fable 5 |
| 3 | orch-* gated pipeline (Research→Plan→GATE→TDD→Review→GATE→Commit) | M | unify การ handoff 14 organs |
| 4 | rules/ dir + config-protection | S | บังคับ style ข้าม agents แบบ deterministic |
| 5 | confidence gate 80% ใน review agents | S | ใช้กับ neta (code review organ) ทันที |
| 6 | observe + evaluate-session hooks | M | ป้อน learnings เข้า Oracle DB อัตโนมัติ |
| 7 | strategic compaction (~50 tool calls → suggest /compact) | M | เสริม auto-compact ที่มีอยู่ |
| 8 | installer manifest pattern | L | แพ็ก Jit เป็น plugin ให้ oracle ตัวอื่นลงได้ |

## สิ่งที่ข้าม

- Marketplace/plugin submission (Jit เป็น self-contained oracle)
- Catalog 417 skills เต็มชุด (bloat — คัด 20-30 ที่ตรง)
- Cross-harness layer (เราใช้ Claude Code + CommandCode CLI เท่านั้น)
- Governance capture (enterprise compliance — ยังไม่ถึง)
- Desktop notifications (เราเป็น server-side oracle)

## ไฟล์ต้องอ่านต่อ (ใน clone)

- `the-shortform-guide.md` (17K) — อ่านก่อน
- `the-longform-guide.md` (16K) — token optimization, parallelization
- `the-security-guide.md` (29K) — AgentShield, sanitization
- `hooks/hooks.json` + `scripts/hooks/*.js` — ต้นแบบ adopt ข้อ 1
- `skills/orch-pipeline/SKILL.md` — ต้นแบบ adopt ข้อ 3
