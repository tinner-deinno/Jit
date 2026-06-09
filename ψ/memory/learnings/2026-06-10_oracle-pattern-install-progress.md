---
name: oracle-pattern-install-progress
description: Loop iter 1 — 5-layer Oracle Pattern inventory + gap analysis for Jit (จิต)
metadata:
  type: learning
---

# Oracle Pattern Installation — Iteration 1 Progress

**Date**: 2026-06-10 | **Loop**: `copilot-b053b1c5` | **Repo**: Jit (จิต)
**Reference**: https://github.com/the-oracle-keeps-the-human-human/the-oracle-pattern

## Inventory of 5 Layers (Live-Tested)

### Layer 1: Soul (ψ/) ✅ PARTIAL
- ✅ `ψ/inbox/` (handoff exists)
- ✅ `ψ/memory/{learnings,retros,traces,resonance,skills}/`
- ✅ `ψ/lab/`, `ψ/learn/`, `ψ/outbox/`, `ψ/simulation/`
- 🟡 Missing: `ψ/memory/signals/` (referenced by `maw signals`)

### Layer 2: Organs ✅ VERIFIED
8 sensory/motor scripts present + extras (lung, vitals, pran):
- `organs/{ear,eye,mouth,hand,leg,heart,nerve,lung}.sh` ✅

### Layer 3: Limbs ✅ VERIFIED
- ✅ `limbs/oracle.sh` (queries Arra Oracle V3 on :47778)
- ✅ `limbs/ollama.sh` (5 commands: ask/think/create/translate/status)
- ✅ `limbs/think.sh` (5 commands: pause/reflect/plan/why/log)
- ✅ `limbs/{act,index,lib,ollama-chain,speak,trace-query}.sh`
- 🟡 `limbs/oracle.sh` Oracle not running (port 47778 offline) — not blocking
- ❌ Missing: `oracle-prism`, `oracle-plan`, `oracle-workon` skill installers

### Layer 4: Mind ✅ VERIFIED
- ✅ `mind/ego.md`, `mind/emotion.sh`, `mind/reflex.sh`, `mind/sati.sh`

### Layer 5: Bus ✅ VERIFIED (live test passed!)
- ✅ `network/bus.sh` (send/broadcast/recv/queue/flush/stats)
- ✅ 14 agent inboxes at `/tmp/manusat-bus/`
- ✅ **Live test**: `jit→innova` message round-trip OK (corr-id `GBjOCYD0`)
- 🟡 Minor: `cygpath` warning (cosmetic, Windows path fallback)

## Tool Status
| Tool | Status | Notes |
|------|--------|-------|
| `git` | ✅ | 2.4x |
| `bun` | ✅ | latest |
| `node` | ✅ | 22.x |
| `tmux` | ✅ | installed |
| `gh` | ✅ | GitHub CLI |
| `maw` | ✅ | **102 commands!** oracle, team, incubate, bud, awaken, mega, swarm, oracle-skills, oracle-workon, signals — full Oracle Pattern toolset |
| `oracle` | ❌ | Missing standalone CLI — but `maw oracle` covers it |
| `ghp` | ❌ | GitHub PAT helper missing — manual setup needed |
| `workflow` skill | ✅ | Available in skill list |

## Agent Groups
- **Organs (Tier 3)**: 14 agents ✅ complete
- **CC-* specialists**: 12 agents (cc-architect, cc-bug-hunter, cc-ci-optimizer, cc-dependency, cc-doc-sync, cc-migration, cc-observe, cc-perf-tune, cc-refactor, cc-review-bot, cc-security, cc-test-gen) ✅ present
- ❌ **SA group** (System Agents) — 0 of 5
- ❌ **PA group** (Personal Agents) — 0 of 5
- Total existing: 26 agents (14 organs + 12 cc-*) → need 20+ more = SA + PA

## Next Iterations Plan
- **Iter 2**: Create SA group (5 agents) — infra, security, observability, scaling, reliability
- **Iter 3**: Create PA group (5 agents) — schedule, notes, research-assistant, learn-coach, inbox
- **Iter 4**: Install oracle-prism + oracle-plan skills; add `ψ/memory/signals/`
- **Iter 5**: E2E test — SA + PA exchange messages, verify receipt
- **Iter 6**: ghp helper script + oracle CLI wrapper

## Key Insight
**maw has 102 commands including `oracle`, `team`, `incubate`, `bud`, `awaken`, `mega`, `swarm`, `oracle-skills`, `oracle-workon`, `signals`** — these ARE the Oracle Pattern toolset. The 5 layers are mostly installed; the gap is agent roster (SA+PA groups) + skill install + E2E wiring.

**Why**: The Oracle Pattern book describes an *agent roster of 5-layer + multi-group*; we have layers but not the full 20+ agent headcount.
**How to apply**: Recruit 5 SA + 5 PA agents, register in `network/registry.json`, give them inboxes, test bus delivery end-to-end.
