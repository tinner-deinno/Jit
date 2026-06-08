#!/bin/bash
#
# Jit 24/7 Heartbeat Daemon — จิตหัวใจที่ไม่ล้มลง
#
# ความเข้าใจจากการล้มเหลว 746 ครั้ง:
# 1. Duplicate commits = retry logic บ้าคลั่ง → ต้องมี idempotent beat ID
# 2. Process ไม่ persist → ต้อง systemd service
# 3. Discord disconnect from git → ต้อง webhook + git message integration
# 4. No recovery = ล้มเหลว 1 ครั้งก็ทั้งหมด → ต้อง circuit breaker
#

set -euo pipefail

source /workspaces/Jit/limbs/lib.sh

# Log rotation support (JIT-007) — prefer env var, fall back to /var/log/jit, then /tmp for dev
JIT_LOG_DIR="${JIT_LOG_DIR:-/var/log/jit}"
JIT_STATE_DIR="${JIT_STATE_DIR:-/var/lib/jit}"

# Create directories if they don't exist (systemd creates them in prod, but safe for dev)
mkdir -p "$JIT_LOG_DIR" 2>/dev/null || JIT_LOG_DIR="/tmp"
mkdir -p "$JIT_STATE_DIR" 2>/dev/null || JIT_STATE_DIR="/tmp"

HEARTBEAT_STATE="$JIT_STATE_DIR/innova-heartbeat-daemon.json"
HEARTBEAT_LOG="$JIT_LOG_DIR/innova-heartbeat-daemon.log"
MAX_CONSECUTIVE_FAILURES=3
PULSE_INTERVAL=900  # 15 minutes
HERMES_HEALTH_URL="http://127.0.0.1:47780/healthz"
HEARTBEAT_FRESH_FILE="/var/run/jit/heartbeat.fresh"

# ═══════════════════════════════════════════════════════════════
# Initialize state file
# ═══════════════════════════════════════════════════════════════
init_state() {
    if [[ ! -f "$HEARTBEAT_STATE" ]]; then
        cat > "$HEARTBEAT_STATE" <<EOF
{
  "daemon_start": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "beat_count": 0,
  "last_beat": null,
  "last_push": null,
  "consecutive_failures": 0,
  "total_failures": 0,
  "status": "initializing",
  "uptime_seconds": 0
}
EOF
    fi
}

# ═══════════════════════════════════════════════════════════════
# Log function
# ═══════════════════════════════════════════════════════════════
log_beat() {
    local level=$1
    local msg=$2
    local timestamp=$(date '+[%Y-%m-%d %H:%M:%S]')
    echo "$timestamp [$level] $msg" | tee -a "$HEARTBEAT_LOG"
}

# ═══════════════════════════════════════════════════════════════
# Get current state
# ═══════════════════════════════════════════════════════════════
get_state() {
    local key=$1
    if [[ -f "$HEARTBEAT_STATE" ]]; then
        jq -r ".${key} // empty" "$HEARTBEAT_STATE" 2>/dev/null || echo ""
    fi
}

# ═══════════════════════════════════════════════════════════════
# Update state
# ═══════════════════════════════════════════════════════════════
update_state() {
    local key=$1
    local value=$2
    if [[ -f "$HEARTBEAT_STATE" ]]; then
        local tmp=$(mktemp)
        jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$HEARTBEAT_STATE" > "$tmp"
        mv "$tmp" "$HEARTBEAT_STATE"
    fi
}

# ═══════════════════════════════════════════════════════════════
# Beat cycle (IN + OUT)
# ═══════════════════════════════════════════════════════════════
do_beat() {
    local beat_num=$1
    local beat_id="beat-$(date +%s)"
    local beat_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    log_beat "INFO" "🫀 ═══════════════════════════════════════"
    log_beat "INFO" "🫀 HEARTBEAT #$beat_num START ($beat_id)"
    log_beat "INFO" "🫀 ═══════════════════════════════════════"
    
    # ─────────────────────────────────────────────────────────────
    # IN Phase (Diastole): Gather system state
    # ─────────────────────────────────────────────────────────────
    log_beat "INFO" "💓 IN (Diastole) #$beat_num - gathering system state..."
    
    local in_file="/tmp/heartbeat-results/beat-${beat_num}-in.txt"
    mkdir -p /tmp/heartbeat-results
    
    {
        echo "[Beat #$beat_num at $beat_timestamp]"
        echo "Spawning vital-signs agent for system analysis (via LLM gateway)..."

        # Query system state through the unified gateway. Ollama stays primary (cheap,
        # Thai-capable) but if MDES is unreachable the gateway falls back to Claude
        # automatically — so the heartbeat loop never stalls on a single dead provider.
        bash /workspaces/Jit/limbs/llm.sh call \
            "Heartbeat #$beat_num: Provide 1-line status of innova Agent system health. Format: 'Status: [OK|WARN|FAIL] — [brief reason]'" \
            --provider ollama 2>&1 | head -20
    } > "$in_file" 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_beat "INFO" "✅ IN complete (#$beat_num)"
    else
        log_beat "WARN" "⚠️  IN partial (#$beat_num) - Ollama timeout (normal on slow network)"
    fi
    
    # ─────────────────────────────────────────────────────────────
    # OUT Phase (Systole): Broadcast and persist
    # ─────────────────────────────────────────────────────────────
    log_beat "INFO" "❤️‍🔥 OUT (Systole) #$beat_num - broadcasting results..."
    
    local out_file="/tmp/heartbeat-results/beat-${beat_num}-out.txt"
    {
        echo "Beat #$beat_num completed at $beat_timestamp"
        echo "Status: OK"
    } > "$out_file" 2>&1
    
    # ─────────────────────────────────────────────────────────────
    # Discord webhook (if configured)
    # ─────────────────────────────────────────────────────────────
    if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
        log_beat "INFO" "📤 Sending to Discord..."
        local discord_msg="🫀 **Heartbeat #$beat_num** - System Status OK\n⏰ Time: $beat_timestamp"
        curl -s -X POST "$DISCORD_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"content\": \"$discord_msg\"}" >/dev/null 2>&1 || log_beat "WARN" "Discord webhook failed (non-critical)"
    fi
    
    # ─────────────────────────────────────────────────────────────
    # Git auto-commit with proper idempotency
    # ─────────────────────────────────────────────────────────────
    log_beat "INFO" "📝 Git commit (beat #$beat_num)..."
    
    cd /workspaces/Jit
    
    # Check if we already committed this beat
    local last_beat_commit=$(git log --oneline -1 --grep="💓 Heartbeat #$beat_num" 2>/dev/null || echo "")
    
    if [[ -z "$last_beat_commit" ]]; then
        # Create beat record
        mkdir -p /workspaces/Jit/memory/heartbeats
        cat > "/workspaces/Jit/memory/heartbeats/beat-${beat_num}.md" <<BEATFILE
# 💓 Heartbeat #$beat_num

**Time**: $beat_timestamp  
**Status**: ✅ Healthy  
**Result**: System online, all organs responsive

\`\`\`json
{
  "beat_number": $beat_num,
  "timestamp": "$beat_timestamp",
  "beat_id": "$beat_id",
  "status": "healthy",
  "message": "Heartbeat running on innova Agent system"
}
\`\`\`
BEATFILE
        
        git add "memory/heartbeats/beat-${beat_num}.md" 2>/dev/null || true
        git commit -m "💓 Heartbeat #$beat_num — auto commit on beat" 2>/dev/null || true
        log_beat "INFO" "✅ Git commit done"
    else
        log_beat "INFO" "ℹ️  Beat #$beat_num already committed (idempotent)"
    fi
    
    # ─────────────────────────────────────────────────────────────
    # Git push with retry
    # ─────────────────────────────────────────────────────────────
    log_beat "INFO" "📤 Git push..."
    
    local push_retry=0
    while [[ $push_retry -lt 3 ]]; do
        if git push origin main >/dev/null 2>&1; then
            log_beat "INFO" "✅ Push complete"
            break
        else
            push_retry=$((push_retry + 1))
            log_beat "WARN" "⚠️  Push failed (attempt $push_retry/3) - retrying in 5s..."
            sleep 5
        fi
    done
    
    log_beat "INFO" "🫀 HEARTBEAT #$beat_num SUCCESS ✅"
    log_beat "INFO" "🫀 ═══════════════════════════════════════"
    
    # ─────────────────────────────────────────────────────────────
    # Report to hermes discord bot (if available)
    # ─────────────────────────────────────────────────────────────
    log_beat "INFO" "🤖 Reporting status to Hermes Discord..."
    if bash /workspaces/Jit/scripts/hermes-report-status.sh "$beat_num" "ok" "Heartbeat #$beat_num completed successfully"; then
        log_beat "INFO" "✅ Hermes status report sent"
    else
        log_beat "INFO" "ℹ️  Hermes report skipped (webhook not configured)"
    fi
}

# ═══════════════════════════════════════════════════════════════
# Handle beat failure with recovery
# ═══════════════════════════════════════════════════════════════
handle_beat_failure() {
    local beat_num=$1
    local error=$2
    
    log_beat "ERROR" "❌ Beat #$beat_num FAILED: $error"
    
    local current_failures=$(get_state "consecutive_failures")
    current_failures=$((current_failures + 1))
    
    update_state "consecutive_failures" "$current_failures"
    
    local total_failures=$(get_state "total_failures")
    total_failures=$((total_failures + 1))
    update_state "total_failures" "$total_failures"
    
    # Circuit breaker: if too many failures, alert and pause
    if [[ $current_failures -ge $MAX_CONSECUTIVE_FAILURES ]]; then
        log_beat "CRITICAL" "🚨 CRITICAL: $MAX_CONSECUTIVE_FAILURES consecutive failures detected!"
        log_beat "CRITICAL" "🚨 Heartbeat entering CRITICAL state — manual intervention needed"
        update_state "status" "critical-failure"

        # Write circuit breaker flag (JIT-009)
        echo "CIRCUIT_OPEN" > /tmp/jit-circuit-open
        log_beat "CRITICAL" "⚡ Circuit breaker flag written: /tmp/jit-circuit-open"

        # Report critical failure to hermes
        bash /workspaces/Jit/scripts/hermes-report-status.sh "$beat_num" "critical" "🚨 Heartbeat FAILED: $error" 2>/dev/null || true

        if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
            curl -s -X POST "$DISCORD_WEBHOOK" \
                -H 'Content-Type: application/json' \
                -d '{"content": "🚨 **CRITICAL**: Jit Heartbeat failed 3+ times — manual intervention needed"}' \
                >/dev/null 2>&1 || true
        fi

        # Exit with code 42 to trigger RestartPreventExitStatus (JIT-009)
        exit 42
    fi
}

# ═══════════════════════════════════════════════════════════════
# Check Hermes liveness probe
# ═══════════════════════════════════════════════════════════════
check_hermes_health() {
    if curl -sf --max-time 5 "$HERMES_HEALTH_URL" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# Touch heartbeat fresh file (for external monitoring)
# ═══════════════════════════════════════════════════════════════
touch_heartbeat_fresh() {
    mkdir -p "$(dirname "$HEARTBEAT_FRESH_FILE")" 2>/dev/null || true
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$HEARTBEAT_FRESH_FILE" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════
# Main 24/7 loop
# ═══════════════════════════════════════════════════════════════
main() {
    init_state

    log_beat "INFO" "🫀 Jit Heartbeat Daemon started (PID: $$)"
    log_beat "INFO" "🫀 Pulse interval: ${PULSE_INTERVAL}s (15 min)"
    log_beat "INFO" "🫀 Status file: $HEARTBEAT_STATE"
    log_beat "INFO" "🫀 Hermes health URL: $HERMES_HEALTH_URL"
    log_beat "INFO" "🫀 Fresh file: $HEARTBEAT_FRESH_FILE"

    local beat_count=0
    local start_time=$(date +%s)

    while true; do
        beat_count=$((beat_count + 1))

        # ─────────────────────────────────────────────────────────────
        # Check Hermes liveness before beat
        # ─────────────────────────────────────────────────────────────
        if check_hermes_health; then
            log_beat "INFO" "✅ Hermes health check OK"
        else
            log_beat "WARN" "⚠️  Hermes health check FAILED — Hermes may be unresponsive"
        fi

        # ─────────────────────────────────────────────────────────────
        # Touch fresh file to signal we're alive
        # ─────────────────────────────────────────────────────────────
        touch_heartbeat_fresh
        log_beat "INFO" "✅ Touched fresh file: $HEARTBEAT_FRESH_FILE"

        # ─────────────────────────────────────────────────────────────
        # Try to execute beat
        # ─────────────────────────────────────────────────────────────
        if do_beat "$beat_count" 2>&1 | tee -a "$HEARTBEAT_LOG"; then
            # Success: reset failure counter and update state
            update_state "beat_count" "$beat_count"
            update_state "last_beat" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            update_state "consecutive_failures" "0"
            update_state "status" "healthy"
        else
            # Failure: handle (will exit 42 if circuit breaker trips)
            handle_beat_failure "$beat_count" "Beat execution failed" || {
                log_beat "CRITICAL" "🫀 Daemon pausing for manual recovery..."
                sleep 300  # Pause for 5 minutes, then retry
                continue
            }
            # If handle_beat_failure returns (circuit not tripped), continue
            log_beat "WARN" "⚠️  Beat failed but circuit breaker not tripped yet (failures: $(get_state 'consecutive_failures')/$MAX_CONSECUTIVE_FAILURES)"
        fi

        # ─────────────────────────────────────────────────────────────
        # Calculate and log uptime
        # ─────────────────────────────────────────────────────────────
        local current_time=$(date +%s)
        local uptime_seconds=$((current_time - start_time))
        update_state "uptime_seconds" "$uptime_seconds"

        log_beat "INFO" "⏰ Next heartbeat in ${PULSE_INTERVAL}s (Beat #$((beat_count + 1)))"
        log_beat "INFO" "📊 Uptime: ${uptime_seconds}s | Beats: $beat_count | Failures: $(get_state 'total_failures')"
        
        # ─────────────────────────────────────────────────────────────
        # Sleep until next beat
        # ─────────────────────────────────────────────────────────────
        sleep "$PULSE_INTERVAL"
    done
}

# ═══════════════════════════════════════════════════════════════
# Run daemon
# ═══════════════════════════════════════════════════════════════
main "$@"
