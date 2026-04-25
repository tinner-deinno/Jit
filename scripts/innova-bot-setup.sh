#!/usr/bin/env bash
# scripts/innova-bot-setup.sh — Detect, clone, and inspect innova-bot repository
# This script helps Jit find or provision the innova-bot body and read its README.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$JIT_ROOT/limbs/lib.sh"

if [ -f "$JIT_ROOT/.env" ]; then
  set -a
  . "$JIT_ROOT/.env"
  set +a
fi

REPO_URL="${1:-${INNOVA_BOT_REPO:-}}"
DEST_DIR="${INNOVA_BOT_PATH:-$JIT_ROOT/innova-bot}"

if [ -z "$REPO_URL" ] && [ ! -d "$DEST_DIR/.git" ]; then
  err "ไม่พบ INNOVA_BOT_REPO และไม่มี innova-bot repo ใน workspace"
  echo "โปรดกำหนด INNOVA_BOT_REPO ใน .env หรือส่ง URL เป็น argument"
  echo "Usage: bash scripts/innova-bot-setup.sh <git-url>"
  exit 1
fi

step "innova-bot path: $DEST_DIR"

if [ -d "$DEST_DIR/.git" ]; then
  ok "พบ innova-bot repository แล้ว ที่ $DEST_DIR"
  if [ -n "$REPO_URL" ]; then
    step "ตรวจสอบ remote และ sync"
    git -C "$DEST_DIR" remote set-url origin "$REPO_URL" 2>/dev/null || true
  fi
  git -C "$DEST_DIR" pull --ff-only 2>/dev/null || warn "pull จาก innova-bot remote ไม่สำเร็จ"
else
  ok "กำลัง clone innova-bot จาก $REPO_URL"
  git clone "$REPO_URL" "$DEST_DIR"
fi

if [ ! -d "$DEST_DIR" ]; then
  err "ไม่สามารถจัดเตรียม innova-bot ได้"
  exit 1
fi

bash "$JIT_ROOT/memory/shared.sh" set innova_bot.path "$DEST_DIR"
bash "$JIT_ROOT/memory/shared.sh" set innova_bot.ready true
bash "$JIT_ROOT/memory/shared.sh" set innova_bot.updated "$(date +%Y-%m-%dT%H:%M:%S)"

if [ -f "$DEST_DIR/README.md" ]; then
  step "อ่าน README ของ innova-bot"
  SUMMARY=$(head -n 40 "$DEST_DIR/README.md" | sed 's/^/  /')
  echo "=== innova-bot README preview ==="
  echo "$SUMMARY"
  echo "================================="
  SHORT=$(head -n 20 "$DEST_DIR/README.md" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-300)
  bash "$JIT_ROOT/memory/shared.sh" set innova_bot.readme_summary "$SHORT"
  bash "$JIT_ROOT/memory/shared.sh" set innova_bot.readme_path "$DEST_DIR/README.md"
else
  warn "ไม่พบ README.md ใน innova-bot repo"
fi

DEFAULT_SETUP="setup.sh"
if [ -f "$DEST_DIR/$DEFAULT_SETUP" ]; then
  step "พบ $DEFAULT_SETUP ใน innova-bot — แสดงคำสั่งติดตั้ง"
  echo "Run: bash $DEST_DIR/$DEFAULT_SETUP"
elif [ -f "$DEST_DIR/bootstrap.sh" ]; then
  step "พบ bootstrap.sh ใน innova-bot — แสดงคำสั่งติดตั้ง"
  echo "Run: bash $DEST_DIR/bootstrap.sh"
else
  info "ไม่มีสคริปต์ setup อัตโนมัติใน innova-bot repo"
fi

ok "innova-bot setup complete"
