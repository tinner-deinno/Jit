# Lesson: Compile-Green Is Not User-Green

**Date**: 2026-06-12 | **Session**: cde397c3 | **Context**: innomcp chat recovery

## The Lesson

A passing build (`tsc EXIT 0`, `npm run build` succeeds) is a weak signal, not proof the system
works. During innomcp recovery, an Explore subagent reported "frontend builds clean ✅" — which I
nearly wrote into the plan as "frontend fine", directly contradicting mom's lived report that
"panels fail, UI พังมาก". Compile ≠ render. Likewise, Phase 1's exit criterion "hello answered" was
satisfied by an incoherent reply ("ห้ามเดาโว้ย") — a non-empty WebSocket frame is not a working chat.

## Rules

1. **When a subagent's static analysis conflicts with the human's direct experience, the human is
   ground truth.** Investigate the contradiction; don't harmonize it away.
2. **Define "done" as user-observable**: browser renders with live data + sensible answer — not
   "it compiles" or "returned non-empty".
3. **Bulk LLM-generated code must pass a build gate before commit.** Fence markers (```ts at line 1)
   + truncation are the signature failure of raw swarm-output commits (MEGA-100).
4. **Embed real API method-lists in generation prompts** so workers can't hallucinate method names.

## Why

The whole innomcp outage was caused by optimizing for "looks generated/committed" over "actually
runs". Declaring victory on a compile or a checkbox reproduces the same anti-pattern at the review
layer. /oracle-prism (design lenses: User/Breaker) is the cheap inline tool that surfaces this —
run it on any plan whose success metric smells like "it compiles".

Related: [[project-innomcp-recovery]], [[feedback-local-first-execution]]
