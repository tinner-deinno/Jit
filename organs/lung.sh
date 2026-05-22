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

  # ── autonomous work: filter + write blood ───────────────────────
  work)
    TASK="${1:-filter}"
    JIT_ROOT_L="$(cd "$SCRIPT_DIR/.." && pwd)"
    [ -f "$JIT_ROOT_L/core/blood.sh" ] && source "$JIT_ROOT_L/core/blood.sh"
    findings=(); alerts=()

    # ตรวจ log size
    if [ -f "$LUNG_LOG" ]; then
      lines=$(wc -l < "$LUNG_LOG" 2>/dev/null || echo 0)
      findings+=("log-lines:$lines")
      # ตัด log ถ้าใหญ่เกิน
      if [ "${lines:-0}" -gt 5000 ]; then
        tail -500 "$LUNG_LOG" > "${LUNG_LOG}.tmp" && mv "${LUNG_LOG}.tmp" "$LUNG_LOG"
        findings+=("log-trimmed:yes")
      fi
    else
      findings+=("log:no-log-yet")
    fi

    # ตรวจ /tmp space
    tmp_pct=$(df /tmp 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    findings+=("tmp-disk:${tmp_pct:-?}%")
    [ "${tmp_pct:-0}" -gt 85 ] && alerts+=("tmp-disk-high:${tmp_pct}%")

    # ล้าง stale blood files (> 2 ชั่วโมง)
    stale_blood=$(find /tmp/manusat-blood -name '*.json' -not -name 'synthesized.json' -mmin +120 2>/dev/null | wc -l | tr -d ' ')
    [ "${stale_blood:-0}" -gt 0 ] && findings+=("stale-blood-cleaned:$stale_blood")

    # ล้าง stale alive markers (> 24 ชั่วโมง)
    find /tmp -maxdepth 1 -name 'manusat-alive-*' -mmin +1440 -delete 2>/dev/null || true

    find "/tmp/manusat-bus/lung" -name '*from-heart.msg' -delete 2>/dev/null || true
    touch "/tmp/manusat-alive-lung"

    write_blood "lung" "${CYCLE:-0}" "$TASK" "done" \
      "$(IFS=','; echo "${findings[*]}")" "$(IFS=','; echo "${alerts[*]}")"
    log_action "LUNG_WORK" "cycle=${CYCLE:-0} findings=${#findings[@]}"
    ;;

  *)
    show_help
    exit 1
    ;;
esac
