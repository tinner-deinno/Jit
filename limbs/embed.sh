#!/usr/bin/env bash
# limbs/embed.sh — Vector Embeddings: สร้างและจัดการ embeddings สำหรับ semantic memory
#
# หลักพุทธ: วิญญาณ — ความรู้สึกร่วมที่เชื่่อมโยงความทรงจำเข้าดวยกน
# "ความทรงจำท่คล้ายกน ดึงดดูซ่งกนและกน ผ่นพลังแห่งควมหมย"
#
# Usage:
#   ./embed.sh generate <key>           — สราง embedding สำหรับ key
#   ./embed.sh build-all                — สราง embeddings สำหรับทก memories
#   ./embed.sh refresh                  — Refresh embeddings ท่เก่อเกน 24h
#   ./embed.sh query "<query>"          — คนหาดวย semantic search
#   ./embed.sh similarity <emb1> <emb2> — คำนวณ cosine similarity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

MEMORY_DIR="/workspaces/Jit/memory"
EMBEDDINGS_DIR="$MEMORY_DIR/embeddings"
MEMORY_INDEX="$MEMORY_DIR/index.json"
EMBEDDING_INDEX="$EMBEDDINGS_DIR/index.embeddings.json"

# MDES Ollama config
OLLAMA_URL="https://ollama.mdes-innova.online"
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma4:e4b}"
OLLAMA_TOKEN="${OLLAMA_TOKEN:-}"

# Embedding weights
SEMANTIC_WEIGHT=0.4
DECAY_WEIGHT=0.35
ACCESS_WEIGHT=0.25

CMD="${1:-help}"
shift || true

# ── Helper Functions ───────────────────────────────────────────────

_load_embedding_index() {
  if [ -f "$EMBEDDING_INDEX" ]; then
    cat "$EMBEDDING_INDEX"
  else
    echo '{"embeddings":{}, "last_updated": null}'
  fi
}

_save_embedding_index() {
  echo "$1" > "$EMBEDDING_INDEX"
}

# สร้าง embedding แบบ local (fallback)
_generate_embedding_local() {
  local text="$1"
  python3 << PYEOF
import hashlib
import struct
import math
import json

text = """$text"""

dimensions = 64
vector = []

for i in range(dimensions):
    h = hashlib.sha256(f"{text}:{i}".encode()).digest()
    val = struct.unpack('f', h[:4])[0]
    val = math.tanh(val)
    vector.append(round(val, 6))

print(json.dumps(vector))
PYEOF
}

# สร้าง embedding ผ่าน MDES Ollama หรือ local fallback
_generate_embedding() {
  local text="$1"

  # ถ้าไม่มี token ใช้ local method
  if [ -z "$OLLAMA_TOKEN" ]; then
    _generate_embedding_local "$text"
    return 0
  fi

  # พยายามใช้ Ollama API
  local response
  response=$(curl -sf --max-time 10 \
    --header "Authorization: Bearer $OLLAMA_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"$(echo "$text" | base64 -w0)\"}" \
    "$OLLAMA_URL/api/embeddings" 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$response" ]; then
    local embedding
    embedding=$(echo "$response" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    emb = d.get('embedding', d.get('embeddings', []))
    if emb:
        print(json.dumps(emb))
    else:
        sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null)

    if [ -n "$embedding" ] && [ "$embedding" != "null" ]; then
      echo "$embedding"
      return 0
    fi
  fi

  # Fallback ไป local
  _generate_embedding_local "$text"
}

cosine_similarity() {
  local vec1="$1"
  local vec2="$2"

  python3 << PYEOF
import json
import math

v1 = json.loads('''$vec1''')
v2 = json.loads('''$vec2''')

if len(v1) != len(v2):
    print("0.0")
    exit(0)

dot_product = sum(a * b for a, b in zip(v1, v2))
norm1 = math.sqrt(sum(a * a for a in v1))
norm2 = math.sqrt(sum(b * b for b in v2))

if norm1 == 0 or norm2 == 0:
    print("0.0")
else:
    similarity = dot_product / (norm1 * norm2)
    similarity = max(0, min(1, (similarity + 1) / 2))
    print(f"{similarity:.6f}")
PYEOF
}

# ── Main Commands ──────────────────────────────────────────────────

case "$CMD" in

  generate)
    KEY="$1"
    if [ -z "$KEY" ]; then
      err "ตองระบุ key: embed.sh generate <key>"
      exit 1
    fi

    if [ ! -f "$MEMORY_INDEX" ]; then
      err "ไมพบ memory index"
      exit 1
    fi

    VALUE=$(python3 << PYEOF
import json
index = json.load(open('$MEMORY_INDEX'))
entry = index.get('entries', {}).get('$KEY')
if entry:
    print(entry.get('value', ''))
else:
    print('')
PYEOF
)

    if [ -z "$VALUE" ]; then
      err "ไมพบ key: $KEY"
      exit 1
    fi

    step "Generating embedding for: $KEY"

    EMBEDDING=$(_generate_embedding "$VALUE")

    if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" = "null" ]; then
      err "Failed to generate embedding"
      exit 1
    fi

    TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
    EMBEDDING_FILE="$EMBEDDINGS_DIR/${KEY}.embedding.json"

    cat > "$EMBEDDING_FILE" << EOF
{
  "key": "$KEY",
  "embedding": $EMBEDDING,
  "model": "$OLLAMA_MODEL",
  "generated_at": "$TIMESTAMP",
  "source": "memory_index"
}
EOF

    # อัพเดท embedding index
    python3 << PYEOF
import json
from datetime import datetime

index_path = '$EMBEDDING_INDEX'
try:
    with open(index_path, 'r') as f:
        index = json.load(f)
except:
    index = {"embeddings": {}, "last_updated": None}

embedding_data = json.loads('''$EMBEDDING''')

index['embeddings']['$KEY'] = {
    'file': '${KEY}.embedding.json',
    'model': '$OLLAMA_MODEL',
    'generated_at': '$TIMESTAMP',
    'dimensions': len(embedding_data)
}
index['last_updated'] = datetime.now().isoformat()

with open(index_path, 'w') as f:
    json.dump(index, f, indent=2)
PYEOF

    DIMENSIONS=$(echo "$EMBEDDING" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
    ok "Generated embedding: $KEY ($DIMENSIONS dims)"
    ;;

  build-all)
    step "Building embeddings for all memories..."

    if [ ! -f "$MEMORY_INDEX" ]; then
      err "ไมพบ memory index"
      exit 1
    fi

    mkdir -p "$EMBEDDINGS_DIR"

    # หา keys ที่ยังไม่มี embedding
    KEYS_WITHOUT_EMBEDDINGS=$(python3 << PYEOF
import json
import os

index = json.load(open('$MEMORY_INDEX'))
existing = set()
if os.path.exists('$EMBEDDINGS_DIR'):
    for f in os.listdir('$EMBEDDINGS_DIR'):
        if f.endswith('.embedding.json'):
            existing.add(f.replace('.embedding.json', ''))

keys_needed = []
for key in index.get('entries', {}).keys():
    if key not in existing:
        keys_needed.append(key)

print(' '.join(keys_needed))
PYEOF
)

    if [ -z "$KEYS_WITHOUT_EMBEDDINGS" ]; then
      info "ทก memories มี embedding แลว"
      exit 0
    fi

    TOTAL=0
    SUCCESS=0
    FAILED=0

    for KEY in $KEYS_WITHOUT_EMBEDDINGS; do
      TOTAL=$((TOTAL + 1))

      VALUE=$(python3 << PYEOF
import json
index = json.load(open('$MEMORY_INDEX'))
entry = index.get('entries', {}).get('$KEY')
if entry:
    val = entry.get('value', '')
    print(val.replace('\n', ' ')[:500] if val else '')
PYEOF
)

      if [ -n "$VALUE" ]; then
        EMBEDDING=$(_generate_embedding "$VALUE")

        if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
          TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
          EMBEDDING_FILE="$EMBEDDINGS_DIR/${KEY}.embedding.json"

          cat > "$EMBEDDING_FILE" << EOF
{
  "key": "$KEY",
  "embedding": $EMBEDDING,
  "model": "$OLLAMA_MODEL",
  "generated_at": "$TIMESTAMP",
  "source": "batch_build"
}
EOF
          SUCCESS=$((SUCCESS + 1))
          info "  ✓ $KEY"
        else
          FAILED=$((FAILED + 1))
          warn "  ✗ $KEY (embedding failed)"
        fi
      else
        FAILED=$((FAILED + 1))
        warn "  ✗ $KEY (no value)"
      fi
    done

    # อัพเดท embedding index
    python3 << PYEOF
import json
import os
from datetime import datetime

index = {"embeddings": {}, "last_updated": None}

embed_dir = '$EMBEDDINGS_DIR'
if os.path.exists(embed_dir):
    for f in os.listdir(embed_dir):
        if f.endswith('.embedding.json'):
            key = f.replace('.embedding.json', '')
            try:
                filepath = os.path.join(embed_dir, f)
                with open(filepath, 'r') as file:
                    data = json.load(file)
                index["embeddings"][key] = {
                    "file": f,
                    "model": data.get("model", "unknown"),
                    "generated_at": data.get("generated_at"),
                    "dimensions": len(data.get("embedding", []))
                }
            except Exception as e:
                pass

index["last_updated"] = datetime.now().isoformat()

with open('$EMBEDDING_INDEX', 'w') as f:
    json.dump(index, f, indent=2)
PYEOF

    ok "Build complete: $SUCCESS succeeded, $FAILED failed (total: $TOTAL)"
    ;;

  refresh)
    step "Refreshing stale embeddings..."

    if [ ! -f "$EMBEDDING_INDEX" ]; then
      info "ไมมี embedding index"
      exit 0
    fi

    STALE_KEYS=$(python3 << PYEOF
import json
from datetime import datetime, timedelta

index = json.load(open('$EMBEDDING_INDEX'))
now = datetime.now()
threshold = now - timedelta(hours=24)

stale = []
for key, meta in index.get('embeddings', {}).items():
    gen_at = meta.get('generated_at', '')
    if gen_at:
        try:
            gen_time = datetime.fromisoformat(gen_at.replace('Z', '+00:00')).replace(tzinfo=None)
            if gen_time < threshold:
                stale.append(key)
        except:
            pass

print(' '.join(stale))
PYEOF
)

    if [ -z "$STALE_KEYS" ]; then
      info "ไมมี embeddings ท่ตอง refresh"
      exit 0
    fi

    for KEY in $STALE_KEYS; do
      info "  Refreshing: $KEY"
      "$SCRIPT_DIR/embed.sh" generate "$KEY" 2>/dev/null || warn "    Failed: $KEY"
    done

    ok "Refresh complete"
    ;;

  query)
    QUERY="$1"
    LIMIT="${2:-10}"

    if [ -z "$QUERY" ]; then
      err "ตองระบุ query: embed.sh query \"<query>\" [limit]"
      exit 1
    fi

    step "Semantic search: '$QUERY'"

    QUERY_EMBEDDING=$(_generate_embedding "$QUERY")

    if [ -z "$QUERY_EMBEDDING" ]; then
      err "Failed to generate query embedding"
      exit 1
    fi

    python3 << PYEOF
import json
import os
import math
from datetime import datetime

QUERY_EMBEDDING = json.loads('''$QUERY_EMBEDDING''')
MEMORY_INDEX = "$MEMORY_INDEX"
EMBEDDINGS_DIR = "$EMBEDDINGS_DIR"
LIMIT = $LIMIT
SEMANTIC_WEIGHT = $SEMANTIC_WEIGHT
DECAY_WEIGHT = $DECAY_WEIGHT
ACCESS_WEIGHT = $ACCESS_WEIGHT
QUERY_TEXT = "$QUERY"

memory_index = json.load(open(MEMORY_INDEX)) if os.path.exists(MEMORY_INDEX) else {"entries": {}}

results = []

for filename in os.listdir(EMBEDDINGS_DIR):
    if not filename.endswith('.embedding.json'):
        continue

    key = filename.replace('.embedding.json', '')
    entry = memory_index.get('entries', {}).get(key)

    if not entry:
        continue

    try:
        emb_data = json.load(open(os.path.join(EMBEDDINGS_DIR, filename)))
        embedding = emb_data.get('embedding', [])

        dot = sum(a * b for a, b in zip(QUERY_EMBEDDING, embedding))
        norm_q = math.sqrt(sum(a * a for a in QUERY_EMBEDDING))
        norm_e = math.sqrt(sum(b * b for b in embedding))

        if norm_q == 0 or norm_e == 0:
            continue

        sim = (dot / (norm_q * norm_e) + 1) / 2

        created_str = entry.get('created_date', datetime.now().isoformat()).replace('Z', '+00:00')
        try:
            created = datetime.fromisoformat(created_str).replace(tzinfo=None)
        except:
            created = datetime.now()
        days_since = (datetime.now() - created).days
        decay_score = 1.0 / (1.0 + max(0, days_since) / 30.0)

        access_count = entry.get('access_count', 0)
        access_score = min(1.0, math.log10(max(0, access_count) + 1) / 3.0)

        combined = (SEMANTIC_WEIGHT * sim) + (DECAY_WEIGHT * decay_score) + (ACCESS_WEIGHT * access_score)

        results.append({
            "key": key,
            "value": entry.get('value', '')[:200],
            "similarity_score": round(sim, 4),
            "decay_score": round(decay_score, 4),
            "combined_score": round(combined, 4),
            "source": "semantic"
        })
    except Exception as e:
        pass

results.sort(key=lambda x: x['combined_score'], reverse=True)

print(f"\n=== Semantic Search Results: '{QUERY_TEXT}' ===")
for r in results[:LIMIT]:
    print(f"  [{r['combined_score']:.3f}] sim={r['similarity_score']:.3f} decay={r['decay_score']:.3f}")
    print(f"    {r['key']}: {r['value'][:80]}...")
    print()

if not results:
    print("  (ไมพบผลลพธ)")
PYEOF
    ;;

  similarity)
    FILE1="$1"
    FILE2="$2"

    if [ ! -f "$FILE1" ] || [ ! -f "$FILE2" ]; then
      err "ไมพบไฟล embedding"
      exit 1
    fi

    VEC1=$(python3 -c "import json; print(json.dumps(json.load(open('$FILE1')).get('embedding', [])))")
    VEC2=$(python3 -c "import json; print(json.dumps(json.load(open('$FILE2')).get('embedding', [])))")

    SIM=$(cosine_similarity "$VEC1" "$VEC2")
    echo "Cosine Similarity: $SIM"
    ;;

  *)
    echo "Usage: embed.sh <command>"
    echo ""
    echo "  generate <key>              — สราง embedding สำหรับ key"
    echo "  build-all                   — สราง embeddings สำหรับทก memories"
    echo "  refresh                     — Refresh embeddings เก่าเกน 24h"
    echo "  query \"<query>\" [limit]     — Semantic search"
    echo "  similarity <file1> <file2>  — คำนวณ cosine similarity"
    echo ""
    echo "Embedding Storage:"
    echo "  $EMBEDDINGS_DIR/"
    ;;
esac
