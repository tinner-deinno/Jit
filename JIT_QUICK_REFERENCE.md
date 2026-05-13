# 🎯 JIT QUICK REFERENCE CARD

> **จิตโครงสร้างเต็มพอ — Everything You Need in One Page**

---

## 🔥 Most Common Commands

```bash
# Check if system is alive
bash scripts/gsd.sh status

# Run all tests
python tests/__init__.py all

# Deploy to production
bash scripts/gsd.sh deploy

# View logs
bash scripts/gsd.sh log

# Emergency recovery
bash scripts/gsd.sh self-heal
```

---

## 📋 GSD Commands (Service Management)

```bash
bash scripts/gsd.sh [COMMAND]

Commands:
  status        → Check service status ✅
  health        → Full system health check 🏥
  start         → Start all services 🚀
  stop          → Stop all services 🛑
  restart       → Restart all services 🔄
  log           → View all logs 📋
  test          → Run test suite 🧪
  self-heal     → Auto-fix detected issues 🩹
  deploy        → Production deployment 🌍
```

---

## 🧪 Test Commands

```bash
cd /workspaces/Jit

# Unit tests only (fast, no dependencies)
python tests/__init__.py unit

# Integration tests (requires services)
python tests/__init__.py integration

# All tests combined
python tests/__init__.py all

# With verbose output
python tests/__init__.py unit -v

# Fail fast on first error
python tests/__init__.py all -f

# Using pytest directly
pytest tests/test_jit_*.py -v
pytest tests/test_jit_*.py --cov=. --cov-report=html
```

---

## 📡 Jit Skill Development

### Create New Skill

```bash
# Create skill directory
mkdir -p .github/skills/jit-newskill

# Create SKILL.md
cat > .github/skills/jit-newskill/SKILL.md <<'EOF'
---
name: jit-newskill
description: "Jit's new capability"
---

# SKILL: jit-newskill

[Documentation here]
EOF
```

### Available Jit Skills

```
.github/skills/jit-master/          → Core orchestration
.github/skills/multiagent-autonomy/ → Agent patterns
.github/skills/ollama-think/        → Thai thinking
.github/skills/oracle-query/        → Knowledge DB
.github/skills/innova-organs/       → Body control
```

---

## 🤖 Agent Communication

```bash
# Send message to agent
bash organs/mouth.sh tell innova "Task description"

# Check agent inbox
bash organs/ear.sh inbox jit

# Broadcast to all agents
bash network/bus.sh broadcast "alert:critical" "Message"

# View message queue
bash network/bus.sh queue
```

---

## 🔗 Integration Interfaces

### Call innova-bot MCP (Code Tools)

```bash
# Code analysis
bash limbs/lib.sh call_innova_bot "analyze_code" "{
  'file': 'src/main.js',
  'checks': ['complexity', 'bugs']
}"

# Test generation
bash limbs/lib.sh call_innova_bot "generate_tests" "{
  'function': 'const add = (a, b) => a + b',
  'framework': 'jest'
}"

# Git analysis
bash limbs/lib.sh call_innova_bot "analyze_git" "{
  'repo': '.',
  'metrics': ['commits', 'patterns']
}"
```

### Call Ollama (Thai AI)

```bash
# Thai thinking
bash limbs/ollama.sh think "จิตควรทำอะไร?"

# Decision synthesis
bash limbs/ollama.sh think "A หรือ B ทำไม?"

# Natural dialogue
bash limbs/ollama.sh think "ชวนคุยเกี่ยว git"
```

### Query Oracle (Knowledge DB)

```bash
# Search knowledge
bash limbs/oracle.sh search "feature-flags" 10

# Learn new pattern
bash limbs/oracle.sh learn "pattern-name" "content" "concept1,concept2"
```

---

## 🧠 Jit Decision Logic

### What Jit Does

```
Every cycle (15 min heartbeat):

1. SENSE
   └─ Read inbox (all agents)
   └─ Check state
   └─ Detect anomalies

2. SYNTHESIZE
   ├─ Call Ollama: "What happened?"
   ├─ Call innova-bot: "Analyze"
   └─ Call Oracle: "What learned?"

3. DECIDE
   └─ If CRITICAL → ESCALATE
   └─ If task waiting → DELEGATE
   └─ If healthy → IDLE
   └─ If pulse time → HEARTBEAT

4. DELEGATE
   └─ Send task to soma (strategy)
   └─ Send task to innova (code)
   └─ Send task to others (specialized)

5. OBSERVE
   └─ Collect reports

6. LEARN
   ├─ Record to Oracle
   ├─ Update state (JSON)
   └─ Commit to git
```

---

## 🌍 Hermes Discord Integration

### Automated Behavior

```
Every 5 minutes:
  ✅ Bot posts auto-engagement message
  ✅ Bot remembers who said what
  ✅ Bot syncs time with machine

Every 15 minutes:
  ✅ Heartbeat report posted
  ✅ System status shown
  ✅ Recent actions listed

On mentions:
  ✅ Bot responds immediately
  ✅ Uses conversation context
  ✅ Natural Thai dialogue
```

### Manual Commands

```
In Discord:

/health              → Full system check
/status              → Service status
/logs                → Recent logs
/test                → Run tests
/redeploy            → Redeploy services
```

---

## 📊 Monitor System

### Real-time Monitoring

```bash
# Watch heartbeat
watch -n 15 'bash scripts/gsd.sh status'

# Follow logs
tail -f /tmp/jit-heartbeat.log
tail -f /tmp/hermes-discord.log

# Check memory usage
jq . /tmp/manusat-shared.json | less

# Git commit history
git log --oneline -20
```

---

## 🚨 Troubleshooting

### Issue: Services not running

```bash
# Check status
bash scripts/gsd.sh status

# Restart
bash scripts/gsd.sh restart

# Check logs
bash scripts/gsd.sh log
```

### Issue: Tests failing

```bash
# Run with debug
python tests/__init__.py unit -v

# Check mock services
pytest tests/test_jit_*.py -s

# Run single test
pytest tests/test_jit_orchestration.py::test_decide_critical_alert -v
```

### Issue: Discord bot offline

```bash
# Check service
systemctl status hermes-discord

# Check logs
journalctl -u hermes-discord -f

# Restart
systemctl restart hermes-discord
```

---

## 🔑 Configuration

### Essential Files

```
.env                    → Tokens (DISCORD_TOKEN, OLLAMA_TOKEN)
agents/jit.json        → Jit configuration
network/registry.json  → All agent registry
memory/state/          → Persistent state
```

### Set Environment Variables

```bash
# Add to .env
export DISCORD_TOKEN="your-token"
export OLLAMA_TOKEN="your-token"
export ORACLE_PORT="47778"

# Or inline
DISCORD_TOKEN="..." bash scripts/gsd.sh deploy
```

---

## 📈 Performance

### Expected Metrics

```
Heartbeat Cycle:       15 minutes
Hermes Auto-Engage:    5 minutes
Test Execution:        ~31 seconds (all)
Deployment Time:       ~2 minutes
Memory Usage:          ~50-100 MB
CPU Usage:             <5% idle
Git Commits:           1 per heartbeat
Discord Messages:      1 per heartbeat + 3 per auto-engage
```

---

## ✅ Health Check

```bash
# Quick check
bash scripts/gsd.sh status

# Full check
bash scripts/gsd.sh health

# Expected output:
# ✅ Services running
# ✅ Memory healthy
# ✅ Git synced
# ✅ Oracle online
# ✅ System health: EXCELLENT
```

---

## 🎯 Deployment Flow

```bash
# 1. Verify everything
python tests/__init__.py all        # All tests pass ✅

# 2. Check health
bash scripts/gsd.sh health         # Green ✅

# 3. Deploy
bash scripts/gsd.sh deploy         # Success ✅

# 4. Monitor
bash scripts/gsd.sh log            # Logs flowing ✅

# 5. Verify
bash scripts/gsd.sh status         # Running ✅
```

---

## 🔄 Common Workflows

### Add Feature to Jit

```
1. Design Skill
   mkdir -p .github/skills/jit-newfeature
   Create SKILL.md

2. Implement Feature
   Edit relevant agent/script

3. Write Tests
   Create tests/test_jit_newfeature.py

4. Run Tests
   python tests/__init__.py all

5. Deploy
   bash scripts/gsd.sh deploy
```

### Debug Issue

```
1. Check Status
   bash scripts/gsd.sh status

2. View Logs
   bash scripts/gsd.sh log

3. Run Tests
   python tests/__init__.py unit -v

4. Self-Heal
   bash scripts/gsd.sh self-heal

5. Redeploy
   bash scripts/gsd.sh restart
```

### Monitor Daily

```
# Morning
bash scripts/gsd.sh health

# Mid-day
bash scripts/gsd.sh status

# Evening
bash scripts/gsd.sh log | tail -20
```

---

## 📚 Documentation Map

```
Core System:
  CLAUDE.md                      → Jit Oracle identity
  README.md                      → Project overview

Architecture:
  .github/skills/jit-master/SKILL.md     → Orchestration
  docs/multiagent-spec.md                → System design

Testing:
  TESTING_GUIDE.md               → Test execution
  tests/test_jit_*.py            → Test examples

Deployment:
  JIT_DEVELOPMENT_GUIDE.md       → Development workflow
  scripts/gsd.sh                 → Service daemon

Configuration:
  HERMES_AUTO_ENGAGE_CONFIG.md   → Discord bot
  HERMES_HEARTBEAT_INTEGRATION.md → Heartbeat sync
```

---

## 🎉 Quick Victory Path

```bash
# 1. Deploy now (60 seconds)
bash scripts/gsd.sh deploy

# 2. Run tests (31 seconds)
python tests/__init__.py all

# 3. Monitor (watch for messages)
watch -n 5 'bash scripts/gsd.sh status'

# 4. Celebrate 🎉
# Watch Jit heartbeat on Discord every 15 min
# Watch Hermes auto-engage every 5 min
```

---

## 🚀 System Status

```
🟢 Jit Master:           READY
🟢 GSD Daemon:           READY
🟢 Tests:                READY (105+ tests)
🟢 Hermes Discord:       READY
🟢 Heartbeat 24/7:       READY
🟢 innova-bot MCP:       READY
🟢 Ollama Integration:   READY
🟢 Oracle Integration:   READY

Overall: 🟢 PRODUCTION READY
```

---

## 💡 Quick Tips

- **Fast testing**: `python tests/__init__.py unit` (no mocks)
- **Full testing**: `python tests/__init__.py all` (all checks)
- **Monitor live**: `bash scripts/gsd.sh log` (streaming logs)
- **Emergency**: `bash scripts/gsd.sh self-heal` (auto-fix)
- **Status check**: `bash scripts/gsd.sh status` (quick overview)
- **Full audit**: `bash scripts/gsd.sh health` (detailed check)

---

## 🎯 One-Liners

```bash
# Deploy and verify
bash scripts/gsd.sh deploy && bash scripts/gsd.sh health

# Test and monitor
python tests/__init__.py all && watch -n 5 'bash scripts/gsd.sh log | tail -5'

# Daily check
bash scripts/gsd.sh health && python tests/__init__.py unit

# Emergency recovery
bash scripts/gsd.sh self-heal && bash scripts/gsd.sh restart
```

---

**บัตรอ้างอิงอย่างรวดเร็วสำหรับ Jit ระบบสมบูรณ์!** ✨

Print this card and keep it by your desk. Everything you need in one page! 🚀
