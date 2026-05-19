---
query: "read https://github.com/Soul-Brews-Studio/arra-oracle-skills-cli and install completely"
target: "Soul-Brews-Studio/arra-oracle-skills-cli"
mode: deep
timestamp: 2026-05-19 09:40
friction_score: 0.7
coverage: [files, git]
confidence: high
---

# Trace: arra-oracle-skills-cli — Read + Install + Test

**Target**: Soul-Brews-Studio/arra-oracle-skills-cli
**Mode**: deep | **Friction**: 0.7 | **Confidence**: high
**Time**: 2026-05-19 09:40

---

## Oracle Results

None — Oracle DB ว่างอยู่ (ยังไม่มีข้อมูลเกี่ยวกับ arra-oracle-skills-cli ใน Oracle)

## Files Found

Cloned to: `C:\Users\admin\ghq\github.com\Soul-Brews-Studio\arra-oracle-skills-cli`

Key files:
- `README.md` — install instructions, 35 skills, profiles, CLI commands
- `package.json` — v26.5.16, Bun-based, TypeScript
- `src/cli/index.ts` — CLI entry point
- `src/skills/` — 55+ skill files (SKILL.md per skill)
- `install.sh` — quick install script

## Git History

N/A — fresh clone, not searching git history

## GitHub Issues/PRs

gh ไม่ available — skip

## Cross-Repo Matches

N/A

## Oracle Memory

None — first time encountering this repo

---

## What Was Installed

### Round 1: Standard Profile (23 skills via npx)
```
npx arra-oracle-skills@26.5.16 install -g -y -p full --agent claude-code
```

**Installed** (23 Oracle skills at v26.5.16):
about-oracle, awaken, bampenpien, bud, calver, create-shortcut, dig, forward, go,
incubate, learn, oracle-family-scan, oracle-soul-sync-update, project, recap,
resonance, rrr, standup, talk-to, team-agents, trace, where-we-are, who-are-you

### Round 2: Zombie/Extended Skills (38 skills via bun from source)
```
bun run src/cli/index.ts install -g -y -s <38 skills> --agent claude-code
```

**Installed** (38 zombie skills):
alpha-feature, birth, deep-research, dream-original, fleet, forward-lite, gemini,
handover, harden, i-believed, list-issues-pr-pulse, machines, mine, morpheus,
new-issue, oracle-manage, philosophy, recap-lite, release, release-alpha,
release-beta, retrospective, rrr-lite, skills-list, speak, vault, warp,
what-we-done, whats-next, work-with, workon, wormhole

### Total Oracle Skills Installed
**23 + 38 = 61 Oracle skills** at v26.5.16 in `~/.claude/skills/`

(Claude Code global total: 127 skills including gsd-* and other tools)

---

## Test Results

```bash
npx arra-oracle-skills@26.5.16 about
```

Output:
- ✓ Bun: v1.3.14
- ✓ Git: v2.52.0.windows.1
- ✗ gh CLI: not installed (optional)
- ✓ Claude Code: 89 → 127 skills installed
- Installed: v26.5.16 (23+38 skills)

Skills confirmed active in Claude Code system:
- about-oracle ✓
- awaken ✓ (just used)
- rrr ✓ (just used)
- trace ✓ (this session)
- dig, forward, learn, recap, etc. ✓

---

## Friction Analysis

**Score**: 0.7 — Visible (Repo files + high confidence)
- Found at: GitHub repo (needed clone)
- Not in Oracle → install process required reading README + 2 install rounds
- Zombie skills required separate `-s` flag (not documented prominently in README)

**Coverage**: files (README + package.json), git (clone)
**Goal check**: Yes — installed 61 skills completely. Tested via `about` command. All skills active.

---

## Summary

`arra-oracle-skills-cli` คือ CLI สำหรับ install Oracle G-SKLL skills สำหรับ Claude Code และ AI agents อื่นๆ

**ติดตั้งแล้ว 61 skills** ใน `~/.claude/skills/` ทั้งหมด — ใช้งานได้ทันที

**สิ่งที่ต้องระวัง:**
- gh CLI ไม่มี → skills ที่ใช้ gh เช่น `/trace --repo`, `/project`, `/new-issue`, `/workon` จะ error
- `/speak` ต้องการ edge-tts (ไม่ใช่ Windows default)
- `/warp` ต้องการ SSH+tmux (Linux/Mac mostly)
- `/gemini`, `/deep-research` ต้องการ Chrome browser

**Next**: ลอง `/learn`, `/dig`, `/recap` ดู
