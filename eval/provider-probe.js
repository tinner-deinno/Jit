#!/usr/bin/env node
/**
 * eval/provider-probe.js — Provider liveness probe for the Mother fleet.
 *
 * Answers the #1 unknown before any swarm: which model backends are alive,
 * which are rate-limited, which are dead — with latency. Reuses the real
 * call path in hermes-discord/model-router.js (noRotate isolates each backend),
 * so a green here means that backend actually answers a chat request.
 *
 * Output:
 *   - markdown table to stdout
 *   - network/provider-status.json  { probed, results: { backend: {...} } }
 *
 * Usage: node eval/provider-probe.js [--timeout 20000]
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

const TIMEOUT = (() => {
  const i = process.argv.indexOf('--timeout');
  return i > -1 ? parseInt(process.argv[i + 1], 10) : 35000; // generous: ollama_mdes cold-start can take >20s
})();

// Backends to probe (keys in model-router BackendManager).
const BACKENDS = ['ollama_mdes', 'ollama_local', 'ollama_cloud', 'thaillm', 'copilot', 'openai', 'openclaude', 'innova_bot'];

const PING = [{ role: 'user', content: 'Reply with exactly: OK' }];

function classify(err) {
  const msg = String(err && err.message || err || '').toLowerCase();
  if (/\b(429|402|403|quota|rate.?limit|exhaust|too many)\b/.test(msg)) return 'RATE_LIMITED';
  if (/\b(401|unauthor|invalid.*(key|token)|missing.*(key|token))\b/.test(msg)) return 'AUTH';
  if (/(econn|enotfound|etimedout|timeout|socket|network|fetch failed|refused)/.test(msg)) return 'UNREACHABLE';
  return 'ERROR';
}

// A backend can answer HTTP-200 yet return an in-band error STRING (e.g.
// innova-bot's ask_local_ai returns "[SYSTEM OVERRIDE]: Local AI query failed"
// when its own backend is down). The ping asks for "OK", so a healthy reply
// contains "ok"; treat error-sentinel replies as a degraded ERROR, not ALIVE.
function isErrorReply(text) {
  const t = String(text || '');
  if (!t.trim()) return true;
  if (/\bok\b/i.test(t)) return false; // echoed the ping → healthy
  return /(system override|query failed|unavailable|not available|backend (failed|error)|i (cannot|can't|am unable)|error:)/i.test(t);
}

function probeOne(backend) {
  const t0 = Date.now();
  return Promise.race([
    router.callModelPromise(PING, { preferBackend: backend, noRotate: true, model: null }),
    new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), TIMEOUT)),
  ]).then(
    (r) => {
      const reply = String(r.reply || '');
      const bad = isErrorReply(reply);
      return {
        backend,
        status: bad ? 'ERROR' : 'ALIVE',
        ms: Date.now() - t0,
        served_by: r.backend,
        sample: reply.slice(0, 60).replace(/\s+/g, ' '),
        ...(bad ? { error: 'in-band error reply: ' + reply.slice(0, 60).replace(/\s+/g, ' ') } : {}),
      };
    },
    (e) => ({ backend, status: classify(e), ms: Date.now() - t0, error: String(e && e.message || e).slice(0, 80) })
  );
}

(async () => {
  console.log(`\n[provider-probe] timeout=${TIMEOUT}ms  probing ${BACKENDS.length} backends...\n`);
  const results = {};
  // Probe in parallel — independent backends.
  const arr = await Promise.all(BACKENDS.map(probeOne));
  for (const r of arr) results[r.backend] = r;

  const icon = { ALIVE: '🟢', RATE_LIMITED: '🟡', AUTH: '🔑', UNREACHABLE: '🔌', ERROR: '🔴' };
  console.log('| backend | status | latency | detail |');
  console.log('|---|---|---|---|');
  for (const b of BACKENDS) {
    const r = results[b];
    const detail = r.status === 'ALIVE'
      ? `served_by=${r.served_by}${r.served_by !== b ? ' ⚠fell-back' : ''} "${r.sample}"`
      : (r.error || '');
    console.log(`| ${b} | ${icon[r.status] || ''} ${r.status} | ${r.ms}ms | ${detail} |`);
  }

  const alive = arr.filter(r => r.status === 'ALIVE' && r.served_by === r.backend).map(r => r.backend);
  console.log(`\n[provider-probe] usable (answered as themselves): ${alive.length ? alive.join(', ') : 'NONE'}`);

  const out = { probed_at_ms: Date.now(), timeout_ms: TIMEOUT, usable: alive, results };
  const outPath = path.join(__dirname, '..', 'network', 'provider-status.json');
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log(`[provider-probe] wrote ${path.relative(path.join(__dirname, '..'), outPath)}`);
  process.exit(0);
})();
