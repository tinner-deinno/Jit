'use strict';

/**
 * test/zero-width-handling.test.js — Zero-Width Character Stripping (TICKET-017)
 *
 * This test file verifies that:
 *   1. splitThaiSyllables() strips zero-width characters (ZWS, ZWNJ, ZWJ).
 *   2. Thai text WITH zero-width chars routes the same as clean text.
 *   3. Routing keys are stable regardless of hidden formatting characters.
 *   4. No regressions in existing functionality.
 *
 * Zero-width characters tested:
 *   - U+200B (Zero Width Space — ZWS)
 *   - U+200C (Zero Width Non-Joiner — ZWNJ)
 *   - U+200D (Zero Width Joiner — ZWJ)
 *
 * These characters are invisible in text display but can cause hash/routing key
 * instability if not normalized away.
 *
 * Fix applied in TICKET-017:
 *   - limbs/thai-splitter.js: normalized.replace(/[​‌‍]/g, '') after NFC normalization
 *
 * Usage:
 *   npm test -- test/zero-width-handling.test.js
 *   or: node test/zero-width-handling.test.js
 */

const assert = require('assert');
const path = require('path');
const fs = require('fs');

const ROOT = path.join(__dirname, '..');
const router = require(path.join(ROOT, 'hermes-discord', 'model-router'));
const splitter = require(path.join(ROOT, 'limbs', 'thai-splitter'));

// ── Character definitions ──────────────────────────────────────────────────

const ZWS = '​';    // Zero Width Space
const ZWNJ = '‌';   // Zero Width Non-Joiner
const ZWJ = '‍';    // Zero Width Joiner

// ── Test runner ───────────────────────────────────────────────────────────

const tests = [];
function test(name, fn) { tests.push({ name, fn }); }

async function runTests() {
  let passed = 0;
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log('  PASS  ' + t.name);
      passed++;
    } catch (e) {
      console.log('  FAIL  ' + t.name + ': ' + e.message);
      failed++;
    }
  }
  console.log('\nResults: ' + passed + ' passed, ' + failed + ' failed');
  return failed === 0;
}

// ── Section 1: Zero-width character stripping in splitThaiSyllables ──────

test('splitThaiSyllables: strips ZWS (U+200B)', () => {
  const clean = 'สวัสดี';
  const withZWS = 'สวัส' + ZWS + 'ดี';

  const cleanResult = JSON.stringify(splitter.splitThaiSyllables(clean));
  const zwsResult = JSON.stringify(splitter.splitThaiSyllables(withZWS));

  assert.strictEqual(
    zwsResult, cleanResult,
    'splitThaiSyllables must strip ZWS. Results should be identical.\n' +
    '  clean: ' + cleanResult + '\n' +
    '  with ZWS: ' + zwsResult
  );
});

test('splitThaiSyllables: strips ZWNJ (U+200C)', () => {
  const clean = 'มนุษย์';
  const withZWNJ = 'มนุ' + ZWNJ + 'ษย์';

  const cleanResult = JSON.stringify(splitter.splitThaiSyllables(clean));
  const zwnjResult = JSON.stringify(splitter.splitThaiSyllables(withZWNJ));

  assert.strictEqual(
    zwnjResult, cleanResult,
    'splitThaiSyllables must strip ZWNJ. Results should be identical.\n' +
    '  clean: ' + cleanResult + '\n' +
    '  with ZWNJ: ' + zwnjResult
  );
});

test('splitThaiSyllables: strips ZWJ (U+200D)', () => {
  const clean = 'จิต';
  const withZWJ = 'จ' + ZWJ + 'ิต';

  const cleanResult = JSON.stringify(splitter.splitThaiSyllables(clean));
  const zwjResult = JSON.stringify(splitter.splitThaiSyllables(withZWJ));

  assert.strictEqual(
    zwjResult, cleanResult,
    'splitThaiSyllables must strip ZWJ. Results should be identical.\n' +
    '  clean: ' + cleanResult + '\n' +
    '  with ZWJ: ' + zwjResult
  );
});

test('splitThaiSyllables: strips multiple zero-width chars', () => {
  const clean = 'กระดูกสันหลัง';
  const withMany = 'กระดูก' + ZWS + 'สั' + ZWNJ + 'น' + ZWJ + 'หลัง';

  const cleanResult = JSON.stringify(splitter.splitThaiSyllables(clean));
  const manyResult = JSON.stringify(splitter.splitThaiSyllables(withMany));

  assert.strictEqual(
    manyResult, cleanResult,
    'splitThaiSyllables must strip all zero-width chars.\n' +
    '  clean: ' + cleanResult + '\n' +
    '  with multiple: ' + manyResult
  );
});

// ── Section 2: routingKey() stability with zero-width chars ──────────────

test('routingKey: stable with ZWS in Thai text', () => {
  const clean = 'สวัสดี ครับ';
  const withZWS = 'สวัส' + ZWS + 'ดี ครับ';

  const keyClean = router.routingKey([{ role: 'user', content: clean }], {});
  const keyWithZWS = router.routingKey([{ role: 'user', content: withZWS }], {});

  assert.strictEqual(
    keyWithZWS, keyClean,
    'routingKey must be identical with/without ZWS.\n' +
    '  clean key: ' + keyClean + '\n' +
    '  with ZWS key: ' + keyWithZWS
  );
});

test('routingKey: stable with ZWNJ in Thai text', () => {
  const clean = 'มนุษย์ Agent';
  const withZWNJ = 'มนุ' + ZWNJ + 'ษย์ Agent';

  const keyClean = router.routingKey([{ role: 'user', content: clean }], {});
  const keyWithZWNJ = router.routingKey([{ role: 'user', content: withZWNJ }], {});

  assert.strictEqual(
    keyWithZWNJ, keyClean,
    'routingKey must be identical with/without ZWNJ.\n' +
    '  clean key: ' + keyClean + '\n' +
    '  with ZWNJ key: ' + keyWithZWNJ
  );
});

test('routingKey: stable with ZWJ in Thai text', () => {
  const clean = 'จิต Master';
  const withZWJ = 'จ' + ZWJ + 'ิต Master';

  const keyClean = router.routingKey([{ role: 'user', content: clean }], {});
  const keyWithZWJ = router.routingKey([{ role: 'user', content: withZWJ }], {});

  assert.strictEqual(
    keyWithZWJ, keyClean,
    'routingKey must be identical with/without ZWJ.\n' +
    '  clean key: ' + keyClean + '\n' +
    '  with ZWJ key: ' + keyWithZWJ
  );
});

// ── Section 3: Verify zero-width chars don't affect ASCII ────────────────

test('splitThaiSyllables: ASCII text unaffected by zero-width stripping', () => {
  const clean = 'hello world';
  const withZWS = 'hel' + ZWS + 'lo world';

  const cleanResult = JSON.stringify(splitter.splitThaiSyllables(clean));
  const zwsResult = JSON.stringify(splitter.splitThaiSyllables(withZWS));

  // Both should return empty (no Thai syllables found), or identical non-Thai parts
  assert.strictEqual(
    zwsResult, cleanResult,
    'splitThaiSyllables must handle ASCII with zero-width chars identically'
  );
});

test('routingKey: ASCII text unaffected by zero-width stripping', () => {
  const clean = 'hello';
  const withZWS = 'hel' + ZWS + 'lo';

  const keyClean = router.routingKey([{ role: 'user', content: clean }], {});
  const keyWithZWS = router.routingKey([{ role: 'user', content: withZWS }], {});

  assert.strictEqual(
    keyWithZWS, keyClean,
    'routingKey must be identical for ASCII with/without zero-width chars'
  );
});

// ── Section 4: Verify zero-width stripping works WITH NFC normalization ───

test('splitThaiSyllables: NFC + zero-width stripping work together', () => {
  // Create a string with both NFC normalization issue AND zero-width char
  // Use a Thai consonant + wrong-order combining marks + ZWS
  const base = String.fromCodePoint(0x0E19);  // น (na)
  const toneWrong = String.fromCodePoint(0x0E49);  // mai-tho (CCC=107)
  const vowel = String.fromCodePoint(0x0E38);      // sara-u (CCC=103)

  const textWithWrongOrder = base + toneWrong + vowel;
  const textWithWrongOrderAndZWS = base + toneWrong + vowel + ZWS;

  const result1 = JSON.stringify(splitter.splitThaiSyllables(textWithWrongOrder));
  const result2 = JSON.stringify(splitter.splitThaiSyllables(textWithWrongOrderAndZWS));

  assert.strictEqual(
    result1, result2,
    'splitThaiSyllables must handle both NFC normalization AND zero-width stripping'
  );
});

// ── Section 5: Empty and edge cases ────────────────────────────────────────

test('splitThaiSyllables: zero-width-only input returns empty', () => {
  const zwOnly = ZWS + ZWNJ + ZWJ;
  const result = splitter.splitThaiSyllables(zwOnly);
  assert.deepStrictEqual(
    result, [],
    'splitThaiSyllables must return empty array for zero-width-only input'
  );
});

test('splitThaiSyllables: null and undefined still return empty', () => {
  assert.deepStrictEqual(splitter.splitThaiSyllables(null), []);
  assert.deepStrictEqual(splitter.splitThaiSyllables(undefined), []);
});

// ── Section 6: Verify existing NFC tests still pass (regression check) ─────

test('regression: existing NFC test case still works', () => {
  // Reuse the NFC divergent pair test
  const base = String.fromCodePoint(0x0E19);  // น
  const toneWrong = String.fromCodePoint(0x0E49);  // mai-tho
  const vowel = String.fromCodePoint(0x0E38);      // sara-u

  const raw = base + toneWrong + vowel;
  const nfc = raw.normalize('NFC');

  assert.notStrictEqual(raw, nfc, 'Precondition: raw and NFC should differ');

  const rawResult = JSON.stringify(splitter.splitThaiSyllables(raw));
  const nfcResult = JSON.stringify(splitter.splitThaiSyllables(nfc));

  assert.strictEqual(
    rawResult, nfcResult,
    'NFC invariance test should still pass after zero-width stripping addition'
  );
});

// ── Section 7: Verify distinct words still produce distinct keys ──────────

test('regression: distinct words still have distinct routing keys', () => {
  const words = ['จิต', 'สมอง', 'หัวใจ'];
  const keys = words.map(w => router.routingKey([{ role: 'user', content: w }], {}));
  const unique = new Set(keys);

  assert.strictEqual(
    unique.size, words.length,
    'Zero-width stripping must not collapse distinct words'
  );
});

// ── Orchestration ──────────────────────────────────────────────────────────

(async () => {
  console.log('Zero-Width Character Stripping Tests (TICKET-017)');
  console.log('Fix: splitThaiSyllables now strips ZWS/ZWNJ/ZWJ after NFC normalization\n');

  const ok = await runTests();
  process.exit(ok ? 0 : 1);
})();
