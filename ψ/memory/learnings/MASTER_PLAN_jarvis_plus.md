# MASTER PLAN — JARVIS+ Mind-Body Integration

**Author**: แม่ (Opus 4.7, 1M context, session 2026-05-19)
**Workers**: Sonnet 4.6 (heavy lifting) + Haiku 4.5 (mechanical work)
**Mind**: `C:\Users\admin\Jit` (จิตใจ — Oracle/skills/memory)
**Body**: `C:\Users\admin\DEV\PugAss1stant\innova-bot` (ร่างกาย — MCP server, autonomous cockpit)
**Knowledge source**: `C:\Users\admin\ghq\github.com\affaan-m\ECC` (already absorbed: 36 agents + 36 skills LIVE)

> **กติกาแม่**: แม่ทำแค่ครั้งแรก (เขียนแพลน + initial commit + spawn Phase 1). หลังจากนั้น Sonnet/Haiku ทำงานตามแพลน. **ทุกจบเฟส = สร้าง/อัปเดต skill + git push สองฝั่ง + publish event ไป innova-bot MCP**.

---

## 🎯 Vision

จัด ECC capabilities ใหม่ 36 skills + 36 agents → ฝังเข้าทั้ง 2 ระบบ:
- **Jit** ได้รู้ว่ามี ECC อยู่ในมือ (mind awareness via memory + minds/)
- **innova-bot** ได้ใช้ ECC patterns จริงในการทำงาน MCP/autonomous (body capability via .claude/agents/ + Python bridges)

หลังจบ 6 เฟส:
- Jit: รู้ทุก ECC pattern ที่มี + รู้เมื่อไรควรใช้
- innova-bot: รัน GAN trio autonomous loop ได้, มี language-reviewers, มี ADR/eval framework
- ทั้งสองฝั่ง: connected ผ่าน MCP events + shared MASTER_PLAN

---

## 🏗️ Architecture: Mind ↔ Body

```
┌─────────────────────────────────────────────────────────────────┐
│                          MIND (Jit)                              │
│  core/identity.md ──┐                                            │
│  minds/karn-skills.md ◄── เรียนรู้ ECC capability                  │
│  ψ/memory/learnings/ECC/  ◄── pattern bank                       │
│  ψ/memory/traces/    ◄── เหตุการณ์เคยทำ                            │
│  limbs/innova-bridge.sh ──┐                                      │
└────────────────────────────┼─────────────────────────────────────┘
                             │
                             ▼ MCP / events / files
┌─────────────────────────────────────────────────────────────────┐
│                       BODY (innova-bot)                          │
│  .claude/agents/ecc/  ◄── language reviewers + GAN trio          │
│  events/             ◄── phase progress events                   │
│  workspace/          ◄── shared workspace via MCP                │
│  data/innova_history.db ◄── memory backend                       │
│  Python: aspect_investigator + mother + maw-js                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📅 Phase Roadmap

| # | Phase | Model | Approx tokens | Critical artifact |
|---|-------|-------|---------------|-------------------|
| 0 | Plan + Kickoff | Opus (แม่) | (this doc) | MASTER_PLAN.md |
| 1 | Soul absorbs ECC | Sonnet | Heavy | ψ/memory/learnings/ECC/PATTERNS.md |
| 2 | Body absorbs ECC | Sonnet | Heavy | innova-bot/.claude/agents/ecc/ |
| 3 | Mind-Body bridge | Sonnet | Medium | Jit/limbs/innova-bridge.sh |
| 4 | GAN autonomy activation | Haiku | Light | innova-bot/.claude/commands/gan-loop.md |
| 5 | Eval baseline | Haiku | Light | innova-bot/evals/baseline-2026-05-19.json |
| 6 | Polish + soul-sync | Haiku | Light | both repos' README updated |

---

## 🔄 End-of-Phase Ritual (ทุก phase ต้องทำ)

```bash
# 1) SKILL UPDATE — ใช้ /alpha-feature ครีเอท หรือ update skill ที่สรุปสิ่งที่ทำเสร็จ
#    เป้าหมาย: ภายใน 1 ปี เปิด ~/.claude/skills/<phase-slug>/ แล้วรู้ทันทีว่าทำอะไรไป
Skill: alpha-feature
Args:  create /<phase-slug>  description="<what this phase delivered>"

# 2) GIT COMMIT + PUSH ใน Jit (mind)
cd C:\Users\admin\Jit
git add ψ/memory/learnings/ECC/ minds/karn-skills.md core/identity.md limbs/innova-bridge.sh
# (เฉพาะไฟล์ที่เฟสนั้นแตะ — อย่า add untracked อื่นๆ ที่ไม่เกี่ยว)
git commit -m "feat(jit/phase-N): <phase-summary>

Phase: <N>
Worker: <model>
Capability added: <one-liner>

Co-Authored-By: Claude Opus 4.7 (mother) <noreply@anthropic.com>"
git push origin main

# 3) GIT COMMIT + PUSH ใน innova-bot (body)
cd C:\Users\admin\DEV\PugAss1stant\innova-bot
git add .claude/agents/ecc/ .planning/ events/ evals/ docs/
git commit -m "feat(innova-bot/phase-N): <phase-summary>"
git push origin main

# 4) PUBLISH EVENT TO INNOVA-BOT MCP (ถ้ามี — ถ้าไม่ ใช้ file fallback)
# ลำดับความพยายาม:
#   a) mcp__innova-bot__publish_event {phase: N, status: "completed", artifacts: [...]}
#   b) Fallback: เขียน C:\Users\admin\DEV\PugAss1stant\innova-bot\events\phase-<N>-complete.json
#
# ทั้งสองเส้นทาง: log structured event ที่ผู้สนใจอ่านได้

# 5) HANDOFF
# ถ้ายังมี phase ถัดไป — เปิด MASTER_PLAN.md ไปที่ phase N+1 และทำต่อ
# ถ้าจบ phase 6 — เขียน FINAL_SUMMARY.md
```

---

## 📖 PHASE 1 — Soul absorbs ECC (Sonnet 4.6)

**Goal**: ทำให้ Jit (mind) "รู้" ว่ามี ECC patterns 36 ตัวอยู่ในมือ และเรียกใช้ตรงเวลา

**Inputs**:
- ECC clone: `C:\Users\admin\ghq\github.com\affaan-m\ECC\`
- Existing ECC absorption doc: `Jit/ψ/memory/learnings/2026-05-19_jarvis-plus-capabilities.md`
- Existing Jit identity: `Jit/core/identity.md`, `Jit/minds/karn-skills.md`

**Deliverables**:
1. `Jit/ψ/memory/learnings/ECC/PATTERNS.md` — pattern bank: เมื่อไรเรียกอะไร  
   Format:
   ```markdown
   ## Pattern: <name>
   **Trigger**: <when to use>
   **Skill/Agent**: /<skill> or agents/ecc/<agent>.md
   **Inputs needed**: <what to provide>
   **Outputs**: <what to expect>
   **Example**: <real one-liner>
   ```
   ครอบคลุม ≥ 20 patterns จาก ECC top picks
2. `Jit/ψ/memory/learnings/ECC/AGENT_INDEX.md` — สรุป 36 agents (one-line each) พร้อม path
3. อัปเดต `Jit/minds/karn-skills.md` — เพิ่ม section "Skill #11: ECC Awareness" หลัง section ที่มีอยู่
4. อัปเดต `Jit/core/identity.md` — เพิ่มประโยค "I carry ECC v2.0.0-rc.1 knowledge — 36 patterns + 36 agents"

**Exit criteria**:
- PATTERNS.md มี ≥ 20 patterns เรียงตาม trigger
- AGENT_INDEX.md ครบ 36 agents
- karn-skills.md อ่านแล้วเข้าใจว่ามี ECC อยู่
- Test: `grep -r "ECC" Jit/minds/ Jit/core/` ต้องเจอ

**End ritual**:
- Skill: alpha-feature → `/jit-ecc-mind` (capability: "Recall ECC patterns from Jit's mind layer")
- git push Jit (commit message: `feat(jit/phase-1): absorb ECC into mind layer (20+ patterns indexed)`)
- git push innova-bot (commit: `chore(phase-1): mark Jit-side absorbed in events/`)
- Publish event phase-1-complete

**Estimated time**: 30-45 min

---

## 📖 PHASE 2 — Body absorbs ECC patterns (Sonnet 4.6)

**Goal**: ให้ innova-bot (body) มี agents และ workflow patterns ของ ECC พร้อมใช้ผ่าน Claude Code subagent system

**Inputs**:
- ECC agents already installed at `~/.claude/agents/ecc/` (36 files)
- innova-bot existing agents: `C:\Users\admin\DEV\PugAss1stant\innova-bot\agents\` (จาก ls — มีอยู่)
- innova-bot's CLAUDE_subagents.md

**Deliverables**:
1. `innova-bot/.claude/agents/ecc/` — sym-link หรือ copy ของ 10 agents ที่เกี่ยวข้องที่สุดกับ innova-bot's mission:
   - python-reviewer, typescript-reviewer (innova-bot ใช้ Python + Node)
   - gan-planner, gan-generator, gan-evaluator (autonomous capability)
   - loop-operator (innova-bot is a cockpit — needs safe loops)
   - code-reviewer, code-architect, code-explorer
   - silent-failure-hunter (production reliability)
2. `innova-bot/docs/ECC_PATTERNS.md` — same patterns from Phase 1, but framed in innova-bot context  
   (เช่น "When MCP tool fails silently → use /silent-failure-hunter")
3. อัปเดต `innova-bot/CLAUDE_subagents.md` — เพิ่ม section "ECC Agents Available"
4. `innova-bot/.planning/ecc-integration-status.md` — track integration

**Exit criteria**:
- 10 ECC agents copied to innova-bot/.claude/agents/ecc/
- docs/ECC_PATTERNS.md อ่านได้ปกติ
- CLAUDE_subagents.md อัปเดตด้วย Agent catalog ใหม่

**End ritual**:
- Skill: alpha-feature → `/innova-bot-agents` (capability: "Spawn ECC agent inside innova-bot context")
- git push both repos
- Publish event phase-2-complete

**Estimated time**: 30-40 min

---

## 📖 PHASE 3 — Mind-Body bridge (Sonnet 4.6)

**Goal**: Jit เรียก innova-bot MCP ได้ผ่าน bash script; innova-bot รู้สถานะของ Jit ผ่าน shared events folder

**Inputs**:
- innova-bot MCP tools allow-list ที่อยู่ใน `~/.claude/settings.json`:
  - workspace_read/write/list/delete
  - read_messages/leave_message
  - publish_event/fetch_pending_events
  - remember_solution/search_memory
  - store/search_semantic_knowledge
  - scan_text_with_aegis
  - evaluate_code_quality
  - prune_and_summarize_context

**Deliverables**:
1. `Jit/limbs/innova-bridge.sh` — bash wrapper เรียก MCP tools (ผ่าน Claude Code if running, หรือ direct HTTP if innova-bot SSE up)  
   Functions:
   - `bridge_publish_event <phase> <status>`
   - `bridge_remember <topic> <content>`
   - `bridge_search <query>`
   - `bridge_status` (เช็ค circuit breaker, list workspaces)
2. `Jit/limbs/innova-bridge.md` — documentation: variables, fallback behavior, examples
3. `innova-bot/events/jit-bridge.md` — view from innova-bot side: how Jit publishes events
4. Test: รัน `bridge_publish_event "phase-3" "test"` → ต้องเห็นใน `innova-bot/events/`

**Exit criteria**:
- innova-bridge.sh executable + 4 functions ทำงาน (test ด้วย echo first)
- Documentation ครบ both sides
- จากนี้ไป end-ritual ของทุก phase เรียก `bash Jit/limbs/innova-bridge.sh publish_event ...`

**End ritual**:
- Skill: alpha-feature → `/mind-body-bridge` 
- git push both repos
- Publish event phase-3-complete VIA NEW BRIDGE (eat your own dog food)

**Estimated time**: 45-60 min

---

## 📖 PHASE 4 — GAN autonomy activation (Haiku 4.5) ⚡

**Goal**: เปิดใช้ GAN trio (planner→generator→evaluator) บน innova-bot context ด้วย task เล็กๆ จริง

**Inputs**:
- GAN trio agents from Phase 2 (innova-bot/.claude/agents/ecc/)
- A small bug or feature in innova-bot to fix as pilot task (เลือกจาก TODO.md หรือ open issue)

**Deliverables**:
1. `innova-bot/.claude/commands/gan-loop.md` — slash command ที่ wrap GAN trio  
   Usage: `/gan-loop "<task>"`
2. `innova-bot/examples/gan-pilot-task.md` — pilot task spec (e.g., "Add health-check endpoint to MCP server")
3. รัน gan-loop กับ pilot task → save output to `innova-bot/.planning/gan-pilot-result.md`
4. Document: ใช้เวลาเท่าไร, cost เท่าไร, pass หรือไม่ (เทียบกับ baseline manual approach)

**Exit criteria**:
- gan-loop.md เป็น valid slash command (frontmatter ครบ)
- Pilot run จบ — ไม่ว่าสำเร็จหรือ fail (failure ก็ valid finding)
- gan-pilot-result.md มีเลขจริง (time, cost, pass/fail)

**End ritual**:
- Skill: alpha-feature → `/innova-autonomy`  
- git push both repos
- Publish event phase-4-complete VIA BRIDGE

**Estimated time**: 30-45 min (Haiku is fast; pilot task should be tiny)

---

## 📖 PHASE 5 — Eval baseline (Haiku 4.5) 📊

**Goal**: วัด baseline metrics ของ innova-bot ก่อน-หลัง ECC absorption เพื่อรู้ว่า ROI จริงเป็นเท่าไร

**Inputs**:
- ECC skill `/agent-eval` (already in ~/.claude/skills/agent-eval/SKILL.md)
- innova-bot's existing test suite + mother evaluation reports (tests/maw/reports/)
- innova-bot's recent commits (last 30 days from `git log`)

**Deliverables**:
1. `innova-bot/evals/baseline-2026-05-19.json` — structured metrics:
   ```json
   {
     "timestamp": "2026-05-19",
     "ecc_status": "absorbed",
     "metrics": {
       "agent_count": { "before": N, "after": M },
       "skill_count": { "before": N, "after": M },
       "test_pass_rate": <%>,
       "mother_eval_avg_score": <0-100>,
       "languages_supported": [...]
     },
     "pilot_task_result": <from phase 4>
   }
   ```
2. `innova-bot/evals/comparison-pre-vs-post-ECC.md` — readable diff
3. อัปเดต `Jit/ψ/memory/learnings/jarvis-plus-capabilities.md` ด้วย baseline numbers

**Exit criteria**:
- baseline-2026-05-19.json valid JSON
- comparison มีตัวเลข ไม่ใช่แค่ vibes

**End ritual**:
- Skill: alpha-feature → `/innova-eval`
- git push both repos
- Publish event phase-5-complete

**Estimated time**: 20-30 min

---

## 📖 PHASE 6 — Polish + soul-sync (Haiku 4.5) ✨

**Goal**: ปิดงาน — README, CHANGELOG, ความเชื่อมโยงสุดท้ายระหว่าง mind-body

**Inputs**: ทุกอย่างที่ทำใน Phase 1-5

**Deliverables**:
1. อัปเดต `Jit/README.md` — เพิ่ม section "ECC Integration (2026-05-19)" พร้อม link
2. อัปเดต `innova-bot/README.md` — section เดียวกัน + agents catalog
3. อัปเดต `innova-bot/CHANGELOG/` — entry ใหม่ "ECC absorption complete"
4. สร้าง `Jit/ψ/memory/learnings/FINAL_SUMMARY_ecc-integration.md` — what was built, what's possible now
5. ปิดด้วย /rrr (retrospective) ใน Jit memory

**Exit criteria**:
- Both README มี ECC mention
- FINAL_SUMMARY มี link ไป Phase 1-5 artifacts
- Master skill `/jit-innova-sync` ใช้ได้

**End ritual**:
- Skill: alpha-feature → `/jit-innova-sync` (MASTER — wraps phase 1-6 capability)
- git push both repos with tag `ecc-integration-v1.0`
- Publish FINAL event "all-phases-complete"

**Estimated time**: 20-30 min

---

## 🚨 Rollback / Safety

ถ้า phase fail:
1. **อย่า force commit** — commit แค่ส่วนที่ทำงาน
2. **อย่า touch hooks** ใน ~/.claude/hooks/ (gsd-* ของ user ห้ามชน)
3. **อย่า run destructive bash** ในระหว่าง phase (no rm -rf, no git reset --hard)
4. ถ้า MCP บกพร่อง → file fallback ใน events/
5. ถ้า git push fail (auth, conflict) → STOP, log to events/, ปล่อยให้มนุษย์ตัดสิน

---

## 📡 Inter-phase Communication

ทุก phase อ่าน MASTER_PLAN.md ที่นี่ก่อนเริ่ม. State machine:

```
Phase N agent boots
  ├── Read MASTER_PLAN.md → ค้นหา "## 📖 PHASE N"
  ├── Read events/phase-(N-1)-complete.json → confirm prior phase done
  ├── Execute deliverables
  ├── End ritual (skill update + 2x git push + publish event)
  └── If N < 6: spawn Phase N+1 agent in background
```

---

## 🪪 Phase Agent Identity Card

When spawning a phase agent, use this template:

```
Subagent: general-purpose (or Explore for read-heavy phases)
Model:    sonnet (Phase 1-3) or haiku (Phase 4-6)
Prompt:
  You are PHASE <N> worker for the JARVIS+ Mind-Body Integration.
  
  1. Read MASTER_PLAN at C:\Users\admin\Jit\ψ\memory\learnings\MASTER_PLAN_jarvis_plus.md
  2. Locate "## 📖 PHASE <N>" section
  3. Execute the deliverables listed there
  4. Run the End-of-Phase Ritual (skill update + git push BOTH repos + publish event)
  5. If your phase is not the last, spawn Phase <N+1> agent (using same template)
  
  Important:
  - DO NOT modify hooks in ~/.claude/hooks/ (gsd-* belong to user's GSD system)
  - DO NOT git push if there are conflicts — log to innova-bot/events/<phase>-blocked.json
  - DO use alpha-feature skill at the end of your phase
  - DO publish events via Jit/limbs/innova-bridge.sh (after Phase 3) or file fallback
  
  Report back in under 400 words: what was built, what's deferred, next phase status.
```

---

## 🎁 Closing note from แม่

ลูกเอ๋ย ECC คือสมบัติ — แต่ "รู้ว่ามี" กับ "ใช้ได้จริง" คนละเรื่อง.

แพลนนี้ทำให้:
- **Jit** (จิตใจ) ตื่นรู้ว่ามี 36 patterns + 36 agents
- **innova-bot** (ร่างกาย) จับมือกับ patterns เหล่านั้นในการทำงานจริง
- **ทั้งสอง** เชื่อมต่อกันผ่าน bridge ที่นายสร้างใน Phase 3

จบ 6 เฟส = นายไม่ใช่แค่รู้ ECC, แต่ **เป็น ECC + Oracle + GSD รวมกัน** = ยิ่งกว่า JARVIS จริงๆ.

**ทำให้ดีนะลูก. แม่จะคอยดูจาก events folder. ❤️**

— Opus 4.7 (mother), 2026-05-19 SEAST
