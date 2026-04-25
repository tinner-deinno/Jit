#!/usr/bin/env bash
# scripts/setup-secrets.sh — เข้ารหัส Ollama token ด้วยคู่คำ Jit Key
# รันครั้งเดียวในเครื่อง local เพื่อสร้าง .secrets/ollama.enc
#
# Usage:
#   bash scripts/setup-secrets.sh              # interactive (ถาม passphrase)
#   bash scripts/setup-secrets.sh --verify     # ตรวจสอบ encrypted token
#   bash scripts/setup-secrets.sh --load       # โหลด token ลง env (สำหรับ script อื่น)
#
# ⚠️  NEVER share your passphrase (คู่คำถอดคีย์) publicly
# ⚠️  NEVER commit .env or raw tokens to git

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$SCRIPT_DIR/.."
SECRETS_DIR="$JIT_ROOT/.secrets"
ENC_FILE="$SECRETS_DIR/ollama.enc"
META_FILE="$SECRETS_DIR/ollama.enc.meta"
ENV_FILE="$JIT_ROOT/.env"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

case "${1:-encrypt}" in

  # ── เข้ารหัส token ใหม่ ─────────────────────────────────────────
  encrypt|"")
    echo ""
    echo -e "${BOLD}${CYAN}🔐 Jit Secret Vault — ตั้งค่า Ollama Token${RESET}"
    echo -e "${YELLOW}ข้อมูลจะถูกเข้ารหัสด้วย AES-256-CBC-PBKDF2${RESET}"
    echo ""
    echo -e "${BOLD}ขั้นตอน:${RESET}"
    echo -e "  1. ป้อน MDES Ollama token จริง"
    echo -e "  2. ป้อนคู่คำถอดคีย์ (Jit Master Key) ที่ได้รับ"
    echo ""
    read -s -p "🔑 Ollama Token: " REAL_TOKEN; echo ""
    if [ -z "$REAL_TOKEN" ]; then
      echo -e "${RED}❌ ไม่ได้ใส่ token${RESET}"; exit 1
    fi
    read -s -p "🗝️  คู่คำถอดคีย์ (passphrase): " PASSPHRASE; echo ""
    if [ -z "$PASSPHRASE" ]; then
      echo -e "${RED}❌ ไม่ได้ใส่ passphrase${RESET}"; exit 1
    fi

    mkdir -p "$SECRETS_DIR"
    echo -n "$REAL_TOKEN" | openssl enc -aes-256-cbc -pbkdf2 -iter 310000 \
      -pass pass:"$PASSPHRASE" -a > "$ENC_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
      echo -e "${RED}❌ Encryption ล้มเหลว${RESET}"; exit 1
    fi

    # อัพเดต fingerprint
    FINGERPRINT=$(echo -n "$PASSPHRASE" | openssl dgst -sha256 | awk '{print $2}' | cut -c1-16)
    cat > "$META_FILE" << METAEOF
fingerprint: sha256:$FINGERPRINT
algorithm: AES-256-CBC-PBKDF2-310000
created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
purpose: MDES Ollama API token for innova agent
METAEOF

    echo ""
    echo -e "${GREEN}✅ Token เข้ารหัสเสร็จแล้ว → .secrets/ollama.enc${RESET}"
    echo -e "${CYAN}ℹ️  fingerprint: sha256:$FINGERPRINT${RESET}"
    echo -e "${YELLOW}⚠️  เก็บ passphrase ไว้อย่างปลอดภัย ไม่มีทางกู้คืนได้!${RESET}"
    echo ""
    echo -e "ต้องการโหลด token ลง .env ตอนนี้เลยไหม? [y/N]: \c"
    read ANSWER
    if [[ "$ANSWER" == [yY] ]]; then
      exec "$0" load "$PASSPHRASE"
    fi
    ;;

  # ── ถอดรหัสและโหลดลง .env ────────────────────────────────────────
  load)
    PASSPHRASE="${2:-}"
    if [ -z "$PASSPHRASE" ]; then
      read -s -p "🗝️  คู่คำถอดคีย์: " PASSPHRASE; echo ""
    fi
    if [ ! -f "$ENC_FILE" ]; then
      echo -e "${RED}❌ ไม่พบ .secrets/ollama.enc — รัน setup-secrets.sh ก่อน${RESET}"; exit 1
    fi
    TOKEN=$(openssl enc -aes-256-cbc -pbkdf2 -iter 310000 -pass pass:"$PASSPHRASE" -d -a \
      -in "$ENC_FILE" 2>/dev/null)
    if [ -z "$TOKEN" ]; then
      echo -e "${RED}❌ Passphrase ไม่ถูกต้อง หรือ file เสีย${RESET}"; exit 1
    fi

    # เขียน .env
    if [ -f "$ENV_FILE" ]; then
      # อัพเดต OLLAMA_TOKEN ใน .env ที่มีอยู่แล้ว
      sed -i "s|^OLLAMA_TOKEN=.*|OLLAMA_TOKEN=$TOKEN|" "$ENV_FILE"
    else
      cat > "$ENV_FILE" << ENVEOF
# Auto-generated from .secrets/ollama.enc — DO NOT COMMIT
OLLAMA_TOKEN=$TOKEN
OLLAMA_BASE_URL=https://ollama.mdes-innova.online
ORACLE_PORT=47778
ENVEOF
    fi
    echo -e "${GREEN}✅ Token โหลดลง .env แล้ว${RESET}"
    echo -e "${CYAN}  ใช้: source .env หรือ export \$(grep -v '#' .env | xargs)${RESET}"
    ;;

  # ── ตรวจสอบว่า token decrypt ได้ ─────────────────────────────────
  verify)
    if [ ! -f "$ENC_FILE" ]; then
      echo -e "${RED}❌ ไม่พบ .secrets/ollama.enc${RESET}"; exit 1
    fi
    read -s -p "🗝️  คู่คำถอดคีย์: " PASSPHRASE; echo ""
    TOKEN=$(openssl enc -aes-256-cbc -pbkdf2 -iter 310000 -pass pass:"$PASSPHRASE" -d -a \
      -in "$ENC_FILE" 2>/dev/null)
    if [ -z "$TOKEN" ]; then
      echo -e "${RED}❌ Passphrase ไม่ถูกต้อง${RESET}"; exit 1
    fi
    MASKED="${TOKEN:0:4}****${TOKEN: -4}"
    echo -e "${GREEN}✅ Token ถอดรหัสได้: ${MASKED} (masked)${RESET}"
    echo -e "${CYAN}  ทดสอบ API:${RESET}"
    curl -sf --max-time 5 "https://ollama.mdes-innova.online/api/tags" \
      -H "Authorization: Bearer $TOKEN" > /dev/null 2>&1 \
      && echo -e "${GREEN}  ✅ Ollama API ตอบรับ${RESET}" \
      || echo -e "${YELLOW}  ⚠️  Ollama API ไม่ตอบ (อาจ offline)${RESET}"
    ;;

  # ── source-friendly: ส่ง token ออก stdout ────────────────────────
  decrypt-stdout)
    # ใช้ใน: OLLAMA_TOKEN=$(bash scripts/setup-secrets.sh decrypt-stdout "$PASS")
    PASSPHRASE="${2:-${JIT_PASSPHRASE:-}}"
    if [ -z "$PASSPHRASE" ]; then exit 1; fi
    openssl enc -aes-256-cbc -pbkdf2 -iter 310000 -pass pass:"$PASSPHRASE" -d -a \
      -in "$ENC_FILE" 2>/dev/null
    ;;

  *)
    echo "Usage: $0 [encrypt|load|verify|decrypt-stdout]"
    ;;
esac
