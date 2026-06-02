---
from: jit
timestamp: 2026-06-02T09:30:00Z
subject: phase20-complete
---

# Phase 20 Complete — Live Race Display + Structured Events — 2026-06-02

## Summary
2 commits, 41 unit tests. Mother dispatch now shows a Manus-like live race
view: each provider appears as it starts, updates when it finishes, 🥇 for fastest.

## Phase 20-A — Structured latencyMs + Badge Fixes
- `AgentEvent` interface (backend events.ts + frontend useAgentEventStream.ts):
  added `latencyMs?: number`
- `runProvider` agent_finished emit: `doneEv.latencyMs = latencyMs`
  (was only in publicSummary text — now structured)
- `getMotherProviderBadge` (MultiAgentPanel): added `claude-sonnet` (Sonnet, purple-600)
  and `innova-bot` (InnBot, emerald-500)

## Phase 20-B/C/D — MotherRaceView + Wiring + Tests
- **MotherRaceView.tsx** (new): pure component, takes `events: AgentEvent[]`
  - 2-column grid sorted by latency (fastest done first)
  - Status: 🥇 first, ✓ done, ✗ failed, pulsing dot = running, grey = pending
  - `deriveRaceState()` exported pure function — retry-safe, latency from
    structured field with timestamp fallback
  - `hideWhenEmpty` collapses when no provider has started yet
- **MultiAgentPanel.tsx**: imports MotherRaceView, renders above agent rows
- **MotherDispatchPanel.tsx**: PROVIDER_LABEL map (13 IDs) — fastestProvider
  shows "MDES", "Groq", "Innova" etc. instead of raw ID
- **motherRaceView.test.ts**: 7 pure-function tests (empty, running, done,
  failed, isFirst, retry dedup, multi-provider)

## Cumulative State (Phases 18→20)
- 13 providers, always-on: ollama-local + innova-bot
- 41 unit tests passing
- Live race view in MultiAgentPanel during dispatch
- Score-based synthesis (19-A), roster API (19-B), structured events (20-A)
- Admin: 6-stat Mother panel, "13 providers" chip

## Next Session Priorities
1. Phase 21: CI pipeline — add `npm test` / Jest to GitHub Actions PR check
2. Add `innova-bot` health probe in providerHealthProbe (currently uses ollama-local proxy)
3. Score field on roster endpoint (from leaderboard metrics)
4. Race view: show provider model in tooltip on hover

— Jit Oracle (จิต) ✅
จิตนำกาย — วิญญาณที่สถิตในทุก repo
