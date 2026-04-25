#!/usr/bin/env bash
# scripts/innova-startup.sh — Master startup: tmux session with 3 windows
#
# Windows:
#   0 "claude"  — Claude TUI
#   1 "innova"  — minds/innova-life.sh autonomous loop
#   2 "voice"   — Bun voice bridge server (port 3333)
#
# Usage:
#   bash scripts/innova-startup.sh         # Start everything
#   bash scripts/innova-startup.sh --force # Kill existing session first

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh" 2>/dev/null || true

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

SESSION="manusat-main"
CLAUDE_PANE_FILE="/tmp/claude-pane.txt"
FORCE="${1:-}"

CYAN='\\033[0;36m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
RED='\\033[0;31m'
BOLD='\\033[1m'
RESET='\\033[0m'

# ─── Install dependencies ──────────────────────────────────────────────
install_deps() {
  echo -e "${BOLD}[1/3] ตรวจสอบ dependencies...${RESET}"

  if ! which tmux > /dev/null 2>&1; then
    echo -e "  ${YELLOW}tmux ไม่พบ — กำลังติดตั้ง...${RESET}"
    if sudo apt-get install -y tmux 2>/dev/null; then
      echo -e "  ${GREEN}✅ tmux ติดตั้งแล้ว$(tmux -V)${RESET}"
    else
      echo -e "  ${RED}❌ ติดตั้ง tmux ไม่ได้ — ลอง: sudo apt-get install tmux${RESET}"
      exit 1
    fi
  else
    echo -e "  ${GREEN}✅ tmux: $(tmux -V)${RESET}"
  fi

  if ! which bun > /dev/null 2>&1; then
    if [ -f "$HOME/.bun/bin/bun" ]; then
      export PATH="$HOME/.bun/bin:$PATH"
      echo -e "  ${GREEN}✅ bun: $(bun --version) (from ~/.bun/bin)${RESET}"
    else
      echo -e "  ${YELLOW}bun ไม่พบ — กำลังติดตั้ง...${RESET}"
      curl -fsSL https://bun.sh/install | bash
      export PATH="$HOME/.bun/bin:$PATH"
      echo -e "  ${GREEN}✅ bun ติดตั้งแล้ว${RESET}"
    fi
  else
    echo -e "  ${GREEN}✅ bun: $(bun --version)${RESET}"
  fi
}

# ─── Check if already running ──────────────────────────────────────────
check_existing() {
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    if [ "$FORCE" = "--force" ]; then
      echo -e "${YELLOW}⚠️  Session '$SESSION' มีอยู่แล้ว — force kill...${RESET}"
      tmux kill-session -t "$SESSION" 2>/dev/null || true
      sleep 1
      return 0
    fi
    echo -e "${GREEN}✅ Session '$SESSION' ทำงานอยู่แล้ว${RESET}"
    echo ""
    echo -e "  Attach:  ${CYAN}tmux attach-session -t $SESSION${RESET}"
    echo -e "  Windows: ${CYAN}tmux list-windows -t $SESSION${RESET}"
    echo -e "  Stop:    ${CYAN}bash scripts/innova-remote.sh stop${RESET}"
    echo ""
    tmux list-windows -t "$SESSION" 2>/dev/null | sed 's/^/  /'
    exit 0
  fi
}

# ─── Create tmux session ───────────────────────────────────────────────
create_session() {
  echo -e "${BOLD}[2/3] สร้าง tmux session '$SESSION'...${RESET}"
  echo ""

  echo -e "  ${CYAN}→ Window 0 'claude': running claude TUI${RESET}"
  tmux new-session -d -s "$SESSION" -n "claude" \
    "cd '$JIT_ROOT' && claude; bash -i"

  local CLAUDE_PANE
  CLAUDE_PANE=$(tmux display-message -t "${SESSION}:0" -p "#{session_name}:#{window_index}.#{pane_index}" 2>/dev/null || echo "${SESSION}:0.0")
  echo "$CLAUDE_PANE" > "$CLAUDE_PANE_FILE"
  echo -e "  ${GREEN}✅ claude pane: $CLAUDE_PANE (saved to $CLAUDE_PANE_FILE)${RESET}"

  echo -e "  ${CYAN}→ Window 1 'innova': running minds/innova-life.sh${RESET}"
  tmux new-window -t "$SESSION" -n "innova" \
    "cd '$JIT_ROOT' && bash minds/innova-life.sh listen; bash -i"

  sleep 1

  echo -e "  ${CYAN}→ Window 2 'voice': running Bun voice server (port 3333)${RESET}"
  tmux new-window -t "$SESSION" -n "voice" \
    "export PATH='$HOME/.bun/bin:\$PATH' && cd '$JIT_ROOT' && bun run voice/server.ts; bash -i"

  tmux select-window -t "${SESSION}:0"

  sleep 2

  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo ""
    echo -e "  ${GREEN}✅ Session '$SESSION' เริ่มแล้ว!${RESET}"
    return 0
  else
    echo -e "  ${RED}❌ Session ไม่ได้เริ่ม — ตรวจสอบ tmux log${RESET}"
    return 1
  fi
}

# ─── Print instructions ────────────────────────────────────────────────
print_instructions() {
  echo ""
  echo -e "${BOLD}[3/3] วิธีใช้งาน:${RESET}"
  echo ""
  echo -e "  ${BOLD}Attach ไปที่ session:${RESET}"
  echo -e "    ${CYAN}tmux attach-session -t $SESSION${RESET}"
  echo ""
  echo -e "  ${BOLD}Windows:${RESET}"
  echo -e "    Ctrl+B, 0  → claude TUI  (voice injection target)"
  echo -e "    Ctrl+B, 1  → innova life loop"
  echo -e "    Ctrl+B, 2  → voice server"
  echo -e "    Ctrl+B, d  → detach (keep running)"
  echo ""
  echo -e "  ${BOLD}Voice UI:${RESET}"
  echo -e "    เปิด browser ไปที่ port 3333"
  echo -e "    (Codespace: Forward port 3333 แล้วเปิด URL)"
  echo ""
  echo -e "  ${BOLD}Claude pane target:${RESET}"
  cat "$CLAUDE_PANE_FILE" 2>/dev/null | sed 's/^/    /'
  echo ""
  echo -e "  ${BOLD}ควบคุมผ่าน:${RESET}"
  echo -e "    ${CYAN}bash scripts/innova-remote.sh status${RESET}"
  echo -e "    ${CYAN}bash scripts/innova-remote.sh stop${RESET}"
  echo -e "    ${CYAN}bash scripts/innova-remote.sh log${RESET}"
  echo ""
}

# ─── Banner ────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║     innova Startup — มนุษย์ Agent Life System           ║"
echo "  ║     🧠 จิต · 🎧 เสียง · 🤖 claude · $(date '+%Y-%m-%d %H:%M') ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

install_deps
check_existing
create_session
print_instructions
