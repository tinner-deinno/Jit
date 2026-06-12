<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: B06 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: refined_via_debug_mantra_loop | iterations: 10
 generated: 2026-06-13T00:00:00.000Z -->
```markdown
# API Contract (innomcp-node)
**Version:** 2.1.0
**Status:** VERIFIED (Logical Design)
**Last Verified:** 2026-06-13

## Global Specifications
- **Base URL:** `/api`
- **Content-Type:** `application/json`
- **Auth Scheme:** Bearer Token (`Authorization: Bearer <accessToken>`)
- **Standard Error Response:**
  ```json
  {
    "error": {
      "code": "string (e.g., 'UNAUTHENTICATED')",
      "message": "Human-readable error message",
      "details": { "field": "reason" }
    }
  }
  ```

## Authentication

### GET /health
- **Auth required:** No
- **Response:** `200 OK`
  ```json
  { "status": "ok", "timestamp": "2026-06-13T00:00:00Z", "version": "2.1.0" }
  ```

### POST /auth/login
- **Auth required:** No
- **Request Body:**
  ```json
  { "email": "user@example.com", "password": "string" }
  ```
- **Response:** `200 OK`
  ```json
  {
    "accessToken": "jwt.header.payload.signature",
    "refreshToken": "string",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "User Name",
      "role": "admin|user",
      "avatarUrl": "url"
    }
  }
  ```
- **Status Codes:** `200`, `401 (INVALID_CREDENTIALS)`, `422 (VALIDATION_ERROR)`, `500`

### GET /auth/me
- **Auth required:** Yes
- **Response:** `200 OK`
  ```json
  {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "User Name",
      "role": "admin|user",
      "avatarUrl": "url"
    }
  }
  ```
- **Status Codes:** `200`, `401 (UNAUTHENTICATED)`, `500`

### POST /auth/refresh
- **Auth required:** No (Token in body)
- **Request Body:**
  ```json
  { "refreshToken": "string" }
  ```
- **Response:** `200 OK`
  ```json
  { "accessToken": "new-jwt", "refreshToken": "new-token" }
  ```
- **Status Codes:** `200`, `401 (INVALID_TOKEN)`, `422`, `500`

## Projects & Tasks

### GET /projects
- **Auth required:** Yes
- **Query Params:** `page=1`, `limit=20`, `search=string`
- **Response:** `200 OK`
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "name": "Project Alpha",
        "description": "Project description",
        "createdAt": "ISO-string",
        "updatedAt": "ISO-string"
      }
    ],
    "meta": { "total": 100, "page": 1, "limit": 20 }
  }
  ```
- **Status Codes:** `200`, `401`, `500`

### POST /projects
- **Auth required:** Yes
- **Request Body:**
  ```json
  { "name": "string", "description": "string" }
  ```
- **Response:** `201 Created`
  ```json
  {
    "project": {
      "id": "uuid",
      "name": "string",
      "description": "string",
      "createdAt": "ISO-string"
    }
  }
  ```
- **Status Codes:** `201`, `400 (BAD_REQUEST)`, `401`, `422`, `500`

### GET /tasks
- **Auth required:** Yes
- **Query Params:** `projectId=uuid` (Required), `status=todo|in-progress|done`, `page=1`, `limit=20`
- **Response:** `200 OK`
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "title": "Implement Auth",
        "status": "in-progress",
        "projectId": "uuid",
        "createdAt": "ISO-string",
        "updatedAt": "ISO-string"
      }
    ],
    "meta": { "total": 50, "page": 1, "limit": 20 }
  }
  ```
- **Status Codes:** `200`, `401`, `404 (PROJECT_NOT_FOUND)`, `500`

## Intelligence & Orchestration

### GET /mdes/models
- **Auth required:** Yes
- **Response:** `200 OK`
  ```json
  {
    "models": [
      {
        "id": "gemma4:31b-cloud",
        "name": "Gemma 4 31B",
        "provider": "mdes-ollama",
        "contextWindow": 131072,
        "isActive": true
      }
    ]
  }
  ```
- **Status Codes:** `200`, `401`, `500`

### POST /chat/stream
- **Auth required:** Yes
- **Request Body:**
  ```json
  {
    "messages": [
      { "role": "system", "content": "You are a helpful assistant." },
      { "role": "user", "content": "Hello!" }
    ],
    "model": "gemma4:31b-cloud",
    "stream": true
  }
  ```
- **Response:** `200 OK` (`text/event-stream`)
  - Chunks: `data: { "chunk": "Hello ", "done": false }`
  - Final: `data: { "chunk": "", "done": true, "finishReason": "stop" }`
- **Status Codes:** `200`, `400`, `401`, `422`, `500`

### GET /memories
- **Auth required:** Yes
- **Query Params:** `q=keyword`, `startDate=ISO-string`, `endDate=ISO-string`
- **Response:** `200 OK`
  ```json
  {
    "data": [
      {
        "id": "uuid",
        "content": "User prefers Thai language",
        "timestamp": "ISO-string",
        "tags": ["preference", "thai"]
      }
    ],
    "meta": { "total": 10, "page": 1, "limit": 20 }
  }
  ```
- **Status Codes:** `200`, `401`, `500`

## Analytics

### GET /dashboard
- **Auth required:** Yes
- **Response:** `200 OK`
  ```json
  {
    "stats": {
      "totalProjects": 12,
      "activeTasks": 45,
      "completedTasks": 120,
      "lastSync": "ISO-string",
      "systemHealth": "healthy"
    }
  }
  ```
- **Status Codes:** `200`, `401`, `500`
```
