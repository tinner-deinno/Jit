<!-- cc-team deliverable
 group: dim-error (Error Handling Analysis)
 member: err-fixer role=Fix Planner model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":20,"completion_tokens":2179,"total_tokens":2199,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":264,"image_tokens":0},"cache_creation_input_tokens":0} | 21s
 generated: 2026-06-12T10:28:35.180Z -->
Below is a set of concrete code diffs for a FastAPI application (Python) that adds centralized, structured logging and robust error handling. The examples assume an existing project structure; each diff shows the exact lines to change or add.

**Key improvements introduced:**

- Custom exception classes with HTTP mapping  
- Global exception handler that logs errors with context (request ID, path, etc.)  
- Structured JSON logging with request‑correlation IDs  
- Database session wrapper that logs queries and errors  

---

### 1. Add logging configuration and a correlation ID middleware

**File: `app/logging_config.py` (new file)**  
```diff
+ import logging
+ import sys
+ from pythonjsonlogger import jsonlogger
+ 
+ def setup_logging():
+     logger = logging.getLogger()
+     logger.setLevel(logging.INFO)
+ 
+     handler = logging.StreamHandler(sys.stdout)
+     formatter = jsonlogger.JsonFormatter(
+         fmt="%(asctime)s %(levelname)s %(name)s %(message)s %(correlation_id)s"
+     )
+     handler.setFormatter(formatter)
+     logger.addHandler(handler)
+ 
+     return logger
+ 
+ def get_correlation_id() -> str:
+     # In production, generate or extract from request headers (see middleware below)
+     return getattr(logging, "_correlation_id", "unknown")
```
**File: `app/middleware.py` (new file)**  
```diff
+ import uuid
+ from starlette.middleware.base import BaseHTTPMiddleware
+ from starlette.requests import Request
+ 
+ class CorrelationIDMiddleware(BaseHTTPMiddleware):
+     async def dispatch(self, request: Request, call_next):
+         correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
+         # Inject into logging context
+         old_id = getattr(logging, "_correlation_id", None)
+         logging._correlation_id = correlation_id
+         try:
+             response = await call_next(request)
+             response.headers["X-Correlation-ID"] = correlation_id
+             return response
+         finally:
+             logging._correlation_id = old_id
```

---

### 2. Custom exceptions and global error handler

**File: `app/exceptions.py` (new file)**  
```diff
+ class AppError(Exception):
+     def __init__(self, message: str, status_code: int = 500):
+         self.message = message
+         self.status_code = status_code
+ 
+ class NotFoundError(AppError):
+     def __init__(self, detail: str = "Resource not found"):
+         super().__init__(detail, status_code=404)
+ 
+ class DatabaseError(AppError):
+     def __init__(self, detail: str = "Database operation failed"):
+         super().__init__(detail, status_code=500)
+ 
+ class ValidationError(AppError):
+     def __init__(self, detail: str = "Validation failed"):
+         super().__init__(detail, status_code=422)
```

**File: `app/main.py` (excerpt showing the new handler)**  
```diff
+ from fastapi import FastAPI, Request
+ from fastapi.responses import JSONResponse
+ import logging
+ from app.exceptions import AppError
+ from app.logging_config import setup_logging, get_correlation_id
+ from app.middleware import CorrelationIDMiddleware
+ 
+ logger = setup_logging()
+ 
  app = FastAPI()
+ app.add_middleware(CorrelationIDMiddleware)
+ 
+ @app.exception_handler(AppError)
+ async def app_error_handler(request: Request, exc: AppError):
+     logger.error(
+         "Application error",
+         extra={
+             "status_code": exc.status_code,
+             "path": request.url.path,
+             "method": request.method,
+             "correlation_id": get_correlation_id(),
+         },
+         exc_info=True,
+     )
+     return JSONResponse(
+         status_code=exc.status_code,
+         content={"detail": exc.message, "correlation_id": get_correlation_id()},
+     )
+ 
+ @app.exception_handler(Exception)
+ async def unhandled_error_handler(request: Request, exc: Exception):
+     logger.critical(
+         "Unhandled exception",
+         extra={
+             "path": request.url.path,
+             "method": request.method,
+             "correlation_id": get_correlation_id(),
+         },
+         exc_info=True,
+     )
+     return JSONResponse(
+         status_code=500,
+         content={"detail": "Internal server error", "correlation_id": get_correlation_id()},
+     )
+ 
  # ... existing routes ...
```

---

### 3. Wrap database operations with logging and error handling

**File: `app/database.py`**  
```diff
+ import logging
+ from contextlib import contextmanager
+ from sqlalchemy import create_engine
+ from sqlalchemy.orm import sessionmaker
+ from app.exceptions import DatabaseError
+ from app.logging_config import get_correlation_id
+ 
+ logger = logging.getLogger(__name__)
  engine = create_engine("sqlite:///./test.db", echo=False)
  SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
  
  @contextmanager
  def get_db():
-     db = SessionLocal()
-     try:
-         yield db
-     finally:
-         db.close()
+     db = SessionLocal()
+     try:
+         logger.debug(
+             "DB session opened",
+             extra={"correlation_id": get_correlation_id()},
+         )
+         yield db
+     except Exception as e:
+         logger.error(
+             "Database error",
+             extra={"correlation_id": get_correlation_id()},
+             exc_info=True,
+         )
+         raise DatabaseError(str(e)) from e
+     finally:
+         db.close()
+         logger.debug(
+             "DB session closed",
+             extra={"correlation_id": get_correlation_id()},
+         )
```

---

### 4. Example route with structured error handling

**File: `app/routes/items.py`**  
```diff
+ import logging
+ from fastapi import APIRouter, HTTPException
+ from app.database import get_db
+ from app.exceptions import NotFoundError, DatabaseError
+ from app.logging_config import get_correlation_id
+ 
+ logger = logging.getLogger(__name__)
  router = APIRouter()
  
  @router.get("/items/{item_id}")
  async def get_item(item_id: int):
-     db = get_db()
-     item = db.query(Item).filter(Item.id == item_id).first()
-     if not item:
-         raise HTTPException(status_code=404, detail="Item not found")
-     return item
+     with get_db() as db:
+         try:
+             item = db.query(Item).filter(Item.id == item_id).first()
+             if not item:
+                 logger.warning(
+                     "Item not found",
+                     extra={"item_id": item_id, "correlation_id": get_correlation_id()},
+                 )
+                 raise NotFoundError(f"Item {item_id} not found")
+             logger.info(
+                 "Item retrieved",
+                 extra={"item_id": item_id, "correlation_id": get_correlation_id()},
+             )
+             return item
+         except NotFoundError:
+             raise  # re-raise to be handled by global handler
+         except Exception as e:
+             logger.error(
+                 "Failed to retrieve item",
+                 extra={"item_id": item_id, "correlation_id": get_correlation_id()},
+                 exc_info=True,
+             )
+             raise DatabaseError("Database operation failed") from e
```

---

### 5. Adjust `requirements.txt` (if needed)

```diff
+ python-json-logger>=2.0.0
```

**Notes for merging:**

- Install the new dependency `python-json-logger` (or replace with `structlog` if preferred).  
- The `pythonjsonlogger` package provides `JsonFormatter`; adjust imports accordingly.  
- The correlation ID is stored in `logging._correlation_id` as a simple thread‑local (works for FastAPI’s async but for production consider `contextvars`).  

These diffs produce a system that:
- Logs all exceptions with request context in JSON format.  
- Returns consistent error responses including a correlation ID.  
- Wraps database sessions in a context manager that logs and converts errors to custom exceptions.  
- Adds a middleware to propagate a correlation ID through the request lifecycle.

Adjust the file paths, class names, and imports to match your exact project structure.
