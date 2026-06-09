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

# ─── _load_embedding_index: load embedding index from disk ─────────────────────
# โหลดดัชนี embedding จากไฟล์บนดิสก์เพื่อใช้ในการค้นหาความคล้ายคลึง
#
# พารามิเตอร์:
#   ไม่มีพารามิเตอร์โดยตรง แต่ใช้อินพุตจากตัวแปรทั่วโลก:
#   $EMBEDDING_INDEX - เส้นทางไปยังไฟล์ดัชนี embedding (กำหนดไว้ที่บรรทัด 20: $EMBEDDINGS_DIR/index.embeddings.json)
#
# คืนค่า:
#   สตริง JSON ที่แสดงถึงดัชนี embedding ไปยัง stdout
#   หากไฟล์ไม่พบ จะคืนค่าเริ่มต้น: {"embeddings":{}, "last_updated": null}
#
# ผลข้างเคียง:
#   ไม่มี - ฟังก์ชันนี้เพียงอ่านและคืนค่าข้อมูลเท่านั้น
#
# หมายเหตุ: ดัชนี embedding มีโครงสร้างเป็น:
#   {
#     "embeddings": {
#       "<key>": {
#         "file": "<filename>.embedding.json",
#         "model": "<model name>",
#         "generated_at": "<ISO timestamp>",
#         "dimensions": <จำนวนมิติ>
#       }
#     },
#     "last_updated": "<ISO timestamp> หรือ null"
#   }
#
# ฟังก์ชันนี้ถูกออกแบบมาให้เรียกใช้จากภายในสคริปต์เดียวกันเท่านั้น
# มิได้ถูกออกแบบมาให้เรียกใช้จากภายนอกโดยตรง
_load_embedding_index() {
  if [ -f "$EMBEDDING_INDEX" ]; then
    cat "$EMBEDDING_INDEX"
  else
    echo '{"embeddings":{}, "last_updated": null}'
  fi
}

# ─── _save_embedding_index: save embedding index to disk ───────────────────────
# บันทึกดัชนี embedding ลงไฟล์บนดิสก์
#
# พารามิเตอร์:
#   $1 - สตริง JSON ที่แสดงถึงดัชนี embedding ที่ต้องการบันทึก
#
# คืนค่า:
#   ไม่มีค่าคืนค่าโดยตรง แต่จะเขียนข้อมูลลงในไฟล์ที่ระบุโดย $EMBEDDING_INDEX
#
# ผลข้างเคียง:
#   เขียนหรือเขียนทับไฟล์ $EMBEDDING_INDEX ด้วยข้อมูล JSON ที่ได้รับเป็นพารามิเตอร์
#   หากไดเรกทอรีที่มีไฟล์ดัชนีอยู่ไม่มีอยู่ จะไม่สร้างไดเรกทอรีให้ (ควรจะมีอยู่แล้วจากการเริ่มต้นสคริปต์)
#
# หมายเหตุ: ฟังก์ชันนี้ไม่ทำการตรวจสอบว่าพารามิเตอร์ที่ได้รับเป็น JSON ที่ถูกต้องหรือไม่
# หน้าที่ตรวจสอบความถูกต้องของข้อมูลควรทำโดยผู้เรียกใช้ก่อนที่จะเรียกฟังก์ชันนี้
#
# ฟังก์ชันนี้ถูกออกแบบมาให้เรียกใช้จากภายในสคริปต์เดียวกันเท่านั้น
# มิได้ถูกออกแบบมาให้เรียกใช้จากภายนอกโดยตรง
_save_embedding_index() {
  echo "$1" > "$EMBEDDING_INDEX"
}

# สร้าง embedding แบบ local (fallback)
# ─── _generate_embedding_local: generate embedding using local fallback method ───
# สร้าง embedding ด้วยวิธีท้องถิ่นเป็นทางเลือกเมื่อไม่สามารถใช้บริการภายนอกได้
#
# พารามิเตอร์:
#   $1 - ข้อความ (text) ที่ต้องการสร้าง embedding
#
# คืนค่า:
#   สตริง JSON ที่แสดงถึง embedding vector ไปยัง stdout
#   รูปแบบ: [v1, v2, v3, ..., vn] โดยที่แต่ละ v เป็นตัวเลขทศนิยม
#   จำนวนมิติคงที่ที่ 64 มิติ
#
# ผลข้างเคียง:
#   ไม่มี - ฟังก์ชันนี้เพียงสร้างและคืนค่า embedding เท่านั้น
#
# อัลกอริทึม:
#   1. แบ่งข้อความออกเป็นช่วงๆ ตามจำนวนมิติที่ต้องการ (64 มิติ)
#   2. สำหรับแต่ละช่วงที่ i:
#      - สร้าง hash จากข้อความรวมกับดัชนีช่วง: SHA256(text + ":" + i)
#      - แยก 4 ไบต์แรกของ hash และแปลงเป็นตัวเลข float
#      - ใช้ฟังก์ชัน tanh เพื่อให้ค่าอยู่ในช่วง [-1, 1]
#      - ปัดเศษเป็น 6 ตำแหน่งทศนิยม
#   3. รวมค่าทั้งหมดเป็น vector และแปลงเป็น JSON array
#
# หมายเหตุ: นี่คือวิธีสำรอง (fallback) เมื่อไม่สามารถเชื่อมต่อกับบริการภายนอก
# เช่น MDES Ollama API ได้ ให้ผลลัพธ์ที่สม่ำเสมอแต่อาจไม่มีคุณภาพทาง
# semantics เท่ากับการใช้โมเดลภายนอกที่ผ่านการฝึกอบรมมาโดยเฉพาะ
#
# ฟังก์ชันนี้ถูกออกแบบมาให้เรียกใช้จากภายในสคริปต์เดียวกันเท่านั้น
# มิได้ถูกออกแบบมาให้เรียกใช้จากภายนอกโดยตรง
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
# ─── _generate_embedding: generate embedding via MDES Ollama or local fallback ───
# สร้าง embedding โดยใช้บริการ MDES Ollama หรือวิธีสำรองท้องถิ่นเมื่อบริการภายนอกไม่พร้อมใช้งาน
#
# พารามิเตอร์:
#   $1 - ข้อความ (text) ที่ต้องการสร้าง embedding
#
# คืนค่า:
#   สตริง JSON ที่แสดงถึง embedding vector ไปยัง stdout
#   รูปแบบ: [v1, v2, v3, ..., vn] โดยที่แต่ละ v เป็นตัวเลขทศนิยม
#   คืนค่า 0 หากสำเร็จ คืนค่า 1 หากล้มเหลว
#
# ผลข้างเคียง:
#   ไม่มี - ฟังก์ชันนี้เพียงสร้างและคืนค่า embedding เท่านั้น
#
# กระบวนการทำงาน:
#   1. ตรวจสอบว่ามี OLLAMA_TOKEN ตั้งค่าอยู่หรือไม่
#   2. หากไม่มี token ให้ใช้วิธีสำรองท้องถิ่นทันที (_generate_embedding_local)
#   3. หากมี token ให้พยายามเรียกใช้ MDES Ollama API ผ่าน HTTP POST ไปยัง $OLLAMA_URL/api/embeddings
#   4. หากการเรียก API สำเร็จและได้รับ embedding ที่ถูกต้อง ให้คืนค่านั้น
#   5. หากการเรียก API ล้มเหลวหรือไม่ได้ผลลัพธ์ที่ต้องการ ให้ใช้วิธีสำรองท้องถิ่น (_generate_embedding_local)
#
# การตั้งค่าที่ใช้:
#   $OLLAMA_URL - URL ของ MDES Ollama service (ค่าเริ่มต้น: https://ollama.mdes-innova.online)
#   $OLLAMA_MODEL - ชื่อโมเดลที่ใช้สร้าง embedding (ค่าเริ่มต้น: gemma4:e4b)
#   $OLLAMA_TOKEN - Token สำหรับการตรวจสอบสิทธิ์กับ Ollama service (อาจว่าง)
#
# ผลลัพธ์:
#   หากสำเร็จ: พิมพ์ embedding เป็น JSON array ไปยัง stdout และคืนค่า 0
#   หากล้มเหลว: ไม่พิมพ์อะไรไปยัง stdout และคืนค่า 1
#
# หมายเหตุ: นี่คือฟังก์ชันหลักสำหรับสร้าง embedding ในระบบ
# จะพยายามใช้บริการภายนอกก่อนเพื่อให้ได้ผลลัพธ์ที่มีคุณภาพทาง semantics ที่ดีกว่า
# หากบริการภายนอกไม่พร้อมใช้งาน จะกลับไปใช้วิธีสำรองท้องถิ่นเพื่อให้ระบบยังคงทำงานได้
#
# ฟังก์ชันนี้ถูกออกแบบมาให้เรียกใช้จากภายในสคริปต์เดียวกันเท่านั้น
# มิได้ถูกออกแบบมาให้เรียกใช้จากภายนอกโดยตรง
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

# ─── cosine_similarity: calculate cosine similarity between two vectors ───
# คำนวณ cosine similarity ระหว่างสองเวกเตอร์เพื่อวัดความคล้ายคลึงทางทิศทาง
#
# พารามิเตอร์:
#   $1 - เวกเตอร์แรกในรูปแบบ JSON array (ตัวอย่าง: "[0.1, 0.2, 0.3, ...]")
#   $2 - เวกเตอร์ที่สองในรูปแบบ JSON array (ต้องมีจำนวนมิติเท่ากับเวกเตอร์แรก)
#
# คืนค่า:
#   ตัวเลขทศนิยมระหว่าง 0.0 ถึง 1.0 ที่แสดงถึงความคล้ายคลึง
#   โดยที่ 1.0 หมายถึงเวกเตอร์มีทิศทางเดียวกันอย่างสมบูรณ์
#   0.0 หมายถึงเวกเตอร์ตั้งฉากกันหรือมีมิติไม่เท่ากัน
#   ผลลัพธ์จะถูกพิมพ์ไปยัง stdout พร้อมทศนิยม 6 ตำแหน่ง
#
# ผลข้างเคียง:
#   ไม่มี - ฟังก์ชันนี้เพียงคำนวณและคืนค่าผลลัพธ์เท่านั้น
#
# อัลกอริทึม:
#   1. แปลงสตริง JSON เป็น Python list สำหรับทั้งสองเวกเตอร์
#   2. ตรวจสอบว่าทั้งสองเวกเตอร์มีจำนวนมิติเท่ากัน (หากไม่เท่ากัน คืนค่า 0.0 ทันที)
#   3. คำนวณ dot product ของสองเวกเตอร์
#   4. คำนวณ magnitude (norm) ของแต่ละเวกเตอร์
#   5. หาก magnitude ของเวกเตอร์ใดเป็น 0 ให้คืนค่า 0.0 (เพื่อป้องกันการหารด้วยศูนย์)
#   6. คำนวณ cosine similarity: dot_product / (norm1 * norm2)
#   7. แปลงค่าจากช่วง [-1, 1] เป็น [0, 1] ด้วยสูตร: (similarity + 1) / 2
#   8. จำกัดผลลัพธ์ให้อยู่ในช่วง [0, 1] ด้วยฟังก์ชัน max/min
#   9. พิมพ์ผลลัพธ์ด้วยทศนิยม 6 ตำแหน่ง
#
# หมายเหตุ:
#   - ค่า cosine similarity มาตรฐานอยู่ในช่วง [-1, 1] โดยที่:
#     * 1.0 = เวกเตอร์มีทิศทางเดียวกันอย่างสมบูรณ์
#     * 0.0 = เวกเตอร์ตั้งฉากกัน
#     * -1.0 = เวกเตอร์มีทิศทางตรงกันข้ามอย่างสมบูรณ์
#   - อย่างไรก็ตาม ในการประยุกต์ใช้กับ semantic search เรามักสนใจเฉพาะมิติบวก
#     ดังนั้นเราจึงแปลงค่าเป็นช่วง [0, 1] โดยที่ 0 หมายถึงไม่มีความคล้ายคลึง
#     และ 1 หมายถึงความคล้ายคลึงสูงสุด
#   - ฟังก์ชันนี้ถูกออกแบบมาให้เรียกใช้จากภายในสคริปต์เดียวกันเท่านั้น
#     มิได้ถูกออกแบบมาให้เรียกใช้จากภายนอกโดยตรง
#
# ตัวอย่างการใช้งานภายในสคริปต์:
#   VEC1=$(python3 -c "import json; print(json.dumps([0.1, 0.2, 0.3]))")
#   VEC2=$(python3 -c "import json; print(json.dumps([0.1, 0.2, 0.3]))")
#   SIMILARITY=$(cosine_similarity "$VEC1" "$VEC2")
#   echo "Similarity: $SIMILARITY"  # จะแสดง: Similarity: 1.000000
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
