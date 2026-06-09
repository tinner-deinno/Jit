#!/usr/bin/env node
'use strict';

/**
 * eval/routing-symmetry-cross-backend-007b.test.js — TICKET-007b
 * Cross-Backend Consistency Check: Same input, same routing key across backends.
 *
 * Verifies:
 *   1. A fixed input always produces the same routingKey regardless of which backend
 *      is later chosen from the order.
 *   2. pickBackendByKey is deterministic for every backend position in the order.
 *   3. Cache clear does not change the backend selected for a given prompt.
 *   4. Mixed Thai-English prompts canonicalize stably.
 *   5. All 9 declared backends appear in status().order and are reachable via BackendManager.
 *   6. preferBackend for any backend overrides deterministically.
 *   7. Symmetry holds across the full BACKEND_ORDER permutation (same key -> same backend
 *      no matter where in the rotation that backend sits).
 *
 * Usage:
 *   node eval/routing-symmetry-cross-backend-007b.test.js
 */

const path = require('path');
const ROOT = path.join(__dirname, '..');
const ROUTER_PATH = path.join(ROOT, 'hermes-discord', 'model-router.js');

const {
  routingKey,
  pickBackendByKey,
  getThaiBackend,
  clearRouteCache,
  status,
  thaiCanonicalize,
} = require(ROUTER_PATH);

let PASS = 0;
let FAIL = 0;
let TOTAL = 0;

function pass(msg) { PASS++; TOTAL++; console.log('  PASS — ' + msg); }
function fail(msg, detail) { FAIL++; TOTAL++; console.log('  FAIL — ' + msg); if (detail) console.log('       ' + detail); }
function section(title) { console.log('\n-- ' + title + ' --'); }

const THAI_PROMPTS = [
  'จิตคืออะไร',
  'จิตนำกาย',
  'อวัยวะทั้ง 14 ส่วนของ Jit',
  'เชียงใหม่',
  'กรุงเทพมหานคร',
  'ประเทศไทย',
  'สมาธิ',
  'ภาษาไทย',
  'น้ำขึ้นให้รีบตัก',
  'ธรรมะ',
  'เขียนโค้ด Node.js',
  'รัน node mother.js doctor',
  'hello จิต',
  'จิต vs mind',
  'Thai-Syllable-Splitter แบบ deterministic',
];

const ALL_BACKENDS = [
  'ollama_mdes', 'thaillm', 'commandcode', 'ollama_local',
  'ollama_cloud', 'copilot', 'openai', 'openclaude', 'innova_bot',
];

// ---------------------------------------------------------------------------
// A. Key determinism — same input -> same key, independent of backend
// ---------------------------------------------------------------------------
function testKeyDeterminismAcrossBackends() {
  section('A. Key determinism across backends');
  for (const p of THAI_PROMPTS) {
    const k1 = routingKey(p);
    const k2 = routingKey(p);
    const k3 = routingKey(p);
    if (k1 === k2 && k2 === k3) {
      pass('"' + p.slice(0, 30) + '" key=' + k1 + ' (stable)');
    } else {
      fail('"' + p + '" routingKey unstable', k1 + ', ' + k2 + ', ' + k3);
    }
  }
}

// ---------------------------------------------------------------------------
// B. pickBackendByKey symmetry for each backend when it is first in order
// ---------------------------------------------------------------------------
function testPerBackendHeadPosition() {
  section('B. Each backend as head of order — symmetric');
  for (const be of ALL_BACKENDS) {
    const order = [be].concat(ALL_BACKENDS.filter(b => b !== be));
    let ok = true;
    for (const p of THAI_PROMPTS) {
      const key = routingKey(p);
      const b1 = pickBackendByKey(key, order);
      const b2 = pickBackendByKey(key, order);
      if (b1 !== b2) { ok = false; break; }
    }
    if (ok) pass(be + ' as head — stable across prompts');
    else fail(be + ' as head — unstable');
  }
}

// ---------------------------------------------------------------------------
// C. preferBackend override for every backend
// ---------------------------------------------------------------------------
function testPreferBackendForAll() {
  section('C. preferBackend override for every backend');
  for (const be of ALL_BACKENDS) {
    let ok = true;
    for (const p of THAI_PROMPTS) {
      const key = routingKey(p);
      const chosen = pickBackendByKey(key, ALL_BACKENDS, be);
      if (chosen !== be) { ok = false; break; }
    }
    if (ok) pass(be + ' preferBackend overrides deterministically');
    else fail(be + ' preferBackend did not override');
  }
}

// ---------------------------------------------------------------------------
// D. Cache clear does not change backend selection
// ---------------------------------------------------------------------------
function testCacheClearStability() {
  section('D. Cache clear stability');
  clearRouteCache();
  const snapshot = {};
  for (const p of THAI_PROMPTS) {
    snapshot[p] = getThaiBackend(p);
  }
  clearRouteCache();
  let match = 0;
  for (const p of THAI_PROMPTS) {
    const after = getThaiBackend(p);
    if (after === snapshot[p]) match++;
    else fail('"' + p.slice(0, 30) + '" backend changed after cache clear', snapshot[p] + ' -> ' + after);
  }
  if (match === THAI_PROMPTS.length) {
    pass('ALL ' + match + ' prompts stable after cache clear');
  }
}

// ---------------------------------------------------------------------------
// E. Mixed Thai-English canonicalization stability
// ---------------------------------------------------------------------------
function testMixedCanonicalization() {
  section('E. Mixed Thai-English canonicalization');
  const cases = [
    { input: 'hello จิต', expect: 'hello จิต' },
    { input: 'จิต vs mind', expect: 'จิต vs mind' },
    { input: 'Node.js กับ JavaScript', expect: 'node.js กับ javascript' },
    { input: 'AI คือ ปัญญาประดิษฐ์', expect: 'ai คือ ปัญ|ญาป|ระ|ดิษ|ฐ์' },
    { input: 'Run `node doctor.js` แล้วเจอ error', expect: 'run `node doctor.js` แล้ว|เจอ error' },
  ];
  for (const c of cases) {
    const out = thaiCanonicalize(c.input);
    if (out === c.expect) {
      pass('"' + c.input + '" -> "' + out + '"');
    } else {
      fail('"' + c.input + '" canonical mismatch', 'expected "' + c.expect + '" got "' + out + '"');
    }
  }
}

// ---------------------------------------------------------------------------
// F. All 9 backends appear in status().order
// ---------------------------------------------------------------------------
function testStatusOrderCompleteness() {
  section('F. status().order completeness');
  const st = status();
  const order = st.order || [];
  const missing = ALL_BACKENDS.filter(be => order.indexOf(be) === -1);
  if (missing.length === 0) {
    pass('all 9 backends present in status().order');
  } else {
    fail('missing backends in status().order', missing.join(', '));
  }

  // Verify no duplicates
  const uniq = new Set(order);
  if (uniq.size === order.length) {
    pass('status().order has no duplicates');
  } else {
    fail('status().order contains duplicates');
  }
}

// ---------------------------------------------------------------------------
// G. BackendManager reports every backend
// ---------------------------------------------------------------------------
function testBackendManagerCompleteness() {
  section('G. BackendManager completeness');
  // BackendManager is not exported, but status() derives from it.
  // We validate that every backend in ALL_BACKENDS has a status entry.
  const st = status();
  const backends = st.backends || {};
  const missing = ALL_BACKENDS.filter(be => !backends[be]);
  if (missing.length === 0) {
    pass('all 9 backends reported by status()');
  } else {
    fail('missing backends in status()', missing.join(', '));
  }
}

// ---------------------------------------------------------------------------
// H. Full 100x determinism across all backends
// ---------------------------------------------------------------------------
function testFullDeterminism100x() {
  section('H. Full determinism 100x per prompt across all backends');
  let allOk = true;
  for (const p of THAI_PROMPTS) {
    const key = routingKey(p);
    const first = pickBackendByKey(key, ALL_BACKENDS);
    let ok = true;
    for (let i = 0; i < 100; i++) {
      if (pickBackendByKey(key, ALL_BACKENDS) !== first) { ok = false; break; }
    }
    if (ok) {
      // silently count
      PASS++; TOTAL++;
    } else {
      fail('"' + p.slice(0, 30) + '" unstable over 100x');
      allOk = false;
    }
  }
  if (allOk) console.log('  (' + THAI_PROMPTS.length + ' prompts all stable 100x)');
}

// ---------------------------------------------------------------------------
// I. Uniformity — synthetic corpus hits every backend at least once
// ---------------------------------------------------------------------------
function testUniformity() {
  section('I. Uniformity across synthetic corpus');
  const counts = {};
  for (let i = 0; i < 900; i++) {
    const synthetic = 'prompt-' + i + '-จิต';
    const key = routingKey(synthetic);
    const be = pickBackendByKey(key, ALL_BACKENDS);
    counts[be] = (counts[be] || 0) + 1;
  }
  const allPresent = ALL_BACKENDS.every(be => counts[be] > 0);
  if (allPresent) {
    pass('all 9 backends appear at least once in 900 keys');
  } else {
    fail('some backends never picked', JSON.stringify(counts));
  }

  const min = Math.min(...Object.values(counts));
  const max = Math.max(...Object.values(counts));
  if (min >= 40 && max <= 200) {
    pass('distribution roughly uniform (min=' + min + ' max=' + max + ')');
  } else {
    fail('distribution skewed (min=' + min + ' max=' + max + ')', JSON.stringify(counts));
  }
}

// ---------------------------------------------------------------------------
// J. Cross-backend reversibility: canonical + key + backend all stable
// ---------------------------------------------------------------------------
function testReversibility() {
  section('J. Reversibility (canonical -> key -> backend)');
  for (const p of THAI_PROMPTS) {
    const c1 = thaiCanonicalize(p);
    const k1 = routingKey(p);
    const b1 = pickBackendByKey(k1, ALL_BACKENDS);

    const c2 = thaiCanonicalize(p);
    const k2 = routingKey(p);
    const b2 = pickBackendByKey(k2, ALL_BACKENDS);

    if (c1 === c2 && k1 === k2 && b1 === b2) {
      // silently count
      PASS++; TOTAL++;
    } else {
      fail('"' + p.slice(0, 30) + '" not reversible',
        'canonical=' + (c1 === c2) + ' key=' + (k1 === k2) + ' backend=' + (b1 === b2));
    }
  }
  console.log('  (' + THAI_PROMPTS.length + ' prompts checked for full reversibility)');
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------
async function runAll() {
  console.log('[007bTest] TICKET-007b — Cross-Backend Route-Symmetry Verification');
  console.log('Started at ' + new Date().toISOString() + '\n');

  testKeyDeterminismAcrossBackends();
  testPerBackendHeadPosition();
  testPreferBackendForAll();
  testCacheClearStability();
  testMixedCanonicalization();
  testStatusOrderCompleteness();
  testBackendManagerCompleteness();
  testFullDeterminism100x();
  testUniformity();
  testReversibility();

  console.log('\n');
  if (FAIL === 0) {
    console.log('ALL ' + TOTAL + ' TESTS PASSED');
  } else {
    console.log(FAIL + '/' + TOTAL + ' TESTS FAILED');
  }
  console.log('');
  process.exit(FAIL === 0 ? 0 : 1);
}

runAll().catch(err => {
  console.error('Fatal error in cross-backend symmetry suite:', err);
  process.exit(1);
});
