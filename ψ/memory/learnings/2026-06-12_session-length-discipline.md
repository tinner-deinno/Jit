---
name: session-length-discipline
description: Sessions > 4h have diminishing returns from context bloat; oracle disambiguation prevents mis-execution
metadata:
  type: feedback
---

# Session Length Discipline + Oracle Disambiguation

**Rule**: Cap sessions at ~4 hours. Run `/forward` after 3-4h even mid-task.

**Why**: 28h marathon session produced 2.2MB JSONL but only 2 small commits to Jit. Context fatigue + retrieval overhead hurt output ratio. Short sessions with clean handoffs outperform marathons.

**How to apply**:
- At 3h mark: check progress → if blocked or spinning, `/forward` now
- At 4h mark: always `/forward`, start fresh
- Good output ratio: ≥1 meaningful commit per 90min of active work

---

**Rule**: When innova says "oracle" → ask which oracle first.

**Why**: Confusion between arra-oracle (DB), oracle-office/fleet (service), oracle-pattern (the-oracle GitHub pattern), and oracle-prism (skill) caused mis-execution (opened wrong thing) in marathon session.

**How to apply**:
- "oracle" alone → clarify: arra-oracle? oracle-office? oracle-pattern?
- If context makes it obvious (e.g., user just linked GitHub), no need to ask

[[playwright-visual-qa-dev-debug]]
