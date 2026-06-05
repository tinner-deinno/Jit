#!/usr/bin/env node
/**
 * eval/status-board.js - Unified Mother control surface.
 *
 * Read-only aggregator over everything the system records:
 *   - provider health     (network/provider-status.json)
 *   - agent leaderboard   (network/leaderboard.json)
 *   - dispatch history    (network/mother-events.jsonl)
 *   - innova-bot bridge   (live GUI/health ping, short timeout)
 *
 * Prints one dashboard. Burns no LLM quota.
 *   node eval/status-board.js [--json]
 */
const fs = require('fs');
const path = require('path');
const http = require('http');

const ROOT = path.join(__dirname, '..');
const envPath = path.join(ROOT, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

function readJSON(filePath, fallback) {
  try {
    const value = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return value && typeof value === 'object' ? value : fallback;
  } catch {
    return fallback;
  }
}

function readEvents() {
  const filePath = path.join(ROOT, 'network', 'mother-events.jsonl');
  if (!fs.existsSync(filePath)) return [];
  return fs.readFileSync(filePath, 'utf8')
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

function pingBridge(timeoutMs = 2500) {
  return new Promise((resolve) => {
    const url = process.env.INNOVA_BOT_GUI_URL || 'http://127.0.0.1:7010/gui';
    let parsed;
    try {
      parsed = new URL(url);
    } catch {
      resolve({ up: false, detail: 'bad URL' });
      return;
    }
    const req = http.get({ host: parsed.hostname, port: parsed.port, path: parsed.pathname, timeout: timeoutMs }, (res) => {
      res.resume();
      resolve({ up: res.statusCode >= 200 && res.statusCode < 300, detail: `HTTP ${res.statusCode}` });
    });
    req.on('timeout', () => {
      req.destroy();
      resolve({ up: false, detail: 'timeout' });
    });
    req.on('error', (error) => resolve({ up: false, detail: error.code || error.message }));
  });
}

function ageStr(ms) {
  if (!ms || Number.isNaN(ms)) return '?';
  const seconds = Math.round((Date.now() - ms) / 1000);
  if (seconds < 90) return `${seconds}s ago`;
  if (seconds < 5400) return `${Math.round(seconds / 60)}m ago`;
  return `${Math.round(seconds / 3600)}h ago`;
}

function providerProbeMeta(ps) {
  return {
    mode: ps.full_probe === false ? 'partial' : 'full',
    probedBackends: Array.isArray(ps.probed_backends) && ps.probed_backends.length ? ps.probed_backends : ['all'],
    cachedUsable: Array.isArray(ps.cached_usable) ? ps.cached_usable : [],
  };
}

function providerFreshness(ps, backend, row) {
  const probed = Array.isArray(ps.probed_backends) ? ps.probed_backends : [];
  if (ps.full_probe === false && probed.length && !probed.includes(backend)) return 'cached';
  return ageStr(row && row.probed_at_ms ? row.probed_at_ms : ps.probed_at_ms);
}

(async () => {
  const ps = readJSON(path.join(ROOT, 'network', 'provider-status.json'), { results: {}, usable: [] });
  const lb = readJSON(path.join(ROOT, 'network', 'leaderboard.json'), { fleet: {} });
  const events = readEvents();
  const bridge = await pingBridge();
  const probeMeta = providerProbeMeta(ps);

  let provStats = {};
  try {
    provStats = require(path.join(ROOT, 'limbs', 'leaderboard-db')).getProviderStats();
  } catch (_) {
    provStats = {};
  }

  const provUse = {};
  for (const event of events) {
    const provider = event.provider || '?';
    provUse[provider] = (provUse[provider] || 0) + 1;
  }

  if (process.argv.includes('--json')) {
    console.log(JSON.stringify({
      providerProbe: probeMeta,
      providers: ps.results,
      usable: ps.usable,
      cachedUsable: probeMeta.cachedUsable,
      fleet: lb.fleet,
      events: events.slice(-10),
      bridge,
      provUse,
    }, null, 2));
    return;
  }

  const statusLabel = { ALIVE: 'OK', RATE_LIMITED: 'LIMIT', AUTH: 'AUTH', UNREACHABLE: 'DOWN', ERROR: 'ERR' };

  console.log('\n[MOTHER STATUS BOARD]');
  console.log(`\n[INNOVA-BOT BRIDGE] ${bridge.up ? 'UP' : 'DOWN'} (${bridge.detail})`);
  console.log(`\n[PROVIDERS] probed ${ageStr(ps.probed_at_ms)} scope=${probeMeta.mode}:${probeMeta.probedBackends.join(',')} fresh usable: ${(ps.usable || []).join(', ') || 'NONE'}`);
  if (probeMeta.cachedUsable.length) {
    console.log(`  cached usable: ${probeMeta.cachedUsable.join(', ')}`);
  }
  console.log('  ' + 'backend'.padEnd(15) + 'status'.padEnd(10) + 'fresh'.padEnd(10) + 'latency'.padEnd(10) + 'phases'.padEnd(8) + 'reliability');
  for (const [backend, row] of Object.entries(ps.results || {})) {
    const stat = provStats[backend];
    const reliability = stat && stat.calls ? `${Math.round(stat.success_rate * 100)}% (${stat.calls})` : '-';
    const freshness = providerFreshness(ps, backend, row);
    console.log(
      '  ' +
      backend.padEnd(15) +
      `${statusLabel[row.status] || row.status || '?'}`.padEnd(10) +
      freshness.padEnd(10) +
      `${row.ms ?? '?'}ms`.padEnd(10) +
      String(provUse[backend] || 0).padEnd(8) +
      reliability
    );
  }

  const proven = Object.entries(lb.fleet || {})
    .filter(([, value]) => !value.provisional)
    .sort((a, b) => (b[1].correctness_score || 0) - (a[1].correctness_score || 0))
    .slice(0, 7);
  console.log('\n[LEADERBOARD] proven agents');
  console.log('  ' + '#'.padEnd(4) + 'agent'.padEnd(16) + 'score'.padEnd(9) + 'tasks');
  proven.forEach(([agent, value], index) => {
    console.log('  ' + String(index + 1).padEnd(4) + agent.padEnd(16) + (+value.correctness_score).toFixed(2).padEnd(9) + value.completed_tasks);
  });

  console.log(`\n[RECENT PHASES] ${events.length} total`);
  for (const event of events.slice(-5)) {
    const nums = (Array.isArray(event.verdicts) ? event.verdicts : []).map(Number).filter((n) => !Number.isNaN(n));
    const verdict = nums.length ? `avg ${(nums.reduce((a, b) => a + b, 0) / nums.length).toFixed(0)}` : 'no-verdict';
    console.log(`  ${(event.ts || '').slice(5, 16)}  ${(event.phase || '?').padEnd(14)} ${(event.provider || '?').padEnd(13)} ${verdict.padEnd(11)} ${event.durationMs || '?'}ms`);
  }
  if (!events.length) console.log('  (no phases recorded yet - run a phase via mother-engine)');
  console.log('');
})();
