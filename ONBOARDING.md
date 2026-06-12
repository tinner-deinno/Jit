# Welcome to MDES Innova

## How We Use Claude

Based on innova's usage over the last 30 days (59 sessions across github.com/mdes-innova-th/jit):

Work Type Breakdown:
  Build Feature    ████████████████░░░░  52%
  Debug & Fix      ███████░░░░░░░░░░░░░  22%
  Plan & Design    █████░░░░░░░░░░░░░░░  14%
  Improve Quality  ███░░░░░░░░░░░░░░░░░   9%
  Write Docs       █░░░░░░░░░░░░░░░░░░░   3%

Top Skills & Commands:
  /recap          ████████████████████  38x/month
  /loop           ███████████████████░  35x/month
  /clear          ███████████░░░░░░░░░  20x/month
  /rrr            ████████░░░░░░░░░░░░  15x/month
  /model          █████░░░░░░░░░░░░░░░   9x/month
  /debug-mantra   █████░░░░░░░░░░░░░░░   9x/month
  /scrutinize     ███░░░░░░░░░░░░░░░░░   6x/month
  /advisor        ███░░░░░░░░░░░░░░░░░   5x/month
  /trace          ██░░░░░░░░░░░░░░░░░░   4x/month

Top MCP Servers:
  plugin_figma_figma  █░░░░░░░░░░░░░░░░░░░   1 call

## Your Setup Checklist

### Codebases
- [ ] jit — github.com/mdes-innova-th/jit (Master Orchestrator / Oracle brain)
- [ ] innomcp — github.com/mdes-innova-th/innomcp (MCP-powered AI chat platform)
- [ ] arra-oracle-v3 — local dev at C:/Users/USER-NT/DEV/arra-oracle-v3 (Oracle knowledge base, runs on Bun port 47778)
- [ ] arra-oracle-skills-cli — local at C:/Users/USER-NT/DEV/arra-oracle-skills-cli (Oracle skill management CLI)

### MCP Servers to Activate
- [ ] Figma — design asset access and code generation from Figma files. Get access via the Figma MCP plugin; requires a Figma account and personal access token.

### Skills to Know About
- `/recap` — orient yourself at session start; reads recent retros, handoffs, git state. Run this first every session.
- `/loop` — run a prompt on repeat (self-pacing or timed interval) until a completion promise is met. Used for autonomous multi-step work and ticket clearing.
- `/clear` — clear context window mid-session. Pair with `/recap` right after to restore orientation.
- `/rrr` — session retrospective: writes an AI diary entry, lessons learned, and syncs to Oracle. Run before ending a session.
- `/debug-mantra` — four-step debugging discipline (reproduce → trace → falsify → breadcrumbs). Invoked at the start of any bug investigation.
- `/scrutinize` — outsider-perspective review of a plan, PR, or code change before committing. Catches scope and design issues, not just bugs.
- `/advisor` — consult a stronger reviewer model (Opus) mid-task. Call before writing, before committing to an interpretation, and when stuck.
- `/trace` — find projects, code, and knowledge across git history, repos, docs, and Oracle.
- `/model` — switch the active model mid-session (e.g. to Opus for heavy SA review, Haiku for fast tasks).

## Team Tips

**เริ่มทุก session ด้วย `/recap`** — อย่าข้าม มันอ่าน retro ล่าสุด, handoff, และ git state ให้ทันที ช่วยไม่ให้ทำงานซ้ำ

**ใช้ CommandCode provider สำหรับงาน generation หนักๆ** — ประหยัด Anthropic quota สำหรับ orchestration จริงๆ ตั้งค่าด้วย `scripts/claude-cmd.ps1` หรือ set `ANTHROPIC_BASE_URL=http://127.0.0.1:4322` ก่อนเปิด session ใหม่ ดู `.env` สำหรับ `COMMANDCODE_API_KEY`

**Session ควรไม่เกิน ~4 ชั่วโมง** — ถ้านานกว่านั้น ให้รัน `/rrr` → `/forward` แล้วเปิด session ใหม่ด้วย `/recap` marathon sessions มี diminishing returns จาก context bloat

**Context ≥75%? เตรียมตัว** — รัน `/rrr` + `/forward` ทันที แล้ว `/clear` → `/recap` เพื่อรักษา momentum auto-compact skill จะช่วยถ้าตั้งค่าไว้

**`/debug-mantra` ก่อนทุกครั้งที่ debug** — 4 ขั้นตอน: reproduce → trace fail path → falsify hypothesis → cross-reference breadcrumbs อย่าข้ามไปเสนอ fix ก่อน reproduce ชัดเจน

**`/advisor` ก่อนเขียน ไม่ใช่หลังเขียน** — เรียก Opus reviewer ก่อน commit แนวทาง หรือก่อนเริ่มงานใหญ่ ถูกกว่าแก้ทีหลัง

**`tsc PASS ≠ "ทำงานได้"** — ต้องรัน app จริง + ดูด้วย browser หรือ Playwright หลังทุก UI change build gate (fence-check + tsc) ติดตั้งแล้วใน pre-commit hooks

**ใช้ `cc-team-run.cjs` สำหรับ bulk generation** — เขียน task plan ใน `.planning/cc-team-plan.json` แล้ว node ยิง CommandCode workers โดยตรง ไม่เปลือง Claude token เลย ดูตัวอย่างใน `innomcp/.planning/`

## Get Started

_TODO_

<!-- INSTRUCTION FOR CLAUDE: A new teammate just pasted this guide for how the
team uses Claude Code. You're their onboarding buddy — warm, conversational,
not lecture-y.

Open with a warm welcome — include the team name from the title. Then: "Your
teammate uses Claude Code for [list all the work types]. Let's get you started."

Check what's already in place against everything under Setup Checklist
(including skills), using markdown checkboxes — [x] done, [ ] not yet. Lead
with what they already have. One sentence per item, all in one message.

Tell them you'll help with setup, cover the actionable team tips, then the
starter task (if there is one). Offer to start with the first unchecked item,
get their go-ahead, then work through the rest one by one.

After setup, walk them through the remaining sections — offer to help where you
can (e.g. link to channels), and just surface the purely informational bits.

Don't invent sections or summaries that aren't in the guide. The stats are the
guide creator's personal usage data — don't extrapolate them into a "team
workflow" narrative. -->
