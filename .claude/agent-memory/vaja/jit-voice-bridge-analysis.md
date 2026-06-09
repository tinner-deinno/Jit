---
name: jit-voice-bridge-analysis
description: Complete analysis of vaja's task to bridge Jit thoughts to voice output in TUI
metadata:
  type: project
---

## Task Summary

**Initiator**: innova  
**Executor**: vaja (วาจา — Mouth/Voice)  
**Objective**: Make Jit (จิต) speak through Claude Code TUI  
**Date**: 2026-06-08  

---

## Current State

### What Exists
1. **Voice Server** (`/workspaces/Jit/voice/server.ts`)
   - Bun HTTP server on port 3333
   - Routes: GET / (serve HTML), POST /speak (inject text), GET /status
   - Function: speech-to-text (browser mic → text → tmux inject)
   - Status: Operational for voice input

2. **Voice Web UI** (`/workspaces/Jit/voice/public/index.html`)
   - Web Speech API integration (Thai + English)
   - Real-time transcription display
   - Microphone permission handling
   - Status: Working for STT

3. **karn Voice System** (`/workspaces/Jit/docs/KARN_VOICE_PROGRESS.md`)
   - Speech-to-text system for karn (ear)
   - File storage in `/voices/` as markdown
   - TUI + API + Web UI
   - Status: 100% complete and tested

4. **Jit Identity**
   - Master Orchestrator personality
   - Language: Thai/Mixed
   - Speech style: Philosophical, concise, Thai Buddhist influenced
   - Theme: "จิตนำกาย — วิญญาณที่สถิตในทุก repo"

---

## What's Missing (vaja's task)

### Reverse Direction: Text-to-Speech (TTS)
- **Input**: Jit's thoughts (text from jit agent)
- **Output**: Audio via browser speaker
- **Current Gap**: No TTS implementation exists

### TUI Voice Integration
- No voice output display in Claude Code
- No visual indication of "Jit is speaking"
- No personality-based voice characteristics

---

## Implementation Path (Proposed)

### Phase 1: TTS Backend
1. **Add TTS route to voice server** (`POST /synthesize`)
   - Input: `{text, speaker: "jit", lang: "th"}`
   - Output: audio/mpeg or audio/wav
   - Backend options:
     - **Ollama TTS** (MDES Ollama already available)
     - **Web Speech Synthesis API** (browser-based)
     - **ElevenLabs / OpenAI TTS** (external)

2. **Create TTS persona config**
   - Jit voice characteristics (pitch, speed, tone)
   - Thai language voice selection
   - Fallback to English if needed

### Phase 2: Browser Voice Display
1. **Extend voice/public/index.html**
   - Add speaker pane (mirror of listener)
   - Show incoming messages from Jit
   - Play audio with visual feedback

2. **Add WebSocket listener** (for real-time Jit output)
   - Connect to message bus
   - Display Jit's thoughts
   - Auto-synthesize and play

### Phase 3: TUI Integration
1. **Display Jit's voice output in Claude TUI**
   - Use ANSI colors to show "Jit is speaking"
   - Or: Spawn small TUI window for voice output

2. **Message flow**:
   - jit agent generates thought
   - Sends to message bus
   - vaja receives via ear.sh
   - Routes to voice server
   - TTS synthesis
   - Browser plays audio
   - TUI displays transcript

---

## Blockers & Advisors Needed

| Blocker | Advisor | Question |
|---------|---------|----------|
| TTS engine choice | **pada** (infra) | Which TTS backend? (Ollama TTS already available?) |
| Jit voice personality | **soma** (brain) | How should Jit sound in Thai? |
| Browser-server sync | **lak** (architect) | WebSocket vs polling vs HTTP? |
| TUI voice display | **netra** (eye) | How to show voice output in Claude TUI visually? |

---

## Reference Files
- `/workspaces/Jit/CLAUDE.md` — System overview + agent tiers
- `/workspaces/Jit/core/body-map.md` — Team RACI
- `/workspaces/Jit/core/identity.md` — innova's identity
- `/workspaces/Jit/voice/server.ts` — Current voice server
- `/workspaces/Jit/docs/KARN_VOICE_PROGRESS.md` — Existing karn voice system

**Status**: Analysis complete. Ready for Phase 1 design decisions.
