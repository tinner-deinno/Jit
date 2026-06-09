#!/usr/bin/env node
'use strict';

/**
 * TICKET-009: Thai Routing Backend Distribution Test
 *
 * Measures fairness of Thai input distribution across 9 backends.
 * Success criteria: ±5% across all backends with 28-phrase corpus.
 *
 * Usage:
 *   node eval/ticket-009-distribution-test.js
 *
 * Expected output:
 *   - Backend distribution chart (per backend: count, percentage, ±delta)
 *   - Pass/fail on ±5% fairness criterion
 *   - Individual phrase routing map
 */

const router = require('../hermes-discord/model-router');
const fs = require('fs');
const path = require('path');

const CORPUS_PATH = path.join(__dirname, '../eval/thai-routing-corpus.md');
const BACKEND_ORDER = [
  'ollama_mdes', 'thaillm', 'commandcode', 'ollama_local',
  'ollama_cloud', 'copilot', 'openai', 'openclaude', 'innova_bot'
];

function readCorpus() {
  try {
    const content = fs.readFileSync(CORPUS_PATH, 'utf8');
    const lines = content.split(/\r?\n/)
      .filter(l => l.trim() && /^\d+\./.test(l.trim()))
      .map(l => l.replace(/^\d+\.\s+/, '').trim());
    return lines;
  } catch (e) {
    console.error('Failed to read corpus:', e.message);
    process.exit(1);
  }
}

function runDistributionTest() {
  const phrases = readCorpus();
  console.log(`\n[TICKET-009] Thai Routing Distribution Test`);
  console.log(`Corpus: ${phrases.length} phrases\n`);

  const backends = BACKEND_ORDER;
  const distribution = {};
  backends.forEach(b => distribution[b] = 0);

  const routing = [];

  // Run multiple iterations to measure stability
  const iterations = 1; // Single pass on 28 phrases
  for (let it = 0; it < iterations; it++) {
    for (const phrase of phrases) {
      const key = router.routingKey([{ content: phrase }], {});
      const selected = router.pickBackendByKey(key, backends);
      distribution[selected]++;
      routing.push({ phrase: phrase.slice(0, 40), key, backend: selected });
    }
  }

  const totalCalls = phrases.length * iterations;
  const expectedPerBackend = totalCalls / backends.length;
  const tolerance = 0.05; // ±5%

  console.log(`Total calls: ${totalCalls}`);
  console.log(`Expected per backend: ${expectedPerBackend.toFixed(2)}`);
  console.log(`Tolerance: ±${(tolerance * 100).toFixed(1)}%\n`);

  console.log('Backend Distribution:');
  console.log('| Backend | Count | % | Expected | Delta | Status |');
  console.log('|---|---|---|---|---|---|');

  let passed = 0;
  let failed = 0;

  for (const backend of backends) {
    const count = distribution[backend];
    const pct = (count / totalCalls) * 100;
    const expectedPct = (expectedPerBackend / totalCalls) * 100;
    const delta = pct - expectedPct;
    const deltaAbs = Math.abs(delta);
    const status = deltaAbs <= (tolerance * 100) ? '✅ PASS' : '❌ FAIL';

    if (deltaAbs <= (tolerance * 100)) {
      passed++;
    } else {
      failed++;
    }

    console.log(
      `| ${backend.padEnd(15)} | ${count.toString().padStart(5)} | ${pct.toFixed(1).padStart(5)}% | ` +
      `${expectedPct.toFixed(1)}% | ${delta > 0 ? '+' : ''}${delta.toFixed(1)}% | ${status} |`
    );
  }

  const fairnessPass = failed === 0;
  console.log(`\nFairness Result: ${passed}/${backends.length} backends within ±5%`);
  console.log(`Overall: ${fairnessPass ? '✅ PASS' : '❌ FAIL'}\n`);

  if (!fairnessPass) {
    console.log('NOTE: With ${phrases.length} phrases into ${backends.length} bins:');
    console.log('  - Expected per bin: ${expectedPerBackend.toFixed(2)}');
    console.log('  - Statistical SD: ~1.7');
    console.log('  - ±5% threshold: ±${(tolerance * expectedPerBackend).toFixed(2)} items');
    console.log('  → Small corpus size may naturally exceed ±5% for deterministic hashing.');
    console.log('    If fairness is critical, consider weighted round-robin assignment instead.');
  }

  // Individual routing map (first 10 phrases for inspection)
  console.log('\nFirst 10 Phrase Routing Map:');
  console.log('| Phrase | Key | Backend |');
  console.log('|---|---|---|');
  for (let i = 0; i < Math.min(10, routing.length); i++) {
    const r = routing[i];
    console.log(`| ${r.phrase.slice(0, 20)}... | ${r.key.slice(0, 30)}... | ${r.backend} |`);
  }

  process.exit(fairnessPass ? 0 : 1);
}

runDistributionTest();
