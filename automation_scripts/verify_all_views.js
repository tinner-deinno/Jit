const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ARTIFACT_DIR = 'C:/Users/USER-NT/.gemini/antigravity/brain/06706a0f-a0d9-41e0-8772-f54d977a2d6b';

const viewsToTest = [
  { name: 'live', label: 'Live Workspace', selector: '[data-center-view="live"]' },
  { name: 'chat', label: 'Chat', selector: '[data-center-view="chat"]' },
  { name: 'devide', label: 'Dev IDE', selector: '[data-center-view="devide"]' },
  { name: 'monitoring', label: 'Dashboard', selector: '[data-center-view="monitoring"]' },
  { name: 'agents', label: 'AI Swarm & Tokens', selector: '[data-center-view="agents"]' },
  { name: 'activity', label: 'Activity', selector: '[data-center-view="activity"]' },
  { name: 'stream', label: 'Raw Stream', selector: '[data-center-view="stream"]' },
  { name: 'telemetry', label: 'Telemetry', selector: '[data-center-view="telemetry"]' },
  { name: 'network', label: 'Agent Network', selector: '[data-center-view="network"]' },
  { name: 'project-progress', label: 'Project Progress', selector: '[data-center-view="project-progress"]' },
  { name: 'starmap', label: 'Agent Map', selector: '[data-starmap-view="starmap"]' },
  { name: 'knowledge-universe', label: 'Knowledge Universe', selector: '[data-starmap-view="knowledge"]' },
  { name: 'mcp-manager', label: 'MCP Manager', selector: '[data-starmap-view="mcp"]' },
  { name: 'reference-repos', label: 'Reference Repos', selector: '[data-starmap-view="references"]' },
  { name: 'knowledge', label: 'MCP Knowledge', selector: '[data-center-view="knowledge"]' },
  { name: 'insights', label: 'Insights', selector: '[data-center-view="insights"]' }
];

(async () => {
  console.log('Launching browser...');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  // Set viewport to standard desktop size
  await page.setViewportSize({ width: 1280, height: 800 });

  console.log('Navigating to http://127.0.0.1:7010/gui ...');
  await page.goto('http://127.0.0.1:7010/gui');
  await page.waitForTimeout(1000);

  // Collect console errors
  const consoleErrors = [];
  page.on('pageerror', err => {
    consoleErrors.push(err.toString());
  });

  const reports = [];

  for (const view of viewsToTest) {
    console.log(`Testing View: ${view.label} ...`);
    
    // Expand accordion groups if needed
    const navLink = await page.$(view.selector);
    if (!navLink) {
      console.warn(`Warning: Navigation link for ${view.label} not found!`);
      continue;
    }

    // Determine parent nav group to expand it if collapsed
    const parentGroup = await page.evaluate(el => {
      const groupEl = el.closest('.nav-group');
      if (groupEl) {
        const toggle = groupEl.querySelector('.nav-group__toggle');
        if (toggle && toggle.getAttribute('aria-expanded') !== 'true') {
          toggle.click();
          return groupEl.getAttribute('data-nav-group');
        }
      }
      return null;
    }, navLink);
    
    if (parentGroup) {
      await page.waitForTimeout(300);
    }

    // Click the menu link
    await page.click(view.selector);
    await page.waitForTimeout(1000); // Wait for transitions and load

    // Take screenshot of the view
    const screenshotPath = path.join(ARTIFACT_DIR, `view_${view.name}.png`);
    await page.screenshot({ path: screenshotPath });
    console.log(`Saved screenshot to ${screenshotPath}`);

    // Analyze layout and active cards
    const layoutInfo = await page.evaluate(() => {
      const centerCards = Array.from(document.querySelectorAll('.layout-col--center .card'));
      return centerCards.map(card => {
        const computed = window.getComputedStyle(card);
        return {
          id: card.id,
          classes: Array.from(card.classList),
          display: computed.display,
          height: computed.height,
          isVisibleClass: card.classList.contains('is-visible')
        };
      });
    });

    reports.push({
      view: view.label,
      cards: layoutInfo
    });
  }

  console.log('\n=== LAYOUT VALIDATION REPORT ===');
  reports.forEach(report => {
    console.log(`\nView: ${report.view}`);
    const visibleCards = report.cards.filter(c => c.display !== 'none');
    console.log('  Visible Cards:');
    if (visibleCards.length === 0) {
      console.log('    (None - possible error)');
    } else {
      visibleCards.forEach(c => {
        console.log(`    - #${c.id} (classes: ${c.classes.join(', ')}, height: ${c.height})`);
      });
    }

    // Detect if more than one center-content card is visible (excluding command deck/chat special combined layout in 'live' view)
    const primaryVisible = visibleCards.filter(c => c.id !== 'panelCommandDeck');
    if (primaryVisible.length > 1 && report.view !== 'Live Workspace') {
      console.warn(`  [WARNING] Layout anomaly: Multiple primary cards are visible simultaneously!`);
    } else {
      console.log(`  [OK] Single main panel layout is correct.`);
    }
  });

  if (consoleErrors.length > 0) {
    console.log('\n=== CONSOLE ERRORS DETECTED ===');
    consoleErrors.forEach(err => console.error(`  - ${err}`));
  } else {
    console.log('\n[OK] No browser console errors detected.');
  }

  await browser.close();
  console.log('Browser closed.');
})().catch(err => {
  console.error('Execution failed:', err);
  process.exit(1);
});
