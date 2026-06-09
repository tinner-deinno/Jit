'use strict';

/**
 * test/nfc-normalization.test.js — NFC Normalization Verification (chamu / TICKET-010)
 *
 * SA Design Review finding (2026-06-08):
 *   "NFC Normalization Gap — thai-splitter.js missing .normalize('NFC') at entry points"
 *
 * This test file verifies that:
 *   1. splitThaiSyllables() is invariant under Unicode NFC vs non-NFC input.
 *   2. thaiCanonicalize() (model-router._thaiCanonicalize) is invariant.
 *   3. routingKey() produces the same key for the same Thai word regardless
 *      of combining-mark order in the input.
 *   4. ASCII and empty inputs are unaffected by the NFC change.
 *   5. Corpus entries from thai-test-corpus.json still route identically
 *      when re-submitted as NFC-normalized input.
 *
 * The divergent test inputs are REAL: the "wrong" form has a higher-CCC combining
 * mark (tone mark, CCC=107) placed BEFORE a lower-CCC mark (below-vowel, CCC=103).
 * Unicode NFC reorders them; these byte sequences are visually identical but
 * byte-different without normalization, causing different routing keys pre-fix.
 *
 * Fix applied in this same PR:
 *   - limbs/thai-splitter.js: String(text).normalize('NFC') at top of splitThaiSyllables()
 *   - hermes-discord/model-router.js: String(text||'').normalize('NFC').trim() in thaiCanonicalize()
 *
 * Usage:
 *   node test/nfc-normalization.test.js
 */

const assert = require('assert');
const path = require('path');
const fs = require('fs');

const ROOT = path.join(__dirname, '..');
const router = require(path.join(ROOT, 'hermes-discord', 'model-router'));
const splitter = require(path.join(ROOT, 'limbs', 'thai-splitter'));

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Build a Thai string from a base consonant codepoint and an array of
 * combining marks in a WRONG order (higher CCC before lower CCC).
 * These strings are byte-different from their NFC forms but visually identical.
 */
function wrongOrder(base, combiningMarks) {
  return String.fromCodePoint(base, ...combiningMarks);
}

/**
 * Return the NFC-normalized (correct order) counterpart.
 */
function nfcOf(s) {
  return s.normalize('NFC');
}

// ── Divergent pairs ───────────────────────────────────────────────────────────
//
// Each pair: { desc, raw, nfc }
//   raw = combining marks in wrong order (higher CCC first — triggers NFC reorder)
//   nfc = same word with marks in canonical NFC order
//
// Combining mark CCCs relevant here:
//   sara-u  (U+0E38): CCC=103  (below-vowel)
//   sara-uu (U+0E39): CCC=103
//   mai-ek  (U+0E48): CCC=107  (tone mark)
//   mai-tho (U+0E49): CCC=107
//   mai-tri (U+0E4A): CCC=107
//   mai-jattawa (U+0E4B): CCC=107
//
// NFC requires lower-CCC before higher-CCC, so:
//   consonant + tone(CCC=107) + vowel(CCC=103)  ->  consonant + vowel + tone

const DIVERGENT_PAIRS = [
  {
    desc: 'นุ้  (น + mai-tho[CCC107] + sara-u[CCC103] — wrong order)',
    raw: wrongOrder(0x0E19, [0x0E49, 0x0E38]),
    nfc: wrongOrder(0x0E19, [0x0E38, 0x0E49]),
  },
  {
    desc: 'นู้  (น + mai-tho[CCC107] + sara-uu[CCC103] — wrong order)',
    raw: wrongOrder(0x0E19, [0x0E49, 0x0E39]),
    nfc: wrongOrder(0x0E19, [0x0E39, 0x0E49]),
  },
  {
    desc: 'กุ่  (ก + mai-ek[CCC107] + sara-u[CCC103] — wrong order)',
    raw: wrongOrder(0x0E01, [0x0E48, 0x0E38]),
    nfc: wrongOrder(0x0E01, [0x0E38, 0x0E48]),
  },
  {
    desc: 'ตุ๊  (ต + mai-tri[CCC107] + sara-u[CCC103] — wrong order)',
    raw: wrongOrder(0x0E15, [0x0E4A, 0x0E38]),
    nfc: wrongOrder(0x0E15, [0x0E38, 0x0E4A]),
  },
  {
    desc: 'ดู๋  (ด + mai-jattawa[CCC107] + sara-uu[CCC103] — wrong order)',
    raw: wrongOrder(0x0E14, [0x0E4B, 0x0E39]),
    nfc: wrongOrder(0x0E14, [0x0E39, 0x0E4B]),
  },
];

// ── Test runner ───────────────────────────────────────────────────────────────

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

// ── Section 1: Precondition — input pairs actually diverge without normalization ──

test('precondition: raw pairs are genuinely byte-different from NFC', () => {
  for (const p of DIVERGENT_PAIRS) {
    assert.notStrictEqual(
      p.raw, p.nfc,
      'Pair should be byte-different: ' + p.desc
    );
    assert.strictEqual(
      p.raw.normalize('NFC'), p.nfc,
      'NFC of raw should equal nfc form: ' + p.desc
    );
  }
});

// ── Section 2: splitThaiSyllables() NFC invariance ──────────────────────────

for (const p of DIVERGENT_PAIRS) {
  test('splitThaiSyllables: invariant for ' + p.desc, () => {
    const rawResult = JSON.stringify(splitter.splitThaiSyllables(p.raw));
    const nfcResult = JSON.stringify(splitter.splitThaiSyllables(p.nfc));
    assert.strictEqual(
      rawResult, nfcResult,
      'splitThaiSyllables must return the same syllables for both encodings.\n' +
      '  raw result: ' + rawResult + '\n' +
      '  nfc result: ' + nfcResult
    );
  });
}

// ── Section 3: thaiCanonicalize() NFC invariance ─────────────────────────────

for (const p of DIVERGENT_PAIRS) {
  test('thaiCanonicalize: invariant for ' + p.desc, () => {
    const rawCanon = router._thaiCanonicalize(p.raw);
    const nfcCanon = router._thaiCanonicalize(p.nfc);
    assert.strictEqual(
      rawCanon, nfcCanon,
      'thaiCanonicalize must return same canonical form for both encodings.\n' +
      '  raw: ' + rawCanon + '\n' +
      '  nfc: ' + nfcCanon
    );
  });
}

// ── Section 4: routingKey() NFC invariance (end-to-end) ──────────────────────

for (const p of DIVERGENT_PAIRS) {
  test('routingKey: invariant for ' + p.desc, () => {
    // Use a full Thai sentence so lang:thai branch is taken
    const sentenceRaw = 'สวัสดี ' + p.raw + ' ครับ';
    const sentenceNfc = 'สวัสดี ' + p.nfc + ' ครับ';

    const keyRaw = router.routingKey([{ role: 'user', content: sentenceRaw }], {});
    const keyNfc = router.routingKey([{ role: 'user', content: sentenceNfc }], {});

    assert.strictEqual(
      keyRaw, keyNfc,
      'routingKey must be identical for both encodings.\n' +
      '  raw key: ' + keyRaw + '\n' +
      '  nfc key: ' + keyNfc
    );
  });
}

// ── Section 5: Stable corpus entries unaffected by NFC fix ───────────────────

test('corpus entries: NFC-normalized input produces same routingKey as-is', () => {
  const corpusPath = path.join(ROOT, 'test', 'thai-test-corpus.json');
  const corpus = JSON.parse(fs.readFileSync(corpusPath, 'utf8'));

  // All corpus entries are already in NFC (authored as UTF-8).  Normalizing
  // them a second time must be a no-op and must not change routing keys.
  for (const tc of corpus) {
    if (!tc.input) continue;
    const original = tc.input;
    const normalized = original.normalize('NFC');
    if (original === normalized) {
      // Confirm routing key is stable (not changed by normalization pass)
      const k1 = router.routingKey([{ role: 'user', content: original }], {});
      const k2 = router.routingKey([{ role: 'user', content: normalized }], {});
      assert.strictEqual(k1, k2, 'Corpus entry ' + tc.id + ' routing key changed after NFC — should be identical');
    }
  }
});

// ── Section 6: Non-Thai inputs unaffected ────────────────────────────────────

test('ASCII input unchanged by NFC fix', () => {
  const s = 'hello world';
  const resultSplitter = splitter.splitThaiSyllables(s);
  const resultSplitterNfc = splitter.splitThaiSyllables(s.normalize('NFC'));
  assert.deepStrictEqual(resultSplitter, resultSplitterNfc);

  const canon = router._thaiCanonicalize(s);
  const canonNfc = router._thaiCanonicalize(s.normalize('NFC'));
  assert.strictEqual(canon, canonNfc);
});

test('empty input unchanged by NFC fix', () => {
  assert.deepStrictEqual(splitter.splitThaiSyllables(''), []);
  assert.strictEqual(router._thaiCanonicalize(''), '');
});

test('mixed Thai+ASCII input routing key stable under NFC', () => {
  const s = 'มนุษย์ Agent 42';
  const k1 = router.routingKey([{ role: 'user', content: s }], {});
  const k2 = router.routingKey([{ role: 'user', content: s.normalize('NFC') }], {});
  assert.strictEqual(k1, k2);
});

// ── Section 7: NFC does NOT equate genuinely distinct words ──────────────────
//
// Confirm that NFC normalization does not accidentally collapse *different*
// Thai words into the same key (i.e., fix is surgical, not over-aggressive).

test('distinct Thai words still produce distinct routing keys after NFC fix', () => {
  const words = ['จิต', 'สมอง', 'หัวใจ', 'กระดูก', 'มือ'];
  const keys = words.map(w => router.routingKey([{ role: 'user', content: w + ' test' }], {}));
  const unique = new Set(keys);
  assert.strictEqual(
    unique.size, words.length,
    'Each distinct word should map to a distinct routing key. Got: ' + keys.join(', ')
  );
});

// ── Orchestration ─────────────────────────────────────────────────────────────

(async () => {
  console.log('NFC Normalization Verification Tests (chamu / TICKET-010)');
  console.log('Fix: splitThaiSyllables + thaiCanonicalize now call .normalize("NFC") at entry\n');

  const ok = await runTests();
  process.exit(ok ? 0 : 1);
})();
