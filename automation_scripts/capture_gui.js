const { chromium } = require('playwright');

(async () => {
  console.log('Launching browser...');
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  console.log('Navigating to http://127.0.0.1:7010/gui ...');
  await page.goto('http://127.0.0.1:7010/gui');

  // Wait for sidebar nav group to load
  await page.waitForSelector('[data-nav-group="starmap-suite"]');

  console.log('Expanding StarMap Suite nav group...');
  await page.click('[data-nav-toggle="starmap-suite"]');
  await page.waitForTimeout(500);

  console.log('Clicking on Agent Map menu...');
  await page.click('[data-center-view="starmap"]');
  await page.waitForTimeout(1000);

  console.log('Taking screenshot of the page...');
  await page.screenshot({ path: 'C:/Users/USER-NT/.gemini/antigravity/brain/06706a0f-a0d9-41e0-8772-f54d977a2d6b/diagnostic_screenshot.png', fullPage: true });

  // Inspect the panel computed styles and classes
  const info = await page.evaluate(() => {
    const panels = ['panelChat', 'panelKnowledge', 'panelStarMap', 'panelAgents'];
    return panels.map(id => {
      const el = document.getElementById(id);
      if (!el) return { id, exists: false };
      const computed = window.getComputedStyle(el);
      return {
        id,
        exists: true,
        classes: Array.from(el.classList),
        display: computed.display,
        visibility: computed.visibility,
        height: computed.height,
        styleAttr: el.getAttribute('style')
      };
    });
  });

  console.log('DIAGNOSTICS_RESULT:');
  console.log(JSON.stringify(info, null, 2));

  await browser.close();
})().catch(err => {
  console.error('Error occurred:', err);
  process.exit(1);
});
