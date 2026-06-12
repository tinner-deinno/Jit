<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: B02 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":102,"completion_tokens":1045,"total_tokens":1147} | 12s
 generated: 2026-06-12T19:28:31.915Z -->
# คู่มือการติดตั้งและใช้งาน (Deployment Runbook) – innomcp (Docker Compose)

## 1. ข้อกำหนดเบื้องต้น (Prerequisites)

- ติดตั้ง Docker และ Docker Compose แล้ว
- ไฟล์ `.env` ต้องมีตัวแปรดังนี้:

```env
MARIADB_ROOT_PASSWORD=your_root_password
MARIADB_DATABASE=innomcp_db
MARIADB_USER=user
MARIADB_PASSWORD=your_password
NEXT_PUBLIC_API_URL=http://api:3011  # สำหรับ build web
```

- พอร์ตที่ต้องว่าง: `3000` (web), `3015` (api), `3308` (mariadb), `6379` (redis)

---

## 2. ขั้นตอนการ Build และ Run

```bash
# สร้าง container
docker compose build

# รันทั้งหมดแบบ background
docker compose up -d
```

รอสักครู่ให้ services เริ่มทำงาน

---

## 3. ตรวจสอบ Healthcheck และความพร้อมของฐานข้อมูล

```bash
# รอให้ทุก service พร้อม (ปรับ timeout ตามต้องการ)
docker compose ps --format "{{.Names}} {{.Status}}"

# ตรวจสอบ MariaDB จริง ๆ (รอจนสามารถเชื่อมต่อได้)
docker compose exec mariadb mariadb -u root -p"$MARIADB_ROOT_PASSWORD" -e "SELECT 1"
```

---

## 4. ตรวจสอบแต่ละ Service

| Service | คำสั่งตรวจสอบ | สิ่งที่ควรเห็น |
|---------|---------------|----------------|
| **MariaDB** | `docker compose logs mariadb` | `ready for connections` |
| **Redis** | `docker compose exec redis redis-cli ping` | `PONG` |
| **API** | `curl -s http://localhost:3015/health` | `OK` หรือ JSON health |
| **Web** | `curl -s http://localhost:3000` | HTML content (ไม่ error) |

---

## 5. ปัญหาที่พบบ่อยและวิธีแก้ไข

### 5.1 พอร์ตถูกครอบครอง (Port already in use)

```bash
# ดูว่า process ไหน占用
sudo lsof -i :3000
# หรือเปลี่ยนพอร์ตใน docker-compose.yml แล้ว rebuild
```

### 5.2 ฐานข้อมูลไม่พร้อม (DB unhealthy)

- ตรวจสอบ logs: `docker compose logs mariadb`
- สาเหตุ: รหัสผ่านผิด, database volume เก่าค้าง
- แก้ไข: ลบ volume `docker compose down -v` แล้ว `up -d` ใหม่

### 5.3 NEXT_PUBLIC_API_URL ถูก bake ผิด

- ค่านี้ถูกฝังตอน build ถ้าเปลี่ยนต้อง rebuild web
- ตรวจสอบค่าจริง:
  ```bash
  docker compose exec web sh -c "echo $NEXT_PUBLIC_API_URL"   # (ถ้า container มี shell)
  ```
- แก้ไข: แก้ `.env` แล้ว `docker compose build web && docker compose up -d web`

---

## 6. ตัวอย่างไฟล์ docker-compose.yml (แนะนำ)

```yaml
version: '3.8'
services:
  mariadb:
    image: mariadb:10.11
    ports:
      - "3308:3306"
    env_file: .env
    volumes:
      - mariadb_data:/var/lib/mysql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  api:
    build: ./api
    ports:
      - "3015:3011"
    env_file: .env
    depends_on:
      - mariadb
      - redis

  web:
    build: ./web
    ports:
      - "3000:3000"
    env_file: .env
    depends_on:
      - api

volumes:
  mariadb_data:
```

---

> **หมายเหตุ:** หากใช้ `docker compose` เวอร์ชันเก่า อาจต้องใช้ `docker-compose` แทน
