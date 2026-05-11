# JIT Skills Guide — คู่มือ Skills ทั้งหมด

**Updated**: 2026-05-12  
**Status**: 19 skills active (11 new in this session)  
**Engines**: MDES Ollama (primary) · Claude CLI · OpenAI Codex

---

## 🗺️ Skills Map

```
                    jit (Orchestrator)
                         │
          ┌──────────────┼──────────────┐
          │              │              │
    📚 Knowledge    🔨 Build       🔍 Research
    ─────────────   ─────────────  ─────────────
    oracle-query    feature-dev    brainstorming
    sleep-research  skill-creator  brave-search
    ollama-chain    writing-plans  socialcrawl
                    executing-plans firecrawl
                    frontend-design ui-ux-pro-max
                    chrome-devtools
```

---

## 📋 Quick Reference

| Skill | trigger | engine | use case |
|-------|---------|--------|---------|
| `brainstorming` | brainstorm, ระดมสมอง | gemma4:26b | ไอเดียใหม่ก่อนวางแผน |
| `writing-plans` | วางแผน, plan | gemma4:26b | สร้าง .plan.md |
| `executing-plans` | ลงมือทำ, run plan | gemma4:26b | execute plan file |
| `feature-dev` | feature, สร้าง feature | 3-model chain | full cycle dev |
| `skill-creator` | create skill, new skill | qwen2.5-coder:32b | สร้าง skill ใหม่ |
| `sleep-research` | วิจัยข้ามคืน, queue | gemma4:26b chain | overnight research |
| `brave-search` | ค้นหา, search web | gemma4:26b | web search + analysis |
| `socialcrawl` | social, github, reddit | gemma4:26b | monitor trends |
| `firecrawl` | crawl, อ่านเว็บ | gemma4:26b | extract web content |
| `ui-ux-pro-max` | ui, ux review | gemma4:26b + Chrome | UI/UX audit |
| `frontend-design` | สร้าง UI, design | qwen2.5-coder:32b | HTML component |
| `chrome-devtools` | chrome, screenshot | Puppeteer | browser automation |
| `oracle-query` | oracle, ค้นหาความรู้ | Oracle REST | knowledge lookup |
| `ollama-multiagent-chain` | chain agents | all models | multi-step pipeline |
| `multiagent-autonomy` | autonomy, orchestrate | all agents | sub-agent patterns |
| `soma-brain` | soma, brain decision | qwen3.5:27b | strategic decisions |
| `innova-organs` | organs, organ routing | — | organ usage guide |
| `innova-multiagent-tmux` | tmux, multiagent | all models | tmux 9-pane layout |
| `agent-customization` | รายงานตัว, update | — | task completion |

---

## 🌙 sleep-research — Overnight Autonomous Research

```bash
# Queue ก่อนนอน
bash .github/skills/sleep-research/run.sh --queue "Next.js 15 migration guide"

# Research ทันที
bash .github/skills/sleep-research/run.sh --now "Thai NLP models 2026"

# ดู status เช้า
bash .github/skills/sleep-research/run.sh --status

# Install จาก GitHub
bash scripts/install-sleep-research.sh
```

**Source repo**: https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep  
**Results**: `memory/sleep-research/results/YYYY-MM-DD_topic.md`  
**Oracle**: `research:YYYY-MM-DD:slug`

---

## 🧠 brainstorming — Multi-Perspective Analysis

```bash
bash .github/skills/brainstorming/run.sh "หัวข้อ"
# Discord: !AnuT1n brainstorm [topic]
```

3 perspectives: Creative (gemma4:26b) · Critical (qwen3.5:27b) · Technical (qwen2.5-coder:32b)  
→ Synthesis → Oracle → nerve.sh broadcast

---

## 🚀 feature-dev — Full-Cycle Feature Development

```bash
bash .github/skills/feature-dev/run.sh "feature description"
# Discord: !AnuT1n feature [description]
```

7 phases: Define → Design → Code → Test → Review → Deploy → Notify  
Agents: jit → soma → lak → innova → chamu → neta → pada → vaja  
Engines: MDES Ollama (default) · Claude CLI (`--claude`) · Codex (`--codex`)

---

## 📝 writing-plans + executing-plans — Plan Pipeline

```bash
# สร้าง plan
bash .github/skills/writing-plans/run.sh "สิ่งที่ต้องทำ"
# ผลลัพธ์: .planning/YYYY-MM-DD_slug.plan.md

# ลงมือทำ
bash .github/skills/executing-plans/run.sh ".planning/2026-05-12_my-task.plan.md"
# หรือ: bash .github/skills/executing-plans/run.sh "keyword"
```

---

## 🔍 brave-search + socialcrawl + firecrawl — Research Pipeline

```bash
# ค้นหาเว็บ
bash .github/skills/brave-search/run.sh "Next.js server components"

# Monitor social
bash .github/skills/socialcrawl/run.sh "github discord.js v14"
bash .github/skills/socialcrawl/run.sh "reddit puppeteer"
bash .github/skills/socialcrawl/run.sh "hn multiagent AI"

# อ่านหน้าเว็บ
bash .github/skills/firecrawl/run.sh "https://docs.discord.js.org" "สรุป slash commands"
```

---

## 🎨 ui-ux-pro-max + frontend-design — UI Pipeline

```bash
# Audit UI
bash .github/skills/ui-ux-pro-max/run.sh "https://mdes-innova.online" "accessibility"

# สร้าง component
bash .github/skills/frontend-design/run.sh "agent status dashboard Thai dark theme"
# ผลลัพธ์: src/ui/agent-status-dashboard-thai-dark-t.html
```

---

## 🛠️ skill-creator — Create New Skills

```bash
bash .github/skills/skill-creator/run.sh "weather-check — เช็คสภาพอากาศแล้วแจ้งผ่าน Discord"
# ผลลัพธ์: .github/skills/weather-check/SKILL.md
```

---

## 🔌 Multi-Engine Integration

ทุก skill รองรับ 3 engines ตามลำดับ priority:

```bash
# 1. MDES Ollama (default, always works)
OLLAMA_TOKEN=your-token bash .github/skills/brainstorming/run.sh "topic"

# 2. Claude CLI (ถ้า install แล้ว)
claude --print "$(cat .github/skills/brainstorming/SKILL.md)" "$ARGUMENTS"

# 3. OpenAI Codex (ถ้ามี key)
OPENAI_API_KEY=sk-... bash .github/skills/feature-dev/run.sh "feature"
```

### Environment Variables

```bash
# Required (MDES)
export OLLAMA_TOKEN="your-mdes-token"

# Optional (Brave Search)
export BRAVE_API_KEY="your-brave-key"

# Optional (Firecrawl)
export FIRECRAWL_API_KEY="your-firecrawl-key"

# Optional (GitHub higher rate limits)
export GITHUB_TOKEN="your-github-token"

# Optional (Codex/OpenAI)
export OPENAI_API_KEY="sk-..."
```

---

## 📡 Discord Bot Commands (Hermes !AnuT1n)

```
!AnuT1n brainstorm [topic]      — ระดมสมอง
!AnuT1n plan [task]             — สร้าง plan
!AnuT1n run-plan [filename]     — execute plan
!AnuT1n ui-ux [url]            — audit UI
!AnuT1n frontend [brief]        — สร้าง component
!AnuT1n search [query]          — ค้นหาเว็บ
!AnuT1n social [platform query] — social media
!AnuT1n crawl [url]            — อ่านหน้าเว็บ
!AnuT1n feature [description]   — สร้าง feature
!AnuT1n skill [name] [desc]     — สร้าง skill ใหม่
!AnuT1n sleep-research [topic]  — queue overnight research
!AnuT1n chrome open/screenshot/inspect/css/ui/js [url]
```

---

## 🌐 MDES Ollama Models Reference

| Model | Best for | Speed |
|-------|---------|-------|
| `gemma4:26b` | Thai, general, creative | Medium |
| `gemma4:e4b` | Fast responses | Fast |
| `qwen3.5:27b` | Deep analysis, review | Medium |
| `qwen2.5-coder:32b` | Code generation | Slow |
| `qwen3-vl:32b` | Vision + UI analysis | Slow |
| `qwen3.5:9b` | Quick reasoning | Fast |

**Endpoint**: `https://ollama.mdes-innova.online/api/generate`  
**Auth**: `Authorization: Bearer $OLLAMA_TOKEN`

---

## 📚 Oracle Knowledge Keys Convention

| Prefix | Example | ใช้เมื่อ |
|--------|---------|---------|
| `brainstorm:` | `brainstorm:karn-voice` | ผล brainstorming |
| `plan:` | `plan:deploy-voice-api` | plan files |
| `execution:` | `execution:deploy-voice-api` | execution results |
| `feature:` | `feature:remind-command` | feature development |
| `research:` | `research:2026-05-12:nextjs` | overnight research |
| `skill:` | `skill:weather-check` | new skills |
| `search:` | `search:discord-js-v14` | web search results |
| `social:` | `social:github:puppeteer` | social crawl |
| `crawl:` | `crawl:docs-discord-js-org` | firecrawl results |
| `ui-analysis:` | `ui-analysis:mdes-innova-online` | UI/UX audits |
| `frontend:` | `frontend:agent-dashboard` | frontend components |

---

## 🔗 Related Docs

- [docs/agent-autonomy.md](agent-autonomy.md) — Autonomous selfhood patterns
- [docs/multiagent-spec.md](multiagent-spec.md) — Full system specification
- [network/protocol.md](../network/protocol.md) — Message bus protocol
- [core/body-map.md](../core/body-map.md) — Organ ownership RACI
- [CLAUDE.md](../CLAUDE.md) — Claude Code integration guide
