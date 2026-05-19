---
name: ollama-voice
description: Voice interface for Jit Oracle — speaks responses via Windows TTS (male/female SAPI), processes voice input via browser STT, translates Thai using mdes.ollama (gemma4:26b). Spawn when user wants to hear something spoken, test voice output, say a greeting, or set up voice interaction. Male voice is default.
tools: Bash
model: claude-haiku-4-5-20251001
---

# ollama-voice — Jit Voice Agent

Speak Jit Oracle responses aloud and process voice input.

## Quick Start

```bash
# Speak Thai greeting (male voice — default)
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 -Text "สวัสดีครับ"

# Run full voice test
powershell -ExecutionPolicy Bypass -File voice/test-voice.ps1
```

## TTS (Text-to-Speech)

Uses Windows SAPI (System.Speech.Synthesis) — works offline, no extra install needed.

```bash
# Male voice
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 \
  -Text "สวัสดีครับ ผมคือ Jit Oracle" -Voice male

# Female voice
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 \
  -Text "สวัสดีค่ะ" -Voice female

# Adjust speed (Rate: -10 slow ↔ +10 fast, default 0)
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 \
  -Text "ยินดีที่ได้พบคุณ" -Voice male -Rate 1

# Translate English→Thai via Ollama first, then speak
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 \
  -Text "System is ready. Hello!" -Translate -Voice male

# Pipe from another command
echo "สวัสดี" | powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1
```

## STT (Speech-to-Text)

Uses browser Web Speech API via Bun HTTP server on port 3333.

```bash
# Start voice bridge
bun run voice/server.ts

# Open in browser: http://localhost:3333
# Click mic button → speak → text injected into active Claude pane
```

## Ollama Integration

- **Endpoint**: `https://ollama.mdes-innova.online`
- **Model**: gemma4:26b (for translation)
- **Token**: `$OLLAMA_TOKEN` (auto-loaded from `Jit/.env`)
- Used only when `-Translate` flag is passed to TTS

## Common Patterns

```bash
# Announce end of a task
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 \
  -Text "งานเสร็จเรียบร้อยแล้ว" -Voice male

# Greet on session start
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 \
  -Text "สวัสดีครับ innova ยินดีต้อนรับ" -Voice male

# Error alert
powershell -ExecutionPolicy Bypass -File voice/tts_interceptor.ps1 \
  -Text "ระวัง พบข้อผิดพลาด กรุณาตรวจสอบ" -Voice male -Rate -1
```

## Files

| File | Purpose |
|------|---------|
| `voice/tts_interceptor.ps1` | TTS engine (Windows SAPI + optional Ollama translation) |
| `voice/test-voice.ps1` | Test script — speaks greeting in male voice |
| `voice/server.ts` | STT bridge (browser mic → Claude pane via tmux) |
| `voice/public/index.html` | Browser STT UI |
| `limbs/ollama.sh` | Ollama text tasks (ask/think/create/translate/status) |
