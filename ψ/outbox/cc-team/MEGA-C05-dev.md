<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C05 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":114,"completion_tokens":603,"total_tokens":717} | 9s
 generated: 2026-06-12T19:28:55.360Z -->
```markdown
---
name: confidence-gate
description: >
  Gate findings/actions below 80% confidence; use for code review by neta organ
  and before secret-using actions.
---

# confidence-gate

## The 80% confidence rule

Only report a finding or take an action when you are **>80% confident** it is correct.  
Manufacturing findings erodes trust faster than misses — false positives degrade the
review process and waste neta’s attention. A miss on a low-confidence item is
acceptable; a false report undermines credibility.

## How to self-estimate confidence

Use a simple mental checklist:

1. **Evidence completeness** – Do I have sufficient context? (e.g., full diff, logs, config)
2. **Consistency** – Does the pattern match known bugs or best practices?
3. **Reproducibility** – Could I explain *why* it’s a problem with concrete reasoning?
4. **Alternative explanations** – Have I ruled out benign causes?

If any of these is weak, reduce your confidence estimate by 10–20%.  
Aim for a single numeric percent (e.g., 85%) — if you hesitate, assume <80%.

## When to escalate vs. proceed

| Confidence | Action |
|------------|--------|
| >80%       | Report finding / proceed with action |
| 60–80%     | Gather more evidence; ask neta for a quick sanity check |
| <60%       | Do not report or act; silently skip or log for later triage |

For secret-using actions (e.g., rotating keys, modifying secrets), require **>90%** confidence.

## Examples

- **Good**: "I see an unvalidated redirect in `auth.go`. 90% confident — matches
  CWE-601, and the route is user-controllable."
- **Bad**: "Maybe this line is SQL injection? 70% confident." → Do not report.
- **Escalate**: "Unclear if this env var is leaked. 75% confident. Net, please verify."

## Reference: neta

Neta is the code review organ — a human (or simulated) reviewer who audits
findings. Always treat neta’s time as precious: only gate high-confidence signals.
If neta rejects a finding, lower the threshold for similar patterns next time.
```
