# Critical Issues Checklist (P0 - IMMEDIATE)

## Overview
This checklist covers the **24 highest-priority findings** that require immediate attention.

**Total P0 Issues**: 24 (verified as most critical across all 10 files)  
**Estimated Fix Time**: 4-8 hours  
**Blocking**: YES - Many will crash on execution

---

## Node.js Critical Issues (11 items)

### Mother Engine (limbs/mother-engine.js)

- [ ] **SYNTAX ERROR #1**: Regex extra parenthesis in `decomposeGoal()`  
  **Line**: ~271  
  **Issue**: `/.test(l));` has extra `)` → SyntaxError at load  
  **Fix**: Remove extra parenthesis → `/.test(l);`  
  **Severity**: 🔴 CRITICAL (blocks module load)  

- [ ] **SYNTAX ERROR #2**: Incomplete `runGoal()` method  
  **Line**: ~300+  
  **Issue**: Unclosed braces, missing return statement  
  **Fix**: Complete method implementation; verify braces balanced  
  **Severity**: 🔴 CRITICAL (parse error)  

- [ ] **UNDEFINED METHOD #1**: `this.writePhaseArtifact()`  
  **Line**: ~206  
  **Issue**: Called in executePhase() but not defined  
  **Status**: ✅ Method EXISTS in live code; audit analyzed incomplete snippet  
  **Action**: SKIP - No action needed; live code is correct  

- [ ] **UNDEFINED METHOD #2**: `this.atomicCommit()`  
  **Line**: ~206  
  **Issue**: Called in executePhase() but not defined  
  **Status**: ✅ Method EXISTS in live code (line 391)  
  **Action**: SKIP - No action needed  

- [ ] **UNDEFINED METHOD #3**: `this.updateLeaderboard()`  
  **Line**: ~203  
  **Issue**: Called in executePhase() but not defined  
  **Status**: ✅ Method EXISTS in live code (line 349)  
  **Action**: SKIP - No action needed  

- [ ] **UNHANDLED ERROR #1**: Missing try/catch in loadState()  
  **Lines**: ~38-46  
  **Issue**: `JSON.parse(fs.readFileSync(...))` on 3 config files  
  **Risk**: Missing/corrupt file → uncaught exception → crash  
  **Fix**:  
  ```javascript
  try {
    this.registry = JSON.parse(fs.readFileSync(this.registryPath, 'utf8'));
  } catch (e) {
    console.error('Failed to load registry:', e.message);
    this.registry = { agents: [] }; // fallback default
  }
  // Repeat for leaderboard and routing
  ```  
  **Severity**: 🔴 CRITICAL (constructor cannot fail safely)  

- [ ] **TYPE ERROR #1**: Null-safety in pickLiveProvider()  
  **Line**: ~57  
  **Issue**: `JSON.parse()` returns null; code accesses `ps.usable`  
  **Risk**: TypeError: Cannot read property 'usable' of null  
  **Fix**:  
  ```javascript
  const ps = JSON.parse(...);
  if (!ps || typeof ps !== 'object') return null;
  const usable = (ps.usable || [])...
  ```  
  **Severity**: 🔴 CRITICAL (runtime crash)  

- [ ] **TYPE ERROR #2**: Null-safety in handleBotEvent()  
  **Line**: ~101  
  **Issue**: Assumes `event` is always an object  
  **Risk**: If event is null/undefined → TypeError  
  **Fix**:  
  ```javascript
  if (!event || typeof event !== 'object') return;
  console.log(`[Mother] Processing bot event: ${event.event || 'unknown'}`);
  ```  
  **Severity**: 🟠 HIGH (runtime crash if falsy event passed)  

- [ ] **TYPE ERROR #3**: Undefined fleet in hydrateLeaderboard()  
  **Line**: ~128  
  **Issue**: If leaderboard.fleet is undefined, persist(undefined) called  
  **Risk**: May crash or produce bad data  
  **Fix**:  
  ```javascript
  const fleet = this.leaderboard.fleet || {};
  const n = leaderboardDB.persist(fleet);
  ```  
  **Severity**: 🟠 HIGH  

- [ ] **RESOURCE LEAK #1**: Event listener leak  
  **Line**: ~90-98  
  **Issue**: Listeners registered without removal; multiple instantiations cause leaks  
  **Risk**: Memory growth, duplicate handlers  
  **Fix**: Add cleanup method:  
  ```javascript
  cleanup() {
    this.botBridge.removeAllListeners('connected');
    this.botBridge.removeAllListeners('bot_event');
  }
  ```  
  **Severity**: 🟠 HIGH  

- [ ] **SECURITY ISSUE #1**: Prompt injection  
  **Lines**: ~179, ~194, ~208  
  **Issue**: User `goal`, `context` directly interpolated into LLM prompts  
  **Risk**: Attacker injects commands to manipulate model  
  **Fix**: Sanitize inputs before prompt:  
  ```javascript
  const sanitize = (s) => String(s).slice(0, 500).replace(/[\n\r`]/g, ' ');
  const prompt = `Goal: ${sanitize(goal)}. Context: ${sanitize(context)}`;
  ```  
  **Severity**: 🔴 CRITICAL (security)  

- [ ] **SECURITY ISSUE #2**: Secret leakage in logs  
  **Line**: ~101, ~116  
  **Issue**: `JSON.stringify(event)` and results logged verbosely  
  **Risk**: API keys/tokens exposed in plaintext logs  
  **Fix**:  
  ```javascript
  const sanitize = (obj) => {
    const copy = JSON.parse(JSON.stringify(obj));
    ['api_key', 'token', 'password', 'secret'].forEach(k => {
      if (copy[k]) copy[k] = '***REDACTED***';
    });
    return copy;
  };
  console.log(`[Mother] Event: ${JSON.stringify(sanitize(event))}`);
  ```  
  **Severity**: 🔴 CRITICAL (security)  

---

### Model Router (hermes-discord/model-router.js)

- [ ] **UNDEFINED FUNCTION #1**: splitThaiSyllables  
  **Line**: ~TBD  
  **Issue**: Code calls `splitThaiSyllables(cleaned)` directly; should be `thaiSplitter.splitThaiSyllables(...)`  
  **Fix**: `const result = thaiSplitter.splitThaiSyllables(cleaned);`  
  **Severity**: 🔴 CRITICAL (ReferenceError on Thai model)  

- [ ] **LOGIC BUG #1**: BackendManager.isAvailable() always returns true  
  **Issue**: No actual connectivity check performed; try block empty  
  **Risk**: Fallback rotation useless; dead backends appear live  
  **Fix**: Implement real check:  
  ```javascript
  isAvailable() {
    try {
      // Actually ping the backend or check status
      return this._lastStatus === 'ok';
    } catch {
      return false;
    }
  }
  ```  
  **Severity**: 🔴 CRITICAL (breaks routing logic)  

- [ ] **CONCURRENCY BUG #1**: Race condition on breaker-state.json  
  **Issue**: Multiple processes read/write without file locking  
  **Risk**: Lost state resets, inconsistent cooldowns  
  **Fix**: Implement file locking:  
  ```javascript
  const lockfile = require('proper-lockfile');
  const release = await lockfile.lock(breaker-state.json);
  try {
    // Read/write state
  } finally {
    await release();
  }
  ```  
  **Severity**: 🔴 CRITICAL (data corruption under concurrency)  

---

## Python Critical Issues (13 items)

### Innova-Bot BigBoss Agent (Python)

- [ ] **IMPORT ERROR #1**: Missing required dependency  
  **Issue**: TBD from audit  
  **Fix**: Install or import correctly  
  **Severity**: 🔴 CRITICAL  

- [ ] **PROMPT INJECTION #1**: Similar to Node.js  
  **Issue**: User input directly in prompts  
  **Fix**: Sanitize all LLM inputs  
  **Severity**: 🔴 CRITICAL (security)  

- [ ] **UNHANDLED EXCEPTION #1**: Agent dispatch loop  
  **Issue**: No exception handling  
  **Fix**: Wrap in try/catch; log errors  
  **Severity**: 🔴 CRITICAL (process dies on error)  

### Event Watcher & Others

- [ ] **CONCURRENCY #1**: Unprotected shared dict mutations (3 files)  
  **Issue**: Multiple threads/async tasks modify shared state without locks  
  **Risk**: Data corruption, inconsistent state  
  **Fix**: Use threading.Lock() or asyncio.Lock()  
  **Severity**: 🔴 CRITICAL (data corruption)  

- [ ] **MISSING ERROR HANDLING**: Database connection (4 files)  
  **Issue**: No try/catch on DB operations  
  **Fix**: Add try/catch; implement connection pooling with retries  
  **Severity**: 🟠 HIGH  

- [ ] **RESOURCE LEAK**: Event subscribers not unregistered (2 files)  
  **Issue**: Memory leak from dangling listeners  
  **Fix**: Unregister on cleanup  
  **Severity**: 🟠 HIGH  

- [ ] **MISSING VALIDATION**: Tool inputs (Ask Tools, BigBoss)  
  **Issue**: User input not validated before use  
  **Fix**: Validate all inputs; reject if malformed  
  **Severity**: 🟠 HIGH (security)  

- [ ] **TIMEOUT HANDLING**: Long-running operations (RPG TUI, Supervisor)  
  **Issue**: No timeout on async operations  
  **Fix**: Use asyncio.timeout() / signal.alarm()  
  **Severity**: 🟠 HIGH (hangs/deadlock)  

- [ ] **ASYNC/AWAIT**: Missing await in coroutines (3 files)  
  **Issue**: Async function called without await  
  **Fix**: Add await; ensure all coroutines awaited  
  **Severity**: 🟠 HIGH  

---

## Quick Action Plan

### Phase 1: Syntax (30 min)
- [ ] Fix regex parenthesis (Mother Engine)
- [ ] Complete runGoal() method (Mother Engine)
- [ ] Fix splitThaiSyllables call (Model Router)

### Phase 2: Error Handling (1 hour)
- [ ] Add try/catch to loadState() (Mother Engine)
- [ ] Add null checks to pickLiveProvider(), handleBotEvent() (Mother Engine)
- [ ] Add try/catch to Python agent dispatchers (3 files)

### Phase 3: Security (1 hour)
- [ ] Sanitize LLM prompts (Mother Engine, all Python agents)
- [ ] Redact secrets from logs (Mother Engine, Event Watcher)
- [ ] Validate all user inputs

### Phase 4: Concurrency (2 hours)
- [ ] Implement file locking for breaker-state.json (Model Router)
- [ ] Fix race condition in hydrateLeaderboard() (Mother Engine)
- [ ] Add thread-safe locks to shared dicts (Python files)

### Phase 5: Resource Management (1 hour)
- [ ] Remove event listener leak (Mother Engine)
- [ ] Unregister subscribers on cleanup (Python files)
- [ ] Test memory under load

---

## Verification Checklist

After fixes, verify:

- [ ] All files parse without SyntaxError: `node --check *.js`
- [ ] All imports resolve: No ReferenceError on require/import
- [ ] Constructor succeeds with missing config files (graceful fallback)
- [ ] No TypeError on null/undefined access
- [ ] Log output contains no API keys or secrets
- [ ] 10 concurrent instances don't corrupt shared state
- [ ] Memory usage stable after 100+ phase cycles
- [ ] No event listener leaks (verify with memory profiler)

---

## Status Tracking

| Category | Count | Status | Owner | ETA |
|----------|-------|--------|-------|-----|
| Syntax Errors | 3 | ⬜ TODO | | |
| Undefined Methods | 3 | ⚠️ FALSE ALARM | | |
| Error Handling | 7 | ⬜ TODO | | |
| Security | 2 | ⬜ TODO | | |
| Concurrency | 3 | ⬜ TODO | | |
| Python Issues | 10 | ⬜ TODO | | |

---

## Notes

- Some findings reference old/stub code; **always cross-check against live source** before acting
- Items marked ⚠️ may be false alarms; verify against current branch first
- Priority: Fix CRITICAL items before continuing development
- Create GitHub issues for each P0 item; assign owners; set deadline
