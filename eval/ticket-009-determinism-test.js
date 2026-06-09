#!/usr/bin/env node
'use strict';

/**
 * TICKET-009: Determinism Validation
 *
 * Verifies that the fixed routing maintains determinism:
 * same Thai phrase → same backend across multiple calls.
 */

const router = require('../hermes-discord/model-router');

const CORPUS = [
  'จิตคืออะไรในมุมมองของพุทธศาสนา?',
  'มนุษย์ Agent คือระบบอะไร?',
  'อวัยวะทั้ง 14 ส่วนของ Jit มีอะไรบ้าง?',
  'ความแตกต่างระหว่าง soma และ innova คืออะไร?',
  'จิตนำกาย หมายความว่าอย่างไร?',
  'ช่วยอธิบายการทำงานของ Multi-Backend Proxy ในภาษาไทยหน่อย',
  'การทำ routing determinism ในระบบ multi-agent สำคัญอย่างไร?',
  'แนะนำวิธีใช้ CommandCode Bridge สำหรับภาษาไทย',
];

const BACKENDS = [
  'ollama_mdes', 'thaillm', 'commandcode', 'ollama_local',
  'ollama_cloud', 'copilot', 'openai', 'openclaude', 'innova_bot'
];

const ITERATIONS = 5;

console.log('\n=== TICKET-009 Determinism Test ===\n');
console.log(`Corpus: ${CORPUS.length} phrases`);
console.log(`Iterations: ${ITERATIONS}`);
console.log(`Backends: ${BACKENDS.length}\n`);

const routes = {};
for (const phrase of CORPUS) {
  routes[phrase] = [];
}

console.log('Running determinism test...');

for (let it = 0; it < ITERATIONS; it++) {
  for (const phrase of CORPUS) {
    const key = router.routingKey([{ content: phrase }], {});
    const backend = router.pickBackendByKey(key, BACKENDS);
    routes[phrase].push(backend);
  }
}

console.log('\nDeterminism Results:');
console.log('| Phrase | Iteration 1 | Iteration 2 | Iteration 3 | Iteration 4 | Iteration 5 | Deterministic? |');
console.log('|---|---|---|---|---|---|---|');

let passed = 0;
let failed = 0;

for (const phrase of CORPUS) {
  const backends = routes[phrase];
  const allSame = backends.every(b => b === backends[0]);

  if (allSame) passed++;
  else failed++;

  const cols = [
    phrase.slice(0, 20) + '...',
    ...backends.map(b => b),
    allSame ? '✅ YES' : '❌ NO'
  ];
  console.log(`| ${cols.join(' | ')} |`);
}

console.log(`\nDeterminism Score: ${passed}/${CORPUS.length} (${(passed / CORPUS.length * 100).toFixed(1)}%)`);

if (failed === 0) {
  console.log('✅ PASS: All phrases route deterministically across iterations.\n');
  process.exit(0);
} else {
  console.log(`❌ FAIL: ${failed} phrases route to different backends.\n`);
  process.exit(1);
}
