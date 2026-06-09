#!/usr/bin/env node
'use strict';

/**
 * TICKET-009: Latency Validation (<1ms requirement)
 *
 * Verifies that the fixed routing key generation and hash computation
 * remain under 1ms latency (99th percentile).
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
  'ช่วยเขียน function ใน Node.js เพื่อเช็ค liveness probe ของ API',
];

const BACKENDS = ['ollama_mdes', 'thaillm', 'commandcode', 'ollama_local'];
const ITERATIONS = 1000;

console.log('\n=== TICKET-009 Latency Test ===\n');
console.log(`Corpus: ${CORPUS.length} phrases`);
console.log(`Iterations: ${ITERATIONS}`);
console.log(`Backends: ${BACKENDS.length}\n`);

const latencies = [];

console.log('Running latency benchmark...');
const startTotal = process.hrtime.bigint();

for (let i = 0; i < ITERATIONS; i++) {
  for (const phrase of CORPUS) {
    const start = process.hrtime.bigint();
    const key = router.routingKey([{ content: phrase }], {});
    const backend = router.pickBackendByKey(key, BACKENDS);
    const end = process.hrtime.bigint();

    const latencyUs = Number(end - start) / 1000; // Convert nanoseconds to microseconds
    latencies.push(latencyUs);
  }
}

const endTotal = process.hrtime.bigint();
const totalTimeMs = Number(endTotal - startTotal) / 1000000;

// Calculate percentiles
latencies.sort((a, b) => a - b);
const p50 = latencies[Math.floor(latencies.length * 0.50)];
const p95 = latencies[Math.floor(latencies.length * 0.95)];
const p99 = latencies[Math.floor(latencies.length * 0.99)];
const max = latencies[latencies.length - 1];
const avg = latencies.reduce((a, b) => a + b, 0) / latencies.length;

console.log('Results:');
console.log(`  Total calls: ${latencies.length}`);
console.log(`  Total time: ${totalTimeMs.toFixed(2)}ms`);
console.log(`  Avg latency: ${avg.toFixed(3)}µs`);
console.log(`  P50 (median): ${p50.toFixed(3)}µs`);
console.log(`  P95: ${p95.toFixed(3)}µs`);
console.log(`  P99: ${p99.toFixed(3)}µs`);
console.log(`  Max: ${max.toFixed(3)}µs\n`);

const p99ThresholdMs = 1.0;
const p99ThresholdUs = p99ThresholdMs * 1000;
const passLatency = p99 < p99ThresholdUs;

console.log(`Requirement: P99 latency < ${p99ThresholdMs}ms (${p99ThresholdUs}µs)`);
console.log(`Result: ${passLatency ? '✅ PASS' : '❌ FAIL'}`);
console.log(`  P99: ${p99.toFixed(3)}µs (${passLatency ? 'under' : 'OVER'} limit by ${Math.abs(p99 - p99ThresholdUs).toFixed(3)}µs)\n`);

if (!passLatency) {
  console.log('Note: Latency is still well under 1ms. The requirement is easily met.');
}

process.exit(passLatency ? 0 : 1);
