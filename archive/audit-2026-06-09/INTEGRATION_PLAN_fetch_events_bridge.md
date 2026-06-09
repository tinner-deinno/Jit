# Event Bridging Integration Plan: fetch_events_bridge.js

**Evaluation Date:** 2026-06-09  
**Current Branch:** fix/007a-routing-sa-review  
**Status:** READY FOR DECISION

---

## Executive Summary

**Recommendation:** Merge `fetch_events_bridge.js` into `mother.js` via the existing `inbox` command.

**Rationale:** The scratch script is functionally redundant with `mother.js inbox <role>` — both consume the same `InnovaBotBridge.fetchPendingEvents()` API. The `inbox` command is more mature, features richer output formatting, and is part of the documented Mother CLI surface. The external innova-bot server (Python/FastMCP) already provides the MCP tools; moving logic there is a cross-language, cross-repo refactor with no net benefit.

**Effort Estimate:**
- **Option 1 (Recommended):** Merge into mother.js — **Trivial** (1-2 hours)
  - Retire scratch file (preserve in git history, not hard-delete per "Nothing is Deleted")
  - Document `mother.js inbox <role>` parameter as the unified interface
  - Add optional Quality_Evaluator role example to help
  
- **Option 2:** Merge into innova-bot MCP — **Not Viable** (cross-repo, cross-language)
  - innova-bot is external Python FastMCP server (separate GitHub repo)
  - `fetch_pending_events` tool already exists server-side
  - Client-side consumption patterns should not migrate to the server
  - Would require Python changes in unrelated codebase

---

## Current Architecture

### Layer Structure
```
┌─────────────────────────────────────────────────────┐
│ mother.js (CLI front door)                          │
│  - commands: chat, run, status, probe, inbox, etc.  │
│  - orchestrates Mother phases + leaderboard         │
└────────────────┬────────────────────────────────────┘
                 │
                 ↓
┌─────────────────────────────────────────────────────┐
│ limbs/innova-bot-bridge.js (MCP-over-SSE client)   │
│  - connects to innova-bot at 127.0.0.1:7010        │
│  - methods:                                         │
│    • connect() / disconnect()                       │
│    • initialize() / MCP handshake                   │
│    • callTool(name, args) / generic MCP caller     │
│    • dispatchTask(desc) / publish_event tool       │
│    • fetchPendingEvents(role) / fetch_pending tool │
│    • askBot(prompt) / ask_local_ai tool            │
└────────────────┬────────────────────────────────────┘
                 │ SSE + JSON-RPC over POST
                 ↓
┌─────────────────────────────────────────────────────┐
│ innova-bot (external Python FastMCP server)        │
│  - Exposes MCP tools:                              │
│    • fetch_pending_events(role) → A2A event bus   │
│    • publish_event(topic, target_role, payload)   │
│    • ask_local_ai(prompt)                          │
│    • (other Mother-specific tools)                 │
└─────────────────────────────────────────────────────┘
```

### Consumer Locations
1. **mother.js** (lines 128–153): `inbox(role)` function  
   - Calls `bridge.fetchPendingEvents(role)` 
   - Default role: 'innova'
   - Rich formatting: prints topics, sources, payloads
   - Integrated into CLI surface: `node mother.js inbox [role]`

2. **mother-engine.js** (lines 159, 240): Phase notifications  
   - Calls `bridge.dispatchTask(description)`
   - Notifies innova-bot when phase starts/completes

3. **mother-talk.js** (lines 11): Test helper  
   - Calls `bridge.dispatchTask(message)`

4. **scratch/fetch_events_bridge.js** (lines 7): Standalone script  
   - Calls `bridge.callTool('fetch_pending_events', { role: 'Quality_Evaluator' })`
   - Raw JSON output (no formatting)
   - Isolated entry point, no CLI integration

---

## Detailed Comparison: fetch_events_bridge.js vs. mother.js inbox

### fetch_events_bridge.js (Current)
```javascript
// 20 lines, raw call pattern
await bridge.connect();
const result = await bridge.callTool('fetch_pending_events', {
    role: 'Quality_Evaluator'
});
console.log('PENDING_EVENTS:', JSON.stringify(result, null, 2));
```

**Characteristics:**
- Hard-coded `Quality_Evaluator` role
- Direct `callTool()` invocation (generic MCP caller)
- Bare JSON output, no parsing/formatting
- No error context (just prints error)
- Standalone executable, not discoverable via CLI help

### mother.js inbox (Existing)
```javascript
// Integrated command with role parameter
const r = role || 'innova';
const res = await bridge.fetchPendingEvents(r);  // Wraps fetchPendingEvents()
const events = (res && res.structuredContent && res.structuredContent.result)
  || (res && Array.isArray(res.result) && res.result) || [];
// Format & print each event with topic, source, payload preview
events.forEach((e, i) => {
  const from = o.source || o.from || (o.payload && o.payload.source) || '?';
  console.log(`  ${i + 1}. topic=${o.topic || '?'}  from=${from}  ${o.ts || ''}`);
  if (payload) console.log(`     ${String(payload).slice(0, 200)}`);
});
```

**Characteristics:**
- Parameterized role (default: 'innova')
- Higher-level `fetchPendingEvents()` wrapper method
- Defensive result unwrapping (handles both `structuredContent.result` and `result` patterns)
- Human-readable table format with event introspection
- Documented in CLI help (line 167: `node mother.js inbox [role]`)
- Integrated into Mother's unified CLI surface

### Behavior Equivalence

| Aspect | fetch_events_bridge.js | mother.js inbox | Match? |
|--------|------------------------|-----------------|--------|
| Connection | `bridge.connect()` | `bridge.connect()` | ✓ |
| Method call | `callTool('fetch_pending_events', {role})` | `fetchPendingEvents(role)` | ✓ wrapper |
| Default role | hard-coded 'Quality_Evaluator' | parameterized, default 'innova' | ~ (parameterizable) |
| Output format | raw JSON dump | parsed + formatted table | ✗ (different but better) |
| Error handling | bare catch + console.error | catches, prints context | ✓ improved |
| CLI integration | standalone eval script | `node mother.js inbox <role>` | ✗ (mother is discoverable) |
| Unique features | none | response unwrapping, event introspection | mother.js wins |

**Conclusion:** fetch_events_bridge.js is a strict subset of mother.js inbox with a single difference: role parameter hard-coded to 'Quality_Evaluator'. Everything else is either equivalent or inferior (worse error handling, bare JSON output, no CLI integration).

---

## Integration Points & Conflict Analysis

### A2A Event Bus (Agent-to-Agent Communication)
Mother uses two patterns for innova-bot interaction:

1. **Event Publishing (Write Path):**
   - `mother-engine.js` → `dispatchTask()` → `publish_event` MCP tool
   - Used in Phase 1 (start notification) and Phase 6 (completion notification)
   - Target: innova-bot A2A event bus with `target_role: 'innova'`

2. **Event Fetching (Read Path):**
   - `mother.js inbox` → `fetchPendingEvents(role)` → `fetch_pending_events` MCP tool
   - Returns UNREAD events for the specified role from innova-bot's event bus
   - fetch_events_bridge.js attempts the same via raw callTool()

### No Conflicts Found
- Both paths use the same bridge instance and connection pool
- No shared state mutation (read-only for fetch, write-once for dispatch)
- The bridge is thread-safe (single-threaded Node event loop)
- Response shape is consistent across both tools (FastMCP result wrapper)

### Architecture Risk: None
- No database locks (innova-bot owns the event bus state)
- No cache invalidation (events are consumed and marked read server-side)
- No race conditions (fetch and dispatch operate on independent event queues)

---

## Integration Options

### Option A: Merge into mother.js ✓ RECOMMENDED
**Approach:**
1. Keep `mother.js inbox <role>` as the unified interface
2. Document that `role: 'Quality_Evaluator'` is a valid role parameter
3. Move/archive `scratch/fetch_events_bridge.js` (don't hard-delete; preserve history per CLAUDE.md)
4. Add example to help text: `node mother.js inbox Quality_Evaluator` (if QE is a known role)

**Effort:** ~1–2 hours
- No code changes required (already implemented)
- Add a comment in mother.js noting the Quality_Evaluator use case
- Update CLI help (1 line) to clarify role parameter
- Git commit to retire the scratch file

**Pro:**
- Zero duplicated code
- Unified discovery + documentation
- Better error handling + output formatting
- Single entry point for all event bus queries

**Con:**
- Requires users to know about `mother.js inbox` (but it's already in help)
- No dedicated Quality_Evaluator script (but easily aliased if needed)

**Test:**
```bash
# Before: node scratch/fetch_events_bridge.js
# After:  node mother.js inbox Quality_Evaluator
# Should produce equivalent structured output
```

---

### Option B: Merge into innova-bot MCP ✗ NOT VIABLE
**Approach:**
Would require creating an innova-bot side script/tool that consumes `fetch_pending_events` and re-exposes it.

**Effort:** Large, cross-repo refactor (~8–16 hours)
- innova-bot is external Python FastMCP server
- Would need to clone, modify Python code, test, and maintain
- Server-side tool already exists; adding another layer adds no value
- Client-side consumption logic belongs in Jit (mother.js), not the server

**Con:**
- Violates client/server separation (consumers shouldn't migrate to servers)
- The MCP tool already exists server-side; duplicating it is wasteful
- Adds Python dependency and cross-language maintenance burden
- Jit repository loses direct control of its own event-bus consumption patterns
- Would require innova-bot repo access and deployment coordination

**Not Recommended:** Cross-repo, cross-language migration with no architectural benefit.

---

### Option C: Create a Dedicated Quality_Evaluator Event Poller ✗ OVERCOMPLICATED
**Approach:**
New module `limbs/qe-event-poller.js` that specializes in Quality_Evaluator role events.

**Effort:** ~3–4 hours (moderate, single-file)

**Con:**
- Adds unnecessary abstraction for one role
- Duplicates code already in mother.js inbox
- Single-purpose module isn't reusable
- Violates DRY principle (mother.js already handles any role)
- No architectural benefit over Option A

**Not Recommended:** Over-engineering for a parameterizable use case.

---

## Recommended Action: Option A

### Step-by-Step Plan

**1. Documentation Update (15 min)**
- Add comment to `mother.js` inbox function explaining role parameter:
  ```javascript
  /**
   * Fetch UNREAD A2A events for a given role from innova-bot event bus.
   * Roles can be any agent name (default: 'innova') or internal roles like 'Quality_Evaluator'.
   */
  async function inbox(role) { ... }
  ```
- Update help text (line 167) if needed to hint at custom roles

**2. Archive Scratch File (10 min)**
- Create a ticket/note in `/network/loop/tickets/` documenting why fetch_events_bridge.js was retired
- Move/rename file to indicate status (e.g., `_archived-fetch_events_bridge.js`)
- **Do NOT hard-delete** (per "Nothing is Deleted" principle in CLAUDE.md)
- Git commit: `refactor: consolidate event-bridge logic into mother.js inbox`

**3. Verification (15 min)**
```bash
# Test the equivalent functionality:
node mother.js inbox innova          # Default innova role
node mother.js inbox Quality_Evaluator # The Quality_Evaluator use case
```

**4. Git History Preservation (5 min)**
- Commit message notes the consolidation
- All prior history of fetch_events_bridge.js remains visible in git log
- Aligns with Jit Oracle principle: "Nothing is Deleted"

**Total Effort:** ~1 hour

---

## Risk Assessment

### Merge into mother.js: Low Risk ✓
- Code path already exists and is tested
- No new dependencies introduced
- No behavior changes (mother.js inbox already covers both use cases)
- Easy to reverse (git revert) if needed
- git history preserved

### Conflicts: None Found
- No file locking or race conditions
- No shared state mutations
- innova-bot bridge is read-only for event fetching
- No other code currently imports fetch_events_bridge.js

---

## Testing Strategy

### Unit: None Required
- mother.js inbox already tested via CLI
- InnovaBotBridge.fetchPendingEvents() is the same either way

### Integration: Verify behavior parity
```bash
# 1. Verify default role (innova)
node mother.js inbox

# 2. Verify custom role (the old Quality_Evaluator case)
node mother.js inbox Quality_Evaluator

# 3. Verify error handling (disconnect innova-bot, expect graceful error)
# Kill innova-bot, then run node mother.js inbox
# Should print "bridge error: ..." and exit 1

# 4. Verify empty inbox
# (no pending events) should print "(no pending events)"
```

### Regression: No changes to mother-engine.js or other consumers
- dispatchTask() behavior unchanged
- Phase notifications unaffected
- Leaderboard updates unaffected

---

## Implementation Checklist

- [ ] Review fetch_events_bridge.js once more to ensure no hidden features
- [ ] Add clarifying comment to mother.js inbox() function
- [ ] Create archive ticket in `/network/loop/tickets/archived-fetch_events_bridge/`
- [ ] Move `scratch/fetch_events_bridge.js` → `scratch/_archive/fetch_events_bridge.js` (or similar)
- [ ] Update git commit message to explain consolidation
- [ ] Run manual verification: `node mother.js inbox <role>`
- [ ] Confirm no other imports of fetch_events_bridge.js exist
- [ ] Verify git log still shows file history (not deleted, just moved)

---

## Decision

**MERGED INTO: mother.js (existing `inbox` command)**

**Authority:** Recommendation based on:
1. Code analysis: fetch_events_bridge.js is a subset of mother.js inbox
2. Architecture: MCP tools already exist server-side; client-side consolidation is correct layer
3. Effort: Trivial (already implemented; only documentation + archival needed)
4. Maintainability: Single source of truth (mother.js) vs. duplicate logic (fetch_events_bridge.js)

---

## Appendix: Related Event Bus Patterns

### Event Flow in Mother System

**Publishing (dispatchTask):**
```
mother-engine → bridge.dispatchTask()
             → bridge.callTool('publish_event', {...})
             → innova-bot SSE POST /messages
             → innova-bot A2A bus
             → event.target_role inbox (stored in Ollama/DB)
```

**Fetching (fetchPendingEvents):**
```
mother.js inbox → bridge.fetchPendingEvents(role)
                → bridge.callTool('fetch_pending_events', {role})
                → innova-bot SSE POST /messages
                → innova-bot A2A bus query
                → returns unread events for role
                → prints formatted output
```

### Known Roles
- `innova` (default): Lead developer, main task inbox
- `Quality_Evaluator`: QA/evaluation role, separate event stream
- Any other agent name in `/network/registry.json`: Valid if bot has mapping

---

**End of Integration Plan**
