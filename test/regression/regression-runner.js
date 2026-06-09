#!/usr/bin/env node
'use strict';

/**
 * test/regression/regression-runner.js — TICKET-009 Regression Automation Framework
 *
 * Loads the Thai test corpus (26 edge cases) and runs every case through every
 * backend defined in hermes-discord/model-router.js.  Compares the routing
 * decision (which backend is chosen) before and after any refactor, detects
 * variance, and writes a JSON + markdown report.
 *
 * Usage:
 *   node test/regression/regression-runner.js
 *
 * Outputs:
 *   test/regression/report.json
 *   test/regression/report.md
 *   test/regression/golden-files/<backend>.json   (expected per-backend results)
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const CORPUS_PATH = path.join(ROOT, 'test', 'thai-test-corpus.json');
const ROUTER_PATH = path.join(ROOT, 'hermes-discord', 'model-router.js');
const SPLITTER_PATH = path.join(ROOT, 'limbs', 'thai-splitter.js');
const REPORT_JSON = path.join(__dirname, 'report.json');
const REPORT_MD = path.join(__dirname, 'report.md');
const GOLDEN_DIR = path.join(__dirname, 'golden-files');

const router = require(ROUTER_PATH);
const { splitThaiSyllables, makeRoutingKey } = require(SPLITTER_PATH);
const corpus = JSON.parse(fs.readFileSync(CORPUS_PATH, 'utf8'));

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

const USABLE_BACKENDS = (() => {
  const st = router.status();
  const order = st.order || [];
  return ALL_BACKENDS.filter(b => order.includes(b));
})();

// ── Helpers ──────────────────────────────────────────────────────────────

function nowIso() { return new Date().toISOString(); }

function pickBackendDeterministic(prompt, prefer) {
  // Use the internal deterministic routing (TICKET-007a)
  const key = router._routingKey(prompt);
  const order = router.status().order || USABLE_BACKENDS;
  return router.pickBackendByKey(key, order, prefer);
}

function loadGolden(backend) {
  const p = path.join(GOLDEN_DIR, `${backend}.json`);
  if (fs.existsSync(p)) {
    try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (_) { return null; }
  }
  return null;
}

function saveGolden(backend, data) {
  const p = path.join(GOLDEN_DIR, `${backend}.json`);
  fs.writeFileSync(p, JSON.stringify(data, null, 2) + '\n', 'utf8');
}

// ── Runner ───────────────────────────────────────────────────────────────

async function runCase(tc, backend) {
  const prompt = tc.input;
  const canonical = router._thaiCanonicalize(prompt);
  const routingKey = router._routingKey(prompt);
  const deterministicBackend = pickBackendDeterministic(prompt, backend);

  let liveBackend = null;
  let liveError = null;

  // Lightweight live call: empty-system prompt, fast timeout, noRotate
  try {
    const result = await router.callModelPromise(
      [{ role: 'user', content: prompt }],
      { preferBackend: backend, noRotate: true, timeoutMs: 8000 }
    );
    liveBackend = result.backend || backend;
  } catch (e) {
    liveError = e.message || String(e);
    liveBackend = backend; // intended target even if call failed
  }

  return {
    id: tc.id || tc.input,
    input: prompt,
    expectedSyllables: tc.expected,
    actualSyllables: splitThaiSyllables(prompt),
    canonical,
    routingKey,
    deterministicBackend,
    liveBackend,
    liveError,
    variance: null, // set later
  };
}

async function runAll() {
  console.log('[RegressionRunner] TICKET-009 — Regression Automation Framework');
  console.log(`Started at ${nowIso()}`);
  console.log(`Corpus size: ${corpus.length} cases`);
  console.log(`Backends to test: ${USABLE_BACKENDS.join(', ')}\n`);

  const report = {
    meta: {
      ticket: 'TICKET-009',
      generatedAt: nowIso(),
      corpusPath: CORPUS_PATH,
      corpusSize: corpus.length,
      backends: USABLE_BACKENDS,
      routerPath: ROUTER_PATH,
      splitterPath: SPLITTER_PATH,
    },
    results: {},
    variance: [],
    summary: {
      totalRuns: 0,
      passes: 0,
      failures: 0,
      variances: 0,
    },
  };

  for (const backend of USABLE_BACKENDS) {
    const golden = loadGolden(backend);
    const backendResults = [];

    console.log(`-- Backend: ${backend} --`);
    for (const tc of corpus) {
      const res = await runCase(tc, backend);
      report.meta.totalRuns = (report.meta.totalRuns || 0) + 1;

      // Syllable accuracy check
      const expectedJson = JSON.stringify(tc.expected);
      const actualJson = JSON.stringify(res.actualSyllables);
      const syllableOk = expectedJson === actualJson;

      // Golden comparison (if golden exists)
      let goldenBackend = null;
      if (golden && golden[res.id]) {
        goldenBackend = golden[res.id].deterministicBackend;
      }
      const backendChanged = goldenBackend && goldenBackend !== res.deterministicBackend;

      // Variance: any deviation from golden or syllable mismatch
      const hasVariance = !syllableOk || backendChanged;
      res.variance = hasVariance ? {
        syllableMismatch: !syllableOk,
        backendChanged,
        goldenBackend,
      } : null;

      if (hasVariance) {
        report.variance.push({
          id: res.id,
          backend,
          reason: !syllableOk ? 'syllable-mismatch' : 'backend-shift',
          detail: res.variance,
        });
        report.summary.variances++;
      }

      if (res.liveError) {
        report.summary.failures++;
      } else {
        report.summary.passes++;
      }

      backendResults.push(res);
      process.stdout.write('.');
    }
    console.log('');

    report.results[backend] = backendResults;

    // Update golden file with current run (always overwrite so golden stays current)
    const goldenData = {};
    for (const r of backendResults) {
      goldenData[r.id] = {
        deterministicBackend: r.deterministicBackend,
        routingKey: r.routingKey,
        canonical: r.canonical,
      };
    }
    saveGolden(backend, goldenData);
  }

  report.summary.totalRuns = report.meta.totalRuns;

  // ── Write reports ─────────────────────────────────────────────────────
  fs.writeFileSync(REPORT_JSON, JSON.stringify(report, null, 2) + '\n', 'utf8');
  fs.writeFileSync(REPORT_MD, renderMarkdown(report), 'utf8');

  console.log(`\nReports written:`);
  console.log(`  JSON: ${REPORT_JSON}`);
  console.log(`  MD  : ${REPORT_MD}`);
  console.log(`\nSummary:`);
  console.log(`  Total runs : ${report.summary.totalRuns}`);
  console.log(`  Passes     : ${report.summary.passes}`);
  console.log(`  Failures   : ${report.summary.failures}`);
  console.log(`  Variances  : ${report.summary.variances}`);

  if (report.summary.variances > 0) {
    console.log('\nCONCLUSION: VARIANCE DETECTED — review report.md');
    process.exit(1);
  } else {
    console.log('\nCONCLUSION: All cases stable — no variance detected.');
    process.exit(0);
  }
}

function renderMarkdown(r) {
  const m = r.meta;
  const s = r.summary;
  let md = `# TICKET-009 Regression Report\n\n`;
  md += `**Generated:** ${m.generatedAt}  \n`;
  md += `**Corpus:** ${m.corpusPath} (${m.corpusSize} cases)  \n`;
  md += `**Backends:** ${m.backends.join(', ')}  \n\n`;

  md += `## Summary\n\n`;
  md += `| Metric | Value |\n`;
  md += `|---|---|\n`;
  md += `| Total runs | ${s.totalRuns} |\n`;
  md += `| Passes | ${s.passes} |\n`;
  md += `| Failures | ${s.failures} |\n`;
  md += `| Variances | ${s.variances} |\n\n`;

  if (r.variance.length === 0) {
    md += `## Variance Detail\n\nNo variances detected. All corpus items produced identical routing decisions and syllable splits compared to golden files.\n\n`;
  } else {
    md += `## Variance Detail\n\n`;
    md += `| Case | Backend | Reason | Detail |\n`;
    md += `|---|---|---|---|\n`;
    for (const v of r.variance) {
      const detail = v.detail.syllableMismatch
        ? 'Syllable split changed'
        : `Backend shifted from ${v.detail.goldenBackend} to current`;
      md += `| ${v.id} | ${v.backend} | ${v.reason} | ${detail} |\n`;
    }
    md += '\n';
  }

  md += `## Per-Backend Results\n\n`;
  for (const backend of m.backends) {
    const rows = r.results[backend] || [];
    md += `### ${backend}\n\n`;
    md += `| Case | Input | Deterministic Backend | Live Error | Variance |\n`;
    md += `|---|---|---|---|---|\n`;
    for (const row of rows) {
      const variance = row.variance ? 'YES' : '—';
      const err = row.liveError ? row.liveError.slice(0, 40) : '—';
      md += `| ${row.id} | \`${row.input.slice(0, 30)}\` | ${row.deterministicBackend} | ${err} | ${variance} |\n`;
    }
    md += '\n';
  }

  md += `## How to Interpret\n\n`;
  md += `- **Variance = syllable-mismatch**: The Thai splitter output changed for this input compared to the corpus \`expected\` array. This is a regression in TICKET-006b logic.\n`;
  md += `- **Variance = backend-shift**: The deterministic routing key changed, causing a different backend to be selected. Review \`golden-files/<backend>.json\` diffs.\n`;
  md += `- **Live Error**: The backend call failed (network, auth, timeout). Not a regression in routing logic, but recorded for reliability tracking.\n`;
  md += `- **Golden files** in \`test/regression/golden-files/\` store the expected deterministic backend per case. Delete or update them after intentional routing changes.\n`;

  return md;
}

runAll().catch(err => {
  console.error('Fatal error in regression runner:', err);
  process.exit(1);
});
