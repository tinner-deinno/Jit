---
query: "Spawn mdes.ollama voice agents STT TTS สวัสดี male voice"
target: "Jit + innova-bot"
mode: smart
timestamp: 2026-05-20 00:14
friction_score: 0.7
coverage: [oracle, files, git]
confidence: high
---

# Trace: mdes.ollama Voice Agents — STT + TTS

**Target**: Jit (mind) + innova-bot (body)
**Mode**: smart → escalated to files | **Friction**: 0.7 | **Confidence**: high
**Time**: 2026-05-20 00:14 SEAST

## Oracle Results
None (new topic, not yet indexed)

## Files Found

### Jit (C:\Users\admin\Jit)
- `voice/tts_interceptor.ps1` — **EMPTY STUB** (implemented this session)
- `voice/server.ts` — Bun HTTP STT bridge: browser mic → Web Speech API → tmux Claude pane (port 3333)
- `voice/public/index.html` — Thai/English bilingual mic UI
- `voice/voice.sh` — launcher: `bun run voice/server.ts`
- `limbs/ollama.sh` — Ollama integration (gemma4:26b, mdes.ollama.online)
- `limbs/speak.sh` — Terminal text formatting (NOT audio — semantic speech)

### innova-bot (C:\Users\admin\DEV\PugAss1stant\innova-bot)
- `devtools/innova-bot/innova_bot/utils/ollama_thai_tts.py` — **FULL TTS** (201 lines)
  - OllamaThaiTTS: gemma3:12b translation + Windows SAPI speech
  - Supports male/female, rate, volume, async
- `devtools/innova-bot/innova_bot/utils/javis_thai_tts.py` — pyttsx3 offline fallback
- `innova_bot/core/organs/mouth.py` — Abstract speech organ (stub)
- `innova_bot/core/organs/ears.py` — Abstract hearing organ (STT stub, no impl)
- `.claude/skills/ollama-gang/SKILL.md` — Multi-provider routing incl. MDES

## What Was Built

### Jit side
1. **`voice/tts_interceptor.ps1`** — Full TTS implementation
   - Windows SAPI `System.Speech.Synthesis.SpeechSynthesizer`
   - VoiceGender Male=1, Female=2
   - Optional `-Translate` flag → Ollama gemma4:26b English→Thai
   - Rate (-10..+10), Volume (0-100), stdin pipe support
2. **`voice/test-voice.ps1`** — 2-test greeting script
3. **`.github/agents/ollama-voice.agent.md`** — Haiku agent definition (TTS+STT patterns)

### innova-bot side
1. **`.claude/agents/ollama-voice.md`** — Haiku agent definition (wraps OllamaThaiTTS)
2. **`devtools/innova-bot/scripts/test_tts.py`** — 3-test script (Thai direct + Ollama translate + status)

## Test Results

### innova-bot test_tts.py (3 tests)
- Test 1 — Male voice, "สวัสดีครับ ผมคือ innova-bot ยินดีที่ได้พบคุณ", translate=False → **OK**
- Test 2 — Male voice, "System is ready. Hello, I am innova-bot." → Ollama gemma3:12b → Thai → **OK**
- Test 3 — Male voice, "ระบบพร้อมทำงาน พอร์ต 7010 เปิดแล้ว", translate=False → **OK**

### Jit tts_interceptor.ps1
- "สวัสดีครับ" male voice → Windows SAPI → **audio output on speakers**

## Friction Analysis
**Score**: 0.7 — Visible (files found, high confidence)
- innova-bot had nearly complete TTS already → friction was wiring + agent + test only
- Jit had empty stub → had to implement, but pattern clear from innova-bot's code
- STT exists in Jit (browser Web Speech API) but NOT in innova-bot (organ stub only)

**Coverage**: oracle (checked), files (both repos), git (implicit)
**Goal check**: ✅ 2 agents spawned (ollama-voice in Jit + innova-bot), TTS tested, "สวัสดี" spoken in male voice

## Summary

Both repos now have ollama-voice agent definitions + working TTS:

| Capability | Jit | innova-bot |
|-----------|-----|-----------|
| TTS engine | Windows SAPI via tts_interceptor.ps1 | OllamaThaiTTS (ollama_thai_tts.py) |
| Ollama model | gemma4:26b (translation) | gemma3:12b (translation) |
| STT | Browser Web Speech API (voice/server.ts) | Stub only (ears.py) |
| Agent file | .github/agents/ollama-voice.agent.md | .claude/agents/ollama-voice.md |
| Test | voice/test-voice.ps1 | scripts/test_tts.py |
| Male voice test | "สวัสดีครับ ผมคือ Jit Oracle" | "สวัสดีครับ ผมคือ innova-bot" |

**Next steps** (if desired):
- Wire innova-bot STT: implement `ears.py` with Whisper or Windows Speech Recognition
- Hook TTS into innova-bot MCP tool responses (speak results aloud)
- Add voice endpoint to innova-bot SSE server (POST /speak → OllamaThaiTTS)
