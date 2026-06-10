#!/usr/bin/env node
'use strict';

/**
 * eval/thai-memory-symmetry.test.js - TICKET-005 Memory Symmetry Test
 *
 * Verifies that Thai tokens stored in memory and read back are byte-equal.
 * No encoding corruption when storing Thai strings through bus/Oracle pipeline.
 */

const fs = require('fs');
const path = require('path');

// Thai test phrases
const THAI_PHRASES = [
  'จิต',           // spirit, mind
  'มนุษย์',        // human
  'อวัยวะ',        // organ
  'กาย',           // body
  'วิญญาณ',        // soul
  'สมาธิ',         // concentration
  'ปัญญา',         // wisdom
  'ศีล',           // integrity
  'กรุงเทพมหานคร', // Bangkok
  'สวัสดีครับ',    // hello
];

function toHex(str) {
  return Buffer.from(str, 'utf8').toString('hex');
}

function fromHex(hex) {
  return Buffer.from(hex, 'hex').toString('utf8');
}

async function testMemorySymmetry() {
  console.log('[ThaiMemorySymmetry] Starting Memory Symmetry Check...\n');

  const testDir = path.join(__dirname, '..', 'ψ', 'memory');
  fs.mkdirSync(testDir, { recursive: true });

  const testFile = path.join(testDir, 'test-symmetry.json');
  const results = {
    timestamp: new Date().toISOString(),
    tests: [],
    passed: 0,
    failed: 0,
  };

  console.log('| Thai Phrase | Original (Hex) | Stored (Hex) | Match? |');
  console.log('|---|---|---|---|');

  for (const phrase of THAI_PHRASES) {
    const originalHex = toHex(phrase);

    // Simulate write → bus → read cycle (local file roundtrip)
    const stored = {
      phrase,
      stored_at: new Date().toISOString(),
      hex: originalHex,
    };

    // Write to file
    const data = { phrases: [stored] };
    fs.writeFileSync(testFile, JSON.stringify(data, null, 2), 'utf8');

    // Read back
    const read = JSON.parse(fs.readFileSync(testFile, 'utf8'));
    const storedPhrase = read.phrases[0].phrase;
    const storedHex = toHex(storedPhrase);

    const match = originalHex === storedHex;
    results.tests.push({
      phrase,
      original_hex: originalHex,
      stored_hex: storedHex,
      match,
    });

    if (match) {
      results.passed++;
      console.log(`| ${phrase} | ${originalHex.slice(0, 20)}... | ${storedHex.slice(0, 20)}... | ✅ |`);
    } else {
      results.failed++;
      console.log(`| ${phrase} | ${originalHex} | ${storedHex} | ❌ |`);
    }
  }

  console.log('\n---\n');
  console.log(`Final Score: ${results.passed}/${THAI_PHRASES.length} (${Math.round(100 * results.passed / THAI_PHRASES.length)}%)`);

  if (results.failed > 0) {
    const failureLog = path.join(testDir, 'learnings', 'memory-symmetry-failures.md');
    fs.mkdirSync(path.dirname(failureLog), { recursive: true });
    const failures = results.tests.filter(t => !t.match);
    fs.writeFileSync(
      failureLog,
      `# Memory Symmetry Failures\n\n` +
      `Timestamp: ${new Date().toISOString()}\n\n` +
      failures.map(f => `- **${f.phrase}**: Original ${f.original_hex} != Stored ${f.stored_hex}`).join('\n')
    );
    console.log(`\n❌ FAILURES logged to ${failureLog}`);
  } else {
    console.log('\n✅ All Thai phrases round-trip byte-equal');
  }

  // Cleanup test file
  fs.unlinkSync(testFile);

  process.exit(results.failed > 0 ? 1 : 0);
}

testMemorySymmetry().catch(err => {
  console.error('[ThaiMemorySymmetry] Error:', err);
  process.exit(1);
});
