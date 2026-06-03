#!/usr/bin/env node
/**
 * mother.js — the innomcp front door (Manus-like control CLI).
 *
 * One entry point to drive the whole Mother system:
 *   node mother.js chat "<goal>"   run a Mother phase on a goal; stream the
 *                                  squad -> verify -> leaderboard -> event loop
 *   node mother.js status          unified status board (providers/board/bridge)
 *   node mother.js probe           refresh provider liveness
 *   node mother.js events [N]      show the last N dispatch events (default 10)
 *   node mother.js help
 *
 * `chat` runs live providers (may be slow if the cheap lane is cold); the other
 * commands burn no LLM quota.
 */
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = __dirname;
function loadEnv() {
  const envPath = path.join(ROOT, '.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

function runScript(rel, args = []) {
  // Delegate to an existing eval script, inheriting stdio so output streams.
  try { execFileSync(process.execPath, [path.join(ROOT, rel), ...args], { stdio: 'inherit' }); }
  catch (e) { /* the child already printed; preserve its exit intent */ process.exitCode = e.status || 1; }
}

function showEvents(n) {
  const p = path.join(ROOT, 'network', 'mother-events.jsonl');
  if (!fs.existsSync(p)) { console.log('No events yet. Run: node mother.js chat "<goal>"'); return; }
  const rows = fs.readFileSync(p, 'utf8').split(/\r?\n/).filter(Boolean)
    .map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  const last = rows.slice(-n);
  console.log(`\nLast ${last.length} of ${rows.length} dispatch events:\n`);
  for (const e of last) {
    const nums = (Array.isArray(e.verdicts) ? e.verdicts : []).map(Number).filter(x => !isNaN(x));
    const avg = nums.length ? `avg ${(nums.reduce((a, b) => a + b, 0) / nums.length).toFixed(0)}` : 'no-verdict';
    console.log(`  ${(e.ts || '').slice(0, 16)}  ${(e.phase || '?').padEnd(14)} ${(e.provider || '?').padEnd(13)} ${avg.padEnd(11)} ${e.durationMs || '?'}ms  [${(e.squad || []).join(',')}]`);
  }
  console.log('');
}

async function chat(goal) {
  loadEnv();
  const MotherEngine = require('./limbs/mother-engine');
  const LB = path.join(ROOT, 'network', 'leaderboard.json');
  const snap = () => { try { const f = JSON.parse(fs.readFileSync(LB, 'utf8')).fleet || {}; const o = {}; for (const k in f) o[k] = f[k].correctness_score; return o; } catch { return {}; } };

  console.log(`\n🌀 Mother — goal: "${goal}"\n`);
  // Construct FIRST: the constructor hydrates the leaderboard from the DB and
  // rewrites the JSON. Snapshot AFTER so the delta reflects this phase only,
  // not the (unrelated) DB->JSON hydration sync.
  const engine = new MotherEngine();
  if (engine.liveProvider) console.log(`   provider: ${engine.liveProvider.backend} (${engine.liveProvider.model || 'default'})`);
  else console.log('   provider: router rotation (no probe — run `node mother.js probe`)');
  const before = snap();

  const t0 = Date.now();
  const results = await engine.executePhase('Chat', goal);
  const after = snap();
  const failed = results && !Array.isArray(results) && results.error;

  console.log(`\n── result (${Date.now() - t0}ms) ──`);
  if (Array.isArray(results)) {
    for (const r of results) {
      console.log(`\n● ${r.agent} (${r.backend}):`);
      console.log('  ' + String(r.reply || '(empty)').replace(/\n/g, '\n  ').slice(0, 600));
    }
  } else {
    console.log('  ' + JSON.stringify(results).slice(0, 400));
  }

  const moved = Object.keys(after).filter(k => before[k] !== after[k]);
  if (moved.length) {
    console.log('\n── leaderboard delta ──');
    for (const k of moved) console.log(`  ${k}: ${(+before[k] || 0).toFixed(2)} → ${(+after[k]).toFixed(2)}`);
  }
  if (failed) {
    console.error(`\n✗ phase failed: ${failed}\n`);
    process.exit(1);
  }
  console.log('\n✓ phase recorded → `node mother.js events` | `node mother.js status`\n');
  process.exit(0);
}

function help() {
  console.log(`
mother.js — innomcp front door

  node mother.js chat "<goal>"   run a Mother phase (live providers)
  node mother.js status          unified status board (no quota)
  node mother.js probe           refresh provider liveness (no LLM)
  node mother.js events [N]      last N dispatch events (default 10)
  node mother.js help
`);
}

const [cmd, ...rest] = process.argv.slice(2);
switch (cmd) {
  case 'chat': {
    const goal = rest.join(' ').trim();
    if (!goal) { console.error('Usage: node mother.js chat "<goal>"'); process.exit(2); }
    chat(goal).catch(e => { console.error(`[Error] ${e && e.message || e}`); process.exit(1); });
    break;
  }
  case 'status': case 'board': runScript('eval/status-board.js'); break;
  case 'probe': runScript('eval/provider-probe.js', rest); break;
  case 'events': showEvents(parseInt(rest[0], 10) || 10); break;
  case 'help': case undefined: help(); break;
  default: console.error(`Unknown command: ${cmd}`); help(); process.exit(2);
}
