#!/usr/bin/env bash
# scripts/cmdteam-daemon.sh — systemd wrapper สำหรับ cmdteam self-improve
#
# Daemon ที่ทำงานใน background เพื่อรัน cmdteam self-improve เป็นระยะๆ
# ทำหน้าที่เป็น wrapper รอบคำสั่ง cmdteam self-improve เพื่อ:
#   โหลดตัวแปรสภาพแวดล้อมจากไฟล์ .env
#   สร้างไดเรกทอรีสำหรับเก็บ log
#   รัน cmdteam self-improve และบันทึก output ไปยัง log file
#   ทำงานเป็น process แทนที่ shell ปัจจุบัน (exec)
#
# การใช้งาน:
#   ติดตั้งเป็น systemd service โดยใช้ไฟล์ jit-daemon.service
#   เริ่มต้นด้วย: systemctl start jit-daemon
#   หยุดด้วย: systemctl stop jit-daemon
#
# สภาพแวดล้อม:
#   อ่านตัวแปรจาก scripts/cmdteam-daemon.env ถ้ามีอยู่
#   บันทึก log ไปยัง logs/cmdteam-daemon.log
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
LOG_FILE="${LOG_DIR}/cmdteam-daemon.log"
ENV_FILE="${REPO_DIR}/scripts/cmdteam-daemon.env"

mkdir -p "${LOG_DIR}"

# Load environment if present
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

cd "${REPO_DIR}"

echo "[$(date -Iseconds)] cmdteam-daemon: starting self-improve cycle" >> "${LOG_FILE}"

# Run cmdteam self-improve loop; replace shell with the process
exec bash cmdteam/cmdteam.sh self-improve >> "${LOG_FILE}" 2>&1