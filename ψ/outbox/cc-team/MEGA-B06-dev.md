<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: B06 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: end_turn | tokens: {"prompt_tokens":136,"completion_tokens":1917,"total_tokens":2053} | 18s
 generated: 2026-06-12T19:28:46.305Z -->
```markdown
# API Contract (innomcp-node)

> ⚠️ Entire document UNVERIFIED – request/response shapes are inferred best-effort.

## GET /api/health
- **Auth required:** No
- **Request:** (none)
- **Response:** `{ "status": "ok", "timestamp": "<ISO string>" }` UNVERIFIED
- **Status:** 200, 500

## POST /api/auth/login
- **Auth required:** No
- **Request body:** `{ "email": "string", "password": "string" }` UNVERIFIED
- **Response:** `{ "accessToken": "jwt...", "refreshToken": "string", "user": { "id", "email", ... } }` UNVERIFIED
- **Status:** 200, 401, 422, 500

## GET /api/auth/me
- **Auth required:** Yes (Bearer accessToken)
- **Request:** (none)
- **Response:** `{ "user": { "id", "email", "name", ... } }` UNVERIFIED
- **Status:** 200, 401, 500

## POST /api/auth/refresh
- **Auth required:** No Bearer header; requires refresh token in body
- **Request body:** `{ "refreshToken": "string" }` UNVERIFIED
- **Response:** `{ "accessToken": "new jwt", "refreshToken": "new token" }` UNVERIFIED
- **Status:** 200, 401, 422, 500

## GET /api/projects
- **Auth required:** Yes (Bearer)
- **Request:** (none) – might accept query params for pagination
- **Response:** `{ "projects": [ { "id", "name", "description", ... } ] }` UNVERIFIED
- **Status:** 200, 401, 500

## POST /api/projects
- **Auth required:** Yes (Bearer)
- **Request body:** `{ "name": "string", "description?": "string" }` UNVERIFIED
- **Response:** `{ "project": { "id", "name", "description", "createdAt", ... } }` UNVERIFIED
- **Status:** 201, 400, 401, 422, 500

## GET /api/tasks
- **Auth required:** Yes (Bearer)
- **Request:** Query params likely `?projectId=<id>` UNVERIFIED
- **Response:** `{ "tasks": [ { "id", "title", "status", "projectId", ... } ] }` UNVERIFIED
- **Status:** 200, 401, 404, 500

## GET /api/dashboard
- **Auth required:** Yes (Bearer)
- **Request:** (none)
- **Response:** `{ "stats": { "projects", "tasks", "completed", ... } }` UNVERIFIED
- **Status:** 200, 401, 500

## GET /api/mdes/models
- **Auth required:** Yes (Bearer)
- **Request:** (none)
- **Response:** `{ "models": [ { "id", "name", "provider", ... } ] }` UNVERIFIED
- **Status:** 200, 401, 500

## Chat/stream endpoints (likely `POST /api/chat/stream`)
- **Auth required:** Yes (Bearer)
- **Request body:** `{ "messages": [{"role":"user","content":"..."}], "model?": "...", "stream": true }` UNVERIFIED
- **Response:** `text/event-stream` (Server-Sent Events) with chunks `data: {"token":"...","done":false}` ... `data: {"done":true}` UNVERIFIED
- **Status:** 200 (for SSE), 400, 401, 422, 500

## GET /api/memories
- **Auth required:** Yes (Bearer)
- **Request:** (none)
- **Response:** `{ "memories": [ { "id", "content", "timestamp", ... } ] }` UNVERIFIED
- **Status:** 200, 401, 500
```
