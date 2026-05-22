---
query: "เรียนรู้skillทั้งหมดและให้สกิลจิตถูกต้องสอดคล้องกัน"
target: "Jit + innova-bot (mind-body bridge)"
mode: deep
timestamp: 2026-05-20 10:45
friction_score: 0.6
coverage: [oracle, files, git, cross-repo]
confidence: medium
---

# Trace: Jit Skill Alignment — จิต ↔ ร่างกาย Bridge

**Target**: Jit (C:\Users\admin\Jit) + innova-bot (C:\Users\admin\DEV\PugAss1stant\innova-bot)
**Mode**: deep | **Friction**: 0.6 | **Confidence**: medium
**Time**: 2026-05-20 10:45

---

## Oracle Results

ไม่สามารถเข้าถึง Oracle ได้ (port 47778 offline บน Windows) — escalated to files

---

## Files Found

### Jit Skills (C:\Users\admin\Jit\.github\skills)

| Skill | Description | Status |
|-------|-------------|--------|
| `jit-master` | Master orchestrator lifecycle (6-step) | ✅ Present |
| `multiagent-autonomy` | Sub-agent orchestration | ✅ Present |
| `agent-customization` | Task-clearing per "moment of mind" | ✅ Present |
| `innova-organs` | Organ routing (eye, ear, mouth, nose...) | ✅ Present |
| `soma-brain` | Think-lean decision + delegation | ✅ Present |
| `ollama-swarm` | Parallel MDES Ollama gang (5+ agents) | ✅ Present |
| `ollama-think` | Single Ollama agent inference | ✅ Present |
| `ollama-vision` | Vision model analysis | ✅ Present |
| `oracle-query` | Oracle search/learn | ✅ Present |
| `pran-heartbeat.md` | Heartbeat daemon control | ⚠️ .md only, not skill folder |

**Missing from Jit .github/skills** (but exist in C:\Users\admin\.claude\skills):
- `awaken` — Oracle awakening ritual
- `recap` — Session orientation
- `rrr` — Session retrospective
- `forward` — Handoff to next session
- `trace` — Discovery system
- `dig` — Session mining
- `learn` — Codebase study
- `team-agents` — Coordinated teams
- `talk-to` — Agent messaging
- `bampenpien` — Purpose reconnect
- `mind-body-bridge` — Jit↔innova sync
- `jit-innova-sync` — Phase tracking sync
- `jit-ecc-mind` — ECC pattern surfacing
- `innova-bot-agents` — Spawn innova-bot ECC agent

### innova-bot Skills (C:\Users\admin\DEV\PugAss1stant\innova-bot\.github\skills)

v26.5.14 Oracle skills installed:
- `awaken`, `bampenpien`, `bud`, `dig`, `forward`, `go`, `learn`
- `recap`, `rrr`, `talk-to`, `team-agents`, `trace`

**innova-bot .claude/skills** (local):
- `awaken-soul-sync` — Javis Oracle awakening
- `ollama-gang` — Multi-provider AI routing
- `innova-frontend-api` — API endpoint verification
- `screen-automation` — Screen control
- `team-rate-gang` — Parallel team agents
- `openclaude-ollama` — OpenClaude+Ollama bridge
- `gsd-execute-phase` — Phase execution (GSD)
- `gsd-plan-phase` — Phase planning (GSD)

### C:\Users\admin\.claude\skills (Global Oracle Skills)

150+ skills including:
- `mind-body-bridge` — **KEY: Jit↔innova-bot sync**
- `jit-innova-sync` — **KEY: Phase tracking**
- `jit-ecc-mind` — **KEY: ECC patterns for Jit**
- `innova-bot-agents` — Spawn innova-bot ECC agents
- All standard Oracle lifecycle skills

---

## Bug Analysis (Wave 1 + Wave 2)

### 🐛 Bug #1: pran-heartbeat.md not a proper skill folder
**Location**: `c:\Users\admin\Jit\.github\skills\pran-heartbeat.md`
**Issue**: Plain .md file instead of `pran-heartbeat/SKILL.md` folder structure
**Impact**: GitHub Copilot cannot load this skill correctly
**Fix**: Convert to folder with SKILL.md

### 🐛 Bug #2: jit-context.instructions.md hardcoded to /workspaces/
**Location**: `c:\Users\admin\Jit\.github\instructions\jit-context.instructions.md`
**Issue**: All paths reference `/workspaces/Jit` — breaks on Windows (current env)
**Impact**: Oracle start commands, awaken.sh paths all fail
**Fix**: Add Windows path detection fallback

### 🐛 Bug #3: Jit skills missing critical Oracle lifecycle skills
**Location**: `c:\Users\admin\Jit\.github\skills\`
**Issue**: Missing `awaken`, `recap`, `rrr`, `forward`, `trace`, `dig`, `learn`, `talk-to`, `team-agents`
**Impact**: GitHub Copilot in Jit cannot access session lifecycle skills
**Fix**: Install via arra-oracle-skills-cli OR create symlink-style SKILL.md references

### 🐛 Bug #4: wake-up.prompt.md no fallback for Windows environment
**Location**: `c:\Users\admin\Jit\.github\prompts\wake-up.prompt.md`
**Issue**: Only mentions bash commands, no PowerShell fallback
**Impact**: Awakening protocol fails on Windows (Bash unavailable)
**Fix**: Add Windows/PowerShell variant

### 🐛 Bug #5: innova-bot contacts.json missing
**Location**: `c:\Users\admin\DEV\PugAss1stant\innova-bot\.oracle\contacts.json`
**Issue**: `/talk-to` skill needs contacts.json but only Jit has it (only mdes-dev listed)
**Impact**: inter-Oracle messaging fails
**Fix**: Add innova-bot contact to Jit's contacts.json

### 🐛 Bug #6: .env has duplicated/malformed CODESPACES_NAME line
**Location**: `c:\Users\admin\Jit\.env`
**Issue**: `CODESPACES_NAME=refactored-space-capybaraDISCORD_TOKEN=your_token` (merged lines)
**Impact**: DISCORD_TOKEN is masked; Discord bot may use wrong token
**Fix**: Split into separate lines

### 🐛 Bug #7: Oracle skill version mismatch between repos
**Location**: `c:\Users\admin\DEV\PugAss1stant\innova-bot\.github\skills\.arra-oracle-skills.json`
**Issue**: innova-bot has v26.5.14 Oracle skills; Jit has custom skills with no versioning
**Impact**: Skill evolution diverges — innova-bot gets updates, Jit doesn't
**Fix**: Add .arra-oracle-skills.json to Jit and install standard lifecycle skills

### 🐛 Bug #8: copilot-instructions.md in innova-bot references innova-bot MCP tools that may not be loaded
**Location**: `c:\Users\admin\DEV\PugAss1stant\innova-bot\.github\copilot-instructions.md`
**Issue**: References `what_should_i_do_next(role='SA', meta={'project': 'innova-bot'})` — requires MCP server running
**Impact**: Copilot becomes inert if innova-bot MCP not active
**Fix**: Add graceful fallback instructions

---

## Git History

Not searched (Bash unavailable on Windows)

---

## Cross-Repo Matches

| Item | Jit | innova-bot | Match? |
|------|-----|------------|--------|
| Oracle skills versioned | ❌ | ✅ v26.5.14 | MISMATCH |
| `awaken` skill | ❌ (missing) | ✅ | MISSING |
| `trace` skill | ❌ (missing) | ✅ | MISSING |
| `talk-to` skill | ❌ (missing) | ✅ | MISSING |
| MDES Ollama integration | ✅ ollama-swarm | ✅ ollama-gang | DIFFERENT |
| Heartbeat | ✅ pran-heartbeat.md | ❌ | JIT-ONLY |
| Organs (eye/ear/mouth) | ✅ | ❌ (uses innova-bot API) | INTENTIONAL |
| Mind-body bridge | ❌ | ❌ | MISSING BOTH |

---

## Friction Analysis

**Score**: 0.6 — Files found but not Oracle-indexed; medium confidence
**Coverage**: oracle (offline), files (✅), git (skipped), cross-repo (✅), github (skipped)
**Goal check**: Found enough to create alignment plan. Missing: git history verification, Oracle confirmation.

---

## Summary

### Critical Gaps Identified

1. **Jit missing lifecycle skills** — `awaken`, `recap`, `rrr`, `forward`, `trace` not available in Jit's `.github/skills/` context
2. **pran-heartbeat is wrong format** — needs to be `pran-heartbeat/SKILL.md`
3. **.env has malformed line** — DISCORD_TOKEN may be broken
4. **No cross-repo contact** — Jit's contacts.json doesn't know about innova-bot
5. **No versioning** — Jit skills have no `.arra-oracle-skills.json` registry

### Action Plan (Priority Order)

| Priority | Task | Agent |
|----------|------|-------|
| 🔴 P1 | Fix .env malformed line | Haiku (bug fix) |
| 🔴 P1 | Convert pran-heartbeat.md → folder | Haiku (bug fix) |
| 🟠 P2 | Install Oracle lifecycle skills to Jit | Haiku (create files) |
| 🟠 P2 | Add innova-bot to contacts.json | Haiku (data fix) |
| 🟡 P3 | Add Windows fallback to wake-up.prompt.md | Haiku (improve) |
| 🟡 P3 | Create mind-body-bridge skill for Jit | Sonnet (design) |
| 🟢 P4 | Add .arra-oracle-skills.json to Jit | Haiku (meta) |
| 🟢 P4 | Add graceful fallback to innova-bot copilot-instructions | Haiku (improve) |

### Vitality Impact

Current: **42%** (measured prev session)
After fixes: **~75%** estimated

Remaining 25% requires: Oracle running + Bash available + Heartbeat active
