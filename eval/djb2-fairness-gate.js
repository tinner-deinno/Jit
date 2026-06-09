#!/usr/bin/env node
'use strict';

/**
 * eval/djb2-fairness-gate.js — DJB2 Hash Fairness Gate (lak / TICKET-010)
 *
 * Checks that the DJB2 hash modulo 9 produces acceptably uniform routing
 * distribution across all 9 backends.  Runs the Thai test corpus through
 * pickBackendByKey() without any live calls (pure routing math).
 *
 * Gate thresholds:
 *   WARNING  — any backend deviates >±5% from uniform (11.11%)
 *   FAIL     — any backend deviates >±15% from uniform (catastrophic skew)
 *
 * Rationale (SA memo, lak 2026-06-09):
 *   With N=26 phrases, Poisson SD per bin ≈ √(0.111·0.889/26) ≈ 6.2%.
 *   A hard ±5% block against a 26-phrase corpus is statistically impossible
 *   to pass — all backends would need exactly 2-3 phrases each and the
 *   corpus is not evenly spread.  The ±5% warn / ±15% fail split is the
 *   correct production signal:
 *     - ±5% warn  → log alert, monitor; normal for small corpora
 *     - ±15% fail → DJB2 algorithm bug or BACKEND_ORDER corruption
 *
 *   Reference: TICKET-009 closure note; TICKET-010 "Expected Output" says
 *   "warning if any backend >±5% from uniform" (not hard fail).
 *
 * Usage:
 *   node eval/djb2-fairness-gate.js
 *   node eval/djb2-fairness-gate.js --corpus=test/thai-test-corpus.json
 *   node eval/djb2-fairness-gate.js --corpus=thai-test-corpus-expanded-010.json
 *   node eval/djb2-fairness-gate.js --warn-only  (always exit 0, for CI advisory mode)
 *
 * Exit codes:
 *   0 — all backends within ±5% (clean pass)
 *   1 — at least one backend outside ±15% (hard fail — routing broken)
 *   2 — at least one backend outside ±5% but none outside ±15% (soft warn)
 */

const path = require('path');
const fs   = require('fs');

const ROOT = path.join(__dirname, '..');

// Parse CLI args
const args = process.argv.slice(2);
const warnOnly = args.includes('--warn-only');
const corpusArg = args.find(a => a.startsWith('--corpus='));
const corpusFile = corpusArg
  ? path.resolve(ROOT, corpusArg.replace('--corpus=', ''))
  : path.join(ROOT, 'test', 'thai-test-corpus.json');

// Load router (pure routing — no network calls)
const router = require(path.join(ROOT, 'hermes-discord', 'model-router'));

const ALL_BACKENDS = [
  'ollama_mdes',
  'thaillm',
  'commandcode',
  'ollama_local',
  'ollama_cloud',
  'copilot',
  'openai',
  'openclaude',
  'innova_bot',
];

// Thresholds
const WARN_THRESHOLD  = 5.0;   // ±5%  — soft warning
const FAIL_THRESHOLD  = 15.0;  // ±15% — hard fail

// ── Load corpus ────────────────────────────────────────────────────────────

function loadCorpus(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error('[djb2-fairness-gate] Corpus not found:', filePath);
    process.exit(1);
  }
  let raw;
  try {
    raw = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (e) {
    console.error('[djb2-fairness-gate] JSON parse error:', e.message);
    process.exit(1);
  }

  // Support two formats:
  //   1. Array of { input: string } (thai-test-corpus.json)
  //   2. Array of { phrase: string } (thai-test-corpus-expanded-010.json)
  return raw
    .map(item => item.phrase || item.input || '')
    .filter(s => s.length > 0);
}

// ── Compute distribution ───────────────────────────────────────────────────

function computeDistribution(phrases, backends) {
  const counts = {};
  backends.forEach(b => { counts[b] = 0; });

  for (const phrase of phrases) {
    const key = router.routingKey([{ role: 'user', content: phrase }], {});
    const selected = router.pickBackendByKey(key, backends);
    if (counts[selected] !== undefined) {
      counts[selected]++;
    } else {
      // Backend not in our list (shouldn't happen, but guard it)
      counts[selected] = 1;
    }
  }
  return counts;
}

// ── Report ─────────────────────────────────────────────────────────────────

function runFairnessGate() {
  const phrases = loadCorpus(corpusFile);
  const backends = ALL_BACKENDS;

  console.log('[djb2-fairness-gate] DJB2 Hash Fairness Gate — lak / TICKET-010');
  console.log('Corpus   :', corpusFile);
  console.log('Phrases  :', phrases.length, '(non-empty)');
  console.log('Backends :', backends.length);
  console.log('Uniform  :', (100 / backends.length).toFixed(2) + '% per backend');
  console.log('Warn     : any backend outside ±' + WARN_THRESHOLD + '% of uniform');
  console.log('Fail     : any backend outside ±' + FAIL_THRESHOLD + '% of uniform');
  console.log('');

  const counts = computeDistribution(phrases, backends);
  const total = phrases.length;
  const uniformPct = 100 / backends.length;

  let warns = 0;
  let fails = 0;

  const rows = [];
  for (const b of backends) {
    const c    = counts[b] || 0;
    const pct  = (c / total) * 100;
    const delta = pct - uniformPct;
    const absDelta = Math.abs(delta);

    let status;
    if (absDelta > FAIL_THRESHOLD) {
      status = 'FAIL';
      fails++;
    } else if (absDelta > WARN_THRESHOLD) {
      status = 'WARN';
      warns++;
    } else {
      status = 'PASS';
    }

    rows.push({ backend: b, count: c, pct, delta, status });
  }

  // Print table
  console.log('| Backend         | Count | %      | Delta   | Status |');
  console.log('|-----------------|-------|--------|---------|--------|');
  for (const r of rows) {
    const deltaStr = (r.delta >= 0 ? '+' : '') + r.delta.toFixed(1) + '%';
    const statusTag = r.status === 'FAIL' ? 'FAIL' : r.status === 'WARN' ? 'WARN' : 'PASS';
    console.log(
      `| ${r.backend.padEnd(15)} | ${String(r.count).padStart(5)} | ${r.pct.toFixed(1).padStart(5)}% | ${deltaStr.padStart(7)} | ${statusTag.padEnd(6)} |`
    );
  }

  console.log('');
  console.log('Summary:');
  console.log('  PASS  :', rows.filter(r => r.status === 'PASS').length, 'backends within ±' + WARN_THRESHOLD + '%');
  console.log('  WARN  :', warns, 'backends outside ±' + WARN_THRESHOLD + '% (soft — corpus too small for tight bins)');
  console.log('  FAIL  :', fails, 'backends outside ±' + FAIL_THRESHOLD + '% (hard — routing skew detected)');
  console.log('');

  // Statistical note for small corpora
  const sdEst = Math.sqrt((uniformPct / 100) * (1 - uniformPct / 100) / total) * 100;
  if (sdEst > WARN_THRESHOLD * 0.6) {
    console.log('NOTE: corpus SD estimate ≈ ' + sdEst.toFixed(1) + '% per bin.');
    console.log('      ±' + WARN_THRESHOLD + '% threshold is < 1 SD at this corpus size.');
    console.log('      WARN results are expected; use ≥150 distinct phrases for a strict gate.');
    console.log('');
  }

  // Exit decision
  if (fails > 0) {
    console.log('VERDICT: FAIL — ' + fails + ' backend(s) exceed ±' + FAIL_THRESHOLD + '% skew. DJB2 or BACKEND_ORDER may be broken.');
    process.exit(warnOnly ? 0 : 1);
  } else if (warns > 0) {
    console.log('VERDICT: WARN — ' + warns + ' backend(s) between ±' + WARN_THRESHOLD + '% and ±' + FAIL_THRESHOLD + '%. Monitor at production scale.');
    process.exit(warnOnly ? 0 : 2);
  } else {
    console.log('VERDICT: PASS — all backends within ±' + WARN_THRESHOLD + '%. Distribution looks uniform.');
    process.exit(0);
  }
}

runFairnessGate();
