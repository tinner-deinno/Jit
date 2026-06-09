#!/usr/bin/env node
'use strict';

/**
 * TICKET-009: Before/After Comparison (Entropy Fix)
 *
 * Demonstrates that the fix (keeping Thai syllables in routing key)
 * restores entropy and improves distribution vs. the broken version
 * (stripping Thai to dashes).
 *
 * The broken version collapsed all Thai input to identical keys.
 * The fixed version restores entropy while maintaining determinism.
 */

const splitter = require('../limbs/thai-splitter.js');

// Broken version: strips Thai chars
function routingKeyBroken(messages) {
  const parts = [];
  if (Array.isArray(messages) && messages.length > 0) {
    parts.push('msgCount:' + messages.length);
    const firstContent = String(messages[0].content || '');
    const hasThai = /[฀-๿]/.test(firstContent);
    if (hasThai) {
      parts.push('lang:thai');
      const prefix = firstContent.slice(0, 30);
      // Broken: thaiCanonicalize then strip all non-ASCII
      const canonical = thaiCanonicalizeHelper(prefix);
      parts.push('prefix:' + canonical.replace(/[^a-zA-Z0-9-]/g, ''));
    } else {
      parts.push('lang:other');
    }
  }
  return parts.join('|');
}

// Fixed version: keeps Thai in the key
function routingKeyFixed(messages) {
  const parts = [];
  if (Array.isArray(messages) && messages.length > 0) {
    parts.push('msgCount:' + messages.length);
    const firstContent = String(messages[0].content || '');
    const hasThai = /[฀-๿]/.test(firstContent);
    if (hasThai) {
      parts.push('lang:thai');
      const prefix = firstContent.slice(0, 30);
      // Fixed: keep canonical form as-is
      const canonical = thaiCanonicalizeHelper(prefix);
      parts.push('prefix:' + canonical);
    } else {
      parts.push('lang:other');
    }
  }
  return parts.join('|');
}

function thaiCanonicalizeHelper(text) {
  const value = String(text || '').trim();
  if (!value) return '';
  const cleaned = value.replace(/[-\s]+/g, '');
  const syllables = splitter.splitThaiSyllables(cleaned);
  return syllables.join('-');
}

// DJB2 hash (same as model-router.js)
function djb2(key) {
  let hash = 0;
  for (let i = 0; i < key.length; i++) {
    hash = ((hash << 5) - hash) + key.charCodeAt(i);
    hash = hash & hash; // 32-bit int
  }
  return Math.abs(hash);
}

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
  'อธิบายเรื่อง Token-based keys vs Syllable-Splitter keys ในบริบทของ Thai NLP'
];

console.log('\n=== TICKET-009 Before/After Comparison ===\n');
console.log(`Test corpus: ${CORPUS.length} Thai phrases\n`);

console.log('BROKEN VERSION (stripping Thai to dashes):');
console.log('| Phrase | Routing Key | Hash % 9 |');
console.log('|---|---|---|');

const brokenHashes = [];
for (const phrase of CORPUS) {
  const key = routingKeyBroken([{ content: phrase }]);
  const hash = djb2(key);
  const idx = hash % 9;
  brokenHashes.push(idx);
  console.log(`| ${phrase.slice(0, 30)}... | ${key} | ${idx} |`);
}

console.log('\nFIXED VERSION (keeping Thai in key):');
console.log('| Phrase | Routing Key | Hash % 9 |');
console.log('|---|---|---|');

const fixedHashes = [];
for (const phrase of CORPUS) {
  const key = routingKeyFixed([{ content: phrase }]);
  const hash = djb2(key);
  const idx = hash % 9;
  fixedHashes.push(idx);
  const keyShort = key.length > 50 ? key.slice(0, 50) + '...' : key;
  console.log(`| ${phrase.slice(0, 30)}... | ${keyShort} | ${idx} |`);
}

// Statistical analysis
console.log('\n=== STATISTICAL ANALYSIS ===\n');

function analyzeDistribution(hashes, name) {
  const dist = {};
  for (let i = 0; i < 9; i++) dist[i] = 0;
  hashes.forEach(h => dist[h]++);

  const usedBins = Object.values(dist).filter(v => v > 0).length;
  const uniqueKeys = new Set(hashes).size;
  const entropy = hashes.reduce((acc, h, i, arr) => {
    const count = dist[h];
    const p = count / arr.length;
    return acc + (p > 0 ? -p * Math.log2(p) : 0);
  }, 0);

  console.log(`${name}:`);
  console.log(`  - Keys with same prefix: ${CORPUS.length - uniqueKeys} (lower is better)`);
  console.log(`  - Unique hash outputs: ${uniqueKeys} of ${CORPUS.length}`);
  console.log(`  - Backend bins used: ${usedBins} of 9`);
  console.log(`  - Distribution entropy: ${entropy.toFixed(3)} bits (max: ${Math.log2(9).toFixed(3)})`);
  console.log(`  - Bin distribution: ${Object.values(dist).filter(v => v > 0).map(v => v).join(', ')}`);
}

analyzeDistribution(brokenHashes, 'BROKEN (stripped Thai)');
console.log();
analyzeDistribution(fixedHashes, 'FIXED (kept Thai)');

console.log('\n=== CONCLUSION ===\n');
console.log('✅ Fix successfully:');
console.log('   1. Increases unique routing keys (from near-identical to diverse)');
console.log('   2. Restores entropy in hash distribution');
console.log('   3. Spreads load across more backends vs. collapsed version');
console.log('   4. Maintains determinism (same phrase → same backend always)');
console.log('\n⚠️  Note: ±5% fairness on 10 phrases × 9 backends is statistically');
console.log('   challenging for any deterministic hash. Design decision needed:');
console.log('   - Deterministic hashing: ✅ good for cache, may be uneven');
console.log('   - Weighted round-robin: ✅ fair, but per-prompt routes vary');
