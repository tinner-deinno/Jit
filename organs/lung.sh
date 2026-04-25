#!/usr/bin/env bash
# organs/lung.sh — ปอด (Lung): ฟอกเลือด, คืนพลังงานบริสุทธิ์ให้ระบบ
#
# ปอดจะรับ context/loads จากหัวใจ แล้วส่งสัญญาณเลือดดีให้หัวใจปล่อยออกไปยังทุก agent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

LUNG_LOG="/tmp/manusat-lung.log"

clean_blood() {
  local PAYLOAD="$*"
  local TS="$(date '+%Y-%m-%dT%H:%M:%S')"
  echo "$TS | lung filter | payload=$PAYLOAD" >> "$LUNG_LOG"
  log_action "LUNG_FILTER" "payload=${PAYLOAD}"

  # จำลองการฟอกของเสียและปรับพลังงาน
  local CLEAN_LEVEL="high"
  local FILTERED="{
    \"clean_status\": \"$CLEAN_LEVEL\",
    \"timestamp\": \"$TS\",
    \"source\": \"lung\"
  }"

  bash "$SCRIPT_DIR/../network/bus.sh" broadcast "heartbeat:lung:done" "$FILTERED" >/dev/null 2>&1 || true
  echo "$FILTERED"
}

show_help() {
  echo "Usage: $0 {filter|status|help}"
  echo "  filter <context>  — ฟอกเลือดและส่ง blood-clean signal"
  echo "  status            — แสดงสถานะปอด"
}

case "${1:-help}" in
  filter)
    shift || true
    clean_blood "$*"
    ;;

  pulse)
    CONTEXT="$*"
    log_action "LUNG_PULSE" "$CONTEXT"
    total_pending=$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("total_pending", 0))' <<<"$CONTEXT" 2>/dev/null || echo 0)
    echo "Lung receives clean energy and keeps the blood pure"
    echo "  total_pending: ${total_pending:-0}"
    ;;

  status)
    echo "=== Lung Status ==="
    echo "log: $LUNG_LOG"
    echo "last entries:"
    tail -5 "$LUNG_LOG" 2>/dev/null || echo "(no log yet)"
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    show_help
    exit 1
    ;;
esac
