#!/usr/bin/env bash
# sleep-research/run.sh — Autonomous overnight research daemon
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true

QUEUE_DIR="$JIT_ROOT/memory/sleep-research/queue"
RESULTS_DIR="$JIT_ROOT/memory/sleep-research/results"
LOG="$JIT_ROOT/memory/sleep-research/run.log"
mkdir -p "$QUEUE_DIR" "$RESULTS_DIR"

MODE="${1:---help}"

_mdes_call() {
  local MODEL="$1" PROMPT="$2" TIMEOUT="${3:-90}"
  local BODY
  BODY=$(python3 -c "import json,sys; print(json.dumps({'model':'$MODEL','prompt':sys.stdin.read(),'stream':False}))" <<< "$PROMPT" 2>/dev/null)
  curl -sf --max-time "$TIMEOUT" "https://ollama.mdes-innova.online/api/generate" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OLLAMA_TOKEN:-}" \
    --data "$BODY" 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null || echo ""
}

_log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

_research_topic() {
  local TOPIC="$1"
  local SLUG
  SLUG=$(echo "$TOPIC" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | cut -c1-40)
  local DATE
  DATE=$(date +%Y-%m-%d)
  local OUT="$RESULTS_DIR/${DATE}_${SLUG}.md"

  _log "🔬 Researching: $TOPIC"

  # Oracle context
  ORACLE_CTX=$(bash "$JIT_ROOT/limbs/oracle.sh" search "$TOPIC" 5 2>/dev/null | head -30 || true)

  # Step 1: General research (gemma4:26b)
  RESEARCH=$(_mdes_call "gemma4:26b" "คุณคือ innova นักวิจัย AI

หัวข้อ: $TOPIC
${ORACLE_CTX:+Oracle context: $ORACLE_CTX}

วิจัยและสรุป:
1. **สถานะปัจจุบัน** — อะไรกำลังเป็นที่นิยม/เปลี่ยนแปลง
2. **Best Practices** — 3-5 patterns ที่ดีที่สุด
3. **ปัญหาที่พบบ่อย** — pitfalls ที่ต้องระวัง
4. **Jit Relevance** — เกี่ยวข้องกับ MDES/Jit system อย่างไร
5. **Action Items** — สิ่งที่ควรทำสำหรับ innova team

ภาษาไทย" 90)

  # Step 2: Deep analysis (qwen3.5:27b)
  DEEP=$(_mdes_call "qwen3.5:27b" "วิเคราะห์เชิงลึก: $TOPIC

Research summary:
$RESEARCH

เพิ่มเติม:
- Hidden insights ที่ research ไม่ได้กล่าวถึง
- Trade-offs ที่สำคัญ
- Long-term implications

ภาษาไทย" 90)

  # Step 3: Code patterns (qwen2.5-coder:32b) — only for tech topics
  CODE_SECTION=""
  if echo "$TOPIC" | grep -qiE "code|api|library|framework|implement|script|function|class|tool|cli|node|python|bash|js"; then
    CODE_SECTION=$(_mdes_call "qwen2.5-coder:32b" "Implementation patterns for: $TOPIC

Context: Jit multiagent system (Node.js CommonJS + bash + MDES Ollama)

Show:
1. Key code snippets / patterns
2. Integration example with Jit organs
3. Common gotchas" 90)
  fi

  # Save result
  cat > "$OUT" << RESULTEOF
# Research: $TOPIC

**Date**: $DATE
**Status**: COMPLETE
**Oracle**: research:$DATE:$SLUG

## 📋 General Research (gemma4:26b)
$RESEARCH

## 🔬 Deep Analysis (qwen3.5:27b)
$DEEP

${CODE_SECTION:+## 💻 Code Patterns (qwen2.5-coder:32b)
$CODE_SECTION}

## 🔗 Sources
- Oracle context: $(echo "$ORACLE_CTX" | wc -l) records
- MDES Ollama: gemma4:26b + qwen3.5:27b + qwen2.5-coder:32b
RESULTEOF

  _log "✅ Saved: $(basename $OUT)"

  # Oracle learn
  COMBINED="$RESEARCH\n\nDeep: $DEEP\n\n${CODE_SECTION}"
  bash "$JIT_ROOT/limbs/oracle.sh" learn \
    "research:$DATE:$SLUG" \
    "$COMBINED" \
    "research,overnight,$SLUG,$DATE" 2>/dev/null || true

  # Notify jit
  bash "$JIT_ROOT/organs/mouth.sh" tell jit \
    "report:research-done" \
    "🌙 Research complete: $TOPIC → Oracle: research:$DATE:$SLUG" 2>/dev/null || true

  echo "$OUT"
}

case "$MODE" in

  --queue|-q)
    TOPIC="${*:2}"
    [ -z "$TOPIC" ] && { err "ระบุ topic: --queue 'research topic'"; exit 1; }
    QFILE="$QUEUE_DIR/$(date +%s)_$(echo "$TOPIC" | tr ' ' '-' | cut -c1-40).txt"
    echo "$TOPIC" > "$QFILE"
    ok "Queued: $TOPIC"
    echo "   File: $QFILE"
    echo "   Queue size: $(ls "$QUEUE_DIR"/*.txt 2>/dev/null | wc -l) items"
    ;;

  --run-queue|--run)
    ITEMS=$(ls "$QUEUE_DIR"/*.txt 2>/dev/null || true)
    if [ -z "$ITEMS" ]; then
      info "Queue is empty. Add topics with: --queue 'topic'"
      exit 0
    fi
    COUNT=$(echo "$ITEMS" | wc -l | tr -d ' ')
    _log "🌙 Starting overnight research run: $COUNT items"
    DONE=0
    while IFS= read -r QFILE; do
      TOPIC=$(cat "$QFILE")
      _research_topic "$TOPIC" || _log "⚠️ Failed: $TOPIC"
      DONE=$((DONE + 1))
      rm -f "$QFILE"
      sleep 2  # กันไม่ให้ hammering
    done <<< "$ITEMS"
    _log "🏁 Research run complete: $DONE/$COUNT topics"
    # Morning report via Discord
    bash "$JIT_ROOT/organs/nerve.sh" signal \
      "research:batch-done" \
      "Overnight research: $DONE topics completed" 2>/dev/null || true
    ;;

  --now|-n)
    TOPIC="${*:2}"
    [ -z "$TOPIC" ] && { err "ระบุ topic: --now 'research topic'"; exit 1; }
    step "🔬 Researching now: $TOPIC"
    OUTFILE=$(_research_topic "$TOPIC")
    echo ""
    cat "$OUTFILE"
    ;;

  --status|-s)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌙 Sleep Research Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Queue: $(ls "$QUEUE_DIR"/*.txt 2>/dev/null | wc -l) items"
    [ -d "$QUEUE_DIR" ] && ls "$QUEUE_DIR"/*.txt 2>/dev/null | while read f; do echo "  • $(cat $f)"; done || true
    echo ""
    echo "Results (last 5):"
    ls -t "$RESULTS_DIR"/*.md 2>/dev/null | head -5 | while read f; do echo "  ✅ $(basename $f)"; done || echo "  (none yet)"
    echo ""
    echo "Log (last 10 lines):"
    tail -10 "$LOG" 2>/dev/null || echo "  (no log yet)"
    ;;

  --install)
    bash "$JIT_ROOT/scripts/install-sleep-research.sh"
    ;;

  --claude)
    # Use Claude CLI as sub-agent researcher
    TOPIC="${*:2}"
    [ -z "$TOPIC" ] && { err "ระบุ topic: --claude 'topic'"; exit 1; }
    if ! command -v claude &>/dev/null; then
      warn "claude CLI not found — falling back to --now"
      bash "$0" --now "$TOPIC"
      exit 0
    fi
    step "🤖 Claude CLI research: $TOPIC"
    claude --print "You are innova (Lead Developer of Jit multiagent system).
Research this topic and save to Oracle:

Topic: $TOPIC
Oracle URL: http://localhost:47778
Jit root: $JIT_ROOT

Steps:
1. bash $JIT_ROOT/limbs/oracle.sh search '$TOPIC' 10
2. bash $JIT_ROOT/.github/skills/brave-search/run.sh '$TOPIC' 2>/dev/null
3. Synthesize findings
4. bash $JIT_ROOT/limbs/oracle.sh learn 'research:$(date +%Y-%m-%d):$TOPIC' [findings] 'research,claude'

Be thorough. Save complete findings."
    ;;

  --help|*)
    echo "🌙 sleep-research — Jit Overnight Research Daemon"
    echo ""
    echo "Usage:"
    echo "  bash run.sh --queue 'topic'      Queue a research topic"
    echo "  bash run.sh --run-queue           Process all queued topics"
    echo "  bash run.sh --now 'topic'         Research now (immediate)"
    echo "  bash run.sh --status              Show queue + recent results"
    echo "  bash run.sh --claude 'topic'      Use Claude CLI as sub-agent"
    echo "  bash run.sh --install             Install from GitHub + setup"
    echo ""
    echo "Source: https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep"
    ;;
esac
