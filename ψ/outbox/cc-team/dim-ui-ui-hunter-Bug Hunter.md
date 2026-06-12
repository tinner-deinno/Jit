<!-- cc-team deliverable
 group: dim-ui (Frontend UI/UX Analysis)
 member: ui-hunter role=Bug Hunter model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":50,"completion_tokens":1560,"total_tokens":1610,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":245,"image_tokens":0},"cache_creation_input_tokens":0} | 12s
 generated: 2026-06-12T10:27:37.695Z -->
## Analysis of `innomcp-next` UI/UX, Layout, and Styling Issues

I cannot directly access your local file system (`C:\Users\USER-NT\DEV\innomcp\innomcp-next`). To provide a **deep, file-specific analysis**, please share relevant code snippets or describe the issues you observe.

However, based on common patterns in Next.js projects, I can give you a **generic checklist of high‑probability issues** along with typical file locations and suggested fixes. Review your project against these items.

---

### 1. Layout Shifts (CLS – Cumulative Layout Shift)

| Symptom | Likely Cause | Affected File Examples | Suggested Fix |
|---------|--------------|------------------------|---------------|
| Page jumps when images load | Missing explicit `width`/`height` on `<Image>` or `<img>` | `components/Hero.js`, `pages/index.js` | Use Next.js `<Image>` with `width` and `height` attributes, or CSS `aspect-ratio`. |
| Flickering during CSR hydration | Unstyled content before JS loads | `pages/_app.js`, `components/Layout.js` | Add `suppressHydrationWarning` or use `next/dynamic` with `ssr: false`. |
| Font-swap causing reflow | Fallback font replaced by custom font | `pages/_document.js`, `styles/globals.css` | Use `font-display: optional` or `swap` with correct fallback sizes. |
| Ad slots / dynamic content | No reserved space for async content | `components/AdBanner.js` | Set a static `min-height` on the container. |

**Fix example for images**  
```jsx
<Image src="/hero.jpg" alt="hero" width={1200} height={600} />
```

---

### 2. Styling Inconsistencies

| Issue | Root Cause | Affected Files | Fix |
|-------|------------|----------------|-----|
| Margins/padding differ across pages | Overlapping CSS modules or global styles | `components/Button.module.css` vs `styles/Button.css` | Use a consistent design system (Tailwind, CSS custom properties). |
| Colors not matching design tokens | Hardcoded hex values | `components/Header.js`, `pages/about.js` | Define colors in a central `theme.js` or CSS variables file. |
| Responsive breakpoints misaligned | Inconsistent `@media` rules | `components/Card.module.css` | Adopt a single breakpoint map (e.g., Tailwind’s `sm:`, `md:`, `lg:`). |
| Font sizes/weights vary | Missing global typography styles | `styles/globals.css` | Set `body` font sizes and reuse `h1`–`h6` tokens. |

**Fix example**  
```css
/* globals.css */
:root {
  --color-primary: #1a73e8;
  --space-unit: 8px;
  --font-base: 16px;
}
```

---

### 3. UI/UX Bugs

| Bug | Description | Typical File | Fix |
|-----|-------------|--------------|-----|
| Button not disabled during loading | No visual or interactive feedback | `components/SubmitButton.js` | Add `disabled={loading}` and a spinner. |
| Form validation errors not clearing | Error state persists after correction | `components/LoginForm.js` | Use `onChange` to reset field errors. |
| Modal / drawer not closing on Escape | Missing keyboard listener | `components/Modal.js` | Add `useEffect` with `keydown` event listener. |
| Tooltip / popover cut off on screen edge | No overflow boundary detection | `components/Tooltip.js` | Use Popper.js or CSS `@media` adjustments. |
| Input focus outline hidden | Removing `:focus` without replacement | `components/SearchInput.js` | Keep a visible `:focus-visible` outline. |

**Fix snippet for modal**  
```jsx
useEffect(() => {
  const handleEsc = (e) => e.key === 'Escape' && close();
  window.addEventListener('keydown', handleEsc);
  return () => window.removeEventListener('keydown', handleEsc);
}, [close]);
```

---

### 4. Performance / UX Regressions

| Symptom | Cause | Files | Fix |
|---------|-------|-------|-----|
| Slow page transitions | Missing `next/link` prefetch | `components/NavLink.js` | Use `<Link prefetch={true}>` (default). |
| Spinner appears on every navigation | No Suspense boundaries | `pages/_app.js` | Wrap page content with `<Suspense fallback={...}>`. |
| Clicking back scrolls to top | Missing `scrollRestoration` | `pages/_app.js` | Apply `history.scrollRestoration = 'manual'` and store scroll positions. |

---

### 5. Accessibility (A11y) Issues

| Problem | Example File | Fix |
|---------|--------------|-----|
| Missing `alt` on images | `components/ProductCard.js` | Provide descriptive `alt` text. |
| Low contrast text | `components/Footer.js` | Check ratio ≥ 4.5:1 using WebAIM tool. |
| Button not keyboard���accessible | `components/CustomButton.js` | Add `role="button"` and `tabIndex={0}` (or use a `<button>` element). |
| Form labels missing | `components/NewsletterForm.js` | Wrap `<label>` around input or use `htmlFor`. |

---

## Next Steps

1. **Copy the above categories** and search your project for matches.
2. **Run Lighthouse** (DevTools → Audits) to detect CLS, contrast, and performance issues.
3. **Enable React Strict Mode** in `next.config.js` to surface side effects and layout problems.

If you can share specific files (e.g., `pages/index.js`, `styles/globals.css`, `components/Layout.js`), I’ll give you a **file‑by‑file, line‑by‑line analysis** with precise fixes.
