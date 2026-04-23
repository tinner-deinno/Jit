#!/usr/bin/env bash
# memory/working.sh — ความจำระยะสั้น (Working Memory): context ของงานปัจจุบัน
#
# หลักพุทธ: มนสิการ (Attention) — จดจ่อกับสิ่งที่กำลังทำ
# บทบาท: short-term context storage, task state, in-progress tracking
#
# Working memory เป็น RAM ของ agent — ล้างหลังเสร็จงาน
# Long-term memory = Oracle (ถาวร)
# Working memory = /tmp (เฉพาะ session)
#
# Usage:
#   ./working.sh focus <task>        — เริ่มงาน (set current task)
#   ./working.sh context <key> <v>   — บันทึก context
#   ./working.sh recall <key>        — เรียกคืน context
#   ./working.sh snapshot            — ดู working memory ทั้งหมด
#   ./working.sh done <summary>      — เสร็จงาน → save to Oracle
#   ./working.sh clear               — ล้าง working memory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../limbs/lib.sh"

CMD="${1:-snapshot}"
shift || true

WM_FILE="/tmp/innova-working-memory.json"
AGENT="${AGENT_NAME:-innova}"

_wm_load() {
  [ -f "$WM_FILE" ] && cat "$WM_FILE" || echo '{"task":null,"context":{},"started":null,"steps":[]}'
}
_wm_save() { echo "$1" > "$WM_FILE"; }

case "$CMD" in

  # ── เริ่มงาน ────────────────────────────────────────────────────
  focus)
    TASK="$*"
    if [ -z "$TASK" ]; then err "ต้องระบุ task"; exit 1; fi
    TS=$(date '+%Y-%m-%dT%H:%M:%S')
    WM=$(python3 -c "
import json
wm = {
  'task': '$TASK',
  'started': '$TS',
  'agent': '$AGENT',
  'context': {},
  'steps': [],
  'status': 'in-progress'
}
print(json.dumps(wm, ensure_ascii=False, indent=2))
")
    _wm_save "$WM"
    log_action "WM_FOCUS" "$TASK"
    ok "โฟกัส: $TASK"

    # Set emotion
    EMOTION="$SCRIPT_DIR/../mind/emotion.sh"
    [ -x "$EMOTION" ] && bash "$EMOTION" feel "focused" "$TASK"
    ;;

  # ── บันทึก context ───────────────────────────────────────────────
  context)
    KEY="$1" VALUE="${2:-}"
    shift 2 || true
    [ -n "$*" ] && VALUE="$VALUE $*"
    CURRENT=$(_wm_load)
    UPDATED=$(python3 -c "
import json, sys
wm = json.loads(sys.argv[1])
wm['context']['$KEY'] = '$VALUE'
print(json.dumps(wm, ensure_ascii=False, indent=2))
" "$CURRENT")
    _wm_save "$UPDATED"
    log_action "WM_CONTEXT" "$KEY=$VALUE"
    info "context: $KEY = $VALUE"
    ;;

  # ── เพิ่ม step ────────────────────────────────────────────────────
  step)
    STEP_DESC="$*"
    CURRENT=$(_wm_load)
    UPDATED=$(python3 -c "
import json, sys
wm = json.loads(sys.argv[1])
wm['steps'].append({'step': '$STEP_DESC', 'ts': '$(date +%H:%M:%S)'})
print(json.dumps(wm, ensure_ascii=False, indent=2))
" "$CURRENT")
    _wm_save "$UPDATED"
    info "step: $STEP_DESC"
    ;;

  # ── เรียกคืน context ─────────────────────────────────────────────
  recall)
    KEY="$1"
    python3 -c "
import json, os
if os.path.exists('$WM_FILE'):
    wm = json.load(open('$WM_FILE'))
    ctx = wm.get('context', {})
    if '$KEY':
        print(ctx.get('$KEY', ''))
    else:
        for k,v in ctx.items():
            print(f'{k}: {v}')
" 2>/dev/null
    ;;

  # ── ดู snapshot ─────────────────────────────────────────────────
  snapshot)
    echo ""
    echo -e "${BOLD}=== Working Memory ===${RESET}"
    if [ -f "$WM_FILE" ]; then
      python3 -c "
import json
wm = json.load(open('$WM_FILE'))
print(f\"  task:    {wm.get('task','(ไม่มี)')}\")
print(f\"  started: {wm.get('started','?')}\")
print(f\"  status:  {wm.get('status','?')}\")
print(f\"  steps:   {len(wm.get('steps',[]))}\")
ctx = wm.get('context', {})
if ctx:
    print(f'  context:')
    for k, v in ctx.items():
        print(f'    {k}: {str(v)[:50]}')
steps = wm.get('steps', [])
if steps:
    print(f'  recent steps:')
    for s in steps[-3:]:
        print(f\"    [{s['ts']}] {s['step']}\")
"
    else
      info "working memory ว่าง"
    fi
    echo ""
    ;;

  # ── เสร็จงาน → save to Oracle ─────────────────────────────────────
  done)
    SUMMARY="$*"
    [ -f "$WM_FILE" ] || { warn "ไม่มี working memory"; exit 0; }

    TASK=$(python3 -c "import json; wm=json.load(open('$WM_FILE')); print(wm.get('task','?'))" 2>/dev/null)
    STEPS=$(python3 -c "import json; wm=json.load(open('$WM_FILE')); print(len(wm.get('steps',[])))" 2>/dev/null)

    step "งานเสร็จ: $TASK ($STEPS steps)"

    # Save to Oracle
    if oracle_ready; then
      FULL_SUMMARY="task: $TASK | steps: $STEPS | summary: $SUMMARY"
      oracle_learn "completed-task:$TASK" "$FULL_SUMMARY" "completed,task,$(date +%Y-%m-%d)" > /dev/null
      ok "บันทึกลง Oracle แล้ว"
    fi

    # ล้าง working memory
    rm -f "$WM_FILE"
    log_action "WM_DONE" "$TASK: $SUMMARY"

    # Set emotion
    EMOTION="$SCRIPT_DIR/../mind/emotion.sh"
    [ -x "$EMOTION" ] && bash "$EMOTION" feel "satisfied" "$TASK done"

    ok "งานเสร็จสมบูรณ์: $TASK"
    ;;

  # ── ล้าง ─────────────────────────────────────────────────────────
  clear)
    rm -f "$WM_FILE" && ok "ล้าง working memory แล้ว"
    log_action "WM_CLEAR" ""
    ;;

  *)
    echo "Usage: working.sh {focus|context|step|recall|snapshot|done|clear}"
    echo ""
    echo "  focus   <task>         — เริ่มงาน"
    echo "  context <key> <value>  — บันทึก context"
    echo "  step    <desc>         — บันทึก step"
    echo "  recall  [key]          — เรียกคืน context"
    echo "  snapshot               — ดู working memory"
    echo "  done    [summary]      — เสร็จงาน → Oracle"
    echo "  clear                  — ล้าง"
    ;;
esac
