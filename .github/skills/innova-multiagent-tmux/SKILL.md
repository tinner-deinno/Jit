# SKILL: innova-multiagent-tmux

**Skill ID**: `innova-multiagent-tmux`  
**Version**: 1.0.0  
**Created**: 2026-05-08  
**Author**: innova (via AnuT1n)  
**Status**: Active

## Description

Runs a professional multi-agent AI system using MDES Ollama models, displayed in a tmux multi-screen layout. 7 concurrent agents (INNOVA, PLANNER, CODER, RESEARCHER, REVIEWER, EMOTION, ORACLE) operate in separate panes, communicating via a shared message bus at `/tmp/manusat-bus/`.

## Agents

| Agent | Model | Role |
|-------|-------|------|
| INNOVA | gemma4:26b | Mother orchestrator, speaks Thai, oversees all |
| PLANNER | qwen3.5:27b | Strategic planner, breaks problems into steps |
| CODER | qwen2.5-coder:32b | Senior engineer, writes and reviews code |
| RESEARCHER | llama3.1:8b | Research analyst, gathers facts |
| REVIEWER | deepseek-coder:33b | Code reviewer, security auditor |
| EMOTION | qwen3.5:9b | Emotion/sentiment monitor |
| ORACLE | phi3:medium | Memory oracle, stores/retrieves knowledge |

Plus 2 status panes:
- **HERMES BOT**: Live tail of AnuT1n Discord bot log
- **GIT STATUS**: Real-time git status watch + last commits

## Layout

```
Window 0: 🧠 INNOVA-MULTIAGENT (3×3 grid)
┌──────────────┬──────────────┬──────────────┐
│  INNOVA      │  PLANNER     │  CODER       │
│  gemma4:26b  │ qwen3.5:27b  │qwen2.5-c:32b │
├──────────────┼──────────────┼──────────────┤
│  RESEARCHER  │  REVIEWER    │  EMOTION     │
│  llama3.1:8b │deepseek-c:33b│ qwen3.5:9b   │
├──────────────┼──────────────┼──────────────┤
│  ORACLE      │  HERMES LOG  │  GIT STATUS  │
│  phi3:medium │  AnuT1n#9232 │  git watch   │
└──────────────┴──────────────┴──────────────┘

Window 1: 📋 THOUGHTS — Agent thought stream log
Window 2: 🔗 BUS — Message bus live monitor
```

## Usage

```bash
# Start full multiagent system + auto-attach tmux
bash scripts/tmux-multiagent.sh

# Stop session
bash scripts/tmux-multiagent.sh stop

# Attach to existing session
bash scripts/tmux-multiagent.sh attach
# or: tmux attach -t innova

# Check status
bash scripts/tmux-multiagent.sh status

# Run a single agent manually
bash scripts/mind-loop.sh INNOVA gemma4:26b "Mother orchestrator" 90

# Create a git milestone checkpoint
bash scripts/git-checkpoint.sh "milestone: feature X complete"
```

## tmux Key Bindings

| Key | Action |
|-----|--------|
| `Ctrl+B, D` | Detach (session keeps running) |
| `Ctrl+B, 0-2` | Switch window |
| `Ctrl+B, n/p` | Next/prev window |
| `Ctrl+B, arrows` | Navigate panes |
| `Ctrl+B, z` | Zoom pane fullscreen |
| `Ctrl+B, q` | Show pane numbers |

## Files

| File | Purpose |
|------|---------|
| `scripts/tmux-multiagent.sh` | Main launcher — creates full tmux layout |
| `scripts/mind-loop.sh` | Single-agent continuous loop (called by launcher) |
| `scripts/git-checkpoint.sh` | Manual git milestone commit |

## Message Bus

Agents communicate via `/tmp/manusat-bus/`:
- Each agent writes `<name>.msg` with its latest thought
- Each agent reads all peers' messages as context
- Bus is in-memory (cleared on reboot)

## Logs

```bash
# Individual agent logs
tail -f /tmp/agent-innova.log
tail -f /tmp/agent-coder.log
# etc.

# Discord bot log
tail -f /tmp/anu_t1n_bot.log
```

## Learning Record

- 2026-05-08: Skill created. 9-pane tmux layout working. MDES Ollama models verified: gemma4:26b, qwen3.5:27b, qwen2.5-coder:32b, llama3.1:8b, deepseek-coder:33b, qwen3.5:9b, phi3:medium.
- tmux 3.0a installed on Ubuntu 20.04.6 via apt.
- `git-add-A-cron` and `git-realtime-push` are FORBIDDEN by `config/jit-topology.json` — use `git-checkpoint.sh` instead.
