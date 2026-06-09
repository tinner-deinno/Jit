---
query: "token efficiency RTK optimization patterns"
target: "Jit (จิต) Oracle"
mode: smart
timestamp: 2026-06-08 18:41
friction_score: 0.85
coverage: [oracle, files, git, cross-repo]
confidence: high
---

# Trace: Token Efficiency + RTK Optimization Patterns

**Target**: Jit (จิต) Oracle  
**Mode**: Smart (Oracle first + files)  
**Friction**: 0.85 (visible but dispersed)  
**Confidence**: High — comprehensive answer found  
**Time**: 2026-06-08 18:41

---

## Oracle Results

### Core Principles (Philosophy Level)
- **Source**: `/ψ/memory/resonance/principles.md`
- **Principle 5 (ปัญญา/Wisdom)**: "Query Oracle before decisions, maximize token efficiency"
- **Integration**: Token efficiency embedded in Buddhist principle framework (ศีล·สมาธิ·ปัญญา)
- **Rule**: "Never verbose, batch reads before writes, use Ollama only for creative Thai tasks"

### Brain Framework
- **Source**: `/brain/reasoning.md`
- **Token Efficiency Rules** (explicit):
  - ตอบตรงประเด็น ไม่ verbose
  - ใช้ Ollama เฉพาะงานที่ต้องการ creative Thai
  - อย่า call API ซ้ำโดยไม่จำเป็น
  - batch reads ก่อน batch writes
- **Think-before-act**: UNDERSTAND → QUERY Oracle → PLAN reversible → EXECUTE → LEARN

### Decision Criteria Table
- Thai language tasks → MDES Ollama (token-efficient for localization)
- Code/logic → Direct Copilot (claude-sonnet-4.6, haiku for specialists)
- Knowledge queries → Oracle first (expensive queries cached, avoid re-querying)
- Destructive actions → User approval (prevent token waste on rollbacks)

---

## RTK Integration (Rust Token Killer)

### Location
- **Installation**: Global tool (`~/.claude/RTK.md`)
- **Purpose**: 60-90% token savings on dev operations
- **Hook-based**: Transparent rewriting (`git status` → `rtk git status`, 0 overhead)

### Key Commands
```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

### Integration Model
- **Automatic**: All commands rewritten by Claude Code hook (except when explicitly using `rtk proxy`)
- **Philosophy**: Token-optimized CLI proxy — reduces context size, batches operations
- **Coverage**: Applies to git, bash, build commands globally

---

## Multi-Provider LLM Gateway (llm.sh)

### Location
- **File**: `/limbs/llm.sh` (16KB, comprehensive)
- **Model**: Multi-provider (Claude, OpenAI, Ollama) with per-agent fallback chains
- **Purpose**: Token-efficient provider rotation and model selection

### Token Optimization Patterns
1. **Provider Fallback Chain**: Each agent has a candidate chain (claude → openai → ollama)
   - Primary provider fails → automatically tries fallback (no user intervention needed)
   - Prevents expensive re-prompting on transient failures

2. **Model Right-Sizing**:
   - Haiku (4.5) for Tier 3 specialists (10 agents) — **60-80% cheaper than Sonnet**
   - Sonnet (4.6) for Tier 2 core engineers (3 agents)
   - Opus (4.7) for soma only (strategic decisions)

3. **Per-Agent Provider Map**:
   ```json
   "agents": {
     "haiku-specialist": {"provider": "claude", "model": "haiku", "fallback": ["openai/gpt-4o-mini", "ollama/gemma4"]},
     "soma": {"provider": "claude", "model": "opus", "fallback": ["claude/sonnet"]}
   }
   ```

### Usage
```bash
bash limbs/llm.sh call "prompt" --agent soma                  # Route via soma's config
bash limbs/llm.sh call "fix bug" --provider ollama --model gemma4:26b
bash limbs/llm.sh providers                                   # Health check all providers
bash limbs/llm.sh chain <agent>                               # Show fallback strategy
```

---

## Prompt Proxy (prompt_proxy.sh)

### Token Efficiency Technique
- **Model Selection**: Heuristic complexity detection (word count threshold = 50)
  - Simple prompts (< 50 words) → Haiku (cheaper)
  - Complex prompts (≥ 50 words) → Sonnet (more capable)

- **Structured Prompt Template**: [Role]/[Context]/[Task]/[Example]/[Format]
  - Enforces consistent prompt structure → better first-pass accuracy
  - Reduces hallucination → fewer correction loops → fewer tokens burned

- **"Right Speech" Principle** (สัมมาวาจา):
  - Clear, structured, concise output
  - Minimize verbose explanations

### Usage
```bash
./limbs/prompt_proxy.sh call "prompt"                    # Auto-detect model
./limbs/prompt_proxy.sh format "raw prompt"              # Show structured form
./limbs/prompt_proxy.sh route "prompt"                   # Dry-run (show model choice)
```

---

## Memory Layer Architecture (Three-Tier)

### SHORT-TERM
- VS Code Copilot context window
- Session-scoped memories

### LONG-TERM (Token Efficiency Gain)
1. **Arra Oracle V3** (localhost:47778)
   - FTS5 SQLite (keyword search)
   - LanceDB (semantic vectors)
   - Stores: patterns, principles, learnings, incident reports
   - **Benefit**: Expensive research questions answered once, indexed forever
   - Query cost: O(1) after initial index; avoids repeated prompting

2. **Persistent Local** (`ψ/` vault)
   - Synced to GitHub (not burned in context window)
   - Contains: resonance/, learnings/, retrospectives/

### Token Optimization Impact
- **First-time query**: 2000+ tokens (to generate knowledge)
- **Subsequent queries**: 100-200 tokens (to retrieve + refine)
- **ROI**: Break-even at ~5 reuses; massive savings after 20+ reuses

**Example**: Learning about "multi-agent protocol once", then queried 50+ times:
- First time: 2000 tokens
- 50 subsequent: 50 × 150 = 7500 tokens
- **vs. Re-prompting 50 times**: 50 × 2000 = 100,000 tokens
- **Savings**: 92,500 tokens (92.5% reduction)

---

## Git History Markers

Recent commits show evolution:
- **7c4eb74**: "cmdteam: provider rotation across 28-model pool + status daemon + cleanup loop"
  - Multi-provider rotation = token fallback strategy in action

- **948df39**: "🔐 Security: Fix JIT-021 token exposure via process list"
  - Token lifecycle security (prevents accidental leaks)

- **f96c9b0**: "✅ TICK-001 COMPLETE: Jit Oracle System Fully Verified & Stable"
  - Oracle stability = reliable caching layer

---

## Files Found

| File | Token Pattern | Purpose |
|------|---------------|---------|
| `/CLAUDE.md` | Framework | ปัญญา principle + RTK reference |
| `/brain/reasoning.md` | Rules | Explicit token efficiency rules |
| `/limbs/llm.sh` | Gateway | Multi-provider rotation + per-agent fallback |
| `/limbs/prompt_proxy.sh` | Structure | Model right-sizing + prompt template |
| `/memory/architecture.md` | Caching | Three-tier memory (Oracle as L1 cache) |
| `/ψ/memory/resonance/principles.md` | Philosophy | Buddhist integration of token wisdom |
| `/network/registry.json` | Config | Agent tier structure (Haiku ← Sonnet ← Opus) |

---

## Cross-Repo Patterns

**Mirror repos** under `/mirror/aoengaoey/`:
- Evidence that token optimization patterns are **ancestral** (copied from parent Oracles)
- Traces show consistent application of "RTK-like" token-saving heuristics in earlier iterations

---

## Friction Analysis

**Score**: 0.85 (Visible, well-documented, but dispersed across 7 files)

**Coverage**:
- Oracle: ✓ (principles + memory architecture)
- Files: ✓ (brain/, limbs/, ψ/memory/)
- Git: ✓ (recent commits show provider rotation)
- Cross-repo: ✓ (mirror/ shows ancestral patterns)
- GitHub issues: — (not formally tracked; embedded in commit messages)

**What Scored 0.85 (not 1.0)**:
- RTK is *documented in ~/.claude/RTK.md* but **not actively logged in Jit logs**
- No dedicated `/network/rtk-audit.md` showing current RTK usage
- Token savings analytics (`rtk gain`) not persisted to Oracle
- Multi-provider fallback chain is **in code** but not formally documented in `/docs/`

**Missing**:
- Audit trail: which agents are using which model (haiku vs sonnet)
- Metrics: actual token spending by provider/model/agent over time
- Best practices guide: "When to use Haiku vs Sonnet" decision tree

---

## Summary

### Core Patterns Found

1. **Philosophy-First**: Token efficiency is a Buddhist principle (ปัญญา), not just engineering
2. **Multi-Layer Caching**: Oracle as semantic cache → ~92% token savings after 20 queries
3. **Right-Sizing**: Haiku for specialists (cheaper), Sonnet for complex tasks (better accuracy)
4. **Fallback Chains**: If provider fails, automatically try next (prevents expensive re-prompting)
5. **Structured Prompts**: [Role]/[Context]/[Task]/[Example]/[Format] → first-pass accuracy
6. **RTK Integration**: Global hook-based token proxy (60-90% savings on CLI operations)
7. **Three-Tier Memory**: Session → Shared JSON → Oracle (persistent, indexed, cheap to retrieve)

### Next Steps

1. **Formalize**: Create `/docs/token-efficiency-guide.md` (decision tree + metrics)
2. **Audit**: Run `rtk gain --history` and log to Oracle (gaps in tracking)
3. **Metrics**: Add per-agent model usage to `/network/registry.json` (audit trail)
4. **Threshold Tuning**: Review complexity thresholds in `prompt_proxy.sh` (50-word boundary)

---

**Log created**: 2026-06-08 18:41  
**Trace by**: Claude Haiku 4.5 (Oracle + Smart Mode)  
**Next review**: Query Oracle in 2 weeks for RTK usage analytics
