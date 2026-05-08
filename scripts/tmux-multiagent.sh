#!/usr/bin/env bash
# ============================================================
#  tmux-multiagent.sh — INNOVA Multiagent Professional Display
#
#  Layout (3×3 grid + status bar):
#  ┌──────────────┬──────────────┬──────────────┐
#  │  INNOVA      │  PLANNER     │  CODER       │
#  │  gemma4:26b  │ qwen3.5:27b  │qwen2.5-c:32b │
#  ├──────────────┼──────────────┼──────────────┤
#  │  RESEARCHER  │  REVIEWER    │  EMOTION     │
#  │  llama3.1:8b │deepseek-c:33b│ qwen3.5:9b   │
#  ├──────────────┼──────────────┼──────────────┤
#  │  ORACLE      │  HERMES BOT  │  GIT STATUS  │
#  │  phi3:medium │  AnuT1n log  │  git watch   │
#  └──────────────┴──────────────┴──────────────┘
#
#  Usage:
#    bash scripts/tmux-multiagent.sh          # start
#    bash scripts/tmux-multiagent.sh stop     # kill session
#    bash scripts/tmux-multiagent.sh attach   # attach
# ============================================================

SESSION="innova"
JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
MIND="$JIT_ROOT/scripts/mind-loop.sh"
BOT_LOG="/tmp/anu_t1n_bot.log"
GIT_CP="$JIT_ROOT/scripts/git-checkpoint.sh"

# ── Colors ───────────────────────────────────────────────────
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
B='\033[1;34m'; M='\033[1;35m'; C='\033[1;36m'
W='\033[1;37m'; NC='\033[0m'

print_banner() {
  echo -e "${M}"
  echo '╔══════════════════════════════════════════════════════════════════╗'
  echo '║     🧠  INNOVA MULTIAGENT SYSTEM  ·  hermes × GSD               ║'
  echo '║     7 AGENTS · MDES Ollama · tmux Professional Layout           ║'
  echo '╚══════════════════════════════════════════════════════════════════╝'
  echo -e "${NC}"
}

# ── Handle args ──────────────────────────────────────────────
case "${1:-start}" in
  stop)
    tmux kill-session -t "$SESSION" 2>/dev/null && \
      echo -e "${Y}[tmux] Session '$SESSION' killed.${NC}" || \
      echo -e "${R}[tmux] No session '$SESSION' found.${NC}"
    exit 0
    ;;
  attach)
    exec tmux attach -t "$SESSION"
    ;;
  status)
    tmux list-sessions 2>/dev/null | grep "$SESSION" || echo "No session."
    exit 0
    ;;
esac

print_banner

# ── Pre-flight checks ─────────────────────────────────────────
echo -e "${C}[CHECK] tmux: $(tmux -V)${NC}"
echo -e "${C}[CHECK] JIT_ROOT: $JIT_ROOT${NC}"
echo -e "${C}[CHECK] mind-loop: $MIND${NC}"
[[ -f "$MIND" ]] || { echo -e "${R}[ERROR] mind-loop.sh not found!${NC}"; exit 1; }

chmod +x "$MIND"
[[ -f "$GIT_CP" ]] && chmod +x "$GIT_CP"

# Kill existing session
tmux kill-session -t "$SESSION" 2>/dev/null && \
  echo -e "${Y}[tmux] Killed existing '$SESSION' session.${NC}"

mkdir -p /tmp/manusat-bus

# ── tmux Config ───────────────────────────────────────────────
# Use 200-col wide terminal for professional look
tmux new-session -d -s "$SESSION" -x 220 -y 55

# ── tmux status bar config ────────────────────────────────────
tmux set-option -t "$SESSION" status on
tmux set-option -t "$SESSION" status-interval 5
tmux set-option -t "$SESSION" status-left-length 40
tmux set-option -t "$SESSION" status-right-length 80
tmux set-option -t "$SESSION" status-style "bg=colour235,fg=colour255"
tmux set-option -t "$SESSION" status-left "#[fg=colour213,bold] 🧠 INNOVA  #[fg=colour240]│ "
tmux set-option -t "$SESSION" status-right \
  "#[fg=colour82]⬡ $(date '+%H:%M') #[fg=colour240]│ #[fg=colour39]#H #[fg=colour240]│ #[fg=colour220]7 AGENTS LIVE"
tmux set-option -t "$SESSION" window-status-current-style "fg=colour213,bold"
tmux set-option -t "$SESSION" pane-border-style "fg=colour240"
tmux set-option -t "$SESSION" pane-active-border-style "fg=colour213"

# ── Window 0: MULTIAGENT GRID ─────────────────────────────────
tmux rename-window -t "$SESSION:0" "🧠 INNOVA-MULTIAGENT"

# Start with pane 0 = INNOVA MOTHER (top-left)
# Split into 3 columns first
tmux send-keys -t "$SESSION:0.0" \
  "bash '$MIND' INNOVA gemma4:26b 'Mother orchestrator, oversees all agents, speaks Thai, wise and decisive' 90" Enter

# Split right → PLANNER (pane 1)
tmux split-window -t "$SESSION:0.0" -h -p 67
tmux send-keys -t "$SESSION:0.1" \
  "bash '$MIND' PLANNER qwen3.5:27b 'Strategic planner, breaks problems into steps, prioritizes tasks' 95" Enter

# Split right again → CODER (pane 2)
tmux split-window -t "$SESSION:0.1" -h -p 50
tmux send-keys -t "$SESSION:0.2" \
  "bash '$MIND' CODER qwen2.5-coder:32b 'Senior software engineer, writes and reviews code, focuses on correctness' 100" Enter

# ── Row 2: split each top pane downward ──────────────────────
# Split INNOVA pane down → RESEARCHER (pane 3)
tmux select-pane -t "$SESSION:0.0"
tmux split-window -t "$SESSION:0.0" -v -p 40
tmux send-keys -t "$SESSION:0.3" \
  "bash '$MIND' RESEARCHER llama3.1:8b 'Research analyst, gathers facts, verifies information, cites sources' 110" Enter

# Split PLANNER pane down → REVIEWER (pane 4)
tmux select-pane -t "$SESSION:0.1"
tmux split-window -t "$SESSION:0.1" -v -p 40
tmux send-keys -t "$SESSION:0.4" \
  "bash '$MIND' REVIEWER deepseek-coder:33b 'Code reviewer and quality auditor, identifies bugs and security issues' 115" Enter

# Split CODER pane down → EMOTION (pane 5)
tmux select-pane -t "$SESSION:0.2"
tmux split-window -t "$SESSION:0.2" -v -p 40
tmux send-keys -t "$SESSION:0.5" \
  "bash '$MIND' EMOTION qwen3.5:9b 'Emotion and sentiment agent, monitors team morale and user wellbeing' 120" Enter

# ── Row 3: bottom status row ─────────────────────────────────
# Split RESEARCHER down → ORACLE (pane 6)
tmux select-pane -t "$SESSION:0.3"
tmux split-window -t "$SESSION:0.3" -v -p 35
tmux send-keys -t "$SESSION:0.6" \
  "bash '$MIND' ORACLE phi3:medium 'Memory oracle, stores and retrieves knowledge, maintains system history' 130" Enter

# Split REVIEWER down → HERMES BOT LOG (pane 7)
tmux select-pane -t "$SESSION:0.4"
tmux split-window -t "$SESSION:0.4" -v -p 35
tmux send-keys -t "$SESSION:0.7" \
  "printf '\033[1;36m╔══ HERMES DISCORD BOT — AnuT1n#9232 ══════════════╗\033[0m\n'; \
   printf '\033[1;36m║  Platform: Discord  ·  Prefix: !AnuT1n            ║\033[0m\n'; \
   printf '\033[1;36m╚════════════════════════════════════════════════════╝\033[0m\n'; \
   touch '$BOT_LOG'; tail -f '$BOT_LOG'" Enter

# Split EMOTION down → GIT STATUS (pane 8)
tmux select-pane -t "$SESSION:0.5"
tmux split-window -t "$SESSION:0.5" -v -p 35
tmux send-keys -t "$SESSION:0.8" \
  "printf '\033[1;33m╔══ GIT CHECKPOINT — mdes-innova-th/Jit ════════════╗\033[0m\n'; \
   printf '\033[1;33m║  Manual commit: bash scripts/git-checkpoint.sh     ║\033[0m\n'; \
   printf '\033[1;33m╚════════════════════════════════════════════════════╝\033[0m\n'; \
   cd '$JIT_ROOT' && while true; do \
     printf \"\n\033[1;33m[%s] git status:\033[0m\n\" \"\$(date +%H:%M:%S)\"; \
     git status --short 2>/dev/null | head -15; \
     printf \"\033[2m--- last 3 commits ---\033[0m\n\"; \
     git log --oneline -3 2>/dev/null; \
     sleep 60; \
   done" Enter

# ── Window 1: AGENT THOUGHTS LOG ─────────────────────────────
tmux new-window -t "$SESSION:1" -n "📋 THOUGHTS"
tmux send-keys -t "$SESSION:1" \
  "printf '\033[1;35m╔══ AGENT THOUGHT STREAM ══════════════════════════════════════════╗\033[0m\n'; \
   printf '\033[1;35m║  Live feed from all 7 agents via /tmp/manusat-bus/               ║\033[0m\n'; \
   printf '\033[1;35m╚══════════════════════════════════════════════════════════════════╝\033[0m\n'; \
   while true; do \
     printf \"\n\033[1m=== $(date '+%Y-%m-%d %H:%M:%S') ===\033[0m\n\"; \
     for f in /tmp/agent-*.log; do \
       [[ -f \"\$f\" ]] || continue; \
       agent=\$(basename \"\$f\" .log | sed 's/agent-//' | tr a-z A-Z); \
       last=\$(tail -1 \"\$f\" 2>/dev/null); \
       [[ -n \"\$last\" ]] && printf '\033[1;36m[%s]\033[0m %s\n' \"\$agent\" \"\${last:0:120}\"; \
     done; \
     sleep 30; \
   done" Enter

# ── Window 2: BUS MONITOR ─────────────────────────────────────
tmux new-window -t "$SESSION:2" -n "🔗 BUS"
tmux send-keys -t "$SESSION:2" \
  "printf '\033[1;32m╔══ MANUSAT MESSAGE BUS — /tmp/manusat-bus/ ═══════════════════════╗\033[0m\n'; \
   printf '\033[1;32m║  Real-time inter-agent communication channel                      ║\033[0m\n'; \
   printf '\033[1;32m╚═══════════════════════════════════════════════════════════════════╝\033[0m\n'; \
   while true; do \
     printf \"\n\033[1m=== BUS SNAPSHOT @ \$(date '+%H:%M:%S') ===\033[0m\n\"; \
     for f in /tmp/manusat-bus/*.msg; do \
       [[ -f \"\$f\" ]] || continue; \
       agent=\$(basename \"\$f\" .msg | tr a-z A-Z); \
       printf '\033[1;33m[%s]\033[0m ' \"\$agent\"; cat \"\$f\" 2>/dev/null | fold -s -w 80; \
       echo ''; \
     done; \
     sleep 15; \
   done" Enter

# ── Select Window 0 main view ─────────────────────────────────
tmux select-window -t "$SESSION:0"
tmux select-pane -t "$SESSION:0.0"

echo ""
echo -e "${G}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${G}║  ✅  INNOVA MULTIAGENT SYSTEM LAUNCHED SUCCESSFULLY              ║${NC}"
echo -e "${G}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${G}║  SESSION: $SESSION                                               ║${NC}"
echo -e "${G}║  AGENTS:  7 (INNOVA · PLANNER · CODER · RESEARCHER ·            ║${NC}"
echo -e "${G}║           REVIEWER · EMOTION · ORACLE)                          ║${NC}"
echo -e "${G}║  WINDOWS: 0=Grid  1=Thoughts  2=Bus                             ║${NC}"
echo -e "${G}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${G}║  ATTACH:  tmux attach -t $SESSION                                ║${NC}"
echo -e "${G}║  DETACH:  Ctrl+B, D                                             ║${NC}"
echo -e "${G}║  SWITCH:  Ctrl+B, [0-2]  or  Ctrl+B, n                         ║${NC}"
echo -e "${G}║  PANES:   Ctrl+B, arrow keys                                    ║${NC}"
echo -e "${G}║  STOP:    bash scripts/tmux-multiagent.sh stop                  ║${NC}"
echo -e "${G}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${M}Auto-attaching in 3 seconds... (Ctrl+C to skip)${NC}"
sleep 3
exec tmux attach -t "$SESSION"
