#!/usr/bin/env node
/**
 * eval/check-all.js — run all no-provider unit checks as a regression gate.
 * Burns zero LLM quota; safe to run anytime / in CI. Exits non-zero if any fail.
 *
 *   node eval/check-all.js
 */
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
// Self-contained checks with their own pass/fail + exit code (no live providers).
const CHECKS = [
  'eval/event-log-check.js',
  'eval/leaderboard-db-check.js',
];

// Inline checks that are quick to assert here (parse + key invariants).
function inlineChecks() {
  const results = [];
  const t = (name, fn) => { try { fn(); results.push({ name, ok: true }); } catch (e) { results.push({ name, ok: false, err: e.message }); } };

  t('mother-engine parses', () => require('../limbs/mother-engine.js'));
  t('model-router parses', () => require('../hermes-discord/model-router.js'));
  t('event-log parses', () => require('../limbs/event-log.js'));
  t('leaderboard-db parses', () => require('../limbs/leaderboard-db.js'));

  // isErrorReply invariants (probe honesty) — re-derive from source to avoid drift.
  t('isErrorReply error-first', () => {
    const fs = require('fs');
    const src = fs.readFileSync(path.join(ROOT, 'eval/provider-probe.js'), 'utf8');
    const fn = eval('(' + src.match(/function isErrorReply[\s\S]*?\n}/)[0].replace('function isErrorReply', 'function') + ')');
    const cases = [['OK', false], ['OK: backend error', true], ['query failed, ok', true], ['not ok', true], ['', true], ['orchestration fine', false]];
    for (const [inp, exp] of cases) if (fn(inp) !== exp) throw new Error(`isErrorReply(${JSON.stringify(inp)})=${fn(inp)} expected ${exp}`);
  });

  // leaderboard-db provider stats round-trip (no DB file mutation — uses in-mem path? it uses real DB; skip write here, just confirm API shape).
  t('leaderboard-db API', () => {
    const db = require('../limbs/leaderboard-db.js');
    if (typeof db.recordProviderResult !== 'function' || typeof db.getProviderStats !== 'function') throw new Error('provider-stats API missing');
  });

  t('innova-bot bridge rejects pending on disconnect', () => {
    const InnovaBotBridge = require('../limbs/innova-bot-bridge.js');
    const bridge = new InnovaBotBridge();
    let rejected = false;
    const timer = setTimeout(() => {}, 10000);
    bridge.pending.set('test-id', {
      resolve: () => {},
      reject: (error) => { rejected = /pending MCP request cancelled/.test(error.message); },
      timer,
    });
    bridge._rejectPending('pending MCP request cancelled');
    if (!rejected) throw new Error('pending promise was not rejected');
    if (bridge.pending.size !== 0) throw new Error('pending map was not cleared');
  });

  return results;
}

(async () => {
  console.log('\n[check-all] regression gate (no LLM quota)\n');
  let failed = 0;

  for (const r of inlineChecks()) {
    console.log(`  ${r.ok ? '✓' : '✗'} ${r.name}${r.ok ? '' : ' — ' + r.err}`);
    if (!r.ok) failed++;
  }

  for (const c of CHECKS) {
    process.stdout.write(`  → ${c} ... `);
    try {
      execFileSync(process.execPath, [path.join(ROOT, c)], { stdio: 'pipe', encoding: 'utf8' });
      console.log('✓ PASS');
    } catch (e) {
      console.log('✗ FAIL');
      const out = (e.stdout || '') + (e.stderr || '');
      console.log('    ' + out.split('\n').filter(Boolean).slice(-3).join('\n    '));
      failed++;
    }
  }

  console.log(`\n[check-all] ${failed ? `❌ ${failed} check(s) FAILED` : '✅ all checks passed'}`);
  process.exit(failed ? 1 : 0);
})();
