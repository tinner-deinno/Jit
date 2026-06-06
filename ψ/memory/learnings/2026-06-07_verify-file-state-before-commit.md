---
pattern: When sub-agents fail mid-task, verify actual file state from system reminders before drafting commit messages or "done" claims
date: 2026-06-07
source: rrr: innomcp (Jit)
concepts: [debugging, file-state, sub-agents, session-limits, verification]
---

# Verify File State Before Claiming Done

When multiple sub-agents fail simultaneously (e.g., hitting session rate limits), the temptation is to draft a summary of "what was supposed to happen." This is wrong.

**The rule**: before writing any commit message or completion claim after sub-agent failures, check system reminders — they show the actual file modifications that were written before the failure. Cross-reference: which changes did get written? Which didn't?

**Why it matters**: committing with a message that describes changes that never happened creates misleading git history. The diff will contradict the message. Future sessions will be confused.

**Pattern**: `system-reminder: Note: [file] was modified` = ground truth. Sub-agent output = intended truth. They differ when limits hit mid-task.

**Correct sequence**:
1. Sub-agents fail → note which ones
2. Read system reminders to see which files actually changed
3. Verify each file exists with `ls` or `grep`
4. Commit only what's confirmed written
5. Complete remaining work manually in a follow-up commit
