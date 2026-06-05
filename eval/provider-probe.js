#!/usr/bin/env node
/**
 * eval/provider-probe.js - Provider liveness probe for the Mother fleet.
 *
 * Answers the main routing question before any swarm: which model backends are
 * alive, which are rate-limited, and which are down. It reuses the real call
 * path in hermes-discord/model-router.js, so a green here means the backend
 * answered a real chat request.
 *
 * Output:
 *   - markdown table to stdout
 *   - network/provider-status.json { usable, results: { backend: {...} } }
 *
 * Usage:
 *   node eval/provider-probe.js [--timeout 20000]
 *   node eval/provider-probe.js [--timeout 20000] [--backends ollama_mdes,thaillm,innova_bot]
 */
const fs = require('fs');
const path = require('path');

// Load .env (model-router reads process.env)
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const router = require('../hermes-discord/model-router');

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i > -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const TIMEOUT = parseInt(arg('--timeout', '35000'), 10);

// Backends to probe (keys in model-router BackendManager).
const ALL_BACKENDS = ['ollama_mdes', 'ollama_local', 'ollama_cloud', 'thaillm', 'copilot', 'openai', 'openclaude', 'innova_bot'];
const REQUESTED_BACKENDS = String(arg('--backends', ''))
  .split(',')
  .map((value) => value.trim())
  .filter(Boolean);
const SELECTED_BACKENDS = (REQUESTED_BACKENDS.length ? REQUESTED_BACKENDS : ALL_BACKENDS)
  .filter((value, index, array) => array.indexOf(value) === index)
  .filter((value) => ALL_BACKENDS.includes(value));
const IS_PARTIAL = SELECTED_BACKENDS.length > 0 && SELECTED_BACKENDS.length < ALL_BACKENDS.length;

const PING = [{ role: 'user', content: 'Reply with exactly: OK' }];

function classify(err) {
  const msg = String(err && err.message || err || '').toLowerCase();
  if (/\b(429|402|403|quota|rate.?limit|exhaust|too many)\b/.test(msg)) return 'RATE_LIMITED';
  if (/\b(401|unauthor|invalid.*(key|token)|missing.*(key|token))\b/.test(msg)) return 'AUTH';
  if (/(econn|enotfound|etimedout|timeout|socket|network|fetch failed|refused)/.test(msg)) return 'UNREACHABLE';
  return 'ERROR';
}

// A backend can answer HTTP-200 yet return an in-band error string (for example
// innova-bot when its own backend is down). The ping asks for "OK", so a
// healthy reply contains "ok"; treat error-sentinel replies as degraded.
function isErrorReply(text) {
  const t = String(text || '').trim();
  if (!t) return true;
  if (/(system override|query failed|unavailable|not available|backend (failed|error)|i (cannot|can't|am unable)|^error\b|:\s*error|\bnot ok\b)/i.test(t)) return true;
  return false;
}

function isUsableProbeReply(text) {
  const t = String(text || '').trim();
  if (isErrorReply(t)) return false;
  return /\bok\b/i.test(t);
}

function probeOne(backend) {
  const startedAt = Date.now();
  return Promise.race([
    router.callModelPromise(PING, { preferBackend: backend, noRotate: true, model: null }),
    new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), TIMEOUT)),
  ]).then(
    (response) => {
      const reply = String(response.reply || '');
      const usable = isUsableProbeReply(reply);
      return {
        backend,
        status: usable ? 'ALIVE' : 'ERROR',
        ms: Date.now() - startedAt,
        served_by: response.backend,
        sample: reply.slice(0, 60).replace(/\s+/g, ' '),
        ...(usable ? {} : { error: 'non-usable probe reply: ' + reply.slice(0, 60).replace(/\s+/g, ' ') }),
      };
    },
    (error) => ({
      backend,
      status: classify(error),
      ms: Date.now() - startedAt,
      error: String(error && error.message || error).slice(0, 80),
    })
  );
}

function readPrevious(outPath) {
  try {
    return JSON.parse(fs.readFileSync(outPath, 'utf8'));
  } catch (_) {
    return { results: {}, usable: [] };
  }
}

function computeUsable(results) {
  return Object.entries(results)
    .filter(([backend, row]) => row && row.status === 'ALIVE' && row.served_by === backend)
    .map(([backend]) => backend)
    .sort();
}

(async () => {
  if (!SELECTED_BACKENDS.length) {
    console.error('[provider-probe] no valid backends selected');
    process.exit(1);
  }

  console.log(`\n[provider-probe] timeout=${TIMEOUT}ms probing ${SELECTED_BACKENDS.length} backends...\n`);
  const results = {};
  const probedAtMs = Date.now();
  const arr = await Promise.all(SELECTED_BACKENDS.map(probeOne));
  for (const row of arr) {
    results[row.backend] = {
      ...row,
      probed_at_ms: probedAtMs,
    };
  }

  const outPath = path.join(__dirname, '..', 'network', 'provider-status.json');
  const previous = readPrevious(outPath);
  const mergedResults = { ...(previous.results || {}), ...results };

  const icon = { ALIVE: 'ok', RATE_LIMITED: 'limit', AUTH: 'auth', UNREACHABLE: 'down', ERROR: 'bad' };
  console.log('| backend | status | latency | detail |');
  console.log('|---|---|---|---|');
  for (const backend of SELECTED_BACKENDS) {
    const row = results[backend];
    const detail = row.status === 'ALIVE'
      ? `served_by=${row.served_by}${row.served_by !== backend ? ' fallback' : ''} "${row.sample}"`
      : (row.error || '');
    console.log(`| ${backend} | ${icon[row.status] || ''} ${row.status} | ${row.ms}ms | ${detail} |`);
  }

  const usable = computeUsable(results);
  const cachedUsable = computeUsable(mergedResults);
  console.log(`\n[provider-probe] usable (fresh probe): ${usable.length ? usable.join(', ') : 'NONE'}`);
  if (IS_PARTIAL) {
    const stale = ALL_BACKENDS.filter((backend) => !SELECTED_BACKENDS.includes(backend));
    console.log(`[provider-probe] partial probe preserved cached rows for: ${stale.join(', ') || 'none'}`);
    console.log(`[provider-probe] cached usable outside this probe: ${cachedUsable.filter((backend) => !usable.includes(backend)).join(', ') || 'none'}`);
  }

  const out = {
    probed_at_ms: probedAtMs,
    timeout_ms: TIMEOUT,
    full_probe: !IS_PARTIAL,
    probed_backends: SELECTED_BACKENDS,
    usable,
    cached_usable: cachedUsable,
    results: mergedResults,
  };
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log(`[provider-probe] wrote ${path.relative(path.join(__dirname, '..'), outPath)}`);
  process.exit(0);
})();
