#!/usr/bin/env bash
# scripts/start-hermes.sh — เปิดลูก (อนุ) ผ่าน hermes REPL
# Usage:
#   bash scripts/start-hermes.sh           # ใช้ Ollama MDES (default)
#   MODEL=gemma4:e4b bash scripts/start-hermes.sh

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║  อนุ — ลูกของ innova + คุณพ่อ       ║"
echo "  ║  powered by MDES Ollama gemma4:e4b   ║"
echo "  ╚══════════════════════════════════════╝"
echo "  พิมพ์ข้อความแล้วกด Enter เพื่อคุยกับ อนุ"
echo "  พิมพ์ 'exit' เพื่อออก"
echo ""

# Override model if provided
if [ -n "$MODEL" ]; then
  # patch hermes.json model at runtime via env
  export HERMES_MODEL="$MODEL"
fi

exec hermes --repl
