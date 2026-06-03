#!/usr/bin/env node
/**
 * eval/doctor.js — Mother self-diagnostic. One command that answers
 * "what's healthy and what's blocking?" across the whole system. No LLM quota.
 *
 * Checks: provider liveness (cached probe), innova-bot bridge, git push gate,
 * leaderboard integrity, recent dispatch success rate. Prints a prioritized
 * DIAGNOSIS with concrete next actions.
 *
 *   node eval/doctor.js
 */
const fs = require('fs');
const path = require('path');
const http = require('http');
const { execSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const envPath = path.join(ROOT, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
const readJSON = (p, f) => { try { const v = JSON.parse(fs.readFileSync(p, 'utf8')); return (v && typeof v === 'object') ? v : f; } catch { return f; } };
const git = (cmd) => { try { return execSync(cmd, { cwd: ROOT, encoding: 'utf8' }).trim(); } catch { return ''; } };

function pingBridge(timeoutMs = 2500) {
  return new Promise((resolve) => {
    const url = process.env.INNOVA_BOT_GUI_URL || 'http://127.0.0.1:7010/gui';
    let u; try { u = new URL(url); } catch { return resolve({ up: false, detail: 'bad URL' }); }
    // Require 2xx for a true health signal (per GPT-5.5 review): a 404/401/3xx
    // means something is listening but the bridge GUI isn't actually serving —
    // that's a false-green, so treat it as DOWN.
    const req = http.get({ host: u.hostname, port: u.port, path: u.pathname, timeout: timeoutMs }, (res) => { res.resume(); resolve({ up: res.statusCode >= 200 && res.statusCode < 300, detail: `HTTP ${res.statusCode}` }); });
    req.on('timeout', () => { req.destroy(); resolve({ up: false, detail: 'timeout' }); });
    req.on('error', (e) => resolve({ up: false, detail: e.code || e.message }));
  });
}

(async () => {
  const blockers = []; const warnings = []; const ok = [];

  // 1. Providers (cached probe)
  const ps = readJSON(path.join(ROOT, 'network', 'provider-status.json'), null);
  if (!ps) { warnings.push('No provider probe yet — run `node mother.js probe`.'); }
  else {
    const ageMin = ps.probed_at_ms ? Math.round((Date.now() - ps.probed_at_ms) / 60000) : '?';
    const usable = ps.usable || [];
    if (!usable.length) blockers.push('No usable providers in last probe — squad has no engine. Re-probe / restore creds.');
    else ok.push(`Providers usable: ${usable.join(', ')} (probed ${ageMin}m ago)`);
    const degraded = Object.entries(ps.results || {}).filter(([, r]) => r.status !== 'ALIVE').map(([b, r]) => `${b}:${r.status}`);
    if (degraded.length) warnings.push(`Degraded lanes: ${degraded.join(', ')}`);
    if (ageMin !== '?' && ageMin > 30) warnings.push(`Provider probe is stale (${ageMin}m) — re-probe for accurate routing.`);
  }

  // 1b. Circuit breakers (persisted) — surface lanes currently tripped.
  const breaker = readJSON(path.join(ROOT, 'network', 'breaker-state.json'), {});
  const now = Date.now();
  const cd = (() => { const n = Math.floor(Number(process.env.BREAKER_COOLDOWN_MS)); return Number.isFinite(n) && n > 0 ? n : 60000; })();
  const tripped = Object.entries(breaker).filter(([, t]) => typeof t === 'number' && (now - t) < cd)
    .map(([b, t]) => `${b} (${Math.round((cd - (now - t)) / 1000)}s left)`);
  if (tripped.length) warnings.push(`Circuit breaker OPEN: ${tripped.join(', ')} — these lanes are being skipped until cooldown.`);

  // 2. innova-bot bridge
  const bridge = await pingBridge();
  if (bridge.up) ok.push(`innova-bot bridge UP (${bridge.detail})`);
  else warnings.push(`innova-bot bridge DOWN (${bridge.detail}) — phase notifications/A2A won't reach the bot.`);

  // 3. Git push gate (the recurring blocker)
  const ahead = git('git rev-list --count origin/main..HEAD');
  if (ahead && parseInt(ahead, 10) > 0) blockers.push(`${ahead} commits unpushed (origin/main). Run \`git push origin main\` (fix PAT 'workflow' scope if rejected).`);
  else if (ahead === '0') ok.push('Git in sync with origin/main.');
  else warnings.push('Could not compare to origin/main (no remote tracking?).');

  // 4. Leaderboard integrity
  const lb = readJSON(path.join(ROOT, 'network', 'leaderboard.json'), { fleet: {} });
  const fleet = lb.fleet || {};
  const agents = Object.keys(fleet).length;
  const bad = Object.values(fleet).filter(v => !(v.correctness_score >= 0 && v.correctness_score <= 100)).length;
  if (agents < 1) warnings.push('Leaderboard fleet empty.');
  else ok.push(`Leaderboard: ${agents} agents` + (bad ? ` (${bad} out-of-range!)` : ''));
  if (bad) blockers.push(`${bad} leaderboard scores out of [0,100] — run a phase to re-clamp or inspect.`);

  // 5. Recent dispatch success
  const evp = path.join(ROOT, 'network', 'mother-events.jsonl');
  if (fs.existsSync(evp)) {
    const rows = fs.readFileSync(evp, 'utf8').split(/\r?\n/).filter(Boolean).map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
    const recent = rows.slice(-5);
    const avgVerdict = recent.map(e => { const n = (Array.isArray(e.verdicts) ? e.verdicts : []).map(Number).filter(x => !isNaN(x)); return n.length ? n.reduce((a, b) => a + b, 0) / n.length : null; }).filter(x => x != null);
    if (avgVerdict.length) {
      const mean = avgVerdict.reduce((a, b) => a + b, 0) / avgVerdict.length;
      ok.push(`Recent ${recent.length} phases avg verdict ${mean.toFixed(0)}/100`);
      if (mean < 50) warnings.push(`Recent phase quality low (avg ${mean.toFixed(0)}) — check provider/verifier health.`);
    }
  } else warnings.push('No dispatch events yet — run `node mother.js chat "<goal>"`.');

  // Report
  console.log('\n🩺 MOTHER DOCTOR\n');
  console.log('✅ HEALTHY'); ok.forEach(s => console.log('   • ' + s));
  if (warnings.length) { console.log('\n⚠️  WARNINGS'); warnings.forEach(s => console.log('   • ' + s)); }
  if (blockers.length) { console.log('\n🔴 BLOCKERS (do these)'); blockers.forEach((s, i) => console.log(`   ${i + 1}. ${s}`)); }
  else console.log('\n🟢 No hard blockers.');
  console.log(`\nverdict: ${blockers.length ? 'ACTION NEEDED' : warnings.length ? 'OK with warnings' : 'ALL GREEN'}\n`);
  process.exit(blockers.length ? 1 : 0);
})();
