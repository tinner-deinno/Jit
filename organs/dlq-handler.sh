#!/usr/bin/env bash
# organs/dlq-handler.sh — DLQ (Dead Letter Queue) Monitor & Remediation
#
# บทบาท: sayanprasathan (ระบบประสาท) monitors bus failures
# ประเภท: expired, unrouted, error, max-retries
# ตัดสินใจ: alert pran (heart) หรือ innova (lead dev) เมื่อ DLQ exceed threshold
#
# Usage:
#   bash organs/dlq-handler.sh status           — ดู DLQ summary
#   bash organs/dlq-handler.sh monitor [interval] — ติดตาม DLQ (background loop)
#   bash organs/dlq-handler.sh audit            — inspect ทั้งหมด
#   bash organs/dlq-handler.sh remediate        — send alerts + dispatch cleanup
#   bash organs/dlq-handler.sh clean <days>    — archive old DLQ (default: 7 days)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-status}"
shift || true

DLQ_ROOT="/tmp/manusat-bus/_dlq"
DLQ_MONITOR="/tmp/dlq-monitor.json"
DLQ_THRESHOLD="${DLQ_THRESHOLD:-50}"          # Alert trigger point
DLQ_CRITICAL="${DLQ_CRITICAL:-100}"           # Critical trigger point
DLQ_HISTORY="/tmp/dlq-history.jsonl"

# ─────────────────────────────────────────────────────────────────────────
# DLQ Categories
# ─────────────────────────────────────────────────────────────────────────

_dlq_count_all() {
  find "$DLQ_ROOT" -type f -name "*.reason" 2>/dev/null | wc -l
}

_dlq_count_by_category() {
  local category="$1"
  find "$DLQ_ROOT/$category" -type f 2>/dev/null | wc -l
}

_dlq_sample() {
  local category="$1" limit="${2:-3}"
  find "$DLQ_ROOT/$category" -type f -name "*.reason" 2>/dev/null | sort -r | head -"$limit"
}

_dlq_analyze_reason() {
  local reason_file="$1"
  python3 -c "
import json
content = open('$reason_file').read()
lines = [l.strip() for l in content.split('\n') if l.strip()]
data = {}
for line in lines:
    if ':' in line:
        k, v = line.split(':', 1)
        data[k.strip()] = v.strip()
print(json.dumps(data, ensure_ascii=False))
"
}

# ─────────────────────────────────────────────────────────────────────────
# Status Report
# ─────────────────────────────────────────────────────────────────────────

_dlq_status() {
  local total=$(_dlq_count_all)
  local expired=$(_dlq_count_by_category "expired")
  local unrouted=$(_dlq_count_by_category "unrouted")
  local error=$(_dlq_count_by_category "error")
  local max_retries=$(_dlq_count_by_category "max-retries")

  echo ""
  echo -e "${BOLD}=== DLQ Status (Dead Letter Queue) ===${RESET}"
  echo "  Total DLQ messages: ${BOLD}$total${RESET}"
  echo ""
  echo "  Breakdown:"
  echo "    expired:    $expired (TTL exceeded)"
  echo "    unrouted:   $unrouted (unknown recipient)"
  echo "    error:      $error (delivery error)"
  echo "    max-retries: $max_retries (retry limit exceeded)"
  echo ""

  # Threshold check
  if [ "$total" -gt "$DLQ_CRITICAL" ]; then
    echo -e "  ${RED}⚠️ CRITICAL${RESET}: $total > $DLQ_CRITICAL (CRITICAL threshold)"
    echo "     → pran should escalate immediately"
  elif [ "$total" -gt "$DLQ_THRESHOLD" ]; then
    echo -e "  ${YELLOW}⚠️ WARNING${RESET}: $total > $DLQ_THRESHOLD (threshold)"
    echo "     → pran should dispatch remediation"
  else
    echo -e "  ${GREEN}✓ HEALTHY${RESET}: $total < $DLQ_THRESHOLD"
  fi
  echo ""

  # Recent samples
  echo "  Recent failures by category:"
  for cat in expired unrouted error max-retries; do
    count=$(_dlq_count_by_category "$cat")
    if [ "$count" -gt 0 ]; then
      echo ""
      echo "    [$cat] — $count files:"
      _dlq_sample "$cat" 2 | while read reason_file; do
        echo "      $(basename "$reason_file")"
        _dlq_analyze_reason "$reason_file" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"        to: {d.get('original_to', 'unknown'):15s} | reason: {d.get('failure_reason', 'N/A')[:40]}\")
"
      done
    fi
  done
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────
# Audit: Deep inspection
# ─────────────────────────────────────────────────────────────────────────

_dlq_audit() {
  echo ""
  echo -e "${BOLD}=== DLQ Audit (Deep Inspection) ===${RESET}"
  echo ""

  local total=$(_dlq_count_all)
  echo "Total messages in DLQ: $total"
  echo ""

  # Categorize by failure reason
  echo "Failure patterns (top 10):"
  find "$DLQ_ROOT" -type f -name "*.reason" -exec grep "failure_reason:" {} \; | \
    sed 's/.*failure_reason://' | sort | uniq -c | sort -rn | head -10 | \
    awk '{print "  [" $1 "] " substr($0, index($0, $3))}'
  echo ""

  # Categorize by recipient (who couldn't receive?)
  echo "Failed recipients (top 10):"
  find "$DLQ_ROOT" -type f -name "*.reason" -exec grep "original_to:" {} \; | \
    sed 's/.*original_to://' | sort | uniq -c | sort -rn | head -10 | \
    awk '{print "  [" $1 "] " substr($0, index($0, $3))}'
  echo ""

  # Categorize by sender
  echo "Failed senders (top 10):"
  find "$DLQ_ROOT" -type f -name "*.reason" -exec grep "original_from:" {} \; | \
    sed 's/.*original_from://' | sort | uniq -c | sort -rn | head -10 | \
    awk '{print "  [" $1 "] " substr($0, index($0, $3))}'
  echo ""
}

# ─────────────────────────────────────────────────────────────────────────
# Remediation: Alert & Dispatch
# ─────────────────────────────────────────────────────────────────────────

_dlq_remediate() {
  local total=$(_dlq_count_all)
  local timestamp=$(date '+%Y-%m-%dT%H:%M:%S')

  # Log to history
  python3 -c "
import json
event = {
  'timestamp': '$timestamp',
  'dlq_count': $total,
  'critical': $total > $DLQ_CRITICAL,
  'warning': $total > $DLQ_THRESHOLD,
  'action': 'assessed'
}
with open('$DLQ_HISTORY', 'a') as f:
    f.write(json.dumps(event) + '\n')
"

  if [ "$total" -gt "$DLQ_CRITICAL" ]; then
    # CRITICAL: alert pran + innova
    warn "🚨 DLQ CRITICAL: $total messages (threshold=$DLQ_CRITICAL)"
    bash "$SCRIPT_DIR/mouth.sh" tell pran "🚨 DLQ CRITICAL: $total dead letters. Investigate unrouted/expired categories immediately."
    bash "$SCRIPT_DIR/mouth.sh" tell innova "🚨 DLQ CRITICAL: $total messages. Review failure_reason patterns in audit: $(find "$DLQ_ROOT" -type f -name '*.reason' | head -3 | xargs -I {} basename {})"
    log_action "DLQ_CRITICAL" "count=$total recipients=pran,innova"
  elif [ "$total" -gt "$DLQ_THRESHOLD" ]; then
    # WARNING: alert pran only
    step "⚠️  DLQ WARNING: $total messages (threshold=$DLQ_THRESHOLD)"
    bash "$SCRIPT_DIR/mouth.sh" tell pran "⚠️ DLQ WARNING: $total dead letters. Please monitor and review."
    log_action "DLQ_WARNING" "count=$total recipient=pran"
  else
    ok "✓ DLQ healthy ($total < $DLQ_THRESHOLD)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────
# Monitor: Background loop
# ─────────────────────────────────────────────────────────────────────────

_dlq_monitor() {
  local interval="${1:-60}"  # Check every 60s by default
  echo "DLQ monitor starting (interval: ${interval}s)"
  echo "PID: $$"

  while true; do
    local total=$(_dlq_count_all)
    local timestamp=$(date '+%Y-%m-%dT%H:%M:%S')

    # Save state
    python3 -c "
import json
state = {
  'last_check': '$timestamp',
  'dlq_count': $total,
  'pid': $$
}
with open('$DLQ_MONITOR', 'w') as f:
    json.dump(state, f)
"

    # Check threshold
    if [ "$total" -gt "$DLQ_THRESHOLD" ]; then
      _dlq_remediate
    fi

    sleep "$interval"
  done
}

# ─────────────────────────────────────────────────────────────────────────
# Clean: Archive old DLQ
# ─────────────────────────────────────────────────────────────────────────

_dlq_clean() {
  local days="${1:-7}"
  local archive_dir="/tmp/dlq-archive"
  mkdir -p "$archive_dir"

  local count=0
  find "$DLQ_ROOT" -type f -mtime +"$days" | while read f; do
    cp "$f" "$archive_dir/"
    rm "$f"
    count=$((count + 1))
  done

  ok "DLQ cleaned: archived files older than $days days"
  log_action "DLQ_CLEAN" "days=$days archived=$count"
}

# ─────────────────────────────────────────────────────────────────────────
# Main dispatcher
# ─────────────────────────────────────────────────────────────────────────

case "$CMD" in
  status)
    _dlq_status
    ;;
  audit)
    _dlq_audit
    ;;
  remediate)
    _dlq_remediate
    ;;
  monitor)
    _dlq_monitor "$@"
    ;;
  clean)
    _dlq_clean "$@"
    ;;
  *)
    echo "Usage: dlq-handler.sh {status|audit|remediate|monitor|clean}"
    echo ""
    echo "  status              — ดู DLQ summary + threshold check"
    echo "  audit               — inspect failure patterns + recipients"
    echo "  remediate           — alert pran/innova if threshold exceeded"
    echo "  monitor [interval]  — background monitor (default: 60s)"
    echo "  clean [days]        — archive old DLQ (default: 7 days)"
    echo ""
    echo "Environment:"
    echo "  DLQ_THRESHOLD=$DLQ_THRESHOLD   (warning at this count)"
    echo "  DLQ_CRITICAL=$DLQ_CRITICAL     (critical at this count)"
    ;;
esac
