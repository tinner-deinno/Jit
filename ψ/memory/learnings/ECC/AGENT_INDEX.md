## ECC Agent Index — 36 Agents

**Source**: github.com/affaan-m/ECC v2.0.0-rc.1
**Installed at**: `C:\Users\admin\.claude\agents\ecc\` (LIVE — auto-spawnable)
**Indexed by**: Phase 1 worker (Sonnet 4.6) — 2026-05-19
**Cross-ref**: `PATTERNS.md` (when-to-use), `../2026-05-19_jarvis-plus-capabilities.md` (impact matrix)

> Format: `agent-name` — one-line capability — `path`

---

### Code Review (language-specific)

1. **python-reviewer** — PEP 8, Pythonic idioms, type hints, security, performance. MUST USE for all `.py` changes. — `~/.claude/agents/ecc/python-reviewer.md`
2. **typescript-reviewer** — Type safety, async correctness, Node/web security, idiomatic TS/JS. MUST USE for all `.ts/.js`. — `~/.claude/agents/ecc/typescript-reviewer.md`
3. **rust-reviewer** — Ownership, lifetimes, error handling, unsafe usage, idiomatic Rust. MUST USE for `.rs`. — `~/.claude/agents/ecc/rust-reviewer.md`
4. **go-reviewer** — Idiomatic Go, concurrency, error handling, performance. MUST USE for `.go`. — `~/.claude/agents/ecc/go-reviewer.md`
5. **java-reviewer** — Spring Boot + Quarkus, JPA/Panache, MongoDB, security, concurrency. Auto-detects framework. — `~/.claude/agents/ecc/java-reviewer.md`
6. **kotlin-reviewer** — Idiomatic Kotlin, coroutine safety, Compose, KMP, Android pitfalls. — `~/.claude/agents/ecc/kotlin-reviewer.md`
7. **swift-reviewer** — Protocol-oriented design, value semantics, ARC, Swift Concurrency. — `~/.claude/agents/ecc/swift-reviewer.md`
8. **csharp-reviewer** — .NET conventions, async patterns, nullable refs, security, performance. — `~/.claude/agents/ecc/csharp-reviewer.md`
9. **cpp-reviewer** — Memory safety, modern C++, concurrency, performance. — `~/.claude/agents/ecc/cpp-reviewer.md`

### Framework Review

10. **django-reviewer** — Django ORM correctness, DRF patterns, migration safety, security misconfigs. MUST USE for Django. — `~/.claude/agents/ecc/django-reviewer.md`
11. **fastapi-reviewer** — Async correctness, DI, Pydantic schemas, OpenAPI quality, production readiness. — `~/.claude/agents/ecc/fastapi-reviewer.md`

### Generic / Cross-language Review

12. **code-reviewer** — Generic code review for quality, security, maintainability. Use immediately after writing code. — `~/.claude/agents/ecc/code-reviewer.md`
13. **code-simplifier** — Simplifies for clarity/consistency/maintainability while preserving behavior. — `~/.claude/agents/ecc/code-simplifier.md`
14. **comment-analyzer** — Audits comments for accuracy, completeness, comment-rot risk. — `~/.claude/agents/ecc/comment-analyzer.md`
15. **type-design-analyzer** — Audits type design for encapsulation, invariants, usefulness. — `~/.claude/agents/ecc/type-design-analyzer.md`
16. **silent-failure-hunter** — Reviews for swallowed errors, bad fallbacks, missing error propagation. — `~/.claude/agents/ecc/silent-failure-hunter.md`

### Architecture & Planning

17. **architect** — System design, scalability, technical decision-making. Use PROACTIVELY for new features/refactors. — `~/.claude/agents/ecc/architect.md`
18. **code-architect** — Designs feature architectures by analyzing existing patterns → implementation blueprints. — `~/.claude/agents/ecc/code-architect.md`
19. **code-explorer** — Deeply analyzes existing features by tracing execution + mapping layers + dependencies. — `~/.claude/agents/ecc/code-explorer.md`
20. **planner** — Expert planning for complex features and refactoring. Auto-activated for planning tasks. — `~/.claude/agents/ecc/planner.md`
21. **network-architect** — Enterprise/multi-site network architecture from requirements. — `~/.claude/agents/ecc/network-architect.md`
22. **a11y-architect** — WCAG 2.2 accessibility for Web/Native; design systems and inclusive UX audit. — `~/.claude/agents/ecc/a11y-architect.md`

### Build / Runtime Resolvers

23. **build-error-resolver** — Build + TypeScript error fixer; minimal diffs only, no architectural edits. — `~/.claude/agents/ecc/build-error-resolver.md`
24. **pytorch-build-resolver** — PyTorch runtime/CUDA/training errors — tensor shapes, devices, gradients, DataLoader, AMP. — `~/.claude/agents/ecc/pytorch-build-resolver.md`

### Performance / Database

25. **performance-optimizer** — Bottlenecks, slow code, bundles, runtime perf, profiling, memory leaks, algos. — `~/.claude/agents/ecc/performance-optimizer.md`
26. **database-reviewer** — PostgreSQL query optimization, schema design, security, perf. Supabase best practices. — `~/.claude/agents/ecc/database-reviewer.md`

### Testing

27. **tdd-guide** — Test-Driven Development enforcer; 80%+ coverage; tests-first methodology. — `~/.claude/agents/ecc/tdd-guide.md`
28. **e2e-runner** — E2E specialist using Vercel Agent Browser (Playwright fallback); journeys, quarantine, artifacts. — `~/.claude/agents/ecc/e2e-runner.md`
29. **pr-test-analyzer** — Reviews PR test coverage quality with focus on behavioral coverage + real-bug prevention. — `~/.claude/agents/ecc/pr-test-analyzer.md`

### GAN Autonomous Trio + Loop Control

30. **gan-planner** — GAN Harness Planner: expands one-line prompt → full spec (features, sprints, eval criteria, design). — `~/.claude/agents/ecc/gan-planner.md`
31. **gan-generator** — GAN Harness Generator: implements per spec, reads evaluator feedback, iterates until threshold. — `~/.claude/agents/ecc/gan-generator.md`
32. **gan-evaluator** — GAN Harness Evaluator: tests live app via Playwright, scores against rubric, gives actionable feedback. — `~/.claude/agents/ecc/gan-evaluator.md`
33. **loop-operator** — Operates autonomous loops, monitors progress, intervenes safely when loops stall. — `~/.claude/agents/ecc/loop-operator.md`

### Meta / Harness / Docs

34. **harness-optimizer** — Analyzes + improves the local agent harness for reliability, cost, throughput. — `~/.claude/agents/ecc/harness-optimizer.md`
35. **doc-updater** — Documentation + codemap specialist; runs `/update-codemaps` and `/update-docs`. — `~/.claude/agents/ecc/doc-updater.md`
36. **docs-lookup** — Fetches up-to-date docs via Context7 MCP for library/framework/API questions. — `~/.claude/agents/ecc/docs-lookup.md`

---

## Quick Triage Table

| Situation | Agent |
|-----------|-------|
| Just wrote Python code | python-reviewer |
| Just wrote TS/JS | typescript-reviewer |
| Build is broken | build-error-resolver |
| PyTorch crashed mid-train | pytorch-build-resolver |
| New feature, no spec | planner → code-architect |
| Existing code is mystery | code-explorer |
| Code works but ugly | code-simplifier |
| Errors being swallowed | silent-failure-hunter |
| Slow endpoint / heavy bundle | performance-optimizer |
| New SQL/migration | database-reviewer |
| Adding tests | tdd-guide → pr-test-analyzer |
| UI flow regression | e2e-runner |
| One-liner → product | gan-planner → gan-generator → gan-evaluator |
| Long autonomous run | loop-operator (supervises) |
| Bad comments | comment-analyzer |
| Weak types | type-design-analyzer |
| WCAG audit | a11y-architect |
| Library API question | docs-lookup |
| Stale docs/codemaps | doc-updater |
| Harness cost spiking | harness-optimizer |

---

**Total**: 36 agents (verified count via `ls ~/.claude/agents/ecc/`)
**License**: Inherited from ECC (MIT, per upstream repo)
**Activation**: Subagents auto-discover via Claude Code agent registry — no manual wiring required.
