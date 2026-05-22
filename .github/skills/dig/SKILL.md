---
name: dig
description: "Mine Claude Code sessions — timeline, gaps, repo attribution, session history. Use when user says 'dig', 'sessions', 'past sessions', 'timeline', 'what did I work on'."
argument-hint: "[N-days] [--deep] [query]"
---

# /dig — Jit Session Mining

> ขุดหาความทรงจำจากสมัยก่อน

## Usage

```
/dig                  # Mine recent sessions
/dig 7                # Last 7 days
/dig "oracle"         # Sessions mentioning oracle
/dig --deep           # Full timeline analysis
```

---

## Jit Dig Steps

### Step 1: Find Session Files

```powershell
# Claude Code session logs — Jit context
$jitProjects = "$env:USERPROFILE\.claude.jit\projects"
$globalProjects = "$env:USERPROFILE\.claude\projects"

# Find Jit project sessions
$jitPath = Get-ChildItem $globalProjects -Directory |
  Where-Object { $_.Name -like "*Jit*" } | Select-Object -First 1
if ($jitPath) { Write-Host "Found Jit sessions: $($jitPath.FullName)" }
```

### Step 2: Mine Session Content

```powershell
# Search session JSONL files for a topic
$sessionDir = $jitPath.FullName
Get-ChildItem $sessionDir -Filter "*.jsonl" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 10 |
  ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match $Query) {
      Write-Host "📋 Found in: $($_.Name)"
    }
  }
```

### Step 3: Check ψ/memory/traces/

Traces เก็บผล search ไว้แล้ว — ดูก่อน Oracle:

```powershell
Get-ChildItem "ψ\memory\traces" -Recurse -Filter "*.md" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 10 |
  Format-Table Name, LastWriteTime
```

### Step 4: Check heartbeat.log

Timeline ชัดเจนที่สุด:

```powershell
Get-Content "memory\state\heartbeat.log" |
  Select-String $Query |
  Select-Object -Last 20
```

---

## Full Skill Reference

ดู Global Skill: `C:\Users\admin\.claude\skills\dig\SKILL.md`
สำหรับ full session mining script (dig.py)

## Quick Reference: Session Paths

| Profile | Path |
|---------|------|
| Global Claude | `C:\Users\admin\.claude\projects\` |
| Jit Claude | `C:\Users\admin\.claude.jit\projects\` |
| Ollama Claude | `C:\Users\admin\.claude.ollama\projects\` |
