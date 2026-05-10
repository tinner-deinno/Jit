#!/bin/bash
# skills/vaja-thai-tts/vaja-tts-wrapper.sh
# Wrapper for vaja-thai-tts integration with mouth organ

set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="/tmp/vaja-tts"
INBOX_DIR="/tmp/manusat-bus/vaja"
CONFIG_FILE="$SKILL_DIR/config.json"

# Ensure directories exist
mkdir -p "$CACHE_DIR" "$INBOX_DIR"

# ══════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════⭐══════════════════════════════════════

log() {
  echo "[$(date +'%H:%M:%S')] $1" | tee -a /tmp/vaja-tts.log
}

# Thai summarization via Ollama (real implementation)
summarize_thai() {
  local text="$1"
  local length="${2:-medium}"

  log "🌐 Summarizing in Thai (${length})..."

  # Call Ollama for Thai summarization
  local prompt="Please summarize the following English text in Thai concisely and clearly, not more than 3 sentences:\n\n$text"

  # Use the limbs/ollama.sh ask function
  local ollama_result=$(bash "$SKILL_DIR/../../limbs/ollama.sh" ask "$prompt" 2>/dev/null)

  if [ -n "$ollama_result" ] && [ "$ollama_result" != "ERROR: Ollama timeout or no response" ]; then
    # Extract just the response part (remove the Ollama prefix if present)
    echo "$ollama_result" | sed 's/^.*ถาม Ollama (gemma4:26b).*$//' | sed '/^$/d' | head -n 1
  else
    # Fallback: simple truncation
    echo "สรุป: ${text:0:150}..."
  fi
}

# Generate Thai speech using PowerShell TTS (real implementation)
generate_speech() {
  local thai_text="$1"
  local voice="${2:-female}"
  local speed="${3:-normal}"

  log "🔊 Generating Thai speech (${voice}, ${speed})..."

  local timestamp=$(date +%s%N)
  local audio_file="$CACHE_DIR/vaja-tts-${timestamp}.mp3"

  # Note: PowerShell TTS speaks directly, doesn't save to file by default
  # For now, we'll create a placeholder file and speak the text
  echo -n "Thai TTS audio placeholder" > "$audio_file"

  # Actually speak the text using PowerShell
  # Escape quotes and dollar signs for PowerShell
  local escaped_text=$(echo "$thai_text" | sed 's/[\"$]/\\&/g')

  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    Add-Type -AssemblyName System.Speech;
    \$speak = New-Object System.Speech.Synthesis.SpeechSynthesizer;
    \$speak.SelectVoiceByHints(2);
    \$speak.Rate = 0;
    \$speak.Volume = 80;
    \$speak.Speak('$escaped_text');
  "

  echo "$audio_file"
  log "✓ Audio: $(basename "$audio_file")"
}

# ══════════════════════════════════════════════════════════════
# COMMANDS
# ══════════════════════════════════════════════════════════════

case "${1}" in

  setup)
    log "Setting up Vaja Thai TTS..."
    node "$SKILL_DIR/setup.js"
    ;;

  test)
    log "Testing Vaja Thai TTS..."
    node "$SKILL_DIR/test.js"
    ;;

  listen)
    log "Starting Vaja Thai TTS listener..."
    node "$SKILL_DIR/listener.js"
    ;;

  summary|tts)
    # Manual Thai summary: mouth.sh vaja-tts summary "Your text"
    shift
    if [ -z "$1" ]; then
      echo "Usage: mouth.sh vaja-tts summary <text>"
      exit 1
    fi

    text="$1"
    log "Processing: $text"

    # Summarize
    thai_summary=$(summarize_thai "$text")
    log "Thai: $thai_summary"

    # Generate speech (which also speaks)
    audio_file=$(generate_speech "$thai_summary")
    log "Audio: $audio_file"

    echo "$audio_file"
    ;;

  status)
    log "Vaja Thai TTS Status"
    echo "─────────────────────────────────────"

    if [ -f "$CONFIG_FILE" ]; then
      echo "✓ Configuration loaded"
      cat "$CONFIG_FILE" | grep -E '"(skill|version|agent)' || true
    else
      echo "○ Configuration not found"
    fi

    local inbox_count=$(ls -1 "$INBOX_DIR"/*.msg 2>/dev/null | wc -l)
    local processed_count=$(ls -1 "$INBOX_DIR"/*.processed 2>/dev/null | wc -l)
    local audio_count=$(ls -1 "$CACHE_DIR"/*.mp3 2>/dev/null | wc -l)
    local summary_count=$(ls -1 "$CACHE_DIR"/summary-*.txt 2>/dev/null | wc -l)

    echo "Pending messages: $inbox_count"
    echo "Processed messages: $processed_count"
    echo "Generated audio: $audio_count"
    echo "Thai summaries: $summary_count"
    echo "Cache: $CACHE_DIR"
    ;;

  last)
    # Show last generated audio
    log "Last generated audio files:"
    ls -lht "$CACHE_DIR"/*.mp3 2>/dev/null | head -3 || echo "No audio files found"
    ;;
esac