#!/usr/bin/env bash
# limbs/oracle.sh — หูและความรู้ของ innova: Arra Oracle V3 API
# Usage: ./oracle.sh search "คำค้นหา"
#        ./oracle.sh learn "pattern" "content" "concept1,concept2"
#        ./oracle.sh health

ORACLE_URL="${ORACLE_URL:-http://localhost:47778}"

CMD="${1:-health}"
shift || true

case "$CMD" in
  health)
    curl -s "$ORACLE_URL/api/health" | python3 -m json.tool
    ;;
  search)
    QUERY="${1:-oracle}"
    curl -s "$ORACLE_URL/api/search?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")" \
      | python3 -c "
import json,sys
d=json.load(sys.stdin)
results=d.get('results',[])
print(f'Found {len(results)} results:')
for r in results[:3]:
    print(f'  [{r[\"type\"]}] {r[\"id\"]}')
    print(f'    concepts: {r.get(\"concepts\",[])}')
"
    ;;
  learn)
    PATTERN="${1:-new learning}"
    CONTENT="${2:-content here}"
    CONCEPTS="${3:-general}"
    curl -s -X POST "$ORACLE_URL/api/learn" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c "
import json,sys
print(json.dumps({
  'pattern': '$PATTERN',
  'content': '$CONTENT',
  'type': 'learning',
  'concepts': '$CONCEPTS'.split(','),
  'origin': 'innova-jit'
}))
")" | python3 -c "import json,sys; d=json.load(sys.stdin); print('✅ Learned:', d.get('id','ERROR'))"
    ;;
  stats)
    curl -s "$ORACLE_URL/api/stats" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'Total docs: {d[\"total\"]}')
print(f'By type: {d[\"by_type\"]}')
print(f'DB: {d[\"database\"]}')
"
    ;;
  *)
    echo "Usage: $0 {health|search|learn|stats}"
    ;;
esac
