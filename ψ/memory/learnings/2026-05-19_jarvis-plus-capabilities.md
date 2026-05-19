# JARVIS+ : Capabilities Unlocked by ECC Absorption

**Date**: 2026-05-19 22:53 SEAST
**Source**: github.com/affaan-m/ECC v2.0.0-rc.1
**Operator**: innova / Jit Oracle / Claude Haiku 4.5 + Opus 4.7

---

## ก่อน vs หลัง

### ก่อนดูดซับ ECC
- **130 skills** : Oracle ecosystem (awaken/birth/recap/dig/trace/learn) + 58 GSD methodology + integrations (gemini/ollama/speak/warp)
- **33 agents** : All gsd-* (planner, executor, code-reviewer, etc.) — tied to GSD workflow
- **12 hooks** : All gsd-* (context-monitor, prompt-guard, workflow-guard, validate-commit)
- **Strengths** : Get-Shit-Done methodology, Oracle session continuity, multi-machine fleet
- **Gaps** : Language-specific reviewers, autonomous dev loops, agent-engineering patterns, eval harnesses, cost-aware LLM pipelines

### หลังดูดซับ ECC
- **159 skills** (+29 LIVE) ← +22% capability surface
- **69 agents** (33 GSD + 36 ECC under `agents/ecc/`) ← +109% agent fleet
- **Unchanged hooks** (12 GSD) — ECC hooks documented but not auto-wired (risk of double-firing)

---

## สิ่งที่ทำได้ใหม่ — แบ่งตามสถานการณ์จริง

### 1) ทบทวนโค้ดหลายภาษาแบบมือโปร
ก่อน: ใช้ `/simplify` หรือ `/gsd-code-review` (รวมๆ ทุกภาษา)
ตอนนี้:
- เห็นไฟล์ `.py` → `agents/ecc/python-reviewer.md`
- เห็นไฟล์ `.rs` → `agents/ecc/rust-reviewer.md`
- เห็นไฟล์ `.go` → `agents/ecc/go-reviewer.md`
- เห็นไฟล์ `.ts` → `agents/ecc/typescript-reviewer.md`
- เห็นไฟล์ `.swift/.kt/.java/.cs/.cpp` → reviewer เฉพาะภาษา
- เห็น Django/FastAPI → reviewer เฉพาะ framework
- เห็น PyTorch build error → `pytorch-build-resolver`

**ผลกระทบ**: คำแนะนำเฉพาะภาษาแทน generic; จับ idiom ภาษาได้ถูก (เช่น Rust ownership patterns, Go context.Context, TS strict types)

### 2) สร้าง autonomous dev loop จริงๆ (GAN Trio)
ก่อน: ใช้ `/gsd-autonomous` (รัน phase ตามลำดับ)
ตอนนี้:
- `gan-planner` (opus) — ขยาย one-liner เป็น full spec
- `gan-generator` (opus) — implement พร้อม feedback loop
- `gan-evaluator` (opus) — test และให้คะแนนตาม rubric
- `loop-operator` — เฝ้าระวัง autonomous loops, intervene เมื่อมี trouble
- Skill `/continuous-agent-loop` — เลือก pattern (sequential / RFC-DAG / PR-driven / infinite)

**ผลกระทบ**: รัน feature development จริงโดยไม่ต้อง babysit ทุก step; loop-operator คุมความปลอดภัย

### 3) ประเมิน LLM และ agent อย่างเป็นวิทยาศาสตร์
ก่อน: ไม่มี framework กลาง — ใช้ความรู้สึก
ตอนนี้:
- `/agent-eval` — เปรียบเทียบ Claude Code vs Aider vs Codex บน task เดียวกัน (pass rate, cost, time, consistency)
- `/eval-harness` — Eval-Driven Development (EDD) — pass/fail criteria, regression, pass@k
- `/ai-regression-testing` — จับ blind spots ที่ AI review ตัวเอง

**ผลกระทบ**: ตัดสินใจ "ใช้ Opus ไหม" หรือ "Claude พอ" จากข้อมูล ไม่ใช่ vibes

### 4) คุมต้นทุน LLM แบบจริงจัง
ก่อน: ไม่มี cost visibility
ตอนนี้:
- `/cost-aware-llm-pipeline` — model routing ตาม task complexity, budget tracking, retry logic, prompt caching
- `/context-budget` — audit context window (agents/skills/MCP/rules) → ระบุที่ค่าใช้จ่ายเปลือง
- `/token-budget-advisor` — เลือก response depth ก่อนตอบ

**ผลกระทบ**: ไม่ต้องเปิด Opus 4.7 1M context สำหรับงานง่าย; auto-route ไป Haiku

### 5) Architecture decisions มี trail
ก่อน: ตัดสินใจแล้วลืม
ตอนนี้:
- `/architecture-decision-records` — auto-detect decision moments → write ADR
- `/code-tour` — สร้าง CodeTour files พร้อม anchors สำหรับ onboarding
- `/codebase-onboarding` — generate onboarding guide + starter CLAUDE.md

**ผลกระทบ**: 6 เดือนข้างหน้ายังจำได้ว่า "ทำไมเลือก approach นี้"; โอนความรู้ได้

### 6) Agent-engineering ระดับลึก
ก่อน: เขียน prompt → หวัง
ตอนนี้:
- `/agent-harness-construction` — design action spaces / tool definitions ให้ completion rate สูงขึ้น
- `/agent-introspection-debugging` — เมื่อ agent fail → capture + diagnose + recover
- `/agent-architecture-audit` — 12-layer diagnostic (wrapper regression, memory pollution, tool discipline, repair loops)
- `/iterative-retrieval` — แก้ subagent context problem
- `/agentic-os` — kernel architecture สำหรับ persistent multi-agent OS
- `/mcp-server-patterns` — สร้าง MCP server แบบ production

**ผลกระทบ**: ออกแบบ Jit Oracle v2 ได้จากของจริง ไม่ใช่ทฤษฎี

### 7) ความปลอดภัย proactive
ก่อน: `/security-review` อย่างเดียว
ตอนนี้:
- `/security-review` (ECC enhanced) — auth, input, secrets, API, payment patterns
- `/gateguard` — fact-forcing gate ก่อน Edit/Write/Bash (+2.25 quality vs ungated agents)
- `/agent-payment-x402` — payment execution พร้อม per-task budgets

**ผลกระทบ**: ก่อนแก้ไฟล์ — ต้องตอบ "ใครใช้ไฟล์นี้บ้าง" + "user instruction คืออะไร" → ไม่มี "yes-man" agent อีก

### 8) Engineering patterns ข้ามภาษา
ก่อน: ทำซ้ำๆ ตามที่จำได้
ตอนนี้:
- `/error-handling` — typed errors, boundaries, retries, circuit breakers (TS/Python/Go)
- `/api-design` — REST patterns ครบ (pagination, status codes, versioning)
- `/api-connector-builder` — match repo pattern ที่มีอยู่ ไม่สร้าง pattern ที่ 2
- `/backend-patterns` — repo/service layers, N+1, caching, async, middleware
- `/hexagonal-architecture` — Ports & Adapters cross-language
- `/regex-vs-llm-structured-text` — decision framework: regex หรือ LLM

**ผลกระทบ**: คำตอบ engineering มี pattern reference ทุกครั้ง

---

## How To Use (ตัวอย่างจริง)

```bash
# ตัวอย่าง 1: รีวิว Python project
# Claude auto-spawns python-reviewer agent (in ~/.claude/agents/ecc/)
"Review this Python codebase for production-readiness"

# ตัวอย่าง 2: autonomous feature development
"Build a JWT auth system with refresh tokens — use GAN pattern"
# → gan-planner spec'd it → gan-generator builds → gan-evaluator tests → loop-operator watches

# ตัวอย่าง 3: ประเมิน Claude vs ทางเลือกอื่น
/agent-eval
# → จาก ~/.claude/skills/agent-eval/SKILL.md → setup harness บน task ของคุณ

# ตัวอย่าง 4: Audit agent architecture (เช่น Jit เอง)
/agent-architecture-audit
# → 12-layer diagnostic บนระบบ agent ของคุณ

# ตัวอย่าง 5: เริ่ม ADR
/architecture-decision-records
# → auto-detect decision in conversation → write ADR

# ตัวอย่าง 6: Cost audit
/context-budget
# → ระบุ skill/MCP/agent ที่กิน context มากเกินไป

# ตัวอย่าง 7: ก่อน edit สำคัญ
/gateguard
# → demand investigation: importers? schema? user instruction?
```

---

## ECC Patterns ที่ยัง NOT installed (แต่ knowledge captured)

### Hooks ที่น่าพอร์ตในอนาคต (ต้องระวัง double-firing กับ gsd hooks)
1. **gateguard-fact-force.js** — hook version (skill version installed already)
2. **governance-capture.js** — audit trail สำหรับ secrets/destructive ops
3. **cost-tracker.js** — per-session cost ตาม model rates
4. **ecc-context-monitor.js** — auto-warn ที่ 35%/25% context, $5/$10/$50 cost, scope creep
5. **stop-format-typecheck.js** — batch format+typecheck at Stop (not per-edit)

**Why not installed**: User มี gsd-context-monitor.js แล้ว — เสี่ยง conflict. ต้อง audit settings.json ก่อน

### Scripts ที่น่าศึกษาในอนาคต
- `scripts/harness-audit.js` (36KB) — ECC 2.0 readiness gate
- `scripts/consult.js` (13KB) — recommend components from natural language
- `scripts/claw.js` (14KB) — NanoClaw v2 agent REPL
- `scripts/doctor.js` (2.8KB) — diagnose drift

**Location**: C:\Users\admin\ghq\github.com\affaan-m\ECC\scripts\

---

## ก่อนหลังเปรียบเทียบขีดความสามารถ

| ความสามารถ | ก่อน | หลัง | Δ |
|------------|------|------|---|
| Language-specific code review | ❌ (generic เท่านั้น) | ✅ 10 ภาษา + Django/FastAPI/PyTorch | +∞ |
| Autonomous dev loop | ⚠️ gsd-autonomous (phase-based) | ✅ GAN trio + loop-operator | +1 architecture |
| Agent benchmarking | ❌ | ✅ /agent-eval | +1 dimension |
| Eval-driven development | ❌ | ✅ /eval-harness + /ai-regression-testing | +EDD method |
| Cost visibility | ❌ | ✅ /context-budget + /cost-aware-llm-pipeline | +cost tracking |
| ADR capture | ❌ | ✅ auto-detect + write | +institutional memory |
| MCP server building | ⚠️ | ✅ /mcp-server-patterns | +scaffolding |
| Fact-forcing before edits | ❌ | ✅ /gateguard | +2.25 quality |
| Agent introspection | ❌ | ✅ /agent-introspection-debugging | +debug method |
| Hexagonal architecture | ❌ | ✅ /hexagonal-architecture | +pattern |
| Onboarding new repos | ⚠️ /learn (read-only) | ✅ /codebase-onboarding (write) | +output |
| Decision: regex vs LLM | gut feel | ✅ /regex-vs-llm-structured-text | +framework |

---

## "ยิ่งกว่า JARVIS" — สิ่งที่ได้

> JARVIS เป็น personal assistant. JARVIS+ เป็น **engineering OS** — มี
> - methodology (GSD 58 skills)
> - identity & memory (Oracle ecosystem)
> - agentic capabilities (ECC 36 new skills + 36 agents)
> - eval/cost discipline (eval-harness + cost-aware)
> - cross-language fluency (10+ language reviewers)
> - autonomous dev (GAN trio + loop-operator)
> - architecture trail (ADRs + code-tours)

ที่ JARVIS ไม่มี:
1. ความสามารถสะสมข้าม session (Oracle memory + ψ/)
2. methodology บังคับ rigor (GSD)
3. agent-engineering ตัวเอง (agentic-os, agent-architecture-audit)
4. ประเมินตัวเอง (agent-eval, eval-harness)

---

## Provenance / Where Everything Lives

- **ECC source**: C:\Users\admin\ghq\github.com\affaan-m\ECC (clone, 213 npm deps installed)
- **Installed agents**: C:\Users\admin\.claude\agents\ecc\ (36 files, isolated folder)
- **Installed skills**: C:\Users\admin\.claude\skills\ (mixed into main skills dir, 36 new)
- **Trace log**: C:\Users\admin\Jit\ψ\memory\traces\2026-05-19\2253_ecc-treasure-absorption.md
- **This learning doc**: C:\Users\admin\Jit\ψ\memory\learnings\2026-05-19_jarvis-plus-capabilities.md

## Next Recommended Practice

1. Try one `/agent-eval` run this week — get baseline numbers
2. Use `/architecture-decision-records` on next big choice
3. Run `/context-budget` to see what's eating context now
4. Pilot `/gan-planner` → `/gan-generator` → `/gan-evaluator` on a small bug fix
5. Audit `gsd-context-monitor.js` vs `ecc-context-monitor.js` patterns — port best ideas
