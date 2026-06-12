<!-- cc-team deliverable
 group: SEC (Secrets overhaul tooling + docs (gitleaks, hooks, CI, sanitizer, playbook, README, hardened compose))
 member: S7 role=dev model=deepseek/deepseek-v4-pro
 finish_reason: stop | tokens: {"prompt_tokens":239,"completion_tokens":3774,"total_tokens":4013,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":3285,"image_tokens":0},"cache_creation_input_tokens":0} | 32s
 generated: 2026-06-12T19:17:09.301Z -->
Replace insecure default fallbacks with required‑variable syntax, keeping non‑secret defaults intact.
```yaml
services:
  mariadb:
    image: mariadb:10.6
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD?MARIADB_ROOT_PASSWORD is required}
      MARIADB_DATABASE: ${DB_NAME:-innomcp}
      MARIADB_USER: ${DB_USER:-innomcp}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD?MARIADB_PASSWORD is required}
    ports:
      - "3306:3306"

  api:
    build: .
    environment:
      DB_HOST: mariadb
      DB_NAME: ${DB_NAME:-innomcp}
      DB_USER: ${DB_USER:-innomcp}
      DB_PASSWORD: ${DB_PASSWORD?DB_PASSWORD is required}
      JWT_SECRET: ${JWT_SECRET?JWT_SECRET is required}
    ports:
      - "8080:8080"
```

Apply patch to remove default passwords and add required vars to `.env.example`.
```bash
# Backup original
cp docker-compose.yml docker-compose.yml.bak

# Replace insecure defaults with required‑variable syntax
sed -i \
  -e 's/^\(\s*MARIADB_ROOT_PASSWORD:\s*\).*$/\1${MARIADB_ROOT_PASSWORD?MARIADB_ROOT_PASSWORD is required}/' \
  -e 's/^\(\s*MARIADB_PASSWORD:\s*\).*$/\1${MARIADB_PASSWORD?MARIADB_PASSWORD is required}/' \
  -e 's/^\(\s*DB_PASSWORD:\s*\).*$/\1${DB_PASSWORD?DB_PASSWORD is required}/' \
  -e 's/^\(\s*JWT_SECRET:\s*\).*$/\1${JWT_SECRET?JWT_SECRET is required}/' \
  docker-compose.yml

# Append required variable placeholders to .env.example
cat >> .env.example <<'EOF'
MARIADB_ROOT_PASSWORD=
MARIADB_PASSWORD=
DB_PASSWORD=
JWT_SECRET=
EOF
```
