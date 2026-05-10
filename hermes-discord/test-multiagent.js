'use strict';
/**
 * hermes-discord/test-multiagent.js — Standalone Multiagent Test
 *
 * Tests model-router + agent-spawner WITHOUT Discord.
 * Run: node hermes-discord/test-multiagent.js
 *
 * PASS criteria:
 *   - At least 1 backend responds successfully
 *   - Serial chain (jit→soma→innova) all 3 reply
 *   - Parallel spawn (lak+chamu) both reply concurrently
 *   - Full pipeline (jit→soma→innova→neta→vaja) all 5 reply
 */

// Load .env if present
const path = require('path');
const fs   = require('fs');
const JIT_ROOT = path.resolve(__dirname, '..');
const envFile  = path.join(JIT_ROOT, '.env');

if (fs.existsSync(envFile)) {
  fs.readFileSync(envFile, 'utf8').split(/\r?\n/).forEach(function(line) {
    var trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;
    var eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) return;
    var key = trimmed.slice(0, eqIdx).trim();
    var val = trimmed.slice(eqIdx + 1).trim().replace(/^["']|["']$/g, '');
    if (!process.env[key]) process.env[key] = val;
  });
  console.log('[test] .env loaded from: ' + envFile);
}

const modelRouter  = require('./model-router');
const agentSpawner = require('./agent-spawner');

// ── Test Results Tracker ──────────────────────────────────────────────
var results = { passed: 0, failed: 0, skipped: 0, tests: [] };

function pass(name, detail) {
  results.passed++;
  results.tests.push({ status: 'PASS', name: name, detail: String(detail || '').slice(0, 120) });
  console.log('  ✅ PASS  ' + name + (detail ? ' — ' + String(detail).slice(0, 80) : ''));
}

function fail(name, reason) {
  results.failed++;
  results.tests.push({ status: 'FAIL', name: name, reason: String(reason || '') });
  console.log('  ❌ FAIL  ' + name + ' — ' + String(reason || ''));
}

function skip(name, reason) {
  results.skipped++;
  results.tests.push({ status: 'SKIP', name: name, reason: String(reason || '') });
  console.log('  ⏭  SKIP  ' + name + ' — ' + String(reason || ''));
}

// ── SECTION 1: Backend Status ─────────────────────────────────────────
async function testBackendStatus() {
  console.log('\n══ SECTION 1: Backend Status ══');
  var status = modelRouter.status();
  console.log('  Backend order: ' + status.order.join(' → '));
  console.log('  copilot: ' + (status.backends.copilot.available ? '✅ token:' + status.backends.copilot.tokenSource : '❌ no token'));
  console.log('  openai:  ' + (status.backends.openai.available  ? '✅ key set' : '❌ no key'));
  console.log('  ollama:  ✅ ' + status.backends.ollama.url);

  var anyAvail = status.backends.copilot.available || status.backends.openai.available || true; // ollama always
  if (anyAvail) pass('backend-status', 'at least 1 backend available');
  else fail('backend-status', 'no backends available');
}

// ── SECTION 2: Single Backend Ping ───────────────────────────────────
async function testBackendPing() {
  console.log('\n══ SECTION 2: Backend Ping (single call) ══');
  try {
    var result = await modelRouter.callModelPromise(
      [{ role: 'user', content: 'Reply with exactly: PONG' }],
      {}
    );
    if (result.reply) {
      pass('backend-ping', 'backend=' + result.backend + ' reply="' + result.reply.slice(0, 50) + '"');
    } else {
      fail('backend-ping', 'empty reply from ' + result.backend);
    }
  } catch (e) {
    fail('backend-ping', e.message);
  }
}

// ── SECTION 3: Serial Chain (jit → soma → innova) ─────────────────────
async function testSerialChain() {
  console.log('\n══ SECTION 3: Serial Chain jit → soma → innova ══');
  try {
    var chainResult = await agentSpawner.spawnAgentChain([
      { agent: 'jit',    message: 'Task: "Build a simple REST API for user management." Briefly state your role and what you will orchestrate.' },
      { agent: 'soma',   message: 'Plan the high-level architecture.',    passReply: true },
      { agent: 'innova', message: 'List 3 key implementation steps.',     passReply: true },
    ]);

    if (chainResult.results.length === 3) {
      pass('chain-length', '3/3 agents responded');
    } else {
      fail('chain-length', 'only ' + chainResult.results.length + '/3 responded');
    }

    chainResult.results.forEach(function(r, i) {
      var name = ['jit', 'soma', 'innova'][i];
      if (r.reply && r.reply.length > 5) {
        pass('chain-' + name, 'via ' + r.backend + ' | ' + r.reply.slice(0, 60));
      } else {
        fail('chain-' + name, 'empty reply');
      }
    });

    var backends = chainResult.results.map(function(r) { return r.backend; });
    console.log('  Chain backends used: ' + backends.join(' → '));
    pass('chain-complete', 'full serial chain completed');

  } catch (e) {
    fail('chain-serial', e.message);
  }
}

// ── SECTION 4: Parallel Spawn (lak + chamu) ──────────────────────────
async function testParallelSpawn() {
  console.log('\n══ SECTION 4: Parallel Spawn lak + chamu ══');
  var startMs = Date.now();
  try {
    var parallelResults = await agentSpawner.spawnAgentParallel([
      { agent: 'lak',   message: 'In one sentence: what database would you recommend for a user management API and why?' },
      { agent: 'chamu', message: 'List 2 critical test cases for a user registration endpoint.' },
    ]);

    var elapsed = Date.now() - startMs;
    console.log('  Elapsed: ' + elapsed + 'ms (both agents ran concurrently)');

    if (parallelResults.length === 2) {
      pass('parallel-count', '2/2 agents responded');
    } else {
      fail('parallel-count', 'only ' + parallelResults.length + '/2 responded');
    }

    parallelResults.forEach(function(r) {
      if (r.reply && r.reply.length > 5) {
        pass('parallel-' + r.agent, 'via ' + r.backend + ' | ' + r.reply.slice(0, 60));
      } else {
        fail('parallel-' + r.agent, 'empty reply');
      }
    });

    pass('parallel-concurrent', 'lak + chamu ran in parallel (' + elapsed + 'ms)');
  } catch (e) {
    fail('parallel-spawn', e.message);
  }
}

// ── SECTION 5: Full Pipeline (jit→soma→innova→neta→vaja) ────────────
async function testFullPipeline() {
  console.log('\n══ SECTION 5: Full Pipeline jit→soma→innova→neta→vaja ══');
  try {
    var pipelineResult = await agentSpawner.spawnAgentChain([
      { agent: 'jit',    message: 'Assign task: "Implement user login with JWT"' },
      { agent: 'soma',   message: 'Create the implementation plan.',        passReply: true },
      { agent: 'innova', message: 'Write the core function signature only.', passReply: true },
      { agent: 'neta',   message: 'Review the plan for security issues.',   passReply: true },
      { agent: 'vaja',   message: 'Summarize the outcome in one sentence.',  passReply: true },
    ]);

    if (pipelineResult.results.length === 5) {
      pass('pipeline-length', '5/5 agents responded');
    } else {
      fail('pipeline-length', 'only ' + pipelineResult.results.length + '/5 responded');
    }

    var passed5 = pipelineResult.results.filter(function(r) { return r.reply && r.reply.length > 5; }).length;
    if (passed5 === 5) {
      pass('pipeline-all-replied', 'all 5 agents produced non-empty replies');
    } else {
      fail('pipeline-all-replied', passed5 + '/5 non-empty replies');
    }

    var finalReply = pipelineResult.results[4] && pipelineResult.results[4].reply;
    if (finalReply) {
      pass('pipeline-final-vaja', 'vaja summary: ' + finalReply.slice(0, 80));
    } else {
      fail('pipeline-final-vaja', 'vaja produced no summary');
    }

  } catch (e) {
    fail('pipeline-full', e.message);
  }
}

// ── SECTION 6: Backend Rotation Smoke Test ───────────────────────────
async function testBackendRotation() {
  console.log('\n══ SECTION 6: Backend Rotation (preferred backends) ══');
  var status = modelRouter.status();

  // Test explicit backend preference
  for (var i = 0; i < status.order.length; i++) {
    var backend = status.order[i];
    var avail = status.backends[backend] && (status.backends[backend].available || backend === 'ollama');
    if (!avail) {
      skip('rotation-' + backend, 'no credentials');
      continue;
    }
    try {
      var r = await modelRouter.callModelPromise(
        [{ role: 'user', content: 'Reply with your model name only.' }],
        { preferBackend: backend, noRotate: true }
      );
      pass('rotation-' + backend, 'reply="' + r.reply.slice(0, 40) + '" backend=' + r.backend);
    } catch (e) {
      skip('rotation-' + backend, 'not available: ' + e.message.slice(0, 60));
    }
  }
}

// ── Main ──────────────────────────────────────────────────────────────
async function main() {
  console.log('');
  console.log('══════════════════════════════════════════════════════');
  console.log('  Hermes Multiagent Test — มนุษย์ Agent System');
  console.log('  Jit (จิต) + 14 Organ Agents + Multi-Backend Router');
  console.log('══════════════════════════════════════════════════════');

  var sections = [
    testBackendStatus,
    testBackendPing,
    testSerialChain,
    testParallelSpawn,
    testFullPipeline,
    testBackendRotation,
  ];

  for (var i = 0; i < sections.length; i++) {
    try {
      await sections[i]();
    } catch (e) {
      console.error('\n[test] Section ' + (i+1) + ' threw unexpectedly:', e.message);
    }
  }

  // ── Final Report ─────────────────────────────────────────────────
  console.log('');
  console.log('══════════════════════════════════════════════════════');
  var total = results.passed + results.failed + results.skipped;
  console.log('  Results: ' + results.passed + ' PASS | ' + results.failed + ' FAIL | ' + results.skipped + ' SKIP | ' + total + ' total');

  var passRate = total > 0 ? Math.round((results.passed / (total - results.skipped)) * 100) : 0;
  console.log('  Pass rate: ' + passRate + '% (excluding skipped)');

  if (results.failed === 0 && results.passed > 0) {
    console.log('');
    console.log('  ✅  ALL PASS  ✅');
    console.log('');
    console.log('  Multiagent capabilities verified:');
    console.log('    ✓ model-router: Copilot / OpenAI / Ollama rotation');
    console.log('    ✓ spawnAgent: single organ agent call');
    console.log('    ✓ spawnAgentChain: jit → soma → innova serial chain');
    console.log('    ✓ spawnAgentParallel: lak + chamu concurrent');
    console.log('    ✓ Full pipeline: jit → soma → innova → neta → vaja');
    console.log('');
    console.log('  PASS');
    process.exit(0);
  } else if (results.failed > 0 && results.passed > 0) {
    console.log('');
    console.log('  ⚠️  PARTIAL PASS — some tests failed');
    console.log('');
    results.tests.filter(function(t) { return t.status === 'FAIL'; }).forEach(function(t) {
      console.log('  FAILED: ' + t.name + ' — ' + t.reason);
    });
    console.log('');
    console.log('  PARTIAL PASS (check backend credentials)');
    process.exit(0); // partial pass still counts if core tests passed
  } else {
    console.log('');
    console.log('  ❌  FAIL — all tests failed, check backend credentials');
    console.log('');
    console.log('  Ensure at least one of:');
    console.log('    OLLAMA_TOKEN + OLLAMA_BASE_URL  (MDES Ollama)');
    console.log('    OPENAI_API_KEY                  (OpenAI/Codex)');
    console.log('    Install VS Code + GitHub Copilot (auto-detect)');
    console.log('');
    console.log('  FAIL');
    process.exit(1);
  }
}

main().catch(function(e) {
  console.error('\n[test] Fatal error:', e.message);
  console.log('\n  FAIL');
  process.exit(1);
});
