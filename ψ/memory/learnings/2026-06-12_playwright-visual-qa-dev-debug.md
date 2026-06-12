---
name: playwright-visual-qa-dev-debug
description: Visual QA ด้วย Playwright headless + CSS sticky bug + Turbopack cache pitfall
metadata:
  type: feedback
---

# Visual QA + Dev Debug Lessons (2026-06-12)

**Rule**: Visual QA is non-negotiable. `tsc --noEmit PASS` does NOT mean UI works.

**Why**: Playwright headless found 3 real bugs invisible to type checker:
1. Turbopack stale cache — old server serving old bundle (MDESBrandHeader not loaded)
2. `overflow-x-hidden` breaking `position: sticky` on all descendants
3. Duplicate empty state content (old + new stacked, page 2000px tall)

**How to apply**:
- After every significant UI change: `pnpm dev` fresh (kill old server first) → Playwright screenshot
- Kill old Node server: `taskkill /F /IM node.exe` (Windows) then verify port free
- Check headers: `totalHeaders` should match expected count
- Check sticky: verify `getBoundingClientRect().top === 0` after scroll for sticky elements

**CSS Sticky + overflow**:
`overflow: hidden` or `overflow-x: hidden` on ANY ancestor breaks `position: sticky` on descendants.
Fix: remove overflow from parent, OR use `position: fixed` instead.

**Turbopack cache**:
If MDESBrandHeader in source but `totalHeaders: 1` in browser → server is stale.
Always `rm -rf .next && pnpm dev` after major file changes.
