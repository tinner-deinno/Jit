#!/usr/bin/env node
/**
 * eval/event-log-check.js — regression tests for limbs/event-log.js.
 * Covers CSV escaping, the leading-whitespace formula-injection bypass,
 * RFC-4180 quoting, and JSON round-trip. Exits non-zero on any failure.
 */
const log = require('../limbs/event-log');
let fail = 0;
const ok = (cond, msg) => { if (!cond) { console.error('  ✗ ' + msg); fail++; } else console.log('  ✓ ' + msg); };

// Formula-injection guard, including leading-whitespace bypass variants.
const injects = ['=1+1', '+1', '-1', '@SUM(A1)', ' =1+1', '  +1', '\t=1', '\r-1', ' @x'];
for (const v of injects) {
  const out = log.escapeCSVField(v);
  // After any optional leading quote, the first non-space-ish content must start with apostrophe.
  ok(out.replace(/^"/, '').startsWith("'"), `injection guarded: ${JSON.stringify(v)} -> ${JSON.stringify(out)}`);
}

// Non-injection values must NOT be apostrophe-prefixed.
for (const v of ['hello', '  hello', '0', 'ollama_mdes', 'vaja;soma']) {
  ok(!log.escapeCSVField(v).startsWith("'"), `not over-guarded: ${JSON.stringify(v)}`);
}

// RFC-4180 quoting.
ok(log.escapeCSVField('a,b') === '"a,b"', 'comma quoted');
ok(log.escapeCSVField('a"b') === '"a""b"', 'quote doubled');
ok(/^".*"$/s.test(log.escapeCSVField('a\nb')), 'newline quoted');

// Both injection AND comma -> apostrophe + quoted.
ok(log.escapeCSVField('=1,2') === `"'=1,2"`, 'injection+comma both handled');

// JSON round-trip + CSV row/column integrity with embedded newline.
const rows = [
  { ts: 't1', phase: 'P', goal: 'multi\nline', provider: 'x', squad: ['a', 'b'], verdicts: [80, 90], durationMs: 5, committed: true },
];
ok(JSON.parse(log.toJSON(rows)).length === 1, 'JSON round-trip');
const csv = log.toCSV(rows);
ok(csv.split('\r\n').filter(Boolean).length === 2, 'embedded newline does not create phantom CSV row');

console.log(fail === 0 ? '\n[event-log-check] PASS' : `\n[event-log-check] FAIL (${fail})`);
process.exit(fail === 0 ? 0 : 1);
