# Changelog: PC3-Jit Agent Bootstrap

Date: 2026-05-05
Node: PC3-Jit (codespaces-a07d24)
Author: systems-engineer (bootstrap session)

## Summary

Full PC3 bootstrap of the Jit/innova agent node from the tinner-deinno/Jit repo.

## Changes

### New Files

- `.GCC/main.md` — GCC checkpoint index
- `.GCC/branches/main/log.md` — timestamped bootstrap log
- `.GCC/branches/main/commit.md` — last-known-good commit record
- `.GCC/branches/main/metadata.json` — node metadata (PC3-Jit)
- `memory/knowledge/` — long-term knowledge directory (created, empty)
- `memory/state/innova.state.json` — PC3 node state (recreated after git pull removed tracking)
- `scripts/pc3_start_all.sh` — one-click PC3 startup script
- `docs/PC3_AGENT_RUNBOOK.md` — PC3 operational runbook
- `docs/MCP_PYVENV_TROUBLESHOOTING.md` — pyvenv.cfg repair guide
- `changelog/2026-05-05-pc3-agent-bootstrap.md` — this file

### Modified Files

- `.env` — added PC3-specific vars: MCP_TRANSPORT, MCP_HOST, MCP_PORT, INNOVA_NODE_ID, OLLAMA_HOST, ORACLE_HEALTH_URL
- `.jit-remotes.json` — added `nodes` section with PC3-Jit entry (version 1.0 → 1.1)

### Preserved Local Changes (stash → pop)

- `scripts/init-life.sh` — added presence reporting to cron step
- `.devcontainer/devcontainer.json` — added hermes-discord start to postStartCommand

## Actions Taken

1. Discovery: inspected repo root, scripts, docs, .github, memory, config
2. git stash → git pull --ff-only (630 commits) → git stash pop (clean merge)
3. Created .GCC directory structure
4. Created memory/knowledge/ directory
5. Updated .env with PC3 node variables
6. Updated .jit-remotes.json with PC3 node entry
7. Updated .github/instructions/jit-context.instructions.md — PC3 node identity (via runbook)
8. Created scripts/pc3_start_all.sh — one-click launcher
9. Created docs/MCP_PYVENV_TROUBLESHOOTING.md — pyvenv fix guide
10. Created docs/PC3_AGENT_RUNBOOK.md — operational runbook
11. Ran init-life.sh → Oracle online, heartbeat daemon started (PID 68711)
12. Ran pytest — 4 pre-existing failures (heartbeat test format mismatch), 1 pass, karn-voice import error

## Verification Results

| Check | Result | Evidence |
|---|---|---|
| Python 3.12.1 | PASS | `/home/codespace/.python/current/bin/python3` |
| Oracle online | PASS | `curl http://localhost:47778/api/health` → ok |
| MDES Ollama | PASS | `init-life.sh --status` → พร้อม |
| Heartbeat daemon | PASS | PID 68711 running |
| Cron | N/A | crontab not available in this container |
| Git sync | PASS | 0 commits behind origin/main |
| innova-bot MCP | BLOCKED | repo not configured (needs INNOVA_BOT_REPO in .env) |
| Port 7010 | BLOCKED | innova-bot not running |

## Pre-existing Test Failures (not introduced by bootstrap)

- `test_commit_when_code_changed` — expects old heartbeat commit format
- `test_skip_commit_on_state_only` — expects old "skipped (state-only)" message
- `test_status_shows_stopped_when_no_daemon` — daemon was running when test assumed stopped
- `test_heart_pulse_triggers_lung_filter` — heart.sh beat OUT now returns JSON, not `->💓`
- `test_karn_voice.py` — import fails: `karn_voice_api` not on PYTHONPATH

## Remaining Blockers

1. **innova-bot MCP**: Set `INNOVA_BOT_REPO=<url>` in `.env`, then run `bash scripts/innova-bot-setup.sh`
2. **Port 7010**: Requires innova-bot to be running
3. **TUI**: Requires innova-bot module (`python -m innova_bot.gui.rpg_tui`)
4. **Cron**: Not available in this container; heartbeat daemon covers this role

## Next Safe Action

1. `git add .` and `git commit -m "feat(pc3): bootstrap Jit agent node"` 
2. `git push origin main`
3. Set `INNOVA_BOT_REPO` in `.env` to activate MCP/Antigravity
