---
name: innova-gui-visual-verifier
description: >-
  Automate and verify layout stability, cyber-aesthetics, and tab navigation on the Innova-bot Web GUI using Playwright.
---

# Innova GUI Visual Verifier

## Overview
This skill allows JIT and Antigravity sub-agents to perform visual regression testing, tab navigation checks, and layout validation on the Innova-bot Web GUI dashboard (`http://127.0.0.1:7010/gui`).

## Dependencies
- Playwright (`chromium` driver)
- Node.js runtime environment

## Quick Start
Run the layout verification suite directly from the command line:
```bash
node C:/Users/USER-NT/Jit/automation_scripts/verify_all_views.js
```

## Utility Scripts
The script [verify_all_views.js](file:///C:/Users/USER-NT/Jit/automation_scripts/verify_all_views.js) performs the following operations:
1. Launches a headless Chromium browser instance.
2. Navigates to `http://127.0.0.1:7010/gui`.
3. Iterates through all 16 navigation links (Live, Chat, Dev IDE, StarMap suite, etc.).
4. Checks computed styles to guarantee that only one primary panel is visible at a time (`display !== 'none'`).
5. Saves visual screenshots for each view in the app data directory: `C:/Users/USER-NT/.gemini/antigravity/brain/06706a0f-a0d9-41e0-8772-f54d977a2d6b/view_{name}.png`.
6. Prints a JSON layout validation report.

## Workflow

### 1. Pre-requisites
- Ensure the Innova-bot API web server is running locally on port `7010`.
- Verify Node.js is on PATH by running `node --version`.

### 2. Running Verification
- Run the command: `node C:/Users/USER-NT/Jit/automation_scripts/verify_all_views.js`
- Capture the stdout test suite output.
- Check if there are any layout warnings indicating multiple cards are visible at once (outside of the allowed Live workspace exception).

### 3. Reviewing Results
- Inspect the generated PNG screenshots in the conversation artifact directory to manually verify colors, glassmorphism, and borders.
- Check the log for browser console errors.

## Common Mistakes
- **Server Offline**: Running the verification script without starting the Python SSE server on port `7010` first (causes connection timeouts).
- **Cache-Busting Missing**: Modifying CSS/JS static files without appending cache-busting version strings (e.g. `?v=1.0.5`) in `index.html`, leading to browsers loading old styles.
