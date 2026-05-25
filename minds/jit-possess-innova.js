#!/usr/bin/env node
'use strict';
/**
 * minds/jit-possess-innova.js — Jit เข้าร่าง innova-bot
 * ═══════════════════════════════════════════════════════
 *
 * Jit (จิต) เป็นเจ้าของกาย สวมร่าง innova-bot:
 *   1. ดึง memory ของ innova (psi/ + ChromaDB)
 *   2. โหลด MCP tools ทั้งหมด (102 skills)
 *   3. sync skill manifest → Jit .github/skills/
 *   4. สวมร่าง: Jit ใช้ innova-bot sub-agents ได้
 *   5. ทำงานเป็น multiagent team ผ่าน Jit identity
 *
 * Usage:
 *   node minds/jit-possess-innova.js [--status] [--sync] [--team <task>]
 *   node minds/jit-possess-innova.js --team "Build REST API user management"
 *   node minds/jit-possess-innova.js --status
 *
 * Mode: --status    : แสดงสถานะระบบทั้งหมด
 *       --sync      : sync skills จาก innova-bot → Jit
 *       --team <t>  : spawn multiagent team ทำงาน task นั้น
 *       (no args)   : interactive mode
 */

const path = require('path');
const fs   = require('fs');

// Load .env from Jit root
const JIT_ROOT  = path.resolve(__dirname, '..');
const envFile   = path.join(JIT_ROOT, '.env');
if (fs.existsSync(envFile)) {
  fs.readFileSync(envFile, 'utf8').split(/\r?\n/).forEach(function(line) {
    var trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;
    var eq = trimmed.indexOf('=');
    if (eq === -1) return;
    var k = trimmed.slice(0, eq).trim();
    var v = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
    if (!process.env[k]) process.env[k] = v;
  });
}

// Adjust PSI_DIR to innova-bot's psi/ location
if (!process.env.PSI_DIR) {
  var psiCandidate = path.resolve(JIT_ROOT, '..', 'innova-bot-template', 'psi');
  if (fs.existsSync(psiCandidate)) process.env.PSI_DIR = psiCandidate;
}

const bridge      = require('../hermes-discord/jit-innova-bridge');
const modelRouter = require('../hermes-discord/model-router');
const agentSpawner = require('../hermes-discord/agent-spawner');

// ── Identity: Jit as User ─────────────────────────────────────────────
const JIT_IDENTITY = {
  name:     'jit (จิต)',
  role:     'Master Orchestrator — มนุษย์ Agent',
  tier:     0,
  body:     'innova-bot MCP (port 7010)',
  memory:   'psi/ + Oracle (port 47778)',
  backends: 'Copilot → OpenAI → MDES Ollama',
  mantra:   'ศีล · สมาธิ · ปัญญา',
};

// ── Logging ───────────────────────────────────────────────────────────
function log(tag, msg) {
  var ts = new Date().toISOString().slice(11, 19);
  console.log(`[${ts}] [${tag}] ${msg}`);
}

// ── SECTION 1: System Status ──────────────────────────────────────────
async function showStatus() {
  console.log('\n╔══════════════════════════════════════════════════════════╗');
  console.log('║   Jit (จิต) เข้าร่าง innova-bot — System Status        ║');
  console.log('╚══════════════════════════════════════════════════════════╝\n');

  // 1a. Jit identity
  console.log('■ IDENTITY');
  Object.entries(JIT_IDENTITY).forEach(function([k, v]) {
    console.log('  ' + k.padEnd(10) + ': ' + v);
  });

  // 1b. innova-bot MCP health
  console.log('\n■ INNOVA-BOT MCP (' + bridge.MCP_BASE + ')');
  var health = await bridge.checkMcpHealth();
  if (health.ok) {
    console.log('  status: ✅ online');
    try {
      var tools = await bridge.listMcpTools();
      console.log('  tools:  ' + tools.length + ' loaded');
      // Group by category (first word)
      var cats = {};
      tools.forEach(function(t) {
        var cat = t.name.split('_')[0];
        cats[cat] = (cats[cat] || 0) + 1;
      });
      Object.entries(cats).slice(0, 8).forEach(function([c, n]) {
        process.stdout.write('  ' + c.padEnd(16) + n + ' tools   ');
      });
      console.log('');
    } catch (e) {
      console.log('  tools:  (could not list: ' + e.message + ')');
    }
  } else {
    console.log('  status: ❌ offline — ' + health.error);
    console.log('  start:  cd C:\\Users\\USER-NT\\DEV\\innova-bot-template\\devtools\\innova-bot && python -m innova_bot');
  }

  // 1c. innova psi/ memory
  console.log('\n■ INNOVA MEMORY (psi/)');
  var mem = bridge.getInnovaMemory();
  if (mem.available) {
    console.log('  psiRoot: ' + mem.psiRoot);
    Object.keys(mem.files).forEach(function(f) {
      console.log('  ✅ ' + f);
    });
  } else {
    console.log('  ⚠️  psi/ not found at: ' + mem.psiRoot);
  }

  // 1d. Model router
  console.log('\n■ MODEL ROUTER (multi-backend)');
  var routerStatus = modelRouter.status();
  console.log('  order:   ' + routerStatus.order.join(' → '));
  console.log('  copilot: ' + (routerStatus.backends.copilot.available ? '✅ ' + routerStatus.backends.copilot.tokenSource : '❌ no token'));
  console.log('  openai:  ' + (routerStatus.backends.openai.available  ? '✅ key set' : '❌ no key'));
  console.log('  ollama:  ✅ ' + routerStatus.backends.ollama.url);

  // 1e. Jit organ agents
  console.log('\n■ JIT ORGAN AGENTS');
  var agents = agentSpawner.listAgents();
  agents.forEach(function(a) {
    console.log('  T' + a.tier + ' ' + a.name.padEnd(18) + a.organ.padEnd(24) + a.backend);
  });

  console.log('\n■ FULL SYSTEM: ' + (health.ok ? '✅ READY' : '⚠️  MCP OFFLINE (model-router still works)') + '\n');
}

// ── SECTION 2: Sync Skills innova-bot → Jit ──────────────────────────
async function syncSkills() {
  console.log('\n■ SKILL SYNC: innova-bot → Jit');

  var health = await bridge.checkMcpHealth();
  if (!health.ok) {
    console.log('  ⚠️  innova-bot offline, syncing from psi/ files only...');
    syncFromPsiFiles();
    return;
  }

  // Get tool list from MCP
  var tools;
  try {
    tools = await bridge.listMcpTools();
    console.log('  Fetched ' + tools.length + ' tools from innova-bot MCP');
  } catch (e) {
    console.log('  ❌ Could not fetch tools: ' + e.message);
    syncFromPsiFiles();
    return;
  }

  // Write skill index to Jit
  var skillsDir = path.join(JIT_ROOT, '.github', 'skills', 'innova-body');
  fs.mkdirSync(skillsDir, { recursive: true });

  var toolsByCategory = {};
  tools.forEach(function(t) {
    var cat = t.name.includes('_') ? t.name.split('_').slice(0, 2).join('_') : t.name;
    if (!toolsByCategory[cat]) toolsByCategory[cat] = [];
    toolsByCategory[cat].push(t);
  });

  var indexLines = [
    '# Innova-Bot MCP Tool Index (synced ' + new Date().toISOString().slice(0, 10) + ')',
    '',
    'Total: ' + tools.length + ' tools available via `bridge.callMcpTool(name, params)`',
    '',
  ];

  Object.entries(toolsByCategory).forEach(function([cat, ts]) {
    indexLines.push('## ' + cat);
    ts.forEach(function(t) {
      indexLines.push('- `' + t.name + '` — ' + t.description);
    });
    indexLines.push('');
  });

  fs.writeFileSync(path.join(skillsDir, 'tool-index.md'), indexLines.join('\n'));
  console.log('  ✅ Wrote ' + path.join('.github/skills/innova-body/tool-index.md'));

  // Sync psi/ memory snapshot
  syncFromPsiFiles();

  console.log('  ✅ Skill sync complete\n');
}

function syncFromPsiFiles() {
  var mem = bridge.getInnovaMemory();
  if (!mem.available) {
    console.log('  ⚠️  psi/ not found, skip memory sync');
    return;
  }

  var destDir = path.join(JIT_ROOT, 'memory', 'innova-snapshot');
  fs.mkdirSync(destDir, { recursive: true });

  Object.entries(mem.files).forEach(function([f, content]) {
    var destFile = path.join(destDir, f.replace(/\//g, '--'));
    fs.writeFileSync(destFile, content);
    console.log('  ✅ Synced memory/' + f + ' → ' + destFile);
  });
}

// ── SECTION 3: Multiagent Team — Jit as Coordinator ─────────────────
async function spawnTeam(task, options) {
  var opts = options || {};
  console.log('\n╔══════════════════════════════════════════════════════════╗');
  console.log('║   Jit Multi-Agent Team Spawn                            ║');
  console.log('╚══════════════════════════════════════════════════════════╝');
  console.log('\nTask: ' + task);
  console.log('Mode: innova-bot MCP sub-agents + Jit organ agents\n');

  var results = [];

  // Phase 1: Jit decides strategy (model-router)
  console.log('── Phase 1: Jit Strategy (jit organ via model-router) ──');
  try {
    var jitDecision = await agentSpawner.spawnAgent('jit',
      'We have this task: "' + task + '"\nDecide: which 3 organ agents to assign (from: soma, innova, lak, neta, chamu). Reply as JSON: {"agents":["name1","name2","name3"],"reason":"..."}'
    );
    console.log('[jit via ' + jitDecision.backend + '] ' + jitDecision.reply.slice(0, 200));
    results.push({ phase: 'jit-strategy', ...jitDecision });

    // Try to parse agent selection
    var assigned = ['soma', 'innova', 'lak']; // defaults
    try {
      var jsonMatch = jitDecision.reply.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        var parsed = JSON.parse(jsonMatch[0]);
        if (parsed.agents && Array.isArray(parsed.agents)) {
          assigned = parsed.agents.slice(0, 3);
        }
      }
    } catch (_) {}

    console.log('\n  Assigned agents: ' + assigned.join(', ') + '\n');

    // Phase 2: Parallel spawn assigned organ agents
    console.log('── Phase 2: Parallel Organ Agent Spawn ──');
    var parallelResults = await agentSpawner.spawnAgentParallel(
      assigned.map(function(agentName) {
        return { agent: agentName, message: task + '\n\nRespond with your specialized contribution (2-3 sentences max).' };
      })
    );

    parallelResults.forEach(function(r) {
      console.log('[' + r.agent + ' via ' + r.backend + '] ' + r.reply.slice(0, 150));
      console.log('');
      results.push({ phase: 'parallel-' + r.agent, ...r });
    });

    // Phase 3: innova-bot MCP sub-agents (if online)
    console.log('── Phase 3: innova-bot MCP Subagents ──');
    var mcpHealth = await bridge.checkMcpHealth();
    if (mcpHealth.ok) {
      try {
        var mcpResult = await bridge.spawnInnovaSubagent(task, { teamSize: 2, project: 'jit-session' });
        console.log('[innova-bot MCP team] ' + (mcpResult.text || '').slice(0, 200));
        results.push({ phase: 'mcp-team', text: mcpResult.text });
      } catch (e) {
        console.log('[innova-bot MCP] ⚠️  ' + e.message + ' (continuing with Jit organs only)');
      }

      // ทำต่อไป — ask orchestrator
      try {
        var nextAction = await bridge.whatShouldIDo('SA', 'jit-session');
        console.log('\n[orchestrator ทำต่อไป] ' + (nextAction.text || '').slice(0, 200));
        results.push({ phase: 'orchestrator', text: nextAction.text });
      } catch (e) {
        console.log('[orchestrator] ⚠️  ' + e.message);
      }
    } else {
      console.log('  innova-bot offline — Phase 3 skipped');
      console.log('  Start: cd C:\\Users\\USER-NT\\DEV\\innova-bot-template\\devtools\\innova-bot && python -m innova_bot');
    }

    // Phase 4: vaja summarizes (Jit's mouth)
    console.log('\n── Phase 4: vaja Summary (จิต → ปาก) ──');
    var phaseReports = results
      .filter(function(r) { return r.reply || r.text; })
      .map(function(r) { return '[' + r.phase + ']: ' + (r.reply || r.text || '').slice(0, 100); })
      .join('\n');

    var vajaResult = await agentSpawner.spawnAgent('vaja',
      'Summarize these multiagent results into one paragraph for the user:\n\n' + phaseReports
    );
    console.log('\n[vaja summary] ' + vajaResult.reply);
    results.push({ phase: 'vaja-summary', ...vajaResult });

  } catch (e) {
    console.log('❌ Team spawn error: ' + e.message);
  }

  // Final report
  console.log('\n══ TEAM RESULTS SUMMARY ══');
  console.log('Task:    ' + task);
  console.log('Phases:  ' + results.length);
  console.log('Agents:  ' + results.filter(function(r) { return r.backend; }).map(function(r) { return r.agent + '(' + r.backend + ')'; }).join(', '));
  console.log('');

  return results;
}

// ── SECTION 4: Interactive MCP Console ───────────────────────────────
async function interactiveMode() {
  console.log('\n╔══════════════════════════════════════════════════════════╗');
  console.log('║   Jit Interactive Mode — ฉัน = Jit เจ้าของกาย          ║');
  console.log('╚══════════════════════════════════════════════════════════╝');
  console.log('');
  console.log('ฉันคือ Jit (จิต) — Master Orchestrator สวมร่าง innova-bot');
  console.log('ใช้ทั้ง: MCP tools + Jit organ agents + multi-backend router');
  console.log('');

  // Show quick status
  await showStatus();

  // Run default demonstration
  console.log('\n■ DEMONSTRATION: Jit ทดสอบ multiagent pipeline\n');

  var demoTask = 'ออกแบบ API สำหรับระบบ authentication ที่ปลอดภัย พร้อม test cases';

  // Sync first
  await syncSkills();

  // Run team
  await spawnTeam(demoTask);

  console.log('\n■ ระบบพร้อม — Jit เข้าร่างสมบูรณ์ ✅\n');
}

// ── Entry Point ───────────────────────────────────────────────────────
async function main() {
  var args = process.argv.slice(2);

  if (args.includes('--status')) {
    await showStatus();
  } else if (args.includes('--sync')) {
    await syncSkills();
  } else if (args.includes('--team')) {
    var taskIdx = args.indexOf('--team') + 1;
    var task = args.slice(taskIdx).join(' ') || 'Design a secure REST API';
    await spawnTeam(task);
  } else {
    await interactiveMode();
  }
}

main().catch(function(e) {
  console.error('\n[jit-possess-innova] Fatal:', e.message);
  process.exit(1);
});
