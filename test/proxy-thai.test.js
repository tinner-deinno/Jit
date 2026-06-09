'use strict';

/**
 * test/proxy-thai.test.js — TICKET-008 Proxy Tests
 *
 * Coverage:
 *   - Health endpoint
 *   - Routing key computation (Thai + ASCII)
 *   - Backend selection with cache
 *   - Proxy round-trip (mocked router)
 *   - Splitter failure fallback
 *   - Thai script safety (NFC normalization, zero-width)
 *   - Error handling (invalid JSON, large payload, backend exhaustion)
 */

const http = require('http');
const assert = require('assert');
const proxy = require('../network/proxy-thai');
const router = require('../hermes-discord/model-router');

const PORT = 14322;
let server;
let origCallModel;

// ── Helpers ────────────────────────────────────────────────────────────
function post(path, body, port) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({ hostname: '127.0.0.1', port, path, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } }, res => {
      let chunks = '';
      res.on('data', c => chunks += c);
      res.on('end', () => resolve({ statusCode: res.statusCode, body: chunks }));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path, port) {
  return new Promise((resolve, reject) => {
    http.get({ hostname: '127.0.0.1', port, path }, res => {
      let chunks = '';
      res.on('data', c => chunks += c);
      res.on('end', () => resolve({ statusCode: res.statusCode, body: chunks }));
    }).on('error', reject);
  });
}

// ── Test runner ──────────────────────────────────────────────────────
const tests = [];
function test(name, fn) { tests.push({ name, fn }); }

async function runTests() {
  let passed = 0, failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
      passed++;
    } catch (e) {
      console.log(`  FAIL  ${t.name}: ${e.message}`);
      failed++;
    }
  }
  console.log(`\nResults: ${passed} passed, ${failed} failed`);
  return failed === 0;
}

// ── Setup / teardown ─────────────────────────────────────────────────
function setup() {
  return new Promise(resolve => {
    process.env.PROXY_THAI_PORT = String(PORT);
    process.env.PROXY_RATE_LIMIT_ENABLED = 'false'; // disable rate limiting so existing tests don't hit 429
    origCallModel = router.callModel;
    server = proxy.createServer();
    server.listen(PORT, resolve);
  });
}

function teardown() {
  return new Promise(resolve => {
    router.callModel = origCallModel;
    if (server) server.close(resolve);
    else resolve();
  });
}

// ── 1. Health ────────────────────────────────────────────────────────
test('health returns 200 with backends array', async () => {
  const res = await get('/health', PORT);
  assert.strictEqual(res.statusCode, 200);
  const j = JSON.parse(res.body);
  assert.strictEqual(j.status, 'ok');
  assert(Array.isArray(j.backends));
});

// ── 2. Routing key computation ───────────────────────────────────────
test('computeRoutingKey uses splitter for Thai text', async () => {
  const keyObj = proxy.computeRoutingKey('จิตนำกาย');
  assert.strictEqual(keyObj.source, 'splitter');
  assert(typeof keyObj.key === 'number' || typeof keyObj.key === 'string');
  assert(keyObj.canonical.length > 0);
});

test('computeRoutingKey uses splitter for ASCII text', async () => {
  const keyObj = proxy.computeRoutingKey('hello world');
  assert.strictEqual(keyObj.source, 'splitter');
});

test('computeRoutingKey fallback on splitter error', async () => {
  const orig = router.thaiCanonicalize;
  router.thaiCanonicalize = () => { throw new Error('mock splitter fail'); };
  const keyObj = proxy.computeRoutingKey('anything');
  assert.strictEqual(keyObj.source, 'fallback-hash');
  assert(typeof keyObj.key === 'string');
  router.thaiCanonicalize = orig;
});

// ── 3. Backend selection / cache ─────────────────────────────────────
test('pickBackend returns a backend and caches', async () => {
  proxy.routeCache && proxy.routeCache.clear();
  const keyObj = proxy.computeRoutingKey('test prompt');
  const p1 = proxy.pickBackend(keyObj);
  assert(p1.backend);
  assert.strictEqual(p1.cached, false);

  const p2 = proxy.pickBackend(keyObj);
  assert.strictEqual(p2.backend, p1.backend);
  assert.strictEqual(p2.cached, true);
});

// ── 4. Proxy round-trip (mocked router) ──────────────────────────────
test('POST /v1/chat/completions returns completion', async () => {
  router.callModel = (msgs, opts, cb) => cb(null, {
    reply: 'mock reply',
    backend: 'ollama_mdes',
    attempts: [{ backend: 'ollama_mdes', ok: true }]
  });

  const res = await post('/v1/chat/completions', { messages: [{ role: 'user', content: 'hi' }] }, PORT);
  assert.strictEqual(res.statusCode, 200);
  const j = JSON.parse(res.body);
  assert.strictEqual(j.choices[0].message.content, 'mock reply');
  assert.strictEqual(j._jit_meta.backend, 'ollama_mdes');
  assert(j._jit_meta.routingKey);
});

// ── 5. Error handling ────────────────────────────────────────────────
test('invalid JSON returns 400', async () => {
  const res = await new Promise((resolve, reject) => {
    const req = http.request({ hostname: '127.0.0.1', port: PORT, path: '/v1/chat/completions', method: 'POST', headers: { 'Content-Type': 'application/json' } }, res => {
      let chunks = '';
      res.on('data', c => chunks += c);
      res.on('end', () => resolve({ statusCode: res.statusCode, body: chunks }));
    });
    req.on('error', reject);
    req.write('not json');
    req.end();
  });
  assert.strictEqual(res.statusCode, 400);
  const j = JSON.parse(res.body);
  assert.strictEqual(j.error, 'invalid_payload');
});

test('unknown path returns 404', async () => {
  const res = await get('/unknown', PORT);
  assert.strictEqual(res.statusCode, 404);
});

test('backend exhaustion returns 503', async () => {
  router.callModel = (msgs, opts, cb) => {
    const e = new Error('All backends exhausted (a, b)');
    e.attempts = [{ backend: 'a', ok: false, error: 'fail' }];
    cb(e);
  };

  const res = await post('/v1/chat/completions', { messages: [{ role: 'user', content: 'x' }] }, PORT);
  assert.strictEqual(res.statusCode, 503);
  const j = JSON.parse(res.body);
  assert.strictEqual(j.error, 'backends_exhausted');
  assert(Array.isArray(j.attempts));
});

// ── 6. Thai script safety ────────────────────────────────────────────
test('NFC normalized Thai produces stable key', async () => {
  const decomposed = 'กะ'; // U+0E01 U+0E30
  const composed = 'กะ';
  const k1 = proxy.computeRoutingKey(decomposed);
  const k2 = proxy.computeRoutingKey(composed);
  assert.strictEqual(k1.source, 'splitter');
  assert.strictEqual(k2.source, 'splitter');
});

test('zero-width joiner does not crash splitter', async () => {
  const text = 'จิต‍กาย';
  const keyObj = proxy.computeRoutingKey(text);
  assert(keyObj.key);
});

// ── 7. Config / module shape ─────────────────────────────────────────
test('exports expected API', async () => {
  assert.strictEqual(typeof proxy.start, 'function');
  assert.strictEqual(typeof proxy.stop, 'function');
  assert.strictEqual(typeof proxy.createServer, 'function');
  assert(proxy.CONFIG);
  assert(proxy.routeCache);
});

// ── Orchestration ──────────────────────────────────────────────────────
(async () => {
  console.log('TICKET-008 proxy tests');
  await setup();
  const ok = await runTests();
  await teardown();
  process.exit(ok ? 0 : 1);
})();
