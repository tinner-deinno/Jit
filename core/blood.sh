#!/usr/bin/env bash
# core/blood.sh — Blood Protocol (เลือด)
#
# เลือด = ข้อมูลที่ไหลเวียนระหว่างอวัยวะในแต่ละรอบชีวิต
# อวัยวะเขียน blood หลังทำงานเสร็จ → หัวใจเก็บรวม → จิตสังเคราะห์
#
# Blood packet format:
#   { organ, cycle, task, status, findings[], alerts[], ts }
#
# ใช้: source "$JIT_ROOT/core/blood.sh"

BLOOD_DIR="${BLOOD_DIR:-/tmp/manusat-blood}"
mkdir -p "$BLOOD_DIR"

# ── write_blood <organ> <cycle> <task> <status> <findings_csv> [alerts_csv]
# atomic: เขียน .tmp ก่อน แล้ว rename — ป้องกัน partial reads
write_blood() {
  local organ="${1:-unknown}" cycle="${2:-0}" task="${3:-work}"
  local status="${4:-done}" findings="${5:-}" alerts="${6:-}"
  local TMPF="${BLOOD_DIR}/.${organ}.tmp.$$"
  local FINAL="${BLOOD_DIR}/${organ}.json"
  python3 -c "
import json, sys, datetime
organ,cycle,task,status,findings,alerts,tmpf = sys.argv[1:]
data = {
  'organ': organ,
  'cycle': int(cycle),
  'task': task,
  'status': status,
  'findings': [f.strip() for f in findings.split(',') if f.strip()],
  'alerts':   [a.strip() for a in alerts.split(',')   if a.strip()],
  'ts': datetime.datetime.now().isoformat()
}
with open(tmpf, 'w', encoding='utf-8') as f:
  json.dump(data, f, ensure_ascii=False, indent=2)
" "$organ" "$cycle" "$task" "$status" "$findings" "$alerts" "$TMPF" \
  && mv "$TMPF" "$FINAL" 2>/dev/null || rm -f "$TMPF" 2>/dev/null
}

# ── collect_all_blood → stdout JSON array ของ blood ทุก organ
collect_all_blood() {
  python3 - << 'PYEOF'
import json, os, glob
blood_dir = os.environ.get('BLOOD_DIR', '/tmp/manusat-blood')
results = []
for f in sorted(glob.glob(f'{blood_dir}/*.json')):
  if 'synthesized' in os.path.basename(f):
    continue
  try:
    with open(f, encoding='utf-8') as fp:
      results.append(json.load(fp))
  except Exception:
    pass
print(json.dumps(results, ensure_ascii=False, indent=2))
PYEOF
}

# ── read_organ_blood <organ> → JSON string หรือ "{}"
read_organ_blood() {
  local f="${BLOOD_DIR}/${1}.json"
  [ -f "$f" ] && cat "$f" || echo '{}'
}

# ── clear_blood — ล้างก่อนเริ่ม cycle ใหม่ (คง synthesized.json ไว้)
clear_blood() {
  find "$BLOOD_DIR" -maxdepth 1 -name '*.json' \
    -not -name 'synthesized.json' -delete 2>/dev/null || true
}

# ── get_all_alerts → "organ: alert" แต่ละ line (สำหรับ jit ตัดสินใจ)
get_all_alerts() {
  python3 - << 'PYEOF'
import json, os, glob
blood_dir = os.environ.get('BLOOD_DIR', '/tmp/manusat-blood')
for f in glob.glob(f'{blood_dir}/*.json'):
  if 'synthesized' in os.path.basename(f):
    continue
  try:
    with open(f, encoding='utf-8') as fp:
      d = json.load(fp)
    for a in d.get('alerts', []):
      print(f"{d.get('organ','?')}: {a}")
  except Exception:
    pass
PYEOF
}
