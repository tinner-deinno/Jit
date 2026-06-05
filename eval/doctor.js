#!/usr/bin/env node
/**
 * eval/doctor.js - Mother self-diagnostic.
 *
 * Checks: provider liveness (cached probe), innova-bot bridge, git push gate,
 * leaderboard integrity, recent dispatch success rate.
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

const readJSON = (filePath, fallback) => {
  try {
    const value = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return value && typeof value === 'object' ? value : fallback;
  } catch {
    return fallback;
  }
};

const git = (cmd) => {
  try {
    return execSync(cmd, { cwd: ROOT, encoding: 'utf8' }).trim();
  } catch {
    return '';
  }
};

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

(async () => {
  const blockers = [];
  const warnings = [];
  const ok = [];

  const ps = readJSON(path.join(ROOT, 'network', 'provider-status.json'), null);
  if (!ps) {
    warnings.push('No provider probe yet - run `node mother.js probe`.');
  } else {
    const ageMin = ps.probed_at_ms ? Math.round((Date.now() - ps.probed_at_ms) / 60000) : '?';
    const usable = Array.isArray(ps.usable) ? ps.usable : [];
    const cachedUsable = Array.isArray(ps.cached_usable) ? ps.cached_usable : [];
    const probeMode = ps.full_probe === false ? 'partial' : 'full';
    const probedBackends = Array.isArray(ps.probed_backends) && ps.probed_backends.length ? ps.probed_backends : ['all'];

    if (usable.length) {
      ok.push(`Fresh usable providers: ${usable.join(', ')} (${probeMode} probe ${probedBackends.join(', ')}, ${ageMin}m ago)`);
    } else if (probeMode === 'full') {
      blockers.push('No usable providers in the last full probe - squad has no engine. Re-probe or restore creds.');
    } else {
      warnings.push(`Fresh usable providers are empty in a partial probe (${probedBackends.join(', ')}). This is incomplete evidence, not a full outage.`);
    }

    if (probeMode === 'partial') {
      const cachedExtra = cachedUsable.filter((backend) => !usable.includes(backend));
      warnings.push(`Provider snapshot is partial (${probedBackends.join(', ')}); routing should use fresh usable only${cachedExtra.length ? `. Cached usable outside this probe: ${cachedExtra.join(', ')}` : '.'}`);
    }

    const degraded = Object.entries(ps.results || {})
      .filter(([, row]) => row.status !== 'ALIVE')
      .map(([backend, row]) => `${backend}:${row.status}`);
    if (degraded.length) warnings.push(`Degraded lanes: ${degraded.join(', ')}`);
    if (ageMin !== '?' && ageMin > 30) warnings.push(`Provider probe is stale (${ageMin}m) - re-probe for accurate routing.`);
  }

  const breaker = readJSON(path.join(ROOT, 'network', 'breaker-state.json'), {});
  const now = Date.now();
  const cooldownMs = (() => {
    const n = Math.floor(Number(process.env.BREAKER_COOLDOWN_MS));
    return Number.isFinite(n) && n > 0 ? n : 60000;
  })();
  const tripped = Object.entries(breaker)
    .filter(([, timestamp]) => typeof timestamp === 'number' && (now - timestamp) < cooldownMs)
    .map(([backend, timestamp]) => `${backend} (${Math.round((cooldownMs - (now - timestamp)) / 1000)}s left)`);
  if (tripped.length) warnings.push(`Circuit breaker OPEN: ${tripped.join(', ')} - these lanes are being skipped until cooldown.`);

  const bridge = await pingBridge();
  if (bridge.up) ok.push(`innova-bot bridge UP (${bridge.detail})`);
  else warnings.push(`innova-bot bridge DOWN (${bridge.detail}) - phase notifications/A2A will miss the bot.`);

  const ahead = git('git rev-list --count origin/main..HEAD');
  if (ahead && parseInt(ahead, 10) > 0) blockers.push(`${ahead} commits unpushed (origin/main). Run \`git push origin main\` once credentials are fixed.`);
  else if (ahead === '0') ok.push('Git in sync with origin/main.');
  else warnings.push('Could not compare to origin/main (no remote tracking?).');

  const lb = readJSON(path.join(ROOT, 'network', 'leaderboard.json'), { fleet: {} });
  const fleet = lb.fleet || {};
  const agents = Object.keys(fleet).length;
  const bad = Object.values(fleet).filter((value) => !(value.correctness_score >= 0 && value.correctness_score <= 100)).length;
  if (agents < 1) warnings.push('Leaderboard fleet empty.');
  else ok.push(`Leaderboard: ${agents} agents${bad ? ` (${bad} out-of-range)` : ''}`);
  if (bad) blockers.push(`${bad} leaderboard scores are out of [0,100] - run a phase to re-clamp or inspect.`);

  const eventsPath = path.join(ROOT, 'network', 'mother-events.jsonl');
  if (fs.existsSync(eventsPath)) {
    const rows = fs.readFileSync(eventsPath, 'utf8')
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
    const recent = rows.slice(-5);
    const avgVerdict = recent
      .map((event) => {
        const nums = (Array.isArray(event.verdicts) ? event.verdicts : []).map(Number).filter((value) => !Number.isNaN(value));
        return nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : null;
      })
      .filter((value) => value != null);
    if (avgVerdict.length) {
      const mean = avgVerdict.reduce((a, b) => a + b, 0) / avgVerdict.length;
      ok.push(`Recent ${recent.length} phases avg verdict ${mean.toFixed(0)}/100`);
      if (mean < 50) warnings.push(`Recent phase quality is low (avg ${mean.toFixed(0)}) - check provider/verifier health.`);
    }
  } else {
    warnings.push('No dispatch events yet - run `node mother.js chat "<goal>"`.');
  }

  console.log('\n[MOTHER DOCTOR]\n');
  console.log('[HEALTHY]');
  ok.forEach((line) => console.log('  - ' + line));
  if (warnings.length) {
    console.log('\n[WARNINGS]');
    warnings.forEach((line) => console.log('  - ' + line));
  }
  if (blockers.length) {
    console.log('\n[BLOCKERS]');
    blockers.forEach((line, index) => console.log(`  ${index + 1}. ${line}`));
  } else {
    console.log('\n[BLOCKERS]');
    console.log('  none');
  }
  console.log(`\nverdict: ${blockers.length ? 'ACTION NEEDED' : warnings.length ? 'OK WITH WARNINGS' : 'ALL GREEN'}\n`);
  process.exit(blockers.length ? 1 : 0);
})();
