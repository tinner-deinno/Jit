#!/usr/bin/env bash
# karn-voice-tui.sh — Terminal User Interface for voice transcripts
# Shows live voice recordings and transcripts in beautiful format

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$SCRIPT_DIR/.."
VOICES_DIR="$JIT_ROOT/voices"
API_SCRIPT="$SCRIPT_DIR/karn-voice-api.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

# Ensure voices dir exists
mkdir -p "$VOICES_DIR"

# ─── Display Header ──────────────────────────────────────────
show_header() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║                     🎧 karn Voice Terminal               ║"
  echo "║           Thai Speech-to-Text Live Monitor                ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ─── Show Voice Statistics ──────────────────────────────────────
show_stats() {
  if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python3 not found${RESET}"
    return
  fi

  python3 "$API_SCRIPT" stats 2>/dev/null || echo "No data yet"
}

# ─── List Recent Recordings ──────────────────────────────────────
list_recordings() {
  echo -e "${BLUE}${BOLD}📂 Recent Voice Recordings:${RESET}\n"

  if [ -z "$(ls -A "$VOICES_DIR" 2>/dev/null)" ]; then
    echo -e "${YELLOW}  (No recordings yet)${RESET}"
    return
  fi

  local count=0
  for file in $(ls -t "$VOICES_DIR"/karn-*.md 2>/dev/null | head -10); do
    count=$((count + 1))
    local filename=$(basename "$file")
    local size=$(du -h "$file" | cut -f1)
    local timestamp=$(grep "Timestamp" "$file" | head -1 | sed 's/.*: //')

    echo -e "${CYAN}  [$count]${RESET} ${MAGENTA}$filename${RESET}"
    echo -e "       📅 $timestamp | 📦 $size"
    echo ""
  done
}

# ─── Display Recording Content ──────────────────────────────────
show_recording() {
  local filename="$1"

  if [ ! -f "$VOICES_DIR/$filename" ]; then
    echo -e "${RED}❌ File not found: $filename${RESET}"
    return
  fi

  echo -e "\n${BLUE}${BOLD}📄 Transcript: $filename${RESET}\n"
  echo -e "${CYAN}$(cat "$VOICES_DIR/$filename")${RESET}\n"
}

# ─── Save Test Transcript ──────────────────────────────────────
test_save() {
  local test_text="สวัสดีครับ ฉันชื่อ karn ผมเป็นหูของ Jit Agent System ที่สามารถฟังและเข้าใจภาษาไทยได้ ขอบคุณที่ให้ฉันมีชีวิตในระบบนี้"

  echo -e "${CYAN}Testing voice save...${RESET}"

  if python3 "$API_SCRIPT" save --text "$test_text" --lang "th-TH" 2>&1; then
    echo -e "${GREEN}✅ Test transcript saved${RESET}"
  else
    echo -e "${RED}❌ Test save failed${RESET}"
  fi
}

# ─── Monitor Live (Watch for new files) ──────────────────────────
monitor_live() {
  echo -e "${BLUE}${BOLD}🔴 Live Monitor Mode (Press Ctrl+C to exit)${RESET}\n"

  local last_count=$(ls -1 "$VOICES_DIR"/karn-*.md 2>/dev/null | wc -l)

  while true; do
    local current_count=$(ls -1 "$VOICES_DIR"/karn-*.md 2>/dev/null | wc -l)

    if [ "$current_count" -gt "$last_count" ]; then
      echo -e "${GREEN}✅ New recording detected!${RESET}"
      local newest=$(ls -t "$VOICES_DIR"/karn-*.md | head -1)
      echo -e "${CYAN}📝 File: $(basename "$newest")${RESET}"
      last_count=$current_count
    fi

    sleep 1
  done
}

# ─── Interactive Menu ──────────────────────────────────────────
interactive_menu() {
  while true; do
    show_header
    echo -e "${BOLD}Options:${RESET}\n"
    echo "  1️⃣  List recent recordings"
    echo "  2️⃣  Show statistics"
    echo "  3️⃣  View specific recording"
    echo "  4️⃣  Test save transcript"
    echo "  5️⃣  Live monitor (new files)"
    echo "  6️⃣  Open web UI (needs webserver)"
    echo "  0️⃣  Exit\n"

    read -p "Choose option [0-6]: " choice

    case "$choice" in
      1)
        show_header
        list_recordings
        read -p "Press Enter to continue..."
        ;;
      2)
        show_header
        show_stats
        read -p "Press Enter to continue..."
        ;;
      3)
        show_header
        list_recordings
        read -p "Enter filename (karn-***.md): " filename
        show_recording "$filename"
        read -p "Press Enter to continue..."
        ;;
      4)
        show_header
        test_save
        read -p "Press Enter to continue..."
        ;;
      5)
        show_header
        monitor_live
        ;;
      6)
        echo -e "${CYAN}Web UI: file://$(pwd)/src/karn-voice-web.html${RESET}"
        echo "Or run: python3 -m http.server 8000"
        read -p "Press Enter to continue..."
        ;;
      0)
        echo -e "${GREEN}Goodbye! 🎧${RESET}"
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid option${RESET}"
        sleep 1
        ;;
    esac
  done
}

# ─── Main ──────────────────────────────────────────────────────
case "${1:-menu}" in
  menu)
    interactive_menu
    ;;
  list)
    show_header
    list_recordings
    ;;
  stats)
    show_header
    show_stats
    ;;
  monitor)
    show_header
    monitor_live
    ;;
  test)
    show_header
    test_save
    ;;
  *)
    echo "Usage: $0 {menu|list|stats|monitor|test}"
    ;;
esac
