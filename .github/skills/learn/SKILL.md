---
name: learn
description: "Explore a codebase with parallel agents — clone, read, and document. Use when user says 'learn [repo]', 'explore codebase', 'study this repo', or shares a GitHub URL to study."
argument-hint: "<repo-url-or-path> [--fast | --deep]"
---

# /learn — Jit Codebase Study

> เรียนรู้ repo ใหม่ก่อนทำงาน

## Usage

```
/learn innova-bot                    # Study innova-bot repo
/learn https://github.com/org/repo  # Clone and study remote repo
/learn . --fast                     # Quick scan current repo
```

---

## Jit Learn Steps

### Step 1: กำหนด Target

```
Local repos:
  innova-bot → C:\Users\admin\DEV\PugAss1stant\innova-bot
  Jit (self) → C:\Users\admin\Jit
  arra-oracle-skills-cli → C:\Users\admin\ghq\github.com\Soul-Brews-Studio\arra-oracle-skills-cli

Remote: use ghq
  ghq get https://github.com/org/repo
  → clones to C:\Users\admin\ghq\github.com\org\repo
```

### Step 2: อ่าน README + CLAUDE.md

ไฟล์ที่ต้องอ่านก่อนเสมอ:
1. `README.md`
2. `CLAUDE.md` (Claude Code instructions)
3. `package.json` หรือ `pyproject.toml` (deps)
4. `.github/copilot-instructions.md`

### Step 3: Map Structure

```powershell
# List top-level structure
Get-ChildItem "C:\Users\admin\DEV\PugAss1stant\innova-bot" -Depth 1 |
  Select-Object Name, Attributes | Format-Table
```

### Step 4: Find Key Files

ค้นหาไฟล์สำคัญ:
- `main.py`, `index.ts`, `server.ts` — entry points
- `*.agent.md`, `*.skill.md` — AI config
- `.env.example` — config keys
- `docs/` — documentation

### Step 5: บันทึกลง ψ/learn/

```powershell
$dir = "ψ\learn\[repo-name]"
New-Item -Path $dir -ItemType Directory -Force | Out-Null
# Write summary to $dir\summary.md
```

---

## innova-bot Quick Reference

innova-bot คือ ร่างกาย (Body) ของระบบ มนุษย์ Agent:
- **Entry**: `innova_bot/main.py` หรือ `innova.cmd`
- **MCP API**: port 7010
- **Oracle JAVIS**: runs inside innova-bot
- **Skills**: `innova-bot/.claude/skills/` (9 local skills)
- **CLAUDE.md**: `C:\Users\admin\DEV\PugAss1stant\innova-bot\CLAUDE.md`

---

## Full Skill Reference

ดู Global Skill: `C:\Users\admin\.claude\skills\learn\SKILL.md`
