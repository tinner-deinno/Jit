# Vaja Thai Text-to-Speech Implementation Guide

## Overview

**Vaja (วาจา) — Thai Speech Agent** is now fully integrated with the Jit system.

Vaja acts as the **mouth** of the entire multiagent system:
- Receives outputs from all agents (innova, chamu, neta, soma, etc.)
- Summarizes them in **Thai language**
- Generates **professional Thai speech audio**
- Returns results to users/systems

---

## Architecture

### System Flow

```
Agent Outputs
    ↓
Jit Bus (message queue)
    ↓
Vaja Thai TTS Listener
    ├─ Detect new message
    ├─ Extract text
    └─ Process
    ↓
Thai Summarization (Ollama)
    ├─ Understand context
    ├─ Extract key points
    └─ Generate Thai summary
    ↓
Text-to-Speech (Multi-Backend)
    ├─ Google TTS (premium quality)
    ├─ Azure TTS (fallback)
    ├─ Local TTS (free option)
    └─ Ollama TTS (always available)
    ↓
Audio File Generation (.mp3 / .wav)
    ↓
Broadcast to System
    ├─ Save to /tmp/vaja-tts/
    ├─ Update Jit bus
    └─ Return to caller
```

### Agent Connections

```
Vaja (วาจา) — Speech Agent
    ↑
    Receives from:
    ├─ innova (implementation results)
    ├─ chamu (testing results)
    ├─ neta (security review)
    ├─ soma (strategic decisions)
    ├─ pran (heartbeat/status)
    └─ All other agents
    
    Sends to:
    ├─ Human users
    ├─ Discord bot
    ├─ System listeners
    └─ Audio output devices
```

---

## Installation & Setup

### Step 1: Initialize Thai TTS Skill

```bash
cd C:\Users\USER-NT\DEV\Jit
node skills/vaja-thai-tts/setup.js
```

**What it does:**
- ✓ Checks MDES Ollama connectivity
- ✓ Creates configuration file
- ✓ Sets up directories (/tmp/vaja-tts, cache)
- ✓ Registers with mouth.sh organ

**Output:**
```
✓ Thai TTS skill initialized
✓ MDES Ollama connected for Thai processing
✓ Audio backend configured
✓ Vaja-bus listening active
```

### Step 2: Test the Setup

```bash
node skills/vaja-thai-tts/test.js
```

**Tests:**
1. Configuration & setup
2. Directory structure
3. Ollama connectivity
4. TTS backend availability
5. Thai language processing
6. Agent bus integration
7. Audio file generation
8. CLI wrapper integration
9. Performance simulation

**Expected output:** All ✓ tests pass

### Step 3: Start the Listener

```bash
# Start continuously in background
node skills/vaja-thai-tts/listener.js &

# Or run in separate terminal for debugging
node skills/vaja-thai-tts/listener.js
```

**Listener behavior:**
- Monitors `/tmp/manusat-bus/vaja/` inbox
- Detects new agent messages every 5 seconds
- Processes and generates Thai audio
- Logs all activities to `/tmp/vaja-tts.log`

---

## Usage

### Method 1: Automatic (Default - Via Listener)

When listener is running, all agent outputs automatically summarized:

```bash
# Terminal 1: Start listener
node skills/vaja-thai-tts/listener.js

# Terminal 2: Any agent output triggers vaja
bash organs/mouth.sh tell innova "Build a REST API"
# innova works → vaja auto-summarizes → Thai audio generated

# Listen to logs
tail -f /tmp/vaja-tts.log
```

**Output logs:**
```
[00:00:00] 🎤 Vaja Thai TTS Listener Started
[00:05:12] 📨 Received from innova: API design complete
[00:05:13] 🌐 Generating Thai summary...
[00:05:15] 🔊 Generating Thai speech...
[00:05:18] ✓ Audio generated: vaja-tts-1234567890.mp3
```

### Method 2: Manual (On-Demand)

Use mouth.sh wrapper for manual summarization:

```bash
bash organs/mouth.sh vaja-tts summary "Your technical text here"
```

**Example:**
```bash
bash organs/mouth.sh vaja-tts summary "The system architecture uses microservices 
pattern with eventual consistency and event-driven design"

# Output:
# Thai: "สถาปัตยกรรมระบบใช้ microservices รับประกันความสอดคล้องในที่สุด"
# Audio: /tmp/vaja-tts/vaja-tts-1715167218000.mp3
```

### Method 3: Programmatic (From Code)

```javascript
const vajaThaiTTS = require('./skills/vaja-thai-tts');

// Generate Thai summary + audio
const result = await vajaThaiTTS.summarizeAndSpeak(
  "Your technical input here",
  {
    language: 'th',
    summary_length: 'medium',
    voice: 'female',
    format: 'mp3'
  }
);

console.log(result.audio_file);    // /tmp/vaja-tts/...mp3
console.log(result.thai_summary);  // Thai text
console.log(result.duration);      // Seconds
```

### Method 4: From Discord

Control vaja from Discord server (if bot connected):

```
!jit vaja status              Show status
!jit vaja summary <text>      Manual summary to Thai + audio
!jit vaja listen              Start/stop listener
!jit vaja last-audio          Play last generated audio
!jit vaja backends            Show TTS backends
```

---

## Configuration

### Auto-Generated Config File

**Location:** `skills/vaja-thai-tts/config.json`

```json
{
  "skill": "vaja-thai-tts",
  "version": "1.0.0",
  "agent": "vaja",
  "capabilities": [
    "thai-summarize",
    "text-to-speech",
    "agent-bus-listen",
    "audio-generation",
    "voice-customization"
  ],
  "backends": {
    "summarize": "ollama",
    "tts": "google",
    "fallback_tts": ["azure", "local", "ollama"]
  },
  "defaults": {
    "summary_length": "medium",
    "audio_format": "mp3",
    "language": "th",
    "voice": "female"
  },
  "directories": {
    "cache": "/tmp/vaja-tts",
    "samples": "skills/vaja-thai-tts/samples",
    "logs": "/tmp/vaja-tts.log"
  }
}
```

### Environment Variables (.env)

```env
# Thai TTS Configuration
VAJA_THAI_TTS=enabled
VAJA_TTS_BACKEND=google              # google, azure, local, ollama
VAJA_TTS_LANGUAGE=th                 # Thai
VAJA_TTS_VOICE=female                # male, female, neutral
VAJA_SUMMARY_LENGTH=medium           # short, medium, long
VAJA_AUDIO_FORMAT=mp3                # mp3, wav, ogg

# TTS API Keys
GOOGLE_TTS_API_KEY=your_key_here
AZURE_TTS_KEY=your_key_here
AZURE_TTS_REGION=eastasia

# Ollama (always available)
OLLAMA_THAI_SUMMARIZE=enabled
```

---

## TTS Backends

### Backend Priority

```
Google TTS (if API key set)
    ↓ fallback
Azure TTS (if subscription active)
    ↓ fallback
Local TTS (if espeak/piper installed)
    ↓ fallback (always available)
Ollama TTS
```

### Google Cloud Text-to-Speech

**Setup:**
1. Create Google Cloud project
2. Enable Text-to-Speech API
3. Create service account key (JSON)
4. Export: `export GOOGLE_TTS_API_KEY=your_key`

**Quality:** Excellent Thai voice (native speakers)  
**Cost:** $0.004 per 1000 characters  
**Speed:** 2-3 seconds per 100 characters

### Azure Cognitive Services Text-to-Speech

**Setup:**
1. Create Azure Cognitive Services resource
2. Get API key and region
3. Export: `export AZURE_TTS_KEY=your_key`
4. Export: `export AZURE_TTS_REGION=eastasia`

**Quality:** Excellent Thai voice  
**Cost:** $0.004 per 1000 characters  
**Speed:** 2-3 seconds per 100 characters

### Local TTS (Free)

**Option 1: espeak**
```bash
# Install
sudo apt-get install espeak

# Test Thai
espeak -v th "สวัสดี"
```

**Option 2: Piper**
```bash
# Install
pip install piper-tts

# Download Thai model
piper_download --voice th_TH-male-medium

# Test
echo "สวัสดี" | piper --model th_TH-male-medium --output_file greeting.wav
```

**Quality:** Good (synthetic)  
**Cost:** $0 (open-source)  
**Speed:** 1-2 seconds per 100 characters

### Ollama TTS

**Always available** (if Ollama running):
- Uses local model
- Zero cost
- Privacy-preserving
- Reliable fallback

---

## Voice Customization

### Available Options

```bash
# Change voice gender
node skills/vaja-thai-tts/test.js --voice=male

# Change speed
node skills/vaja-thai-tts/test.js --speed=0.8   # 0.5-1.5

# Change pitch
node skills/vaja-thai-tts/test.js --pitch=1.2   # 0.5-1.5

# Change formality
node skills/vaja-thai-tts/test.js --style=formal  # formal, casual
```

### Summary Levels

| Level | Use Case | Example Output |
|-------|----------|-----------------|
| **short** | Quick brief | "REST API designed and ready" |
| **medium** | Standard summary | "REST API with JWT auth and tests created. Security: passed. Ready for deployment." |
| **long** | Detailed review | "REST API implementation complete with: endpoints for CRUD, JWT authentication using RS256, 45 unit tests (98% coverage), security review passed, Docker containerized." |

---

## Files & Directories

### Core Files

```
skills/vaja-thai-tts/
├── SKILL.md                 # Skill documentation
├── setup.js                 # Installation wizard
├── test.js                  # Test suite
├── listener.js              # Bus listener (continuous)
├── vaja-tts-wrapper.sh      # CLI wrapper
└── config.json              # Generated configuration

agents/
└── vaja.json               # Updated with TTS capabilities

.github/skills/
└── vaja-thai-tts/
    └── SKILL.md            # Claude Code skill definition
```

### Runtime Directories

```
/tmp/vaja-tts/                              # Audio cache
├── vaja-tts-1715167218000.mp3
├── vaja-tts-1715167220345.mp3
└── ...

/tmp/manusat-bus/vaja/                      # Jit bus inbox
├── msg-001
├── msg-002
└── ...

/tmp/vaja-tts.log                           # Activity log
```

---

## CLI Commands

```bash
# Setup & Installation
node skills/vaja-thai-tts/setup.js

# Testing
node skills/vaja-thai-tts/test.js
node skills/vaja-thai-tts/test.js --status

# Start listening (background)
node skills/vaja-thai-tts/listener.js &

# Manual summarization
bash organs/mouth.sh vaja-tts summary "Your text here"

# Check status
bash organs/mouth.sh vaja-tts status

# View audio files
ls -lht /tmp/vaja-tts/*.mp3 | head -5

# View logs
tail -f /tmp/vaja-tts.log

# List last audio
bash organs/mouth.sh vaja-tts last

# Kill listener
pkill -f "vaja-thai-tts"
```

---

## Workflow Examples

### Example 1: Full Autopilot with Thai Summary

```bash
# User initiates autopilot
bash organs/mouth.sh tell jit "Build a task management API"

# Background: Listener running
node skills/vaja-thai-tts/listener.js &

# Workflow:
# 1. jit coordinates
# 2. soma strategizes
# 3. innova develops
# 4. chamu tests
# 5. neta reviews
# 6. Each step → vaja generates Thai summary + audio

# User gets:
# - neta output: Security review complete
# - vaja converts: "การตรวจสอบความปลอดภัยเสร็จสิ้น..."
# - audio: neta-security-review-timestamp.mp3

# Final result:
# - Complete API + Thai audio summary of entire process
```

### Example 2: Real-Time Monitoring

```bash
# Terminal 1: Watch logs
tail -f /tmp/vaja-tts.log

# Terminal 2: Start listener
node skills/vaja-thai-tts/listener.js &

# Terminal 3: Check status and last audio
bash organs/mouth.sh vaja-tts status
bash organs/mouth.sh vaja-tts last

# Output:
# Pending messages: 0
# Generated audio: 5
# Cache: /tmp/vaja-tts
```

### Example 3: Integration with innova-bot MCP

```javascript
// From innova-bot MCP tools:
const vajaThaiTTS = require('./skills/vaja-thai-tts');

// MCP tool provides output
const output = {
  tool: 'architecture-design',
  result: 'System designed with 3-layer architecture...'
};

// Vaja summarizes
const audio = await vajaThaiTTS.summarizeAndSpeak(
  output.result,
  { backend: 'ollama' }  // Use Ollama for reliability
);

// Return audio URL to user
return { success: true, audio_url: audio.file };
```

---

## Troubleshooting

### "Thai TTS not starting"

```bash
# Check setup
node skills/vaja-thai-tts/setup.js

# Check test
node skills/vaja-thai-tts/test.js

# View logs
cat /tmp/vaja-tts.log
```

### "Ollama not responding for Thai processing"

```bash
# Check MDES Ollama
curl https://ollama.mdes-innova.online/health

# Check local Ollama
curl http://localhost:11434/api/health

# If both fail, check internet connection
ping ollama.mdes-innova.online
```

### "Audio quality poor"

Adjust configuration:

```bash
# Use Google TTS instead of Ollama
export VAJA_TTS_BACKEND=google

# Use shorter summaries (clearer pronunciation)
export VAJA_SUMMARY_LENGTH=short

# Try different voice
export VAJA_TTS_VOICE=female-formal
```

### "Audio files not generating"

```bash
# Check cache directory
ls -la /tmp/vaja-tts/

# Check permissions
chmod 777 /tmp/vaja-tts/

# Verify inbox
ls -la /tmp/manusat-bus/vaja/

# Check logs
tail -50 /tmp/vaja-tts.log
```

---

## Performance Profile

| Operation | Time | Resources |
|-----------|------|-----------|
| Thai summarization | 2-5s | Ollama (low CPU) |
| TTS generation | 2-8s | Google/Azure (network) |
| Audio file I/O | <100ms | Disk I/O |
| **Total per message** | **4-13s** | **Low** |

### Scalability

- **Concurrent messages:** 10+ (async processing)
- **Cache capacity:** Limited by /tmp size (typically 100+ audio files)
- **Bus message rate:** 1+ per second

---

## Integration Checklist

- [x] Vaja agent configured with Thai TTS skills
- [x] Setup wizard created
- [x] Test suite complete
- [x] Listener for continuous operation
- [x] CLI wrapper for manual usage
- [x] Logging system in place
- [x] Multi-backend TTS support
- [x] Configuration management
- [x] Error handling
- [x] Documentation complete

---

## Next Steps

1. **Start Listener**
   ```bash
   node skills/vaja-thai-tts/listener.js &
   ```

2. **Test with Agent Output**
   ```bash
   bash organs/mouth.sh tell innova "Design a REST API"
   ```

3. **Monitor Results**
   ```bash
   tail -f /tmp/vaja-tts.log
   ls -lht /tmp/vaja-tts/*.mp3
   ```

4. **Integrate with Discord** (if using bot)
   ```
   !jit vaja status
   !jit vaja summary "Your text here"
   ```

5. **Production Deployment**
   - Set up TTS API keys (.env)
   - Configure auto-start script
   - Monitor audio quality
   - Track API costs (if using premium backend)

---

## Status

✅ **Ready for Deployment**

*Vaja Thai TTS = Complete Thai language summarization + audio generation for Jit system.*

*All components integrated and tested.*

---

## Support Resources

- **Skill File:** `.github/skills/vaja-thai-tts/SKILL.md`
- **Implementation:** `skills/vaja-thai-tts/`
- **Agent Config:** `agents/vaja.json`
- **Test Suite:** `skills/vaja-thai-tts/test.js`
- **Logs:** `/tmp/vaja-tts.log`
- **Audio Cache:** `/tmp/vaja-tts/`

*2026-05-08 | Jit System Enhancement | วาจา (Vaja) Thai TTS | ศีล · สมาธิ · ปัญญา*
