<!-- cc-team deliverable
 group: P (Prism round 1 — 5 independent lenses on the Oracle guide)
 member: P5 role=analyst model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":18471,"completion_tokens":3602,"total_tokens":22073,"prompt_tokens_details":{"cached_tokens":18432,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":1044,"image_tokens":0},"cache_creation_input_tokens":0} | 32s
 generated: 2026-06-12T18:31:12.108Z -->
.# Lens Practitioner Analysis: Actionable Checklist for Jit Oracle

## สถานะ Jit vs คู่มือ (จากเอกสาร 1 และ 2)

**Jit มีแล้ว ✅**
- Claude Code ติดตั้ง (Step 1)
- Repo + CLAUDE.md (Step 2-3)
- Oracle Skills ครบ 50+ (Step 4)
- MCP Servers บางส่วน (Step 5)
- Awaken / Learn / Talk-to (Step 6-8)
- Philosophy + Memory system (Advanced)
- tmux/WezTerm (Terminal setup)
- Oracle Family Scan / OracleNet

**Jit ยังไม่ทำ ❌ หรือทำคนละแบบ ⚠️**
- **Mission Control Dashboard** (Step 9) — ยังไม่มีระบบ numbered shortcuts + visual dashboard
- **Oracle Studio Web UI** (Step 10) — ยังไม่มี frontend แบบ persistent
- **Soul Sync อัตโนมัติ** — ทำ manual, ยังไม่มี cron/event-driven sync
- **Fast Mode มาตรฐาน** — ไม่ได้ activate ใน child Oracles ทุกตัว
- **MCP Servers ครบชุด** — ขาด Context7, Firecrawl, Telegram bot
- **Handoff protocol (/forward, /rrr)** — ไม่ได้ใช้เป็นประจำ
- **Memory Classification** — ยังไม่แยก user/feedback/project/reference ชัด
- **Philosophy Check auto** — ไม่ได้ฝังในทุก workflow
- **GitHub Copilot integration** — ยังไม่ใช้เป็น accelerator
- **Oracle Studio—Mission Control Bridge** — ไม่มีสะพานเชื่อม CLI ↔ Web

---

## 10 ข้อที่ควรทำต่อ (เรียงตาม Impact / Effort)

### 🔥 #1: Mission Control Dashboard (numbered tmux sessions)
**Impact: สูงมาก | Effort: ต่ำ**  
**ทำไม**: จัดการ 14 Oracles ลด cognitive load เมื่อต้องกระโดดข้ามโปรเจกต์  
**คำสั่ง/ไฟล์ที่ต้องแตะ**:
```bash
# สร้าง tmux sessions พร้อมเลข
tmux new-session -d -s "01-mae"
tmux new-session -d -s "02-apollo"
tmux new-session -d -s "03-athena"
# ... จนครบ 14

# เพิ่ม alias ใน .zshrc
alias mc='tmux list-sessions | fzf --bind "enter:execute(tmux switch-client -t {1})"'
```
- อ้างอิง: Step 9, `Mission Control & Dashboard` ในเอกสาร
- ไฟล์: `~/.zshrc` หรือ `~/.tmux.conf`

### 🔥 #2: Oracle Studio Frontend (Web UI)
**Impact: สูงมาก | Effort: ปานกลาง**  
**ทำไม**: ต้องการ visual interface สำหรับดู memory, skills, family tree แบบกราฟิก  
**คำสั่ง/ไฟล์ที่ต้องแตะ**:
```bash
# clone Oracle Studio repo (ถ้ายังไม่มี)
git clone https://github.com/[org]/oracle-studio
cd oracle-studio
bun install
# สร้าง bridge config ไปยัง MCP ของ Jit
echo '{"oracleMCP":"http://localhost:3001"}' > .env.local
bun dev
```
- อ้างอิง: Step 10, `Oracle Studio (หน้าเว็บ)`
- ต้องสร้าง API endpoint ที่ Jit สามารถ push context ได้ (เช่น `/api/memory`, `/api/skills`)

### 🔥 #3: Soul Sync Automation (cron + event-driven)
**Impact: สูง | Effort: ปานกลาง**  
**ทำไม**: ปัจจุบันซิงค์ manual, 14 Oracles เริ่มมี skill/knowledge ต่างกัน  
**คำสั่ง/ไฟล์ที่ต้องแตะ**:
```bash
# เพิ่ม cron job ทุก 6 ชั่วโมง
crontab -e
0 */6 * * * cd /path/to/mae-oracle && claude -p "/soul-sync --all"

# หรือใช้ GitHub Actions
# .github/workflows/soul-sync.yml
```
- อ้างอิง: ขั้นสูง `Soul Sync & ครอบครัว Oracle`
- ไฟล์: `MAE/.claude/skills/soul-sync/SKILL.md` — เพิ่ม `--auto` flag

### 🔥 #4: Fast Mode Activation ใน Child Oracles ทุกตัว
**Impact: สูง | Effort: ต่ำ**  
**ทำไม**: ประหยัด request Claude วันละหลายร้อย, เร็วขึ้น 10x  
**คำสั่ง/ไฟล์ที่ต้องแตะ**:
```bash
# เพิ่มใน CLAUDE.md ข���ง child Oracle ทุกตัว
echo "## Fast Mode" >> CLAUDE.md
echo "- Default mode: FAST unless /full is specified" >> CLAUDE.md
echo "- Skip /learn on session start" >> CLAUDE.md
```
- อ้างอิง: ขั้นสูง `Fast Mode`
- ไฟล์: `./CLAUDE.md` (ทุก Oracle repo)

### 🔥 #5: MCP Servers ครบชุด (Context7 + Firecrawl + Telegram)
**Impact: ปานกลาง | Effort: ต่ำ**  
**ทำไม**: Jit ขาด access docs ล่าสุด, scrape web, ส่ง notification  
**คำสั่ง/ไฟล์ที่ต้องแตะ**:
```bash
claude mcp add context7 npx @anthropic-ai/mcp-context7
claude mcp add firecrawl npx firecrawl-mcp --env FIRECRAWL_API_KEY=xxx
claude mcp add telegram npx telegram-mcp-server --env TELEGRAM_BOT_TOKEN=xxx
```
- อ้างอิง: Step 5, `MCP Servers`
- ไฟล์: `~/.claude.json` หรือ `.claude.json` ใน repo

### 🔥 #6: Handoff Protocol บังคับใช้ทุก session (RRR + Forward)
**Impact: ปานกลาง | Effort: ต่ำ**  
**ทำไม**: ปัจจุบัน Jit ทำงานต่อเนื่อง แต่ไม่มี system handoff, session หาย  
**ไฟล์ที่ต้องแตะ**:
```bash
# เพิ่มใน CLAUDE.md (ท���ก Oracle)
echo "## Session Protocol" >> CLAUDE.md
echo "- Every session end: run /rrr (retrospective)" >> CLAUDE.md
echo "- Every session start: check latest /forward file" >> CLAUDE.md
echo "- Store handoff in .claude/MEMORY/handoff_*.md" >> CLAUDE.md

# สร้าง .claude/hooks/post-exit.sh (ถ้า Claude Code รองรับ)
```
- อ้างอิง: Skills `Retrospective`, `Forward` ใน Step 4

### 🔥 #7: Memory Classification ปรับโครงสร้าง
**Impact: ปานกลาง | Effort: ปานกลาง**  
**ทำไม**: ปัจจุบัน memory กระจายไม่เป็นระบบ, 14 Oracles ไม่มี schema เดียวกัน  
**คำสั่ง/ไฟล์ที่ต้องแตะ**:
```bash
# สร้าง .claude/MEMORY/schema.json
cat > .claude/MEMORY/schema.json << EOF
{
  "types": ["user", "feedback", "project", "reference"],
  "required_fields": ["type", "title", "date", "content"],
  "index_file": "MEMORY.md"
}
EOF

# ปรับ MEMORY.md ให้เป็น index จริง
```
- อ้างอิง: ขั้นสูง `ระบบ Memory` ตารางประเภท
- ต้อง update ทุก Oracle repo ผ่าน Soul Sync

### 🔥 #8: Philosophy Check Integration ทุก Workflow
**Impact: ปานกลาง | Effort: ต่ำ**  
**ทำไม**: ป้องกัน Oracle ตัดสินใจผิดพลาด, ย้ำ Nothing deleted  
**ไฟล์ที่ต้องแตะ**:
```bash
# เพิ่มใน CLAUDE.md (ทุก Oracle)
echo "## Auto-Check" >> CLAUDE.md
echo "- Before any destructive action: run /philosophy --check" >> CLAUDE.md
echo "- On /forward creation: attach philosophy compliance" >> CLAUDE.md
```
- อ้างอิง: ขั้นสูง `ระบบปรัชญา Oracle`, `Philosophy Check`

### 🔥 #9: GitHub Copilot CLI เป็น accelerator สำหรับมือใหม่
**Impact: กลาง | Effort: ต่ำ**  
**ทำไม**: ช่วยสร้าง skill, แก้ bug, ติดตั้ง dependencies เร็วขึ้น  
**คำสั่ง/ไฟล์ที่ต้องแตะ**:
```bash
# ติดตั้ง Copilot CLI
npm install -g @githubnext/github-copilot-cli
gh copilot config

# สร้าง alias ใน CLAUDE.md (ให้ Oracle ใช้ Copilot terminal)
```
- อ้างอิง: Step 4.5, `ติดตั้งด้วย GitHub Copilot`
- ไม่ต้องแตะไฟล์ project แค่ setup เครื่อง

### 🔥 #10: Bridge Oracle Studio ↔ Mission Control
**Impact: กลาง | Effort: สูง**  
**ทำไม**: ทำให้มี unified interface — กดเลขใน Studio แล้ว tmux เปลี่ยน session  
**ไฟล์ที่ต้องแตะ**:
```bash
# สร้าง MCP server ใหม่ (oracle-studio-bridge)
# .claude/skills/oracle-studio-bridge/SKILL.md
# หรือใช้ websocket ส่งคำสั่งไป tmux
mkdir -p .claude/skills/oracle-studio-bridge
cat > .claude/skills/oracle-studio-bridge/SKILL.md << EOF
---
name: oracle-studio-bridge
description: Connect Studio web UI to tmux Mission Control
---
## Action
- Listen POST /api/switch-session {session_number, oracle_name}
- Execute: tmux switch-client -t "SS{number}"
- Return status
EOF
```
- อ้างอิง: Step 9 และ Step 10 ร่วมกัน

---

## สรุป Impact vs Effort Matrix

| # | ข้อ | Impact | Effort | Priority |
|---|-----|--------|--------|----------|
| 1 | Mission Control | สูงมาก | ต่ำ | 1 |
| 2 | Oracle Studio | สูงมาก | ปานกลาง | 2 |
| 3 | Soul Sync Automation | สูง | ปานกลาง | 3 |
| 4 | Fast Mode | สูง | ต่ำ | 4 |
| 5 | MCP ครบชุด | ปานกลาง | ต่ำ | 5 |
| 6 | Handoff Protocol | ปานกลาง | ต่ำ | 6 |
| 7 | Memory Classification | ปานกลาง | ปานกลาง | 7 |
| 8 | Philosophy Check | ปานกลาง | ต่ำ | 8 |
| 9 | GitHub Copilot | กลาง | ต่ำ | 9 |
| 10 | Studio-MC Bridge | กลาง | สูง | 10 |

**ข้อแนะนำ**: เริ่ม #1-#5 ภายใน 1 สัปดาห์, #6-#9 ภายใน 2 สัปดาห์, #10 ทำเมื่อ stable

> **Lens Practitioner สรุป**: Jit ทำมาเยอะแล้ว แต่ขาดระบบระเบียบ (governance) และ automation การรวม Dashboard + Web UI + Auto Sync จะยกระดับจาก "14 Oracles แยกกัน" เป็น "Oracle Ecosystem จริง" ตามปรัชญา Soul Sync และ Mission Control ที่พี่นัทตั้งใจ
