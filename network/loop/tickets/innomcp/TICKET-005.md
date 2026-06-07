# TICKET-005: Memory-Symmetry Check for Thai-Tokens
**Team**: innomcp
**Status**: pending
**Owner**: Jit (จิต) — Mother Orchestrator
**Priority**: P2
**Cycle assigned**: 176

## Goal
Verify that Thai tokens stored in `ψ/memory/` and `Oracle` (Arra Oracle V3) are byte-equal on read/write — i.e., no encoding corruption when storing Thai strings through the bus / Oracle pipeline.

## Steps
1. Pick 10 known Thai phrases (จิต, มนุษย์, อวัยวะ, กาย, วิญญาณ, สมาธิ, ปัญญา, ศีล, กรุงเทพมหานคร, สวัสดีครับ).
2. Write each to `ψ/memory/test-symmetry.json` via `limbs/oracle.sh learn` (or the equivalent memory write).
3. Read back via `limbs/oracle.sh search` and compare byte-by-byte.
4. If mismatch, log to `ψ/memory/learnings/memory-symmetry-failures.md` with line + offset of the divergence.
5. Test the path: write → bus → Oracle → search → return.

## Acceptance
- 10/10 Thai phrases round-trip byte-equal.
- No UTF-8 BOM, no NFC/NFD normalization drift.
- Test added to `eval/soul-check.sh`.

## Confidence: 70
