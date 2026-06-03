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

async function run(goal, max) {
  loadEnv();
  const MotherEngine = require('./limbs/mother-engine');
  console.log(`\n🌀 Mother — multi-phase goal: "${goal}"\n`);
  const engine = new MotherEngine();
  if (engine.liveProvider) console.log(`   provider: ${engine.liveProvider.backend} (${engine.liveProvider.model || 'default'})`);
  const t0 = Date.now();
  const out = await engine.runGoal(goal, max);
  console.log(`\n── ${out.phases.length} phases complete (${Date.now() - t0}ms) ──`);
  out.summaries.forEach((s, i) => console.log(`\n${i + 1}. ${s}`));
  console.log('\n✓ all phases recorded → `node mother.js events` | `node mother.js status`\n');
  process.exit(0);
}

function showArtifacts(runArg) {
  const base = path.join(ROOT, 'network', 'artifacts');
  if (!fs.existsSync(base)) { console.log('No artifacts yet. Run: node mother.js run "<goal>"'); return; }
  const runs = fs.readdirSync(base).filter(d => { try { return fs.statSync(path.join(base, d)).isDirectory(); } catch { return false; } })
    // Numeric sort by the run-<epoch> timestamp (lexicographic mis-orders a
    // non-numeric run name); fall back to string compare on ties.
    .sort((a, b) => ((+(a.match(/\d+/) || [0])[0]) - (+(b.match(/\d+/) || [0])[0])) || a.localeCompare(b));
  if (!runs.length) { console.log('No artifact runs yet.'); return; }
  const run = runArg && runs.includes(runArg) ? runArg : runs[runs.length - 1];
  const dir = path.join(base, run);
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.md')).sort();
  console.log(`\nArtifacts for ${run} (${files.length} phase file(s)) — ${runs.length} run(s) total:\n`);
  for (const f of files) {
    const txt = fs.readFileSync(path.join(dir, f), 'utf8');
    console.log(`── ${f} ──`);
    console.log(txt.slice(0, 700).replace(/\n{3,}/g, '\n\n'));
    console.log(txt.length > 700 ? `… (${txt.length} chars total)\n` : '');
  }
}

async function inbox(role) {
  loadEnv();
  const InnovaBotBridge = require('./limbs/innova-bot-bridge');
  const bridge = new InnovaBotBridge();
  const r = role || 'innova';
  console.log(`\n📥 Mother inbox — A2A events for role "${r}" (from innova-bot bus)\n`);
  try {
    await bridge.connect();
    const res = await bridge.fetchPendingEvents(r);
    const events = (res && res.structuredContent && res.structuredContent.result)
      || (res && Array.isArray(res.result) && res.result) || [];
    if (!events.length) { console.log('  (no pending events)'); }
    else events.forEach((e, i) => {
      const o = typeof e === 'string' ? { raw: e } : (e || {});
      const from = o.source || o.from || (o.payload && o.payload.source) || '?';
      console.log(`  ${i + 1}. topic=${o.topic || '?'}  from=${from}  ${o.ts || ''}`);
      const payload = o.payload != null ? (typeof o.payload === 'string' ? o.payload : JSON.stringify(o.payload)) : (o.raw || '');
      if (payload) console.log(`     ${String(payload).slice(0, 200)}`);
    });
    console.log('');
  } catch (e) {
    console.error(`  bridge error: ${e.message}`);
    process.exit(1);
  }
  process.exit(0);
}

function help() {
  console.log(`
mother.js — innomcp front door

  node mother.js chat "<goal>"       run ONE Mother phase (live providers)
  node mother.js run "<goal>" [--phases N]   decompose into <=N phases (default 4) and run all
  node mother.js status              unified status board (no quota)
  node mother.js doctor              health self-diagnostic + blockers (no quota)
  node mother.js test                run all no-provider regression checks (no quota)
  node mother.js probe               refresh provider liveness (no LLM)
  node mother.js events [N]          last N dispatch events (default 10)
  node mother.js artifacts [runId]   show phase output artifacts (latest run)
  node mother.js inbox [role]        fetch pending A2A events from innova-bot (default role: innova)
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
  case 'run': {
    // Phase count via explicit --phases N (NOT a trailing digit, which would
    // steal a number that's legitimately part of the goal, e.g. "fix bug 3").
    let max = 4; const parts = [];
    for (let i = 0; i < rest.length; i++) {
      if ((rest[i] === '--phases' || rest[i] === '-n') && /^\d+$/.test(rest[i + 1] || '')) max = parseInt(rest[++i], 10);
      else parts.push(rest[i]);
    }
    const goal = parts.join(' ').trim();
    if (!goal) { console.error('Usage: node mother.js run "<goal>" [--phases N]'); process.exit(2); }
    run(goal, Math.max(1, Math.min(8, max))).catch(e => { console.error(`[Error] ${e && e.message || e}`); process.exit(1); });
    break;
  }
  case 'status': case 'board': runScript('eval/status-board.js'); break;
  case 'doctor': runScript('eval/doctor.js'); break;
  case 'test': runScript('eval/check-all.js'); break;
  case 'probe': runScript('eval/provider-probe.js', rest); break;
  case 'events': showEvents(parseInt(rest[0], 10) || 10); break;
  case 'artifacts': showArtifacts(rest[0]); break;
  case 'inbox': inbox(rest[0]).catch(e => { console.error(`[Error] ${e && e.message || e}`); process.exit(1); }); break;
  case 'help': case undefined: help(); break;
  default: console.error(`Unknown command: ${cmd}`); help(); process.exit(2);
}
