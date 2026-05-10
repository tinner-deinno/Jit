#!/usr/bin/env bash
# scripts/memory-sweep.sh — Memory Survey & Consolidation
# ════════════════════════════════════════════════════════════════════
# สำรวจและรวบรวมความจำทั้งหมดของระบบ:
#   - Agent bus messages (inbox ทั้งหมด)
#   - Working memory + shared state
#   - Retrospectives
#   - Jit-bridge messages
# แล้ว consolidate เป็น digest และ learn ลง Oracle
#
# Usage:
#   bash scripts/memory-sweep.sh         — full sweep
#   bash scripts/memory-sweep.sh inbox   — scan bus inboxes only
#   bash scripts/memory-sweep.sh retro   — scan retrospectives
#   bash scripts/memory-sweep.sh state   — show current states
#   bash scripts/memory-sweep.sh learn   — learn digest to Oracle
# ════════════════════════════════════════════════════════════════════

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then set -a; . "$JIT_ROOT/.env"; set +a; fi

BUS_ROOT="/tmp/manusat-bus"
SWEEP_LOG="/tmp/memory-sweep.log"
SWEEP_DIGEST="/tmp/memory-sweep-digest.json"
CMD="${1:-full}"
shift || true

log_sweep() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] SWEEP: $1" | tee -a "$SWEEP_LOG"; }

# ─── Scan bus inboxes ──────────────────────────────────────────────
scan_inboxes() {
    echo ""
    step "📬 Scanning agent inboxes..."

    local TOTAL_MSGS=0
    local AGENTS=("jit" "innova" "soma" "lak" "neta" "vaja" "chamu" "rupa" "pada" "netra" "karn" "mue" "pran" "sayanprasathan")

    declare -A INBOX_SUMMARY
    for AGENT in "${AGENTS[@]}"; do
        local INBOX_DIR="$BUS_ROOT/$AGENT"
        if [ -d "$INBOX_DIR" ]; then
            local COUNT
            COUNT=$(find "$INBOX_DIR" -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')
            INBOX_SUMMARY[$AGENT]="$COUNT"
            if [ "$COUNT" -gt 0 ]; then
                echo "  ${AGENT}: ${COUNT} messages"
                TOTAL_MSGS=$(( TOTAL_MSGS + COUNT ))
            fi
        fi
    done

    echo "  Total: ${TOTAL_MSGS} pending messages"
    log_sweep "inbox scan: ${TOTAL_MSGS} total messages"
    echo "$TOTAL_MSGS"
}

# ─── Summarize recent messages ─────────────────────────────────────
summarize_recent_messages() {
    local MAX_AGE_HOURS="${1:-24}"
    local MAX_MSGS="${2:-20}"

    python3 - << PYEOF
import os, glob, json

bus_root = "${BUS_ROOT}"
max_msgs = ${MAX_MSGS}
summaries = []

for agent_dir in sorted(glob.glob(os.path.join(bus_root, "*"))):
    agent = os.path.basename(agent_dir)
    msgs = sorted(glob.glob(os.path.join(agent_dir, "*.msg")))[-max_msgs:]
    for msg_path in msgs:
        try:
            content = open(msg_path).read()
            lines = content.split('\n')
            headers = {}
            body_lines = []
            in_body = False
            for line in lines:
                if line == '---':
                    in_body = True
                elif in_body:
                    body_lines.append(line)
                elif ':' in line:
                    k, _, v = line.partition(':')
                    headers[k.strip()] = v.strip()

            summaries.append({
                'agent': agent,
                'from': headers.get('from', '?'),
                'subject': headers.get('subject', '?'),
                'timestamp': headers.get('timestamp', '?'),
                'body_preview': ' '.join(body_lines)[:100],
                'file': os.path.basename(msg_path),
            })
        except Exception as e:
            pass

# Sort by timestamp desc
summaries.sort(key=lambda x: x.get('timestamp',''), reverse=True)
print(json.dumps(summaries[:${MAX_MSGS}], ensure_ascii=False, indent=2))
PYEOF
}

# ─── Scan retrospectives ───────────────────────────────────────────
scan_retrospectives() {
    echo ""
    step "📖 Scanning retrospectives..."

    local RETRO_DIR="$JIT_ROOT/memory/retrospectives"
    if [ ! -d "$RETRO_DIR" ]; then
        warn "No retrospectives directory"
        return
    fi

    local COUNT=0
    local SUMMARY=""

    while IFS= read -r RETRO_FILE; do
        ((COUNT++)) || true
        local DATE_PART
        DATE_PART=$(echo "$RETRO_FILE" | grep -oP '\d{4}/\d+/\d+' | head -1 || echo "?")
        local SIZE
        SIZE=$(wc -l < "$RETRO_FILE" 2>/dev/null || echo "0")
        SUMMARY="${SUMMARY}\n  ${DATE_PART}: ${SIZE} lines"
    done < <(find "$RETRO_DIR" -name '*.md' -o -name '*.json' 2>/dev/null | sort | tail -10)

    echo -e "$SUMMARY"
    echo "  Total retrospective files: $COUNT"
    log_sweep "retrospectives: ${COUNT} files found"
}

# ─── Show current states ───────────────────────────────────────────
show_states() {
    echo ""
    step "📊 Current system states..."

    local STATES=(
        "/tmp/manusat-shared.json:Shared State"
        "/tmp/innova-working-memory.json:Working Memory"
        "/tmp/innova-state.json:Innova Life State"
        "/tmp/agent-autonomy-state.json:Autonomy State"
        "/tmp/mcp-loop-state.json:MCP State"
        "/tmp/jarvis-claude-state.json:JARVIS State"
        "/tmp/ollama-proxy.pid:Ollama Proxy"
    )

    for ENTRY in "${STATES[@]}"; do
        local FILE="${ENTRY%%:*}"
        local LABEL="${ENTRY##*:}"
        if [ -f "$FILE" ]; then
            local SIZE
            SIZE=$(wc -c < "$FILE" 2>/dev/null || echo "0")
            local AGE_MINS
            AGE_MINS=$(python3 -c "
import os, time
try:
    mtime = os.path.getmtime('$FILE')
    print(int((time.time() - mtime) / 60))
except:
    print('?')
" 2>/dev/null || echo "?")
            echo -e "  ${GREEN}✓${RESET} ${LABEL}: ${SIZE}b, ${AGE_MINS}m ago"
        else
            echo -e "  ${YELLOW}○${RESET} ${LABEL}: not found"
        fi
    done
}

# ─── Build digest ─────────────────────────────────────────────────
build_digest() {
    log_sweep "Building digest..."

    python3 - << PYEOF
import os, glob, json, time

digest = {
    "generated": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "agent": "innova",
    "inbox_totals": {},
    "recent_messages": [],
    "active_states": [],
    "retrospective_count": 0,
}

# Inbox scan
bus_root = "${BUS_ROOT}"
for agent_dir in glob.glob(os.path.join(bus_root, "*")):
    agent = os.path.basename(agent_dir)
    count = len(glob.glob(os.path.join(agent_dir, "*.msg")))
    if count > 0:
        digest["inbox_totals"][agent] = count

# Recent messages (last 10 across all agents)
all_msgs = []
for msg_path in glob.glob(os.path.join(bus_root, "*", "*.msg")):
    try:
        content = open(msg_path).read()
        lines = content.split('\n')
        h = {}
        for line in lines:
            if line == '---': break
            if ':' in line:
                k,_,v = line.partition(':')
                h[k.strip()] = v.strip()
        all_msgs.append({
            "agent": os.path.basename(os.path.dirname(msg_path)),
            "subject": h.get("subject","?"),
            "from": h.get("from","?"),
            "ts": h.get("timestamp","?"),
        })
    except: pass
all_msgs.sort(key=lambda x: x.get("ts",""), reverse=True)
digest["recent_messages"] = all_msgs[:10]

# State files
state_files = [
    "/tmp/manusat-shared.json",
    "/tmp/innova-state.json",
    "/tmp/mcp-loop-state.json",
    "/tmp/jarvis-claude-state.json",
]
for sf in state_files:
    if os.path.exists(sf):
        try:
            d = json.load(open(sf))
            digest["active_states"].append({"file": os.path.basename(sf), "data": d})
        except: pass

# Retrospectives
retro_dir = "${JIT_ROOT}/memory/retrospectives"
digest["retrospective_count"] = len(
    glob.glob(os.path.join(retro_dir, "**", "*.md"), recursive=True) +
    glob.glob(os.path.join(retro_dir, "**", "*.json"), recursive=True)
)

with open("${SWEEP_DIGEST}", "w") as f:
    json.dump(digest, f, indent=2, ensure_ascii=False)

print(json.dumps({
    "inbox_agents": len(digest["inbox_totals"]),
    "inbox_messages": sum(digest["inbox_totals"].values()),
    "recent_msgs": len(digest["recent_messages"]),
    "states": len(digest["active_states"]),
    "retros": digest["retrospective_count"],
}, ensure_ascii=False))
PYEOF
}

# ─── Learn digest to Oracle ────────────────────────────────────────
learn_to_oracle() {
    if [ ! -f "$SWEEP_DIGEST" ]; then
        err "No digest — run 'memory-sweep.sh full' first"
        return 1
    fi

    ORACLE_URL="${ORACLE_URL:-http://127.0.0.1:47778}"
    if ! curl -sf --max-time 5 "${ORACLE_URL}/api/health" >/dev/null 2>&1; then
        warn "Oracle offline — skipping learn"
        return 0
    fi

    local SUMMARY
    SUMMARY=$(python3 -c "
import json
d = json.load(open('${SWEEP_DIGEST}'))
total_msgs = sum(d.get('inbox_totals',{}).values())
agents = ', '.join(sorted(d.get('inbox_totals',{}).keys()))
subjects = [m.get('subject','') for m in d.get('recent_messages',[])][:5]
print(f'Memory sweep at {d.get(\"generated\",\"?\")}. Inbox: {total_msgs} messages across agents: {agents}. Recent subjects: {\", \".join(subjects[:3])}. Retros: {d.get(\"retrospective_count\",0)} files.')
" 2>/dev/null || echo "memory sweep completed")

    bash "$JIT_ROOT/limbs/oracle.sh" learn \
        "memory-sweep" \
        "$SUMMARY" \
        "memory,sweep,agent,inbox,state" 2>/dev/null \
    && ok "Digest learned to Oracle"
}

# ─── Full sweep ────────────────────────────────────────────────────
full_sweep() {
    echo ""
    echo -e "${CYAN}${BOLD}🔍 Memory Sweep — $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    scan_inboxes
    scan_retrospectives
    show_states

    echo ""
    step "Building digest..."
    RESULT=$(build_digest 2>/dev/null || echo "{}")
    echo "  $RESULT"

    log_sweep "full sweep complete: $RESULT"
    echo ""
    ok "Sweep complete → $SWEEP_DIGEST"
}

# ─── Dispatch ──────────────────────────────────────────────────────
case "$CMD" in
    full)    full_sweep ;;
    inbox)   scan_inboxes ;;
    retro)   scan_retrospectives ;;
    state)   show_states ;;
    learn)   learn_to_oracle ;;
    digest)  build_digest ;;
    help|*)
        echo ""
        echo "scripts/memory-sweep.sh — Memory survey & consolidation"
        echo ""
        echo "Commands:"
        echo "  full    Full sweep (default)"
        echo "  inbox   Scan agent bus inboxes"
        echo "  retro   Scan retrospective files"
        echo "  state   Show all state files"
        echo "  digest  Build digest file"
        echo "  learn   Learn digest to Oracle"
        echo ""
        ;;
esac
