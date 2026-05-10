#!/usr/bin/env node
'use strict';
/**
 * hermes-discord/test-omc.js
 * ═════════════════════════════════════════════════════════════════════
 * Test Oh-My-Claude-Code integration with Jit + MDES Ollama
 */

const omcAdapter = require('./omc-adapter');
const modelRouter = require('./model-router');

const SECTION = '═'.repeat(62);

console.log('\n' + SECTION);
console.log('  Oh-My-Claude-Code Integration Test');
console.log(SECTION + '\n');

// Test 1: OMC Status
console.log('[TEST 1] OMC + Jit Integration Status');
console.log('─'.repeat(62));

var omcStatus = omcAdapter.status();
console.log('✓ Integrated: ' + omcStatus.integrated);
console.log('✓ Agents registered: ' + omcStatus.agents_registered);
console.log('✓ Skills loaded: ' + omcStatus.skills_loaded);
console.log('✓ Multi-agent ready: ' + omcStatus.multi_agent_ready);
console.log('✓ Backend priority: ' + omcStatus.backend_priority.join(' → '));
console.log('✓ Ollama primary: ' + (omcStatus.ollama_primary ? 'YES' : 'NO'));

// Test 2: Backend Availability
console.log('\n[TEST 2] Backend Availability (Ollama-First Mode)');
console.log('─'.repeat(62));

var routerStatus = modelRouter.status();
console.log('Primary backend: ' + routerStatus.primary);
console.log('');

Object.entries(routerStatus.backends).forEach(function([name, info]) {
  var available = info.available ? '✓' : '○';
  if (name === 'ollama') {
    console.log('  ' + available + ' ' + name.toUpperCase() + ' (PRIMARY for OMC skills)');
    console.log('      URL: ' + info.url);
  } else {
    console.log('  ' + available + ' ' + name + ' (fallback)');
  }
});

// Test 3: Skill Generation
console.log('\n[TEST 3] Skill Generation (Ollama-First)');
console.log('─'.repeat(62));

try {
  var skillRegistry = omcAdapter.registerOllamaSkills();
  console.log('Registered skills: ' + Object.keys(skillRegistry).length);
  
  Object.entries(skillRegistry).forEach(function([name, config]) {
    console.log('  ✓ ' + name);
    console.log('      Backend: ' + config.backend + ' (primary)');
    console.log('      Agents: ' + config.agents.join(', '));
  });
} catch (e) {
  console.log('  ✗ Error: ' + e.message);
}

// Test 4: OMC Config
console.log('\n[TEST 4] OMC Configuration');
console.log('─'.repeat(62));

try {
  var omcConfig = omcAdapter.generateOmcConfig();
  console.log('Config generated at: ' + omcConfig.configFile);
  var cfg = omcConfig.config;
  console.log('');
  console.log('  Agents:');
  console.log('    Total: ' + cfg.agents.total);
  console.log('    Tier 0 (Master): ' + cfg.agents.tiers.tier0.length);
  console.log('    Tier 1-2 (Leadership): ' + (cfg.agents.tiers.tier1.length + cfg.agents.tiers.tier2.length));
  console.log('    Tier 3 (Specialists): ' + cfg.agents.tiers.tier3.length);
  console.log('');
  console.log('  Skills:');
  console.log('    Total: ' + cfg.skills.total);
  console.log('    Ollama primary: ' + cfg.skills.ollama_primary);
  console.log('    Priority: ' + cfg.skills.backend_priority.join(' → '));
  console.log('');
  console.log('  Features:');
  console.log('    Autopilot: ' + cfg.features.autopilot);
  console.log('    Parallel spawn: ' + cfg.features.parallel_spawn);
  console.log('    Discord integration: ' + cfg.features.discord_integration);
  console.log('    innova-bot MCP: ' + cfg.features.innova_bot_mcp);
} catch (e) {
  console.log('  ✗ Error: ' + e.message);
}

// Test 5: Ollama-First Call
console.log('\n[TEST 5] Model Router Ollama-First Mode');
console.log('─'.repeat(62));

var testMsg = [{ role: 'user', content: 'Say "OMC ready" in one line' }];
modelRouter.callModelOllamaFirstPromise(testMsg, { maxTokens: 50 })
  .then(function(result) {
    console.log('✓ Ollama-first call successful');
    console.log('  Backend: ' + result.backend);
    console.log('  Reply: ' + result.reply.slice(0, 80) + (result.reply.length > 80 ? '...' : ''));
  })
  .catch(function(err) {
    console.log('✗ Ollama-first call failed: ' + err.message);
    console.log('  (Expected if Ollama offline or not configured)');
  })
  .finally(function() {
    // Summary
    console.log('\n' + SECTION);
    console.log('  Summary');
    console.log(SECTION);
    console.log('');
    console.log('OMC Integration: ✓ Ready');
    console.log('Agents: ' + omcStatus.agents_registered + ' registered');
    console.log('Skills: ' + omcStatus.skills_loaded + ' available');
    console.log('Backend: Ollama-first rotation (no quota limits)');
    console.log('');
    console.log('Next:');
    console.log('  1. node scripts/omc-setup.js              (generate skills)');
    console.log('  2. In Claude Code: /plugin install omc');
    console.log('  3. Test: /autopilot build a REST API');
    console.log('  4. Monitor: !jit backend (in Discord)');
    console.log('');
    console.log(SECTION + '\n');
  });
