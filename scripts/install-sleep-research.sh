#!/usr/bin/env bash
# scripts/install-sleep-research.sh
# Install + integrate https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep
# เชื่อมกับ Jit system: MDES Ollama + Oracle + Hermes Discord
set -euo pipefail
JIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true

REPO_URL="https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep"
INSTALL_DIR="$JIT_ROOT/_reference_repos/sleep-research"
QUEUE_DIR="$JIT_ROOT/memory/sleep-research"
mkdir -p "$QUEUE_DIR" "$INSTALL_DIR"

step "🌙 Installing Auto-claude-code-research-in-sleep..."

# ──────────────────────────────────────────────────────────────────
# 1. Clone / pull repo
# ──────────────────────────────────────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
  step "  Updating existing clone..."
  git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || warn "Pull failed — using cached version"
elif command -v git &>/dev/null; then
  step "  Cloning $REPO_URL..."
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null && ok "Cloned" || {
    warn "Git clone failed — fetching README via curl..."
    curl -sfL "https://raw.githubusercontent.com/wanshuiyin/Auto-claude-code-research-in-sleep/main/README.md" \
      -o "$INSTALL_DIR/README.md" 2>/dev/null || true
  }
fi

# ──────────────────────────────────────────────────────────────────
# 2. Read + summarize README with MDES
# ──────────────────────────────────────────────────────────────────
README="$INSTALL_DIR/README.md"
README_CONTENT=""
[ -f "$README" ] && README_CONTENT=$(cat "$README" 2>/dev/null | head -200 || true)
[ -z "$README_CONTENT" ] && README_CONTENT=$(curl -sfL \
  "https://raw.githubusercontent.com/wanshuiyin/Auto-claude-code-research-in-sleep/main/README.md" \
  2>/dev/null | head -200 || echo "")

if [ -n "$README_CONTENT" ]; then
  step "  Analyzing with MDES..."
  SUMMARY=$(python3 -c "
import json, subprocess, sys, os
body = json.dumps({
  'model': 'gemma4:26b',
  'prompt': '''วิเคราะห์ repo นี้และสรุป:
1. มันทำอะไร
2. คุณสมบัติหลัก
3. วิธี integrate กับ Jit (MDES Ollama + Oracle + agents)

README:
''' + sys.argv[1],
  'stream': False
})
r = subprocess.run(
  ['curl', '-sf', '--max-time', '60',
   'https://ollama.mdes-innova.online/api/generate',
   '-H', 'Content-Type: application/json',
   '-H', 'Authorization: Bearer ' + os.environ.get('OLLAMA_TOKEN', ''),
   '--data', body],
  capture_output=True, text=True
)
try:
  print(json.loads(r.stdout).get('response', ''))
except: pass
" "$README_CONTENT" 2>/dev/null || echo "(MDES analysis unavailable)")
  echo ""
  echo "📋 Repo Analysis:"
  echo "$SUMMARY"
  
  # Save to Oracle
  bash "$JIT_ROOT/limbs/oracle.sh" learn \
    "sleep-research:install" \
    "Source: $REPO_URL\nSummary: $SUMMARY" \
    "sleep-research,install,autonomous,claude" 2>/dev/null || true
fi

# ──────────────────────────────────────────────────────────────────
# 3. Create Jit integration config
# ──────────────────────────────────────────────────────────────────
cat > "$QUEUE_DIR/config.json" << 'CONFIGEOF'
{
  "_comment": "Auto-claude-code-research-in-sleep × Jit integration config",
  "source_repo": "https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep",
  "mdes_endpoint": "https://ollama.mdes-innova.online",
  "oracle_url": "http://localhost:47778",
  "models": {
    "researcher": "gemma4:26b",
    "analyzer": "qwen3.5:27b",
    "coder": "qwen2.5-coder:32b",
    "synthesizer": "gemma4:26b"
  },
  "schedule": {
    "enabled": false,
    "cron": "0 2 * * *",
    "_comment": "Run at 2 AM daily. Set enabled=true and add to crontab manually."
  },
  "output": {
    "oracle_learn": true,
    "discord_notify": true,
    "save_markdown": true,
    "output_dir": "memory/sleep-research/results"
  },
  "agent_notify": "jit",
  "report_channel": "hermes-discord"
}
CONFIGEOF

mkdir -p "$QUEUE_DIR/results" "$QUEUE_DIR/queue"

# ──────────────────────────────────────────────────────────────────
# 4. Register cron hint (user must enable manually)
# ──────────────────────────────────────────────────────────────────
CRON_CMD="0 2 * * * cd $JIT_ROOT && bash .github/skills/sleep-research/run.sh --run-queue 2>&1 >> /tmp/jit-sleep-research.log"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Installation complete!"
echo ""
echo "📁 Install dir:  $_INSTALL_DIR" 2>/dev/null || echo "📁 Install dir:  $INSTALL_DIR"
echo "📁 Queue dir:    $QUEUE_DIR"
echo "📁 Config:       $QUEUE_DIR/config.json"
echo ""
echo "▶️  Manual cron (add with: crontab -e):"
echo "   $CRON_CMD"
echo ""
echo "▶️  Run now:  bash .github/skills/sleep-research/run.sh"
echo "▶️  Queue:    bash .github/skills/sleep-research/run.sh --queue 'research topic here'"
