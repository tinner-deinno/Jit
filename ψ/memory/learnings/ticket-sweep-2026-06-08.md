---
name: ticket-sweep-2026-06-08
description: Backlog scan + classification สำหรับ "Ticket Sweep Storm" — Phase 1 result, 2026-06-08
metadata:
  type: learning
  created: 2026-06-08
  scope: cross-project
  concepts: [backlog, sweep, multi-agent, routing, ticket-management]
---

# Ticket Sweep Storm — Phase 1: Scan Result

**Date**: 2026-06-08  
**Orchestrator**: jit (จิต)  
**SA**: lak (หลัก)  
**PA**: vaja (วาจา)  
**Human approval**: innova (Full storm + Soft archive in ψ/)

## Scope Inventory (scan result)

### Source A — reports/ (17 JSON files, ~140KB total)
| File | Category | Priority | Action |
|------|----------|----------|--------|
| `task-completion.json` (14:00) | Old task #1 | LOW | Archive |
| `task-completion-4.json` (14:01) | Old task #4 | LOW | Archive |
| `task-completion-8.json` (14:03) | Old task #8 | LOW | Archive |
| `task-completion-12.json` (14:07) | Old task #12 | LOW | Archive |
| `code-review-001-security-quality.json` (14:27) | Merged JIT-011 evidence | LOW | Archive |
| `code-review-004-quick.json` (14:30) | Latest review | **KEEP** | — |
| `JIT-006-VALIDATION-TASK.json` (14:01) | Merged JIT-006 evidence | LOW | Archive |
| `JIT-006-analysis.json` (13:50) | Merged JIT-006 evidence | LOW | Archive |
| `JIT-020-TEST-RESULTS.json` (14:20) | Merged JIT-020 evidence | LOW | Archive |
| `jit011_test_report.json` (14:21) | Merged JIT-011 evidence | LOW | Archive |
| `doc-task-2-completion.json` (14:21) | Old doc | LOW | Archive |
| `doc-task-6-completion.json` (14:24) | Old doc | LOW | Archive |
| `doc-task-8-completion.json` (14:26) | Old doc | LOW | Archive |
| `integration-test-5-codex.json` (14:35) | Latest test | **KEEP** | — |

### Source B — eval/ (14 files, 100KB)
- 5 ของ JIT-006 (DELIVERY-SUMMARY, QUICK-REF, README, TEST-SUMMARY, test-plan) — **Archive** (merged evidence)
- 9 scripts (`body-check.sh`, `health-monitor.sh`, `soul-check.sh`, `security-check.sh`, `integration-test-*.sh`, `provider-latency-test.sh`, `monitor.sh`, `test-hermes-discord.sh`) — **Keep** (operational)
- 1 newest `provider-latency-test.sh` (14:30) — **Keep**

### Source C — Bus inboxes (15 agents, P1+P2 messages)
- **Stale priority messages** ค้างตั้งแต่ 11:58 (3+ ชม.) ใน: jit, soma, lak, neta, vaja, chamu
- **DLQ**: ว่าง (threshold=10, ไม่มี items)
- **innova + netra**: มี recent `.msg` files (14:35+) — live traffic ไม่แตะ

### Source D — GitHub Issues
- **Open issues: 0** (clean repo)

## Total Items: 30 (15 reports archive + 9 ops-keep + 6 bus stale + 0 gh)

## Resource Budget
- **CPU**: 2 cores, load 6.78 (overloaded!)
- **RAM**: 3.0Gi available of 7.8Gi
- **LLM concurrency cap**: 6 (from `config/providers.json`)
- **Strategy**: Auto-scale batches default 10, ramp 20 if CPU<60%, drop 5 if CPU>80%

## Routing Plan (Phase 2)
| Group | Items | Provider | Agent | Why |
|-------|-------|----------|-------|-----|
| A. Security/critical | 0 (already merged) | — | — | — |
| B. Code review | 1 (`code-review-004-quick`) | claude/sonnet | neta | Already reviewed, just keep |
| C. Doc/report archive | ~15 reports | claude/haiku | mue | Cheap, mechanical |
| D. Bus cleanup | 6 stale P1/P2 | claude/haiku | lung | Purifier role |
| E. Eval ops verification | 9 scripts | ollama/gemma4:e4b | chamu | Quick smoke test |
