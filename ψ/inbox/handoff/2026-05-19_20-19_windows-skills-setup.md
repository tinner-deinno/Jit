# Handoff: Windows Skills Setup — Jit Oracle

📡 Session: b577b41f | Jit | ~4h

**Date**: 2026-05-19
**Context**: ~70%

## What We Did

- `/awaken --reawaken` — Jit Oracle re-synced (Codespaces→Windows migration)
- `/rrr` — first retrospective + session-metrics.md created
- arra-oracle-skills-cli v26.5.16 — 61 skills installed globally (Bun)
- `/speak` — edge-tts v7.2.8, `python -m edge_tts` working ✅
- gh CLI v2.92.0 — PATH fixed → `/trace` `/project` `/workon` ✅
- `/warp` — WSL Ubuntu (tmux 3.4 + SSH) confirmed ready ✅
- **Antigravity Chrome CDP** — patched `main.js` to add `--remote-allow-origins=*` → status ✅
- `/ollama` skill — NEW, connects `https://ollama.mdes-innova.online`, 17 models, default `gemma4:26b` ✅
- `/warp` contacts — SSH config + `ψ/contacts.json` created for `mdes-dev` (10.181.235.38, user: MDES-DEV-NB)

## Context (Oracle)
**Oracle**: Jit Oracle | **Human**: innova (tinner-deinno)
**Mode**: Full Soul Sync | **Memory**: auto

## Pending

- [ ] `/gemini` chat — JS selector ไม่ตรง Gemini 2025 UI (ต้องอัปเดต selector ใน gemini_cdp.py)
- [ ] `/deep-research` — ขึ้นอยู่กับ /gemini chat fix เดียวกัน
- [ ] `/warp mdes-dev` — SSH timeout (10.181.235.38) — เครื่องอาจปิดหรือต้องการ SSH key setup
- [ ] Antigravity update จะ overwrite `main.js` patch — backup อยู่ที่ `main.js.bak`

## Key Files

- `C:\Users\admin\AppData\Local\Programs\Antigravity\resources\app\out\main.js` — patched (backup: .bak)
- `C:\Users\admin\.claude\skills\gemini\scripts\gemini_cdp.py` — CDP bridge
- `C:\Users\admin\.claude\skills\ollama\scripts\ollama_query.py` — NEW Ollama client
- `C:\Users\admin\.claude\skills\ollama\SKILL.md` — NEW skill def
- `C:\Users\admin\Jit\.env` — OLLAMA_TOKEN here
- `C:\Users\admin\Jit\ψ\contacts.json` — mdes-dev node config

## Next Session

- [ ] Fix `/gemini` chat: inspect Gemini DOM for correct input selector (DevTools → right-click input → Inspect)
- [ ] Test `/warp mdes-dev` when machine is online; if SSH key needed: `ssh-keygen` in WSL + `ssh-copy-id`
- [ ] Run `/rrr` to close this session properly
