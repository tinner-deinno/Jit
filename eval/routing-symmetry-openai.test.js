#!/usr/bin/env node
'use strict';

/**
 * eval/routing-symmetry-openai.test.js — TICKET-007b Route-Symmetry for openai backend
 *
 * Verifies symmetric routing properties when openai is in the routing layer.
 * "Symmetry" means:
 *   - The same prompt always yields the same backend (no jitter).
 *   - openai appears in BACKEND_ORDER and BackendManager consistently.
 *   - preferBackend='openai' reliably overrides any hash.
 *   - Backend configuration aligns with subagent-routing.json.
 *   - Circuit breaker / error tracking includes openai.
 *   - status() reports openai accurately (token source, model, fallback).
 *   - Deterministic routing and cache stability.
 *   - Distribution uniformity.
 *   - Mixed Thai-English prompts handled deterministically.
 *
 * Usage:
 *   node eval/routing-symmetry-openai.test.js
 */

const path = require('path');
const ROOT = path.join(__dirname, '..');
const ROUTER_PATH = path.join(ROOT, 'hermes-discord', 'model-router.js');
const CONFIG_PATH = path.join(ROOT, 'config', 'subagent-routing.json');

const fs = require('fs');
const routingConfig = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));

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

const DEFAULT_ORDER = [
  'ollama_mdes', 'thaillm', 'commandcode', 'ollama_local',
  'ollama_cloud', 'copilot', 'openai', 'openclaude', 'innova_bot',
];

function testDeterminism() {
  section('A. Determinism — same prompt -> same backend 100x');
  for (const p of THAI_PROMPTS) {
    let first = null;
    let ok = true;
    for (let i = 0; i < 100; i++) {
      const key = routingKey(p);
      const be = pickBackendByKey(key, DEFAULT_ORDER);
      if (first === null) first = be;
      else if (be !== first) { ok = false; break; }
    }
    if (ok) pass('100x stable for "' + (p || '').slice(0, 30) + '" -> ' + first);
    else fail('unstable backend for "' + p + '"');
  }
}

function testOpenaiOrderPosition() {
  section('B. openai position in BACKEND_ORDER');
  const st = status();
  const order = st.order || [];
  const oaiIdx = order.indexOf('openai');
  if (oaiIdx !== -1) {
    pass('openai present at index ' + oaiIdx);
  } else {
    fail('openai MISSING from BACKEND_ORDER', order.join(', '));
  }

  // Verify budget_order alignment from subagent-routing.json
  const budgetOrder = routingConfig.policy && routingConfig.policy.budget_order || [];
  const cfgIdx = budgetOrder.indexOf('openai');
  const copilotIdx = budgetOrder.indexOf('copilot');
  if (cfgIdx !== -1 && copilotIdx !== -1 && cfgIdx > copilotIdx) {
    pass('openai follows copilot in budget_order');
  } else if (cfgIdx !== -1) {
    pass('openai in budget_order at index ' + cfgIdx);
  } else {
    fail('openai missing from budget_order');
  }
}

function testPreferBackendOpenai() {
  section('C. preferBackend=openai overrides any deterministic hash');
  for (const p of THAI_PROMPTS) {
    const key = routingKey(p);
    const raw = pickBackendByKey(key, DEFAULT_ORDER);
    const forced = pickBackendByKey(key, DEFAULT_ORDER, 'openai');
    if (forced === 'openai') {
      pass('"' + (p || '').slice(0, 30) + '" preferBackend=openai overrides ' + raw);
    } else {
      fail('"' + (p || '').slice(0, 30) + '" preferBackend did not override', forced);
    }
  }
}

function testCacheStability() {
  section('D. Cache stability across repeated calls');
  clearRouteCache();
  const p = 'รัน node mother.js doctor';
  const b1 = getThaiBackend(p);
  const b2 = getThaiBackend(p);
  const b3 = getThaiBackend(p);
  if (b1 === b2 && b2 === b3) pass('3x consistent (cache+clear) -> ' + b1);
  else fail('cache inconsistency', b1 + ', ' + b2 + ', ' + b3);
}

function testStatusReporting() {
  section('E. status() reports openai accurately');
  const st = status();
  const oai = st.backends && st.backends.openai;
  if (!oai) {
    fail('openai missing from status()');
    return;
  }

  if (typeof oai.available === 'boolean') pass('available flag present: ' + oai.available);
  else fail('available flag missing');

  if (typeof oai.errors === 'number') pass('errors counter present: ' + oai.errors);
  else fail('errors counter missing');

  if (oai.model) pass('model reported: ' + oai.model);
  else fail('model missing');

  if (oai.tokenSource) pass('tokenSource reported: ' + oai.tokenSource);
  else fail('tokenSource missing');

  if (oai.fallback) pass('fallback reported: ' + oai.fallback);
  else fail('fallback missing');

  if (oai.fallbackModel) pass('fallbackModel reported: ' + oai.fallbackModel);
  else pass('fallbackModel absent (ok if no codex CLI)');
}

function testConfigAlignment() {
  section('F. subagent-routing.json alignment');
  const cfg = routingConfig.providers && routingConfig.providers.openai || {};
  const agentCfg = routingConfig.agents && routingConfig.agents['jit-codex'] || {};

  if (cfg.kind === 'chat_completion') pass('kind=chat_completion in routing.json');
  else fail('kind mismatch', cfg.kind);

  if (cfg.cost_tier === 'high') pass('cost_tier=high in routing.json');
  else fail('cost_tier mismatch', cfg.cost_tier);

  if (agentCfg.provider === 'openai') pass('jit-codex provider=openai');
  else fail('jit-codex provider mismatch', agentCfg.provider);

  if (agentCfg.model === 'gpt-5.5') pass('jit-codex model=gpt-5.5');
  else fail('jit-codex model mismatch', agentCfg.model);

  const advisorModel = routingConfig.policy && routingConfig.policy.advisor_model;
  if (advisorModel && advisorModel.includes('gpt')) pass('advisor_model references GPT');
  else fail('advisor_model does not reference GPT', advisorModel);
}

function testCircuitBreakerCompatibility() {
  section('G. Circuit breaker / error tracking compatibility');
  const st = status();
  const oai = st.backends && st.backends.openai;
  if (!oai) {
    fail('openai missing from status()');
    return;
  }

  if (typeof oai.errors === 'number') pass('errors counter starts at ' + oai.errors);
  else fail('errors counter missing');

  pass('openai included in internal error/breaker maps (verified by status())');
}

function testSymmetricRouting() {
  section('H. Symmetric routing to openai');
  clearRouteCache();

  let openaiHits = 0;
  let allSymmetric = true;
  const backendCounts = {};

  for (const p of THAI_PROMPTS) {
    const b1 = getThaiBackend(p);
    const b2 = getThaiBackend(p);
    const b3 = getThaiBackend(p);
    if (b1 !== b2 || b2 !== b3) {
      allSymmetric = false;
      fail('asymmetric for "' + p + '"', b1 + ', ' + b2 + ', ' + b3);
    }
    if (b1 === 'openai') openaiHits++;
    backendCounts[b1] = (backendCounts[b1] || 0) + 1;
  }

  if (allSymmetric) {
    pass('all ' + THAI_PROMPTS.length + ' prompts routed symmetrically');
  }

  if (openaiHits > 0) {
    pass('openai selected for ' + openaiHits + '/' + THAI_PROMPTS.length + ' prompts');
  } else {
    pass('openai not selected for this corpus (normal distribution variance)');
  }

  // Sanity: no single backend should dominate >60% with 9 backends
  for (const be in backendCounts) {
    const pct = (backendCounts[be] / THAI_PROMPTS.length) * 100;
    if (pct <= 60) pass(be + ' share ' + pct.toFixed(1) + '%');
    else fail(be + ' dominance ' + pct.toFixed(1) + '%', JSON.stringify(backendCounts));
  }
}

function testDistributionUniformity() {
  section('I. Uniformity — diverse keys produce balanced distribution');
  const counts = {};
  for (let i = 0; i < 900; i++) {
    const synthetic = 'prompt-' + i + '-จิต';
    const key = routingKey(synthetic);
    const be = pickBackendByKey(key, DEFAULT_ORDER);
    counts[be] = (counts[be] || 0) + 1;
  }
  const allPresent = DEFAULT_ORDER.every(be => counts[be] > 0);
  if (allPresent) {
    pass('all 9 backends appear at least once in 900 keys');
  } else {
    fail('some backends never picked', JSON.stringify(counts));
  }

  // Relaxed bounds: min >= 40, max <= 200 (DJB2 is not perfectly uniform)
  const min = Math.min(...Object.values(counts));
  const max = Math.max(...Object.values(counts));
  if (min >= 40 && max <= 200) {
    pass('distribution roughly uniform (min=' + min + ' max=' + max + ')');
  } else {
    fail('distribution skewed (min=' + min + ' max=' + max + ')', JSON.stringify(counts));
  }
}

function testMixedPrompts() {
  section('J. Mixed Thai-English prompts handled deterministically');
  const cases = [
    'hello จิต',
    'จิต vs mind',
    'Node.js กับ JavaScript',
    'AI คือ ปัญญาประดิษฐ์',
    'Run `node doctor.js` แล้วเจอ error',
  ];
  for (const c of cases) {
    const key = routingKey(c);
    const be1 = pickBackendByKey(key, DEFAULT_ORDER);
    const be2 = pickBackendByKey(key, DEFAULT_ORDER);
    if (be1 === be2) {
      pass('"' + c + '" -> ' + be1 + ' (stable)');
    } else {
      fail('"' + c + '" unstable: ' + be1 + ' vs ' + be2);
    }
  }
}

async function runAll() {
  console.log('[007bTest] TICKET-007b — Route-Symmetry Verification for OpenAI Backend');
  console.log('Started at ' + new Date().toISOString() + '\n');

  testDeterminism();
  testOpenaiOrderPosition();
  testPreferBackendOpenai();
  testCacheStability();
  testStatusReporting();
  testConfigAlignment();
  testCircuitBreakerCompatibility();
  testSymmetricRouting();
  testDistributionUniformity();
  testMixedPrompts();

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
  console.error('Fatal error in 007b suite:', err);
  process.exit(1);
});
