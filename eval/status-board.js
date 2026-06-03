#!/usr/bin/env node
/**
 * eval/status-board.js — Unified Mother control surface (Manus-like).
 *
 * Read-only aggregator over everything the system records:
 *   - provider health      (network/provider-status.json)
 *   - agent leaderboard    (network/leaderboard.json)
 *   - dispatch history      (network/mother-events.jsonl)
 *   - innova-bot bridge     (live GUI/health ping, short timeout)
 *
 * Prints one dashboard. Burns no LLM quota. Use it to see system state at a glance.
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

function readJSON(p, fallback) {
  // Note: JSON.parse('null') returns null without throwing, so an explicit
  // object check is needed — otherwise a literal `null` artifact bypasses the
  // catch and crashes downstream property access.
  try { const v = JSON.parse(fs.readFileSync(p, 'utf8')); return (v && typeof v === 'object') ? v : fallback; }
  catch { return fallback; }
}

function readEvents() {
  const p = path.join(ROOT, 'network', 'mother-events.jsonl');
  if (!fs.existsSync(p)) return [];
  return fs.readFileSync(p, 'utf8').split(/\r?\n/).filter(Boolean)
    .map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
}

function pingBridge(timeoutMs = 2500) {
  return new Promise((resolve) => {
    const url = process.env.INNOVA_BOT_GUI_URL || 'http://127.0.0.1:7010/gui';
    let u; try { u = new URL(url); } catch { return resolve({ up: false, detail: 'bad URL' }); }
    const req = http.get({ host: u.hostname, port: u.port, path: u.pathname, timeout: timeoutMs }, (res) => {
      res.resume();
      resolve({ up: res.statusCode < 500, detail: `HTTP ${res.statusCode}` });
    });
    req.on('timeout', () => { req.destroy(); resolve({ up: false, detail: 'timeout' }); });
    req.on('error', (e) => resolve({ up: false, detail: e.code || e.message }));
  });
}

function ageStr(ms) {
  if (!ms || isNaN(ms)) return '?';
  const s = Math.round((Date.now() - ms) / 1000);
  if (s < 90) return `${s}s ago`;
  if (s < 5400) return `${Math.round(s / 60)}m ago`;
  return `${Math.round(s / 3600)}h ago`;
}

(async () => {
  const ps = readJSON(path.join(ROOT, 'network', 'provider-status.json'), { results: {}, usable: [] });
  const lb = readJSON(path.join(ROOT, 'network', 'leaderboard.json'), { fleet: {} });
  const events = readEvents();
  const bridge = await pingBridge();
  // Learned provider reliability (Iteration 6) — optional, DB may be absent.
  let provStats = {};
  try { provStats = require(path.join(ROOT, 'limbs', 'leaderboard-db')).getProviderStats(); } catch (_) { provStats = {}; }

  // Provider usage counts from event history.
  const provUse = {};
  for (const e of events) { const p = e.provider || '?'; provUse[p] = (provUse[p] || 0) + 1; }

  const icon = { ALIVE: '🟢', RATE_LIMITED: '🟡', AUTH: '🔑', UNREACHABLE: '🔌', ERROR: '🔴' };

  if (process.argv.includes('--json')) {
    console.log(JSON.stringify({ providers: ps.results, usable: ps.usable, fleet: lb.fleet, events: events.slice(-10), bridge, provUse }, null, 2));
    return;
  }

  console.log('\n╔══════════════════════════════════════════════════════════╗');
  console.log('║            MOTHER STATUS BOARD (innomcp)                  ║');
  console.log('╚══════════════════════════════════════════════════════════╝');

  console.log(`\n▍ INNOVA-BOT BRIDGE   ${bridge.up ? '🟢 UP' : '🔴 DOWN'}  (${bridge.detail})`);

  console.log(`\n▍ PROVIDERS   probed ${ageStr(ps.probed_at_ms)}   usable: ${(ps.usable || []).join(', ') || 'NONE'}`);
  console.log('  ' + 'backend'.padEnd(15) + 'status'.padEnd(16) + 'latency'.padEnd(10) + 'phases'.padEnd(8) + 'reliability');
  for (const [b, r] of Object.entries(ps.results || {})) {
    const s = provStats[b];
    const rel = s && s.calls ? `${Math.round(s.success_rate * 100)}% (${s.calls})` : '—';
    console.log('  ' + b.padEnd(15) + `${icon[r.status] || ''} ${r.status}`.padEnd(16) + `${r.ms ?? '?'}ms`.padEnd(10) + String(provUse[b] || 0).padEnd(8) + rel);
  }

  const proven = Object.entries(lb.fleet || {})
    .filter(([, v]) => !v.provisional)
    .sort((a, b) => (b[1].correctness_score || 0) - (a[1].correctness_score || 0)).slice(0, 7);
  console.log('\n▍ LEADERBOARD (proven agents)');
  console.log('  ' + '#'.padEnd(4) + 'agent'.padEnd(16) + 'score'.padEnd(9) + 'tasks');
  proven.forEach(([k, v], i) => console.log('  ' + String(i + 1).padEnd(4) + k.padEnd(16) + (+v.correctness_score).toFixed(2).padEnd(9) + v.completed_tasks));

  console.log(`\n▍ RECENT PHASES   (${events.length} total)`);
  for (const e of events.slice(-5)) {
    const nums = (Array.isArray(e.verdicts) ? e.verdicts : []).map(Number).filter(n => !isNaN(n));
    const v = nums.length ? `avg ${(nums.reduce((a, b) => a + b, 0) / nums.length).toFixed(0)}` : 'no-verdict';
    console.log(`  ${(e.ts || '').slice(5, 16)}  ${(e.phase || '?').padEnd(14)} ${(e.provider || '?').padEnd(13)} ${v.padEnd(11)} ${e.durationMs || '?'}ms`);
  }
  if (!events.length) console.log('  (no phases recorded yet — run a phase via mother-engine)');
  console.log('');
})();
