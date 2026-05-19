## ECC Pattern Bank — When to Use What

**Author**: Phase 1 worker (Sonnet 4.6) — 2026-05-19
**Source**: ECC v2.0.0-rc.1 (36 skills + 36 agents LIVE in `~/.claude/`)
**Cross-ref**: `AGENT_INDEX.md`, `../2026-05-19_jarvis-plus-capabilities.md`

> **How to read this file**: each pattern is a triggered playbook. Search for the **Trigger** that matches your situation; the **Skill/Agent** line tells you exactly what to invoke.

---

## Pattern: Language-specific code review (Python)
**Trigger**: A `.py` file was edited, written, or pasted for review.
**Skill/Agent**: `agents/ecc/python-reviewer.md` (auto-spawned via Claude Code)
**Inputs needed**: File path(s) or diff; optional: framework hint (Django, FastAPI).
**Outputs**: PEP 8 violations, type-hint gaps, idiom issues, security smells (eval, pickle, SQL string concat), performance notes.
**Example**: After `Edit innova-bot/devtools/innova-bot/innova_bot/server.py`, ask "review my changes" → python-reviewer fires automatically.

---

## Pattern: Language-specific code review (TypeScript / JavaScript)
**Trigger**: A `.ts`, `.tsx`, `.js`, or `.jsx` file changed.
**Skill/Agent**: `agents/ecc/typescript-reviewer.md`
**Inputs needed**: File or diff; mention if Node, Next.js, or browser.
**Outputs**: Type-safety gaps (any/unknown abuse), async/await mistakes, security (XSS, prototype pollution), idiomatic suggestions.
**Example**: "Review the auth middleware I just wrote in `src/middleware/auth.ts`."

---

## Pattern: Build / type-error firefight
**Trigger**: `tsc`, `cargo build`, `go build`, `mvn`, or any compile step failed and we need green again fast.
**Skill/Agent**: `agents/ecc/build-error-resolver.md`
**Inputs needed**: Error log (full traceback), failing file path.
**Outputs**: Minimal-diff fixes. NO architectural changes — only what's needed to compile.
**Example**: "TypeScript error TS2322 in `src/api/users.ts:42` — fix it."

---

## Pattern: PyTorch training crashed
**Trigger**: PyTorch runtime/CUDA error — tensor shapes, device mismatch, gradient NaN, DataLoader hang, mixed precision blow-up.
**Skill/Agent**: `agents/ecc/pytorch-build-resolver.md`
**Inputs needed**: Stack trace, model code, batch shape, device info (CPU/CUDA/MPS).
**Outputs**: Targeted patch: `.to(device)` placement, shape reconciliation, gradient checkpointing, amp.autocast scope fix.
**Example**: "Training crashed with `RuntimeError: Expected all tensors on cuda:0 but got cpu` — fix it."

---

## Pattern: One-liner to full product (GAN autonomous loop)
**Trigger**: User says "Build feature X" with no spec, wants autonomy not babysitting.
**Skill/Agent**: `agents/ecc/gan-planner.md` → `gan-generator.md` → `gan-evaluator.md` (orchestrated by `loop-operator.md`)
**Inputs needed**: One-line goal; optional repo path; success threshold (e.g. "all E2E green").
**Outputs**: Spec (planner), implementation iterations (generator), Playwright score reports (evaluator), final PR.
**Example**: "Build a JWT auth system with refresh tokens — use the GAN trio."

---

## Pattern: Safe long-running autonomous loop
**Trigger**: Multi-hour or multi-day autonomous task. Risk: stuck loops, runaway cost.
**Skill/Agent**: `agents/ecc/loop-operator.md` + skill `/continuous-agent-loop`
**Inputs needed**: Loop spec (sequential / RFC-DAG / PR-driven / infinite), budget cap, stall heuristic.
**Outputs**: Watchdog reports, intervention events, safe pause/resume.
**Example**: "Run /gan-loop overnight on the open issue backlog — supervise with loop-operator."

---

## Pattern: Agent / agent-harness benchmarking
**Trigger**: Need to decide "Claude Code vs Aider vs Codex" or "Opus vs Sonnet vs Haiku" for a task class.
**Skill/Agent**: `/agent-eval`
**Inputs needed**: Task suite (3-10 representative tasks), grading rubric, agents to compare.
**Outputs**: Pass rate, $/task, time, consistency table. Recommendation memo.
**Example**: "/agent-eval — compare Sonnet 4.6 vs Haiku 4.5 on innova-bot bug-fix tasks."

---

## Pattern: Eval-driven development (regression-safe AI changes)
**Trigger**: Adding/modifying an AI feature (prompt, agent, tool) that can silently regress.
**Skill/Agent**: `/eval-harness` + `/ai-regression-testing`
**Inputs needed**: Golden test cases (input → expected output), pass/fail criteria, pass@k target.
**Outputs**: Eval suite, baseline numbers, regression alarms when accuracy drops.
**Example**: "Before tuning the maw prompt, build a /eval-harness with 20 golden cases."

---

## Pattern: Cost audit (context-eating tools)
**Trigger**: Token bill rising, sessions feel sluggish at start, suspect skill/MCP bloat.
**Skill/Agent**: `/context-budget`
**Inputs needed**: List of active skills, MCP servers, agents, rules.
**Outputs**: Ranked bloat list, prioritized cuts, projected token savings.
**Example**: "/context-budget — Claude Code session is 35% full at boot, find the culprits."

---

## Pattern: Cost-aware LLM routing
**Trigger**: Building a feature that calls Claude API repeatedly; risk of $$$.
**Skill/Agent**: `/cost-aware-llm-pipeline`
**Inputs needed**: Task complexity tiers, model rate card, monthly budget.
**Outputs**: Routing rules (Haiku for triage, Sonnet for build, Opus for review), prompt-cache configuration, retry policy.
**Example**: "Add cost-aware routing to innova-bot's `ask_local_ai` tool."

---

## Pattern: Pre-edit fact-forcing gate
**Trigger**: About to Edit/Write/Bash on a file/system without yet investigating importers, data schema, user constraints.
**Skill/Agent**: `/gateguard` (skill version installed; hook version intentionally NOT wired to avoid clash with `gsd-*` hooks)
**Inputs needed**: Intended change, file path.
**Outputs**: Forced answers to: who imports this? what's the data shape? what did the user actually ask? +2.25 quality points over ungated.
**Example**: "/gateguard — before I rewrite `utils/citta_engine.py`."

---

## Pattern: Silent failure audit
**Trigger**: System "works" but bugs slip through. Logs show nothing. Errors get swallowed.
**Skill/Agent**: `agents/ecc/silent-failure-hunter.md`
**Inputs needed**: Module path or list of files; description of suspicious behavior.
**Outputs**: List of swallowed errors, bad fallbacks, missing propagation, recommended fixes.
**Example**: "Hunt silent failures in `innova-bot/devtools/innova-bot/agents/`."

---

## Pattern: Architecture decision capture
**Trigger**: About to make a non-trivial choice (DB, framework, pattern) that future-you will forget the "why" of.
**Skill/Agent**: `/architecture-decision-records`
**Inputs needed**: Conversation context (auto-detects decision moments), alternatives considered, chosen path.
**Outputs**: ADR file in `docs/adr/NNNN-title.md` with context/alternatives/decision/consequences.
**Example**: "Choosing between SQLite and Postgres for innova_history.db → emit an ADR."

---

## Pattern: Onboarding new codebase
**Trigger**: First contact with an unfamiliar repo; need to ramp fast.
**Skill/Agent**: `/codebase-onboarding` (write output) + `/code-tour` (anchored walkthrough)
**Inputs needed**: Repo URL or path, optional persona (backend dev, security, SRE).
**Outputs**: Onboarding guide (architecture map, entry points, conventions), `.tour` files, starter `CLAUDE.md`.
**Example**: "Onboard me to `arra-oracle-v3` — I need to ship a feature this week."

---

## Pattern: Multi-language hexagonal refactor
**Trigger**: Domain logic tangled with frameworks; tests slow because they need DB/HTTP.
**Skill/Agent**: `/hexagonal-architecture`
**Inputs needed**: Module to refactor, languages in use (TS/Java/Kotlin/Go).
**Outputs**: Ports & Adapters layout, dependency-inversion plan, use-case orchestration scaffolding.
**Example**: "Refactor `daemons/heartbeat.py` along hexagonal lines — pure domain in core, adapters at edges."

---

## Pattern: API design (REST endpoints)
**Trigger**: New REST resource or refactoring an existing one.
**Skill/Agent**: `/api-design`
**Inputs needed**: Resource name, operations, consumers, versioning concerns.
**Outputs**: URL scheme, status codes, pagination/filtering, error shape, versioning strategy, rate-limit plan.
**Example**: "Design `/v1/sessions` endpoints for Jit Oracle session API."

---

## Pattern: New integration / API connector
**Trigger**: Adding a 3rd-party API integration to an existing repo.
**Skill/Agent**: `/api-connector-builder`
**Inputs needed**: Target API spec, repo to integrate into.
**Outputs**: Connector that **matches the repo's existing pattern** (no inventing a second architecture).
**Example**: "Add a Notion connector to innova-bot — match how the existing Ollama connector is built."

---

## Pattern: Error handling overhaul (typed, retried, circuit-broken)
**Trigger**: Production reliability gap; ad-hoc try/except everywhere.
**Skill/Agent**: `/error-handling`
**Inputs needed**: Language (TS/Python/Go), module list.
**Outputs**: Typed error hierarchy, error boundaries, retry policies, circuit breakers, user-facing messages.
**Example**: "Add /error-handling patterns to `innova-bot/devtools/innova-bot/scripts/`."

---

## Pattern: Production MCP server build
**Trigger**: Building or hardening an MCP server (innova-bot is one).
**Skill/Agent**: `/mcp-server-patterns`
**Inputs needed**: Tool list, transport mode (stdio/SSE), validation needs.
**Outputs**: Tool registration via SDK, Zod/Pydantic validation, error responses, lifecycle handling.
**Example**: "Audit innova-bot's MCP tool registration against /mcp-server-patterns."

---

## Pattern: Agent harness self-audit
**Trigger**: Suspect Jit Oracle or innova-bot's own agent system is leaking quality (wrapper regression, memory pollution, repair loops).
**Skill/Agent**: `/agent-architecture-audit` + `/agent-introspection-debugging`
**Inputs needed**: Agent definitions, recent failure transcripts, tool list.
**Outputs**: 12-layer severity-ranked findings, code-first fixes, recovery transcripts.
**Example**: "Audit Jit's 14-agent system architecture — find pollution and repair loops."

---

## Pattern: TDD workflow enforcement
**Trigger**: Starting a new feature or bug fix; want tests-first discipline.
**Skill/Agent**: `agents/ecc/tdd-guide.md` + `/tdd-workflow`
**Inputs needed**: Feature spec or bug repro.
**Outputs**: Failing test first → minimal code → refactor; 80%+ coverage target.
**Example**: "TDD me through adding a new `workspace_apply_patch` MCP tool."

---

## Pattern: PR test-quality review
**Trigger**: A PR is up; want to check tests actually catch bugs (not just coverage theatre).
**Skill/Agent**: `agents/ecc/pr-test-analyzer.md`
**Inputs needed**: PR diff, test files added/changed.
**Outputs**: Behavioral-coverage assessment, real-bug-prevention score, missing-test list.
**Example**: "Analyze PR #123 — are its tests actually useful or just hitting lines?"

---

## Pattern: Performance optimization
**Trigger**: Slow endpoint, large bundle, render jank, suspected memory leak.
**Skill/Agent**: `agents/ecc/performance-optimizer.md`
**Inputs needed**: Profile data or symptoms, perf target.
**Outputs**: Bottleneck list, algorithmic fixes, bundle splits, memoization, async reorg.
**Example**: "/agents/ecc/performance-optimizer — why is `list_recent_tool_activity` slow?"

---

## Pattern: Database / SQL audit
**Trigger**: New migration, slow query, schema change, RLS/security concern (Postgres or Supabase).
**Skill/Agent**: `agents/ecc/database-reviewer.md`
**Inputs needed**: SQL or migration file, target Postgres version.
**Outputs**: Query optimization, index plan, RLS policy review, migration safety.
**Example**: "Review this Supabase migration for RLS + performance."

---

## Pattern: Accessibility audit
**Trigger**: New UI component or design system change; WCAG 2.2 compliance needed.
**Skill/Agent**: `agents/ecc/a11y-architect.md`
**Inputs needed**: Component code or design.
**Outputs**: WCAG violation list, fixes (ARIA, focus, contrast, keyboard), inclusive-design recommendations.
**Example**: "Audit the dashboard sidebar for WCAG 2.2 AA."

---

## Pattern: Documentation lookup (library / framework API)
**Trigger**: Need current docs for a library — not stale training-data knowledge.
**Skill/Agent**: `agents/ecc/docs-lookup.md` + `/documentation-lookup` (Context7 MCP)
**Inputs needed**: Library name + topic (e.g. "Next.js 15 server actions").
**Outputs**: Current docs excerpts + code examples, version-pinned.
**Example**: "How do I configure Pydantic v2 validators? Use docs-lookup."

---

## Pattern: Documentation / codemap refresh
**Trigger**: After a chunky refactor, READMEs and codemaps are stale.
**Skill/Agent**: `agents/ecc/doc-updater.md`
**Inputs needed**: Repo path, scope (full or module).
**Outputs**: Refreshed `docs/CODEMAPS/*`, updated READMEs, guide regeneration.
**Example**: "Refresh codemaps after the agents/ refactor."

---

## Pattern: Code exploration (understand before changing)
**Trigger**: Need to modify an unfamiliar feature; high blast radius.
**Skill/Agent**: `agents/ecc/code-explorer.md`
**Inputs needed**: Feature name or entry-point file.
**Outputs**: Execution-path trace, architecture-layer map, dependency list.
**Example**: "Explore the heartbeat daemon path before I touch it."

---

## Pattern: Code architecture design (blueprint before build)
**Trigger**: New feature spec is solid; need a concrete implementation blueprint matching existing patterns.
**Skill/Agent**: `agents/ecc/code-architect.md`
**Inputs needed**: Feature spec, repo path.
**Outputs**: File list, interfaces, data flow, build order — blueprint ready for an executor agent.
**Example**: "Design the file structure for the new ECC bridge skill."

---

## Pattern: Code comment health check
**Trigger**: Codebase has stale or contradictory comments; high comment-rot risk.
**Skill/Agent**: `agents/ecc/comment-analyzer.md`
**Inputs needed**: Files or whole module.
**Outputs**: Stale/wrong/redundant comment list with fix suggestions.
**Example**: "Audit comments in `daemons/` — flag anything that contradicts the code."

---

## Pattern: Type design audit
**Trigger**: Types feel weak — `any` everywhere, business rules in if-statements instead of type definitions.
**Skill/Agent**: `agents/ecc/type-design-analyzer.md`
**Inputs needed**: TS / Python / Rust file.
**Outputs**: Encapsulation gaps, invariants that should be types, usefulness ratings.
**Example**: "Audit `models/session.ts` — are invariants actually enforced?"

---

## Pattern: E2E test orchestration
**Trigger**: Need to add or maintain E2E coverage of a critical user flow.
**Skill/Agent**: `agents/ecc/e2e-runner.md`
**Inputs needed**: User journey spec, app URL, target browser.
**Outputs**: Playwright/Vercel Agent Browser journey, flaky-test quarantine, artifact uploads.
**Example**: "Add an E2E for the /gui workspace_apply_patch flow."

---

## Pattern: Decision — regex vs LLM for parsing
**Trigger**: Parsing structured text and unsure whether to use regex or an LLM call.
**Skill/Agent**: `/regex-vs-llm-structured-text`
**Inputs needed**: Sample inputs, accuracy target, cost budget.
**Outputs**: Decision: start with regex; escalate to LLM only on low-confidence regex misses (hybrid pattern).
**Example**: "Parsing git commit messages for type/scope — regex or LLM?"

---

## Pattern: Backend / service-layer patterns
**Trigger**: Building backend service; want repo/service split, N+1 prevention, caching, async, middleware done right.
**Skill/Agent**: `/backend-patterns`
**Inputs needed**: Framework (Node/Express, Next.js API routes), domain.
**Outputs**: Layer structure, common pitfalls avoided, middleware pattern.
**Example**: "Set up the backend layout for a new Next.js API route handling auth."

---

## Pattern: Harness tuning (local agent harness throughput / cost)
**Trigger**: Local agent harness (Claude Code or innova-bot's loop) feels slow or expensive.
**Skill/Agent**: `agents/ecc/harness-optimizer.md` + `/agent-harness-construction`
**Inputs needed**: Current harness config, recent run logs, target metric (latency, $, completion rate).
**Outputs**: Tool definition tweaks, observation-format changes, action-space reduction.
**Example**: "Optimize the maw harness — completion rate is 60%, want 80%."

---

## Pattern: Security review (auth/secrets/payment)
**Trigger**: Adding authentication, handling user input, working with secrets, API endpoints, payment.
**Skill/Agent**: `/security-review`
**Inputs needed**: Feature scope, sensitive data inventory.
**Outputs**: Comprehensive security checklist, secure-pattern recommendations, common-vuln list.
**Example**: "/security-review — before merging the new payment integration."

---

## Pattern: Network architecture
**Trigger**: Designing enterprise or multi-site network from requirements (routing, validation, automation).
**Skill/Agent**: `agents/ecc/network-architect.md`
**Inputs needed**: Site list, traffic patterns, security domain map.
**Outputs**: Routing plan, validation procedure, automation hooks, troubleshooting matrix.
**Example**: "Design the network for a 3-site MDES branch rollout."

---

## Pattern: Code simplification (clarity refactor)
**Trigger**: Code works but reads like spaghetti; tests pass; want clearer code without changing behavior.
**Skill/Agent**: `agents/ecc/code-simplifier.md`
**Inputs needed**: Module or recently-modified file.
**Outputs**: Simpler code (renames, extract method, dead-code removal) preserving behavior.
**Example**: "Simplify `psi/lib.sh` — keep behavior, improve readability."

---

## Closing Notes

- **Default to Trigger-match**: don't memorize all 35 patterns — just look up by trigger keyword.
- **Skills vs agents**: skills are recipes (markdown + scripts); agents are sub-Claudes with tool access. Some patterns combine both (e.g. /tdd-workflow skill + tdd-guide agent).
- **Sister index**: see `AGENT_INDEX.md` for one-liner-per-agent and the quick triage table.
- **Future**: PHASE 2 worker will mirror these patterns into `innova-bot/docs/ECC_PATTERNS.md` framed in body/MCP context.

**Pattern count**: 35 (target was ≥20 — exceeded by design to cover all ECC capability areas).
