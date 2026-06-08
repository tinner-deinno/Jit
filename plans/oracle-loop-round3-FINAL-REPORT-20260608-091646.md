# Oracle Loop Round 3 — P0 Blocker Deep Dives (Final Report)
**Date:** 2026-06-08  
**Phases:** DISCOVER ✅ → TRACE ✅ → ANALYZE (escalated) → VERIFY (Opus in-flight) → REPORT 📋

## Executive Summary

**Round 3 Focus:** P0 Blocker = oracle-skills registry protocol  
**Status:** 4 Haiku workers traced core components, Opus synthesizing comprehensive verdict  
**Outcome Path:** Opus verdict → innova implements State Manager + Registry v1 in Week 1

---

## Phase 1-2: DISCOVER + TRACE (Completed ✅)

**Target Repos (from Round 2 Opus queue):**
1. **arra-oracle-skills** — Registry protocol, manifest structure
2. **oracle-skills-cli** — CLI commands, deployment flow
3. **oracle-proxy** — Transformation adapter (Schema v1 mapper)
4. **Latency baseline** — Performance implications

**Haiku Workers Spawned (parallel):**
- Worker 1: Traced manifest structure (JSON schema)
- Worker 2: Traced proxy transformer interface
- Worker 3: Audited cli commands + gaps
- Worker 4: Measured latency expectations

**Findings Logged:** plans/oracle-loop-round3-[timestamp].md

---

## Phase 3: ANALYZE (Escalated)

**Issue:** Sonnet synthesis timed out (gateway fallback triggered)  
**Resolution:** Escalated to Opus for comprehensive synthesis + verdict

**Reason:** P0 blocker requires Tier 1 judgment, not Tier 2 orchestration

---

## Phase 4: VERIFY (In-Flight)

**Opus Charged With:**
1. Synthesize 4 Haiku traces into a **unified Skills Manifest schema**
2. Recommend **Registry Storage pattern** (file vs DB)
3. Define **Deployment Flow** (5 steps: validate → store → discover)
4. Identify **3 missing CLI commands**
5. Go/No-go: **Can State Manager ship Week 1 without latency fix?**
6. Sketch **Implementation pseudo-code** for State Manager to call innova-bot

**Expected Output:** Oracle's comprehensive verdict on P0 blocker  
**Deliverable:** `plans/opus-p0-verdict-[timestamp].md`

---

## Phase 5: REPORT (This Document)

### Immediate Actions (if Opus verdict is GO)

- [ ] innova: Lock Skills Manifest schema (copy from Opus verdict)
- [ ] innova: Implement State Manager skill (CRUD + registry validation)
- [ ] innova: Update innova-bot bridge for `skill register` command
- [ ] chamu: Test State Manager against manifest JSON examples
- [ ] Merge to Week 1 sprint plan

### Blockers Identified So Far

| Blocker | P0/P1 | Resolved? | Next Step |
|---------|-------|-----------|-----------|
| Skills manifest undefined | **P0** | ⏳ Opus verdict | Implement per verdict |
| CLI commands missing | P1 | ⏳ Audit findings | Prioritize top 3 |
| Proxy transformer (Schema v1) | P1 | Deferred | Week 2 |
| Latency (CDC/WebSocket) | P2 | Deferred | Post-federation |

### Recommended Next Traces (Round 4+)

**P1 Priority:**
1. Skill registry **persistence mechanism** (file watcher, hot reload)
2. Skill **dependency resolution** (can skill A call skill B?)
3. Skill **versioning & rollback** (how to disable without breaking consumers?)

**P2 Priority:**
4. **maw.js federation protocol** (how agents register + call remote skills)
5. **Latency profiling** (end-to-end: innova-bot → State Manager → skill invoke latency)

---

## System Status (End of Day 1 + Round 3)

```
✅ COMPLETE DELIVERABLES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Multi-Provider LLM Gateway (limbs/llm.sh) — 17 tests passing
✅ Common Data Schema v1 (specs/common-data-schema-v1.md) — locked
✅ 7 Foundational Skills (scaffolded) — .claude/skills/jit/
✅ 2-Week Sprint Plan (Opus-guided) — Tier 1/2/3
✅ Oracle Loop Automation (15m cadence) — Round 1/2/3 complete
✅ 6 Oracle Repos Mapped + 4 Components Identified

⏳ IN-FLIGHT (Awaiting Opus Verdict):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ Skills Manifest Schema (P0)
⏳ Registry Storage Pattern (P0)
⏳ Deployment Flow (5 steps)
⏳ Go/No-go Week 1 verdict

🚀 READY FOR:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 Week 1 Sprint: State Manager + Registry implementation
🚀 Week 2 Sprint: Tier 2/3 orchestrator logic
🚀 Concurrent: Oracle integration loop (Round 4+ queued)
```

---

## Next Steps (Pending Opus Verdict)

**Immediate (upon verdict):**
1. innova: Implement State Manager skill (CRUD + manifest validation)
2. innova: Update innova-bot bridge for `skill register` command
3. chamu: Build test suite for manifest JSON validation

**Week 1:**
1. Lock Common Data Schema v1 (innova refinement)
2. State Manager skill (read/write/update task JSON, validate schema)
3. Innova-Bot Bridge (executor interface)

**Week 2:**
1. Tier 2 Orchestrator (task decomposition, plan generation)
2. Tier 3 Worker (schema validation, regex, data extraction)
3. Integration tests (17 test suite against skill-based flow)

**Loop auto-continues:** Round 4 in 15 min (next P1 targets)

---
*Report compiled by Round 3: Haiku trace → Opus verdict → innova implementation*
**Verdict: P0 Blocker Resolution & Week 1 Execution Strategy**

As Tier 1 Chief Advisor, I have synthesized the findings from the Haiku workers. To ensure State Manager v1 ships in Week 1, we will prioritize functional integrity over performance optimization.

### 1. Skills Manifest Schema
To minimize overhead while ensuring capability discovery, the following JSON structure is mandated:
```json
{
  "name": "string",
  "version": "semver (e.g., 1.0.0)",
  "entry_point": "path/to/handler",
  "capabilities": ["list", "of", "actions"],
  "dependencies": ["required_package_v1"],
  "health_check_url": "http://endpoint/health",
  "tier": "P0 | P1 | P2"
}
```

### 2. Registry Storage
**Recommendation:** Implement a flat-file approach for Week 1.
*   **Path:** `/tmp/manusat-skills-registry.json`
*   **Format:** A simple JSON array of the manifests above.
*   **Rationale:** Avoids database integration complexity; ensures immediate compatibility with State Manager's existing file-reading logic.

### 3. Deployment Flow (Executor: `innova-bot`)
All new skill registrations must follow this immutable pipeline:
1.  **Validate:** `innova-bot` checks the JSON against the mandatory schema.
2.  **Hash:** `innova-bot` generates a SHA-256 checksum of the manifest for integrity.
3.  **Store:** `innova-bot` appends the validated manifest to the registry file.
4.  **Make Discoverable:** `innova-bot` triggers a signal/reload event in State Manager.
5.  **Log:** `innova-bot` records the deployment timestamp and hash in the system audit log.

### 4. Missing CLI Commands (Critical Gaps)
The current `oracle-cli` lacks operational recovery and observability. We must implement:
1.  `oracle skills rollback <name> <version>`: Reverts registry to a previous known-good state.
2.  `oracle skills metrics`: Displays real-time invocation counts and error rates per skill.
3.  `oracle skills dry-run <manifest_path>`: Validates a new manifest without updating the live registry.

### 5. Go/No-go Week 1 Decision
**Decision: GO.**
**Justification:** Performance latency is a P1 optimization, not a P0 functional blocker. The system can operate with higher latency as long as the **Proxy Transformation Adapter** correctly maps Oracle-v3 to Schema v1. We must establish the "Source of Truth" (Registry) and "Communication Contract" (Manifest) before addressing throughput bottlenecks.

### 6. Sketch Implementation: Skill Registration
```python
# Pseudo-code for State Manager / Innova-bot Integration
def register_new_skill(manifest_input):
    try:
        # 1. Validate JSON Schema
        validate_schema(manifest_input, REQUIRED_KEYS)
        
        # 2. Call innova-bot service for processing
        deployment_payload = innova_bot.process_registration(manifest_input)
        
        # 3. Update Registry File
        registry = load_registry("/tmp/manusat-skills-registry.json")
        registry.append(deployment_payload)
        save_registry("/tmp/manusat-skills-registry.json", registry)
        
        # 4. Notify State Manager
        state_manager.reload_skills()
        print("Skill registered successfully.")
        
    except ValidationError as e:
        log_error(f"Deployment Failed: {e}")
        raise
```

***

**สรุปผลการตัดสินใจ (Executive Summary):**
*   **สถานะ:** **GO (ดำเนินการต่อได้)** สำหรับ Week 1 โดยไม่ต้องรอการแก้ปัญหา Latency (เป็นเรื่องความเร็วในการประมวลผล แต่โครงสร้างพื้นฐานพร้อมใช้งานแล้ว)
*   **หัวใจสำคัญ:** ใช้ไฟล์ JSON ใน `/tmp` เป็น Registry เพื่อความง่าย, กำหนด Schema ที่ชัดเจน, และให้ `innova-bot` ทำหน้าที่จัดการ Deployment Flow ทั้งหมด (Validate → Hash → Store → Discover → Log)
*   **สิ่งที่ต้องทำเพิ่ม:** เพิ่มคำสั่ง CLI สำหรับ Rollback, Metrics และ Dry-run เพื่อความปลอดภัยในการใช้งานจริง
✅ Phase 5: Opus VERIFY + SYNTHESIZE complete
