# Cleaned Swarm Audit Findings

## File: Jit Mother Engine


Here is the synthesized list of concrete bugs and issues that must be fixed. Duplicates and low-priority noise (e.g., code smells, architectural suggestions, testability recommendations) have been removed. Only bugs, syntax errors, runtime crashes, security vulnerabilities, race conditions, and other immediate failures are included.

---

### Concrete Bugs & Issues to Fix

1. **Syntax error: Extra parenthesis in `decomposeGoal` regex**  
   Line contains `/.test(l));` – the extra closing parenthesis causes a `SyntaxError` at load time, preventing the module from being parsed.

2. **Syntax error: Incomplete `runGoal` method**  
   The method ends abruptly with an unclosed object literal and missing closing braces/return statement. This is a parse error.

3. **Undefined method `writePhaseArtifact` called in `runGoal`**  
   `this.writePhaseArtifact(runId, ...)` is invoked but never defined in the class. Runtime `ReferenceError`.

4. **Undefined method `atomicCommit` called in `executePhase`**  
   `await this.atomicCommit()` is invoked but never defined. Runtime `TypeError`.

5. **Undefined method `updateLeaderboard` called in `executePhase`**  
   `await this.updateLeaderboard(...)` is invoked but never defined. Runtime `TypeError`.

6. **Constructor crashes on missing or malformed JSON files**  
   `loadState()` performs `JSON.parse(fs.readFileSync(...))` without try/catch. If any of `registry.json`, `leaderboard.json`, or `subagent-routing.json` is missing or corrupt, the constructor throws an uncaught exception, crashing the process.

7. **Crash in `pickLiveProvider` if `ps` is not an object**  
   `JSON.parse(...)` may return `null` or a non-object; accessing `ps.usable` then throws `TypeError`.

8. **`handleBotEvent` crashes on falsy `event`**  
   `console.log(\`...${event.event}...\`)` assumes `event` is an object. If `event` is `null` or `undefined`, a `TypeError` is thrown.

9. **`hydrateLeaderboard` may call `persist(undefined)`**  
   If `this.leaderboard.fleet` is `undefined` (e.g., missing leaderboard file), `leaderboardDB.persist(this.leaderboard.fleet)` passes `undefined`, likely causing a crash or silent failure.

10. **`leaderboardDB.recordProviderResult` called with undefined `backend`**  
    Loop `for (const a of attempts)` accesses `a.backend` without null check. If an attempt entry lacks `backend`, the DB call may fail or produce bad data.

11. **Prompt injection vulnerability**  
    User-controlled `goal`, `context`, and phase titles are directly interpolated into LLM prompts. An attacker can inject instructions to manipulate the model or leak internal data.

12. **Directory traversal in artifact writing**  
    `writePhaseArtifact` (undefined) likely writes files based on `ph.title`. Without sanitization, `../` paths could overwrite files outside the intended directory.

13. **Secret leakage via unsanitized logging**  
    `handleBotEvent` logs `JSON.stringify(event)` and results are logged verbosely. If bot events or agent responses contain API keys or tokens, they will be exposed in logs.

14. **Inconsistent path resolution for artifacts**  
    `path.join('network/artifacts', runId)` uses a relative path (cwd) while all other paths use `__dirname`. This will write artifacts to the wrong location when the process is started from a different directory.

15. **Unbounded `prevFull` string growth in `runGoal`**  
    All previous phase outputs are concatenated into `ctx` (capped at 3000 characters per phase but never limited across phases). Over many phases, this causes increasing memory usage and context size.

16. **Missing error handling for `updateLeaderboard`**  
    `await this.updateLeaderboard(...)` is not wrapped in try/catch. If it throws (undefined method or DB error), the entire phase fails silently without commit or event logging.

17. **Duplicate `botBridge.connect()` calls without state guard**  
    Called in `loadState()` (constructor) and again in `executePhase()`. Multiple connections may cause duplicate event handlers or socket errors.

18. **Event listener leak**  
    `setupBotEventListeners` registers listeners on `this.botBridge` without removing them. Repeated instantiation of `MotherEngine` (e.g., hot-reload) causes memory growth and duplicate handler execution.

19. **Race condition in `hydrateLeaderboard`**  
    Uses `leaderboardDB.count() > 0` check and subsequent `persist/hydrate` without locking. If multiple instances or concurrent calls run, data loss or duplication can occur.

20. **Unsafe `JSON.parse` without validation**  
    Multiple calls to `JSON.parse(fs.readFileSync(...))` assume valid JSON. Corrupt files throw a parse error; no fallback default is provided.

21. **Inconsistent return type from `executePhase`**  
    Returns an array on success, but on failure from `spawnAgentParallel` catch returns `{ error, details }`. The caller checks `!Array.isArray(res) && res.error` – fragile and hides errors if `res` is falsy.

22. **Potential type error in `prevFull` construction**  
    `String(r.reply || '').trim()` assumes `r.reply` is a string. If it is an object, `String(...)` produces `'[object Object]'`, corrupting the context passed to subsequent phases.

23. **Hardcoded agent name `'soma'` in `decomposeGoal`**  
    `spawnAgent('soma', ...)` assumes the agent exists. If it does not, goal decomposition fails completely. No fallback or configuration.

24. **Unused import `execSync` poses latent command injection risk**  
    `const { execSync } = require('child_process');` is imported but never used. If future code uses it with unsanitized input, arbitrary command execution is possible. Remove the import.

--- 

These 24 items must be addressed to make the code functional, secure, and resilient to common errors.


---

## File: Jit Model Router


## QE_Evaluator Synthesis: Jit Model Router – Concrete Bugs & Issues

1. **Undefined function `splitThaiSyllables`** – The import `const thaiSplitter = require('../limbs/thai-splitter');` is present, but the code calls `splitThaiSyllables(cleaned)` directly instead of `thaiSplitter.splitThaiSyllables(cleaned)`. This will throw a `ReferenceError` at runtime whenever a Thai model alias is processed. (Agents: SA_Architect #1, Bug_Hunter #2, QA_Planner #2, Perf_Tuner #1)

2. **`BackendManager.isAvailable` always returns `true`** – The method’s `try` block is empty and unconditionally returns `true`. No actual connectivity check is performed, rendering the fallback rotation useless and security checks bypassed. (All agents)

3. **Circuit breaker threshold never applied** – `BREAKER_THRESHOLD` is computed but never read. The `_errors` counters are never incremented or checked; the breaker only uses a time-based cooldown from disk, ignoring consecutive failures. (SA_Architect #7, Bug_Hunter #4, Error_Handler #3)

4. **Race condition on persisted breaker state** – Multiple concurrent Node.js processes (or async calls) read/write the same file (`breaker-state.json`) without locking. In-memory mutations and file writes are not atomic, leading to lost trips/resets and inconsistent cooldowns. (SA_Architect #6, Concurrency_Analyst #1, Refactoring_Expert #12)

5. **Unprotected shared `_errors` object** – Modifications to `_errors` counters across asynchronous callbacks are not atomically guarded. If an async operation yields between read and write, counts can be corrupted. (Concurrency_Analyst #2)

6. **Missing module exports** – The file ends abruptly without exporting any function. The documented `router.callModel()` is undefined, making the module unusable. (SA_Architect #8, QA_Planner #1, Refactoring_Expert #1)

7. **Silent exception swallowing** – Empty `catch` blocks throughout the code (`.env` parsing, breaker file writes, skill file reads) hide configuration and persistence failures, making debugging impossible. (SA_Architect #9, Error_Handler #1)

8. **Incomplete Thai Unicode range in regex** – The regex `/[฀-๿]/` only covers the first half of the Thai Unicode block (U+0E00–U+0E3F). Many common Thai characters (e.g., ร, ล, อ, า, ี) fall outside this range, causing `_normalizeModelAlias` to misclassify Thai text as non-Thai and produce incorrect alias resolutions. (Bug_Hunter #1)

9. **Recursion risk in `_normalizeModelAlias`** – The fallback path calls `_normalizeModelAlias(stripped)` without a depth limit. A pathological input that still contains Thai characters after stripping can lead to infinite recursion or stack overflow. (SA_Architect #11, Refactoring_Expert #13, Concurrency_Analyst #4)

10. **Security: Secret leakage from `SKILL.md`** – The code reads `OLLAMA_TOKEN` from a non-secret markdown file via regex, bypassing proper secret management. (Security_Auditor #1)

11. **Security: Insecure manual `.env` loading** – The `.env` file is parsed with `fs.readFileSync` and sets `process.env` without sanitization, allowing arbitrary environment variable injection. (Security_Auditor #2)

12. **Security: Unprotected breaker state file** – The state file is stored at a predictable path with no permission checks. An attacker with write access can inject malformed JSON (prototype pollution) or read failing-backend information. (Security_Auditor #3)

13. **Security: Unvalidated backend URLs** – Backend URLs taken directly from environment variables are used in HTTP calls without validation, allowing traffic to arbitrary hosts if an attacker controls the env. (Security_Auditor #4)

14. **Missing directory for breaker state file** – If the `network/` directory does not exist, the synchronous write in `_saveBreaker` will throw an exception that is silently caught, causing breaker persistence to fail silently. (Perf_Tuner #4)

15. **Inconsistent error tracking** – The `_errors` object omits the `innova_bot` backend while including `commandcode`, leading to incomplete failure counting for that lane. (Documentation_Validator #5)

16. **`_normalizeThaiLLMBaseUrl` may produce invalid base URL** – Stripping trailing path segments (`/v1/chat/completions` or `/chat/completions`) without proper normalization can result in a URL with no path or an unintended path, corrupting endpoint construction. (QA_Planner #10)

17. **Incomplete AUTH error detection section** – The code ends with a comment `// ── AUTH error detection ────────────────────────────────` but no implementation follows, leaving authentication error handling missing. (Documentation_Validator #8)

18. **Alias map example mismatch in `_normalizeModelAlias`** – The docstring example `'จิต-โมเดล-26บ'` would not produce the map key `'จิต-โม-เดล-26-บ'`, so the example would fail to resolve via the map, causing incorrect routing for that alias. (Documentation_Validator #6)


---

## File: Jit Innova-Bot Bridge


### QE_Evaluator Synthesis – Concrete Bugs & Issues for "Jit Innova-Bot Bridge"

1. **Unbounded reconnection loop** – `handleDisconnect()` recursively calls itself without respecting `RETRY_CONFIG.MAX_RETRIES`. The bridge will retry indefinitely even when the server is permanently unreachable, exhausting system resources (sockets, timers, event loop).  
   *Fix: cap reconnection attempts and emit an unrecoverable error when the limit is reached.*

2. **Race condition in `connect()`: lost `endpoint` event** – The `EventSource` is created **before** the listener for the `'endpoint'` event is attached. If the server sends the endpoint event synchronously before the listener is registered, that event is lost and the connect promise never resolves, leading to a 30-second timeout and a broken connection state.  
   *Fix: register all event handlers **before** creating the `EventSource`, or buffer events.*

3. **Double resolution of the connect promise** – Both the `addEventListener('endpoint')` handler and the `onmessage` handler may parse an endpoint and call `resolve(true)`. The second resolve is ignored, but the bridge may emit `'connected'` twice and set state incorrectly, confusing consumers.  
   *Fix: use a one-time flag (e.g., `this._connectResolved`) to prevent duplicate resolution.*

4. **Leaked HTTP/HTTPS agents** – `httpAgent` and `httpsAgent` are created once and never destroyed. After repeated connect/disconnect cycles, idle sockets accumulate, preventing clean process exit and causing resource leaks.  
   *Fix: call `agent.destroy()` inside `disconnect()` (and optionally in a `destroy()` method).*

5. **Concurrent `connect()` calls create duplicate `EventSource` instances** – The method only guards against `CONNECTED` state, not `CONNECTING`. Multiple calls spawn separate SSE connections, overwrite `this.eventSource` without closing the previous one, and leave multiple pending promises and listeners.  
   *Fix: add a guard (e.g., `this._connectingPromise`) to return the existing promise if already connecting, and close any previous `eventSource` before reassigning.*

6. **Connection timeout races with late `endpoint` event** – The timeout fires and rejects the connect promise, but the `endpoint` event listener remains active. If the event arrives after the timeout, the bridge sets `state = CONNECTED`, starts heartbeat, and emits `'connected'`—the caller already believes the connection failed, leading to state inconsistency and duplicated connections.  
   *Fix: after rejecting, close the `eventSource` and ignore further events using a flag.*

7. **Retry logic in `sendCommand` abandons the original promise** – When an HTTP POST fails with a transient error, the method recursively calls itself with a **new** `id` and a **new** `responsePromise`. The original promise (returned to the caller) is never resolved or rejected—it will eventually timeout (30s) even if the retry succeeds. This breaks request-response correlation.  
   *Fix: reuse the same pending entry (reset the timer) across retries, or resolve/reject the original promise directly.*

8. **Heartbeat cancels an active connection attempt** – The heartbeat interval checks `this.state !== CONNECTED` and calls `handleDisconnect()`. While `connect()` is in progress, the state is `CONNECTING`, so a heartbeat tick will close the in-use `EventSource` and start a new reconnection, leaving the original `connect()` promise hanging forever.  
   *Fix: only trigger reconnection when the state is `DISCONNECTED`; skip `CONNECTING` and `RECONNECTING`.*

9. **`disconnect()` does not cancel scheduled reconnect backoff** – If `handleDisconnect()` is mid-`await this.sleep(delay)` when `disconnect()` is called, the sleep continues and then calls `connect()`, reconnecting despite the explicit shutdown.  
   *Fix: introduce a cancellation flag (e.g., `this._stopped`) checked after the sleep.*

10. **Race condition in `initialize()`: duplicate MCP handshake** – Multiple concurrent calls to `initialize()` or `callTool()` can send duplicate `initialize` MCP requests because the `this.initialized` check is not atomic. The bot may reject or misbehave.  
    *Fix: use a mutex/promise queue (e.g., `this._initPromise`) to serialize initialization.*

11. **Uncaught async exception in heartbeat** – The heartbeat interval callback calls `this.handleDisconnect()` (which is `async`) without try/catch. If the reconnect attempt throws an unhandled promise rejection, it could crash the process.  
    *Fix: wrap the call in a try/catch and log the error.*

12. **EventSource automatic reconnection conflicts with custom logic** – The `eventsource` npm library defaults to automatic reconnection (`reconnect: true`). This creates a second reconnection loop alongside the custom `handleDisconnect` logic, leading to duplicate connections and erratic behavior.  
    *Fix: disable auto-reconnect by passing `{ reconnect: false }` to the `EventSource` constructor.*

13. **SSRF via unvalidated session ID** – The session ID received from the SSE `endpoint` event is used directly to construct the POST URL in `sendCommand()`. An attacker who can inject a malicious absolute URL (e.g., via spoofed event or MITM) can force the bridge to make requests to arbitrary hosts.  
    *Fix: validate that the resolved URL’s host and port are within an allowed set (e.g., only 127.0.0.1).*

14. **Unauthenticated SSE event injection (spoofed MCP responses)** – The `onmessage` handler trusts any SSE message whose `id` matches a pending request. An attacker who can inject arbitrary SSE events can resolve promises with attacker-controlled data, leading to incorrect tool execution or information disclosure.  
    *Fix: use cryptographically random request IDs and optionally sign responses.*

15. **Prompt injection vulnerability** – `dispatchTask(taskDescription)` and `askBot(prompt)` pass user-supplied strings directly to the bot’s MCP tools without sanitization. An attacker can inject malicious instructions that the bot’s AI may execute (e.g., “output internal data”).  
    *Fix: validate or escape input, and require explicit confirmation for sensitive operations.*

16. **No authorization or permission checks** – Any caller with a reference to the `InnovaBotBridge` instance can invoke any method (e.g., `callTool`, `askBot`, `disconnect`) without authentication or role-based access. This exposes full bot control to untrusted code.  
    *Fix: implement an access-control layer (e.g., API keys, capability tokens).*

17. **Missing input validation on configuration parameters** – The `config.endpoint` and `config.gui` values are used to create `EventSource` and as base URLs without validation. If user-controlled, they can lead to SSRF or connection to malicious endpoints.  
    *Fix: validate URLs against a whitelist and reject malformed or external hosts.*


---

## File: Innova-Bot Model Router (Python)


### Clean, Numbered List of Concrete Bugs/Issues That Must Be Fixed

1. **Logic Bug: `_endpoint_for` Ignores Runtime Local Set**  
   `__init__` builds `_effective_local` to guarantee certain models (e.g., from env vars) always route locally, but `_endpoint_for` never checks this set. Models forced to local can be misrouted to the remote endpoint, breaking documented guarantees.

2. **Duplicate Model Sets Cause Inconsistency**  
   `REMOTE_KNOWN_MODELS` and `REMOTE_LIGHTWEIGHT_MODELS` are nearly identical but maintained separately. `_endpoint_for` uses one, `adapt_model_for_url` uses the other. Any update to one set without the other creates routing/adaptation mismatches.

3. **Fragile `.env` Path Resolution (Directory Traversal Risk)**  
   `Path(__file__).resolve().parents[4]` assumes a fixed directory depth. If the file is moved or the project restructured, the wrong `.env` may be loaded (or none). An attacker with write access to a parent directory could plant a malicious `.env` to override secrets.

4. **Missing Input Validation in `route()`**  
   - `prompt` is passed to `len(prompt)` without a `None` check → `TypeError`.  
   - `enforce_model` is used directly without validation against the known model sets, allowing arbitrary strings that can cause misrouting or information leakage.

5. **Overly Broad `except Exception` in `get_agent_model`**  
   Catches all exceptions and returns `None`, silencing real bugs (e.g., `TypeError`, `ImportError`). Debugging becomes harder; failures are masked.

6. **Inconsistent Model Set Usage Between Routing and URL Adaptation**  
   `_endpoint_for` uses `REMOTE_LIGHTWEIGHT_MODELS`, while `adapt_model_for_url` uses `REMOTE_KNOWN_MODELS`. A model routed to remote may not be adapted correctly if it isn’t in the other set (or vice‑versa).

7. **Fragile URL Parsing in `adapt_model_for_url`**  
   `.rstrip("/").split("/api/")[0]` breaks for URLs that contain `/api/` in a query string, path parameters, or multiple segments. Using `urllib.parse.urlparse` is needed to reliably extract the base host.

8. **Dead Code (Unused Functions and Attributes)**  
   - `build_ollama_auth_headers` and `normalize_ollama_probe_url` are defined but never called.  
   - `_effective_local` attribute and `_local_set` property are computed but never used; they waste memory and add confusion.

9. **Module‑Level Global Router Instance Prevents Configuration Updates**  
   `router = HybridModelRouter()` creates a singleton at import time. Environment changes after import (e.g., reloading `.env`) are not reflected, making the router state stale and hard to test or reconfigure.

10. **No Authorization Check on Model Routing**  
    The `HybridModelRouter` does not verify that the caller is authorized to use a particular model or endpoint. Any code importing the module can trigger remote API calls with the stored bearer token, posing a security risk.

11. **Sensitive Routing Details Logged at INFO Level**  
    Model names, endpoint URLs, and complexity scores are logged via `logger.info`. In production, these logs may be ingested by third‑party systems or exposed to users, leaking internal routing logic and potentially sensitive endpoints.

12. **Inaccurate Token Cost Estimation**  
    `track_cost` divides character count by 4 to estimate tokens. This is a rough heuristic that can be highly inaccurate for non‑English text or models with different tokenization (real ratios vary from 3 to 5 chars per token).

13. **Stale/Misleading Comments Contradict Actual Logic**  
    - Comment “never fall back to llama3.2” – no such fallback exists.  
    - Comment for `LOCAL_POWERFUL_MODELS` says “must run locally”, but models in this set appear in `REMOTE_LIGHTWEIGHT_MODELS` and can be routed remotely.  
    - Comment in `__init__` claims `_endpoint_for` returns `LOCAL_ENDPOINT` for certain models, but the method never uses `_local_set`.  
    These comment bugs make code maintenance error‑prone.

14. **Silent Failure When `python-dotenv` Is Missing**  
    `except ImportError: pass` swallows the missing dependency with no warning. Environment variables may not load, and downstream functions silently use defaults or `None` values.

15. **`get_agent_model()` Uses `lru_cache` Indefinitely**  
    The `@lru_cache` decorator caches agent registry results without expiration. If the registry changes dynamically (e.g., after startup), stale entries are returned until process restart.


---

## File: Innova-Bot Ask Tools (Python)


Here is the consolidated list of concrete bugs and issues that must be fixed, synthesized from all specialist reports. Security vulnerabilities and runtime errors are prioritized; vague suggestions or testability improvements are omitted.

---

### Numbered List of Concrete Bugs / Issues

1. **Command Injection in `_ask_via_cmd`**  
   `cmd` is passed directly to `shlex.split()` and executed without validation, allowing arbitrary command execution if the input is attacker-controlled.

2. **Server‑Side Request Forgery (SSRF) in `_ask_via_http`**  
   The `url` parameter is used in an HTTP request without scheme/host validation, enabling access to internal network resources or cloud metadata endpoints.

3. **Sensitive Data Leakage via Conversation Log**  
   `_append_ai_conversation_log` writes all conversation data to a world‑readable file (`ai_conversations.jsonl`) with no permission restrictions or redaction of secrets.

4. **Silent Exception Swallowing in `_append_ai_conversation_log`**  
   The bare `except Exception: pass` hides all write errors (disk full, permission denied), causing silent data loss.

5. **Python Version Incompatibility (`datetime.UTC`)**  
   `datetime.datetime.now(datetime.UTC)` requires Python 3.11+; older interpreters raise `AttributeError`.

6. **Missing Subprocess Timeout in `_ask_via_cmd`**  
   No timeout is set for the subprocess call, so a hung command blocks the thread indefinitely.

7. **Circuit Breaker Not Enforced Before HTTP Requests**  
   `_ask_via_http` does not call `_provider_is_blocked()`, so requests are made even when the provider is in cooldown or circuit‑open.

8. **Auth Cooldown Not Triggered on HTTP 401/403**  
   `_ask_via_http` never calls `_mark_remote_auth_cooldown()` when receiving unauthorized responses; the fallback chain may retry indefinitely.

9. **Potential `KeyError` in Retry Policy Access**  
   `_compute_retry_delay` and `_record_provider_failure` access `policy["max_retries"]`, `policy["auth_cooldown_seconds"]`, etc. without `.get()` – a malformed or incomplete policy dict causes a crash.

10. **Fragile URL Fallback Using String Slicing**  
    `_ask_via_http` manipulates URLs with `url.rstrip("/")[:-len("api/generate")]` – this breaks when the URL contains query parameters (`?`), fragments (`#`), or a different path structure.

11. **`_sanitize_json_text` Corrupts Dict Keys**  
    The function converts all keys (including integers, `None`) to strings, silently altering the data structure.

12. **Silent Authentication Bypass When Token Is Empty**  
    `_build_auth_headers_from_env` returns an empty dict if `OLLAMA_API_TOKEN` is missing, allowing unauthorized requests.

13. **Environment Variable Parsing Can Raise `ValueError`**  
    `float(os.getenv("REMOTE_OLLAMA_AUTH_COOLDOWN_SEC", ...))` throws if the env var is empty or non‑numeric.

14. **Incomplete `_ask_via_cmd` Implementation**  
    The function ends abruptly with an unfinished `if os.name == "nt":` block, leaving the code non‑functional.

15. **Stale Read of Provider Failure State**  
    `_get_provider_failure_state` returns a copy outside the lock; functions like `_remote_auth_cooldown_active` then read a potentially stale `cooldown_until` value.

16. **Unbounded Memory Growth in `_PROVIDER_FAILURE_STATE`**  
    The dictionary grows without eviction if dynamic provider keys are ever introduced, causing a memory leak.

17. **`shlex.split` on Malformed Command Raises `ValueError`**  
    No try/except in `_ask_via_cmd` – a malformed `cmd` string causes an unhandled crash.

18. **False Provider Identification in `_provider_from_cmd`**  
     Substring matching (`"claude" in value`) matches unintended strings like `"myclaude"`, misrouting requests.

19. **Hardcoded Workspace Root Depth**  
    `Path(__file__).resolve().parents[4]` assumes a fixed directory depth; the application breaks if the file is moved or deployed with a different structure.


---

## File: Innova-Bot Event Watcher (Python)


## Concrete Bugs & Issues (Must Fix)

1. **Race condition / data corruption in `_rewrite_event_status`** – Reads entire JSONL file, modifies one line, writes back without any file locking or atomic rename. Concurrent watcher instances or overlapping poll cycles can lose events, duplicate processing, or corrupt the file.

2. **Negative `ok_count` in `_handle_code_ready`** – `ok_count = result.get("files_reviewed",0) - len(result.get("errors",[]))` can become negative if errors outnumber reviewed files, leading to nonsensical downstream values.

3. **Unhandled `asyncio.CancelledError` leaves event stuck as `PROCESSING`** – The task created by `asyncio.create_task` can be cancelled; `CancelledError` is a `BaseException` not caught by `except Exception`, so the event status remains `PROCESSING` forever with no recovery mechanism.

4. **`datetime.UTC` does not exist** – Uses `datetime.datetime.now(datetime.UTC).isoformat()`; Python’s `datetime` module has no attribute `UTC`. This raises an `AttributeError` at runtime, breaking any code path that calls this (e.g., `_rewrite_event_status`).

5. **`float(os.getenv(...))` crashes on invalid environment value** – At module level, `float(os.getenv("EVENT_WATCHER_INTERVAL_S", "5"))` raises `ValueError` if the env var is not a valid float, preventing the entire watcher from importing. No fallback.

6. **`_save_agent_report` silently discards all previous reports if JSON file is corrupt** – If the report file exists but contains invalid JSON, `json.loads` raises an exception that is caught by a broad `except Exception`, leaving `data` empty and overwriting the file with only the new role, erasing all prior reports.

7. **Incorrect project name derivation for filenames with multiple underscores** – `slug = events_file.stem[: -len("_events")]` followed by `slug.replace("_", "-")` can produce malformed project names (e.g., `my_events_events.jsonl` → `my-events-`), causing events to be processed under a nonexistent project.

8. **Directory traversal via malicious event filename** – The project name derived from the events file’s stem is inserted directly into file paths without validation. An attacker who creates a file named `../../../etc/passwd_events.jsonl` can make `resolve_workspace` and `_save_agent_report` write/read outside the intended workspace, leading to arbitrary file access.

9. **Prompt injection via unvalidated event payloads** – In `_handle_new_requirement` and `_handle_sa_done`, user-controlled strings (`req_text`, `analysis`) are directly embedded into AI prompts without sanitization or instruction separation, allowing an attacker to override system prompts and manipulate LLM output.

10. **Lazy imports mask missing dependencies and cause runtime failures** – Critical imports (e.g., `PayloadSigner`, `request_automated_review`, `update_project_state`) are deferred inside functions. If a module is missing, the error manifests at an unpredictable time, often halting all event processing.

11. **Unbounded task creation leading to resource exhaustion** – `_scan_and_process` spawns an `asyncio.create_task` for every `UNREAD` event without any concurrency limiter. Under high load, this can oversubscribe the event loop and thread pool, causing memory exhaustion or severe slowdowns.

12. **Swallowed exception in `_handle_code_ready` when publishing `REVIEW_FAILED`** – The nested `except Exception: pass` silently suppresses any error from `publish_event`, hiding critical fallback failures.

13. **Dead code: `_ZOMBIE_SWEEPER_INTERVAL_S` and `_ZOMBIE_STALE_MINUTES`** – These environment variables are parsed at module level but never used anywhere. They add confusion and suggest the zombie-sweeper logic is missing, leaving `PROCESSING` events unrecoverable.

14. **Synchronous file I/O blocks the event loop** – `_rewrite_event_status`, `_save_agent_report`, and `_scan_and_process` read/write files synchronously (e.g., `read_text()`, `write_text()`), blocking the async event loop. This degrades performance and prevents scalability.

15. **Missing event_id key handling in `_rewrite_event_status`** – `ev.get("event_id") == event_id` fails silently when `event_id` is `None` or missing; the event is never found and the function exits without updating any status.


---

## File: Innova-Bot BigBoss Agent (Python)


## Consolidated Bug/Issue List

1. **Syntax error – incomplete `except` statement**  
   The file ends with `excep` inside `_execute_internal_actions`, causing a `SyntaxError` on module load. This is a compile-time failure.

2. **Logger used before definition**  
   `_get_oracle_v2_context()` calls `logger.debug(...)` before `logger` is defined (imported after the function). This will raise a `NameError` at runtime if the function is called before the import completes.

3. **`datetime.UTC` incompatible with Python <3.11**  
   `datetime.UTC` (constant) is used in `_internal_append_report` and `_internal_git_commit`. On Python 3.10 and earlier this raises `AttributeError`.

4. **Race condition on `_WORKER_STARTED` flag**  
   The flag is accessed and set without a lock. Multiple threads can both see `False` and start duplicate workers, leading to double processing or resource exhaustion.

5. **Race condition on `_TASKS` dictionary**  
   Only `_record()` uses `_TASKS_LOCK`. Any read access (or concurrent writes) from other code paths is unprotected, causing data corruption.

6. **Directory traversal in `_resolve_bigboss_target_path`**  
   The regex `[\w/\\._-]+` allows `..` sequences, and the returned path is not validated against the workspace root. An attacker can write files outside the intended directory.

7. **Potential command injection in `_internal_git_commit`**  
   The commit `message` (truncated to 256 chars) is not sanitized. Malicious newlines or control characters can inject additional git options.

8. **Secret leakage in error responses**  
   `_force_execute_with_retry` returns exception strings verbatim (e.g., `f"# Error during generation: {exc}"`), potentially exposing API keys, paths, or stack traces. `_get_oracle_v2_context` logs exception details without redaction.

9. **Missing authorization on internal tools**  
   Tools like `internal_write_file`, `internal_git_commit`, and `internal_run_tests` are exposed to the LLM with no permission checks. A compromised prompt can overwrite files, commit unwanted changes, or run arbitrary commands.

10. **Indefinite thread blockage in `_run_async_sync`**  
    `th.join()` has no timeout. If the coroutine hangs (I/O deadlock, infinite loop), the calling thread freezes forever.

11. **Deadlock risk in `_run_async_sync`**  
    If a thread calls `_run_async_sync` while holding `_TASKS_LOCK` (or any lock that the spawned thread may acquire), a deadlock occurs.

12. **Silent exception swallows**  
    - `_get_arsenal_summary`: `except Exception: pass` – discards all errors with no logging.  
    - `_get_oracle_v2_context`: catches `Exception`, logs only at `debug` level, returns empty string.  
    - `_resolve_bigboss_target_path`: two `try-except` blocks swallow errors without any logging, silently falling back to a default path.  
    - `_internal_git_commit`: broad `except Exception` returns error dict without logging the stack trace.  
    - `_force_execute_with_retry`: exception string is stored but never logged.

13. **Memory leak – `_TASKS` dictionary**  
    Tasks are added and updated but never removed. The dictionary grows unbounded, eventually exhausting heap memory.

14. **Resource leak – daemon threads**  
    Each call to `_run_async_sync` creates a daemon thread that may be abruptly terminated on exit, leaving open file handles, network connections, or database cursors uncleaned.

15. **Missing task state cleanup on failure**  
    If `_execute_internal_actions` raises an unhandled exception, the task remains with status `"running"` forever – no error state is recorded.

16. **No retry/fallback on Oracle-V2 RAG failure**  
    `_get_oracle_v2_context` returns an empty string on any exception, silently degrading the planning phase with no indicator of missing reference data.

17. **`except BaseException` in `_run_async_sync`**  
    Catches `KeyboardInterrupt` and `SystemExit`, which should propagate. This can make the process unresponsive or impossible to stop.

18. **Inline imports inside functions**  
    Multiple functions (e.g., `_internal_run_tests`, `_force_execute_with_retry`, `_internal_git_commit`) import modules at runtime. This delays dependency errors and prevents static analysis; can cause `ImportError` only when the function is called, not at startup.

19. **`_get_arsenal_summary` defined but never called**  
    Dead code that should be removed to avoid confusion and maintenance overhead.

20. **`_TASK_QUEUE` defined but never used**  
    Dead code; the module defines a `queue.Queue` that is never referenced.


---

## File: Innova-Bot Swarm Manager (Python)


**Innova-Bot Swarm Manager (Python) – Must-Fix Issues**

1. **Security: Unrestricted command injection via `inject_command`**  
   `TmuxSwarmController.inject_command` passes the `command` argument directly to `tmux send-keys` without validation, allowing arbitrary keystrokes (including shell commands) to be injected into running tmux panes. Restrict access, sanitize input, or whitelist allowed commands.

2. **Security: Missing authentication/authorization**  
   All public methods of `SwarmManager` and `TmuxSwarmController` are unprotected. Any caller can enqueue tasks, claim/submit tasks, inject commands, capture output, etc. Implement authentication (e.g., API keys) and authorization checks.

3. **Security: Arbitrary node creation (resource exhaustion)**  
   `_ensure_node` creates a new `SwarmNodeState` for any unseen `node_id`. Without validation or rate limiting, an attacker can flood the system with fake nodes, causing memory exhaustion. Restrict node IDs to a pre‑configured set or enforce a maximum node count.

4. **Security: Insufficient tmux session name validation**  
   The `session_name` parameter in `inject_command`, `capture_screen`, and `attach_console` is only stripped and defaulted, not sanitized. Malformed names (spaces, `;`, `-t`) can cause unintended tmux behavior or injection. Validate to alphanumeric, hyphens, and underscores only.

5. **Bug: `submit_response` accepts responses for unclaimed tasks**  
   A task with `claimed_by == None` (pending) can be completed by any node, bypassing the claim mechanism. Require that the task be claimed and that the responding node matches the claimant; otherwise raise an error.

6. **Bug: `submit_response` unconditionally resets node state**  
   Node status and `active_task_id` are reset regardless of whether the submitted task matches the node’s active task. This can overwrite a concurrently assigned task. Only reset node state when `task.task_id == node.active_task_id`.

7. **Bug: `claim_next_task` allows a busy node to claim**  
   There is no check that `node.status == "idle"` before assigning a new task. A busy node overwrites its `active_task_id`, losing the previous task. Add an idle check and reject claims from busy nodes.

8. **Bug: Unhandled `subprocess.TimeoutExpired` in `_run`**  
   `subprocess.run` with `timeout` raises `subprocess.TimeoutExpired`, which is not caught by the existing `except` clause (it catches only `CalledProcessError`). This causes an unhandled crash. Wrap the call in a `try/except subprocess.TimeoutExpired` and raise a controlled `RuntimeError`.

9. **Bug: Fragile workspace root calculation**  
   `Path(__file__).resolve().parents[2]` assumes the file is exactly two levels deep in the project tree. Moving or restructuring the project will break initialization. Use an environment variable or explicit configuration instead.

10. **Bug: Missing existence check for script directory**  
    `_scripts_dir` is computed but never validated as an existing directory. If it does not exist, `_start_script.exists()` may give a confusing error. Check directory existence and raise a clear error message.

11. **Bug: Stale claimed tasks never timeout**  
    Tasks transition to `"claimed"` but have no timeout. If the claiming node crashes or never submits a response, the task remains stuck in the queue and blocks further processing. Implement a heartbeat-based or absolute timeout to abort stale claimed tasks.

12. **Bug: Nodes stuck in `"warning"` status after task failure**  
    `submit_response` sets node status to `"warning"` on error, but there is no automatic reset to `"idle"`. The node becomes permanently unavailable for new tasks. Add a recovery mechanism (e.g., cooldown timer or health‑check reset).

13. **Bug: Silent node‑ID normalization to `"remote_node"`**  
    `_ensure_node` converts empty/`None`/whitespace node IDs to the hardcoded `"remote_node"` without warning, masking input errors. Raise a `ValueError` for invalid node IDs; do not silently fall back.

14. **Bug: Silent fallback of invalid task status to `"completed"`**  
    In `submit_response`, unknown status values (anything other than `"completed"`, `"error"`, `"rejected"`) are silently mapped to `"completed"`. This hides typos and can cause incorrect finalization. Raise a `ValueError` for unsupported statuses.

15. **Bug: Memory leak – `_tasks` dictionary grows without bound**  
    Tasks are added


---

## File: Innova-Bot Supervisor Loop (Python)


### Cleaned List of Concrete Bugs/Issues

1. **Crash on invalid environment variable** – `int(os.getenv(...))` raises `ValueError` if the variable is set to a non‑numeric string (e.g., `"abc"`). Affects all 15+ config assignments and prevents module load.

2. **`workspace` can be `None` causing `AttributeError`** – When `item.get("workspace")` is falsy, `workspace` is set to `None`, but it is later passed to `_sync_ai_knowledge_snapshot` which calls `workspace.exists()` → crash.

3. **Missing workspace key resolves to current working directory** – `Path(str(item.get("workspace") or "")).resolve()` produces `Path("").resolve()` (the CWD), causing the supervisor to scan and process unintended folders.

4. **Directory traversal vulnerability** – `workspace` paths are not validated against a safe root. An attacker who can control the project list can read arbitrary files via `path.read_text()` (e.g., `/etc/passwd`).

5. **Identity‑check cooldown bypass** – Cooldowns are keyed by `project` extracted from untrusted chat metadata (`meta.project`). An attacker can create a new project ID to bypass per‑project rate limits, causing repeated identity warnings.

6. **Denial of service via unbounded file reads** – `path.read_text()` loads entire files into memory with no size limit. A very large file (or symlink loop) can exhaust memory.

7. **Denial of service via unvalidated JSON parsing** – `json.loads()` on untrusted event payloads without depth/size limits can cause excessive CPU/memory consumption.

8. **Early‑exit logic error in `_sync_ai_knowledge_snapshot`** – `break` only exits the inner `for path in root.rglob(...)` loop; the outer `for root in scan_roots` loop continues, potentially collecting more than the intended 30 targets.

9. **False‑positive substring match in identity checks** – `"wit" in text` matches words like `"with"`, and `_FORBIDDEN_IDENTITY_TOKENS` overlaps with `_normalize_role_token` mappings, causing unnecessary corrections.

10. **Unsafe assumption about return type of `run_multi_ide_sentinel`** – The code expects a dict (`sentinel_result.get("ok")`), but the function may return a boolean or `None`, causing an `AttributeError`.

11. **Unsafe `item.get()` when project list contains non‑dict elements** – If `get_active_projects()` returns items that are not dictionaries, `item.get("project")` raises `AttributeError` → crash.

12. **Blocking synchronous I/O inside async loop** – `get_active_projects()`, `fetch_pending_events()`, and similar calls are invoked without `await` or `asyncio.to_thread`. If they perform I/O (DB, network), they block the event loop, starving other tasks.

13. **Busy‑wait spin loop** – The `while True` loop in `start_supervisor_loop` contains no `await asyncio.sleep()` call, consuming 100% CPU and preventing other coroutines from running.

14. **`asyncio.to_thread` misuse for `store_semantic_knowledge`** – If `store_semantic_knowledge` is actually an `async` function, wrapping it in `asyncio.to_thread` will fail silently or not execute correctly.

15. **Unbounded growth of cooldown dictionaries** – `a_last_sent`, `b_last_sent`, `identity_last_sent`, etc. accumulate entries for every new project and are never cleaned, causing a memory leak over time.

16. **Unhandled module‑level `ImportError`** – `from innova_bot.utils.config_guardian import ProjectGuardian` inside `start_supervisor_loop` is not guarded; if the module is missing, the error is raised at runtime and not caught.


---

## File: Innova-Bot RPG TUI (Python)


## QE_Evaluator Synthesis: Concrete Bugs & Issues to Fix

1. **Syntax error – truncated code**  
   The file ends with `nodes =` and is missing the remainder of an assignment or class definition. This is a **compile-time syntax error** and prevents the entire module from being imported or executed.

2. **Unvalidated file paths – directory traversal risk**  
   `_tail_lines(path, state)` and `_todo_phase_progress(repo_root)` accept paths that may come from environment variables or command-line arguments. They open arbitrary files without checking the path is within an allowed directory. An attacker could read sensitive files (e.g., credentials, configs) if they can control these inputs.

3. **Untrusted data displayed in UI – injection risk**  
   Values from LLM responses and network payloads (e.g., `micro_thought`, `Cognitive_Trace_Log`) are rendered without sanitization. Although Rich escapes HTML, these strings may contain ANSI escape sequences that corrupt the display, hide information, or mislead operators.

4. **Error information leakage – secrets in health panel**  
   In `_probe_ollama_sync`, the raw exception message is truncated (80 chars) and returned in the health dictionary. If the error includes sensitive data (URL with tokens, internal file paths, IPs), it can be displayed in the header panel to any viewer.

5. **File descriptor leak – `_tail_lines` never closes open files**  
   The opened file handle is stored in `state["fp"]` and never closed. Repeated calls (especially when the file path changes) leak file descriptors, eventually causing `OSError: too many open files`.

6. **`_tail_lines` always returns an empty list**  
   The function opens the file, seeks to the end, then reads `chunk_size` bytes from the end. Because it seeks to the end first, the read returns zero bytes. Consequently, no log lines are ever displayed. The function is effectively broken.

7. **`_progress_panel` creates duplicate Progress bars on every render**  
   Each call creates a new `Progress` instance and adds tasks with the same names. Over time this accumulates duplicate bars in the panel, causing visual clutter and unbounded memory growth.

8. **Crash when `TuiLogBuffer.__init__` receives `None` as maxlen**  
   `int(maxlen)` raises `TypeError` if `maxlen` is `None` (e.g., from external config). No fallback value is provided, causing the application to crash on startup.

9. **Unhandled exception in `_todo_phase_progress` – file read can crash UI**  
   `todo.read_text()` can raise `FileNotFoundError`, `PermissionError`, or `UnicodeDecodeError`. Because this function is called inside the `Live` render loop, any such exception propagates and terminates the entire TUI.

10. **`_poll_key_nonblocking` (Unix) can leave terminal in raw mode**  
    If an exception occurs after `tty.setraw(fd)` but before the `finally` block (e.g., during `select()`), the terminal settings are not restored because `old_settings` may not have been captured. The terminal remains in an unusable raw mode.

11. **`_detect_active_agent` false positives due to substring matching**  
    `if key in low:` matches substrings (e.g., "gravity" inside "antigravity"). This can misidentify the active agent and display the wrong alias.

12. **`_dialog_panel` page number calculation inverted**  
    `page_now` is computed in a way that contradicts typical scroll direction (scroll=0 should be last page, but the formula may produce negative or inverted values). Users will see confusing page labels and incorrect navigation.

13. **`_subconscious_panel` scroll not clamped – negative page numbers**  
    `int(scroll)` is not bounded to `max_scroll`, so a scroll value larger than maximum leads to negative `page_now` calculations and broken display.

14. **Partial line loss in `_tail_lines` across chunk boundaries**  
    `data.splitlines()` may break a line in half when the chunk does not end at a newline. Incomplete lines at the end of a read are discarded, causing data corruption in the displayed file tail.

15. **Non-thread-safe `deque` in `TuiLogBuffer` – race condition risk**  
    `collections.deque` is not thread-safe. If `push()` is called from a background thread while `recent()`/`window()` is called from the main TUI thread, the deque may be corrupted, leading to missing or duplicated log entries.

16. **Synchronous HTTP call blocks the main TUI thread**  
    `_probe_ollama_sync` performs a blocking HTTP request with a 2-second timeout. If called on every render cycle (e.g., inside `_header_panel`), the entire UI freezes for up to 2 seconds, making the TUI unresponsive.

17. **`BoundedUiEventQueue` eviction policy not atomic – can lose events**  
    Both `put_log` and `put_key` check `full()` and then call `get_nowait()` to drop the oldest item. In a concurrent scenario, another thread may take items between the check and the eviction, causing the new item to be dropped incorrectly. Additionally, `put_log` uses a `while` loop that may drain multiple events unnecessarily.

18. **`_poll_key_nonblocking` swallows all exceptions silently**  
    Broad `except Exception` catches terminal misconfiguration, import errors, or permission issues and returns `None`. This hides real failures and makes debugging impossible.

19. **Missing exception handling in `_tail_lines` file open**  
    No `try`/`except` around `path.open()`. A race condition (file deleted between `.exists()` and `open()`) or a permission error will raise an unhandled exception and crash the TUI.

20. **`BoundedUiEventQueue` busy-wait loop under full queue**  
    When the queue is full, `put_log` spins in a `while self._q.full()` loop calling `get_nowait()`. This can consume 100% CPU, starve the consumer thread, and discard all events before the consumer wakes.


---

