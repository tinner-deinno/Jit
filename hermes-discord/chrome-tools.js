'use strict';
/**
 * chrome-tools.js — Chrome DevTools Protocol wrapper for Hermes/Jit agents
 *
 * Tools: navigate · screenshot · inspectElement · getCSS · analyzeUI · runJS
 *
 * Standalone modes:
 *   node chrome-tools.js --mcp    → stdio JSON-RPC 2.0 MCP server
 *   node chrome-tools.js --http   → REST API on port 4040 (CHROME_MCP_PORT)
 *   node chrome-tools.js --test <url>
 */

const path = require('path');
const os   = require('os');

// ── Chrome executable detection ──────────────────────────────────
function findChrome() {
  const env = process.env.CHROME_PATH;
  if (env) return env;
  const candidates = {
    win32: [
      'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
      'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
      (process.env.LOCALAPPDATA || '') + '\\Google\\Chrome\\Application\\chrome.exe',
    ],
    linux: [
      '/usr/bin/google-chrome',
      '/usr/bin/chromium-browser',
      '/usr/bin/chromium',
    ],
    darwin: [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Chromium.app/Contents/MacOS/Chromium',
    ],
  };
  const list = candidates[os.platform()] || [];
  const fs = require('fs');
  for (const p of list) {
    try { if (fs.existsSync(p)) return p; } catch(_) {}
  }
  return null; // puppeteer will use bundled Chromium
}

// ── Lazy puppeteer loader ─────────────────────────────────────────
let _puppeteer = null;
function getPuppeteer() {
  if (!_puppeteer) _puppeteer = require('puppeteer');
  return _puppeteer;
}

async function launchBrowser(opts) {
  const puppeteer = getPuppeteer();
  const executablePath = findChrome();
  const launchOpts = {
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
  };
  if (executablePath) launchOpts.executablePath = executablePath;
  if (opts && opts.headless === false) launchOpts.headless = false;
  return puppeteer.launch(launchOpts);
}

// ── Core tools ────────────────────────────────────────────────────

async function navigate(targetUrl) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    const start = Date.now();
    const response = await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    const loadTime = Date.now() - start;
    const title = await page.title();
    const status = response ? response.status() : 0;
    const finalUrl = page.url();
    return { title, status, loadTime, finalUrl, url: targetUrl };
  } finally {
    await browser.close();
  }
}

async function screenshot(targetUrl) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });
    await page.goto(targetUrl, { waitUntil: 'networkidle2', timeout: 30000 });
    const title = await page.title();
    const tmpFile = path.join(os.tmpdir(), 'chrome-shot-' + Date.now() + '.png');
    await page.screenshot({ path: tmpFile, fullPage: false });
    const vp = page.viewport();
    return { title, file: tmpFile, width: vp ? vp.width : 1280, height: vp ? vp.height : 800, url: targetUrl };
  } finally {
    await browser.close();
  }
}

async function inspectElement(targetUrl, selector) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    const info = await page.evaluate(function(sel) {
      var el = document.querySelector(sel);
      if (!el) return null;
      var rect = el.getBoundingClientRect();
      return {
        tagName: el.tagName.toLowerCase(),
        id: el.id || null,
        classes: Array.from(el.classList),
        text: el.textContent.trim().slice(0, 200),
        attributes: Object.fromEntries(Array.from(el.attributes).map(function(a) { return [a.name, a.value]; })),
        rect: { top: Math.round(rect.top), left: Math.round(rect.left), width: Math.round(rect.width), height: Math.round(rect.height) },
        childCount: el.children.length,
        innerHTML: el.innerHTML.slice(0, 500),
      };
    }, selector);
    if (!info) throw new Error('Element not found: ' + selector);
    return info;
  } finally {
    await browser.close();
  }
}

async function getCSS(targetUrl, selector) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    const styles = await page.evaluate(function(sel) {
      var el = document.querySelector(sel);
      if (!el) return null;
      var cs = window.getComputedStyle(el);
      var keyProps = [
        'color', 'background-color', 'font-size', 'font-family', 'font-weight',
        'margin', 'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
        'padding', 'border', 'width', 'height', 'display',
        'position', 'top', 'left', 'z-index', 'opacity', 'transform',
        'border-radius', 'box-shadow', 'text-align', 'line-height', 'flex-direction',
      ];
      var result = {};
      keyProps.forEach(function(p) { result[p] = cs.getPropertyValue(p); });
      return result;
    }, selector);
    if (!styles) throw new Error('Element not found: ' + selector);
    return styles;
  } finally {
    await browser.close();
  }
}

async function analyzeUI(targetUrl) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1280, height: 800 });
    await page.goto(targetUrl, { waitUntil: 'networkidle2', timeout: 30000 });
    const analysis = await page.evaluate(function() {
      function countTag(tag) { return document.querySelectorAll(tag).length; }
      var bodyCS = window.getComputedStyle(document.body);
      var headings = Array.from(document.querySelectorAll('h1,h2,h3')).slice(0, 5).map(function(h) {
        return { tag: h.tagName.toLowerCase(), text: h.textContent.trim().slice(0, 80) };
      });
      var allEls = Array.from(document.querySelectorAll('*')).slice(0, 50);
      var colors = allEls.map(function(el) {
        return window.getComputedStyle(el).backgroundColor;
      }).filter(function(c) { return c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent'; });
      var uniqueColors = Array.from(new Set(colors)).slice(0, 10);
      var descMeta = document.querySelector('meta[name=description]');
      return {
        title: document.title,
        description: descMeta ? descMeta.content : '',
        viewport: { width: window.innerWidth, height: window.innerHeight },
        stats: {
          headings: countTag('h1,h2,h3,h4,h5,h6'),
          links: countTag('a'),
          images: countTag('img'),
          forms: countTag('form'),
          buttons: countTag('button,[type=submit]'),
          paragraphs: countTag('p'),
          inputs: countTag('input,textarea,select'),
        },
        topHeadings: headings,
        dominantColors: uniqueColors,
        bodyFont: bodyCS.fontFamily,
        bodyBackground: bodyCS.backgroundColor,
        bodyColor: bodyCS.color,
      };
    });
    return analysis;
  } finally {
    await browser.close();
  }
}

async function runJS(targetUrl, script) {
  const browser = await launchBrowser();
  try {
    const page = await browser.newPage();
    await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    // eslint-disable-next-line no-new-func
    const result = await page.evaluate(new Function('return (' + script + ')'));
    return { result, type: typeof result };
  } finally {
    await browser.close();
  }
}

// ── Callback wrappers (for bot.js CommonJS compatibility) ─────────
function wrapAsync(fn, callback) {
  fn().then(function(r) { callback(null, r); }).catch(function(e) { callback(e); });
}

module.exports = {
  navigate:       function(url, cb) { wrapAsync(function() { return navigate(url); }, cb); },
  screenshot:     function(url, cb) { wrapAsync(function() { return screenshot(url); }, cb); },
  inspectElement: function(url, sel, cb) { wrapAsync(function() { return inspectElement(url, sel); }, cb); },
  getCSS:         function(url, sel, cb) { wrapAsync(function() { return getCSS(url, sel); }, cb); },
  analyzeUI:      function(url, cb) { wrapAsync(function() { return analyzeUI(url); }, cb); },
  runJS:          function(url, script, cb) { wrapAsync(function() { return runJS(url, script); }, cb); },
};

// ── Standalone server modes ───────────────────────────────────────
if (require.main === module) {
  const mode = process.argv[2];

  // ── MCP stdio mode ──────────────────────────────────────────────
  if (mode === '--mcp') {
    process.stdin.setEncoding('utf8');
    let buf = '';
    process.stdin.on('data', function(data) {
      buf += data;
      const lines = buf.split('\n');
      buf = lines.pop();
      lines.forEach(function(line) {
        if (!line.trim()) return;
        let req;
        try { req = JSON.parse(line); } catch(e) { return; }
        handleMCPReq(req);
      });
    });

    function sendMCP(obj) { process.stdout.write(JSON.stringify(obj) + '\n'); }

    async function handleMCPReq(req) {
      const id = req.id;
      const method = req.method;
      const params = req.params || {};

      if (method === 'initialize') {
        sendMCP({ jsonrpc: '2.0', id, result: {
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: { name: 'chrome-devtools-mcp', version: '1.0.0' },
        }});
        return;
      }
      if (method === 'tools/list') {
        sendMCP({ jsonrpc: '2.0', id, result: { tools: [
          { name: 'chrome_navigate',    description: 'Open URL in Chrome — returns title, status, loadTime', inputSchema: { type: 'object', properties: { url: { type: 'string', description: 'Target URL' } }, required: ['url'] } },
          { name: 'chrome_screenshot',  description: 'Take screenshot of URL — saves to temp file', inputSchema: { type: 'object', properties: { url: { type: 'string' } }, required: ['url'] } },
          { name: 'chrome_inspect',     description: 'Inspect DOM element by CSS selector', inputSchema: { type: 'object', properties: { url: { type: 'string' }, selector: { type: 'string' } }, required: ['url', 'selector'] } },
          { name: 'chrome_css',         description: 'Get computed CSS styles for element', inputSchema: { type: 'object', properties: { url: { type: 'string' }, selector: { type: 'string' } }, required: ['url', 'selector'] } },
          { name: 'chrome_analyze_ui',  description: 'Full UI analysis: headings, colors, fonts, stats', inputSchema: { type: 'object', properties: { url: { type: 'string' } }, required: ['url'] } },
          { name: 'chrome_run_js',      description: 'Execute JavaScript expression in page context', inputSchema: { type: 'object', properties: { url: { type: 'string' }, script: { type: 'string', description: 'JS expression to evaluate' } }, required: ['url', 'script'] } },
        ]}});
        return;
      }
      if (method === 'tools/call') {
        const tool = params.name;
        const args = params.arguments || {};
        try {
          let result;
          if (tool === 'chrome_navigate')   result = await navigate(args.url);
          else if (tool === 'chrome_screenshot') result = await screenshot(args.url);
          else if (tool === 'chrome_inspect')    result = await inspectElement(args.url, args.selector);
          else if (tool === 'chrome_css')        result = await getCSS(args.url, args.selector);
          else if (tool === 'chrome_analyze_ui') result = await analyzeUI(args.url);
          else if (tool === 'chrome_run_js')     result = await runJS(args.url, args.script);
          else throw new Error('Unknown tool: ' + tool);
          sendMCP({ jsonrpc: '2.0', id, result: { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] } });
        } catch(e) {
          sendMCP({ jsonrpc: '2.0', id, error: { code: -32000, message: e.message } });
        }
        return;
      }
      sendMCP({ jsonrpc: '2.0', id, error: { code: -32601, message: 'Method not found: ' + method } });
    }
    process.stderr.write('🌐 Chrome DevTools MCP server running (stdio JSON-RPC 2.0)\n');

  // ── HTTP REST mode ──────────────────────────────────────────────
  } else if (mode === '--http') {
    const http = require('http');
    const PORT = parseInt(process.env.CHROME_MCP_PORT || '4040');
    const server = http.createServer(function(req, res) {
      let body = '';
      req.on('data', function(d) { body += d; });
      req.on('end', async function() {
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Access-Control-Allow-Origin', '*');
        try {
          const data = body ? JSON.parse(body) : {};
          const urlParsed = new URL('http://localhost' + req.url);
          const tool = urlParsed.pathname.replace(/^\/api\//, '');
          let result;
          if (tool === 'navigate')    result = await navigate(data.url);
          else if (tool === 'screenshot')  result = await screenshot(data.url);
          else if (tool === 'inspect')     result = await inspectElement(data.url, data.selector);
          else if (tool === 'css')         result = await getCSS(data.url, data.selector);
          else if (tool === 'analyze_ui')  result = await analyzeUI(data.url);
          else if (tool === 'run_js')      result = await runJS(data.url, data.script);
          else if (tool === 'health')      result = { status: 'ok', service: 'chrome-devtools-mcp', port: PORT };
          else { res.writeHead(404); res.end(JSON.stringify({ error: 'Not found: ' + tool })); return; }
          res.writeHead(200);
          res.end(JSON.stringify(result));
        } catch(e) {
          res.writeHead(500);
          res.end(JSON.stringify({ error: e.message }));
        }
      });
    });
    server.listen(PORT, function() {
      console.log('🌐 Chrome DevTools MCP HTTP server on port ' + PORT);
      console.log('   Endpoints: /api/navigate  /api/screenshot  /api/inspect  /api/css  /api/analyze_ui  /api/run_js  /api/health');
    });

  // ── Quick test mode ──────────────────────────────────────────────
  } else {
    const testUrl = process.argv[3] || 'https://example.com';
    console.log('🌐 Chrome DevTools — testing with:', testUrl);
    console.log('Usage: node chrome-tools.js --mcp | --http | --test <url>');
    navigate(testUrl).then(function(r) {
      console.log('✅ Navigate result:', JSON.stringify(r, null, 2));
    }).catch(function(e) { console.error('❌', e.message); });
  }
}
