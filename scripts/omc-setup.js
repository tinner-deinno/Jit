#!/usr/bin/env node
'use strict';
/**
 * scripts/omc-setup.js
 * ═════════════════════════════════════════════════════════════════════
 *
 * Oh-My-Claude-Code (OMC) Setup Wizard
 * Bridges OMC with Jit system + MDES Ollama
 *
 * Usage:
 *   node scripts/omc-setup.js [--auto] [--config]
 */

const fs = require('fs');
const path = require('path');
const omcAdapter = require('../hermes-discord/omc-adapter');
const agentSpawner = require('../hermes-discord/agent-spawner');

const JIT_ROOT = __dirname;
const CLAUDE_CONFIG_DIR = path.join(process.env.HOME || process.env.USERPROFILE, '.claude');

// ── Logging ───────────────────────────────────────────────────────────
function log(tag, msg) {
  var ts = new Date().toISOString().slice(11, 19);
  console.log(`[${ts}] [${tag}] ${msg}`);
}

function section(title) {
  console.log('\n' + '═'.repeat(60));
  console.log('  ' + title);
  console.log('═'.repeat(60) + '\n');
}

// ── Main Setup ───────────────────────────────────────────────────────
async function runSetup() {
  section('Oh-My-Claude-Code + Jit System Integration');

  log('INFO', 'Starting OMC setup wizard...');

  // Step 1: Create .claude directory structure
  log('STEP', '1. Setting up .claude/omc directory');
  var omcDir = path.join(CLAUDE_CONFIG_DIR, 'omc');
  if (!fs.existsSync(omcDir)) {
    fs.mkdirSync(omcDir, { recursive: true });
    log('OK', '.claude/omc/ created');
  } else {
    log('OK', '.claude/omc/ already exists');
  }

  // Step 2: Generate OMC config
  log('STEP', '2. Generating OMC configuration');
  var omcConfig = omcAdapter.generateOmcConfig();
  log('OK', 'OMC config written to: ' + omcConfig.configFile);
  console.log('   Agents: ' + omcConfig.config.agents.total);
  console.log('   Skills: ' + omcConfig.config.skills.total);
  console.log('   Backend priority: ' + omcConfig.config.skills.backend_priority.join(' → '));

  // Step 3: Register OMC bridge
  log('STEP', '3. Registering OMC bridge with Jit agents');
  var bridge = omcAdapter.registerOmcBridge(null, agentSpawner);
  log('OK', 'OMC bridge registered');
  console.log('   Agent mappings: ' + Object.keys(bridge.agentMap).length);

  // Step 4: Generate core skills
  log('STEP', '4. Generating OMC skills (Ollama-first)');
  var skillRegistry = omcAdapter.registerOllamaSkills();
  var skillCount = 0;
  Object.entries(skillRegistry).forEach(function([skillName, skillConfig]) {
    try {
      var skillInfo = omcAdapter.generateSkill(
        skillName,
        skillConfig.description,
        skillConfig.task
      );
      skillCount++;
      console.log('   ✓ ' + skillName);
    } catch (e) {
      log('WARN', 'Failed to generate ' + skillName + ': ' + e.message);
    }
  });
  log('OK', skillCount + ' skills generated (Ollama as primary backend)');

  // Step 5: Create bridge script
  log('STEP', '5. Creating OMC command bridge');
  var bridgeScript = path.join(CLAUDE_CONFIG_DIR, 'commands', 'omc.sh');
  var bridgeDir = path.dirname(bridgeScript);
  if (!fs.existsSync(bridgeDir)) {
    fs.mkdirSync(bridgeDir, { recursive: true });
  }

  var bridgeContent = `#!/bin/bash
# OMC Bridge for Jit System
# Executes OMC commands with MDES Ollama preference

JIT_ROOT="${path.join(JIT_ROOT, '..')}jit"
NODE=\\$(which node)

# Parse command
CMD="\\$1"
ARGS="\\${@:2}"

case \\$CMD in
  setup)
    echo "OMC Setup already complete"
    ;;
  status)
    \\$NODE \\$JIT_ROOT/scripts/omc-setup.js --status
    ;;
  skill)
    \\$NODE \\$JIT_ROOT/scripts/omc-setup.js --skill "\\$ARGS"
    ;;
  test)
    \\$NODE \\$JIT_ROOT/hermes-discord/test-multiagent.js
    ;;
  *)
    echo "Unknown OMC command: \\$CMD"
    exit 1
    ;;
esac
`;

  fs.writeFileSync(bridgeScript, bridgeContent);
  fs.chmodSync(bridgeScript, 0o755);
  log('OK', 'OMC command bridge created');

  // Step 6: Verify backends
  log('STEP', '6. Verifying backend availability');
  var routerStatus = require('../hermes-discord/model-router').status();
  Object.entries(routerStatus.backends).forEach(function([name, info]) {
    var avail = info.available ? '✓' : '○';
    console.log('   ' + avail + ' ' + name);
  });

  // Final report
  section('Setup Complete');
  console.log('✓ ' + omcConfig.config.agents.total + ' agents registered');
  console.log('✓ ' + skillCount + ' skills loaded');
  console.log('✓ Configuration complete');
  console.log('');
  console.log('Next steps:');
  console.log('  1. In Claude Code, run: /plugin install oh-my-claudecode');
  console.log('  2. Test with: $ /autopilot build a REST API');
  console.log('  3. Check: $ /omc-status');
  console.log('');
  console.log('Backend stack: Ollama (primary) → OpenClaude → OpenAI → Copilot');
  console.log('');

  return omcConfig;
}

// ── Status Check ──────────────────────────────────────────────────────
function showStatus() {
  section('OMC + Jit System Status');
  
  var omcStatus = omcAdapter.status();
  console.log('Integrated: ' + (omcStatus.integrated ? '✓' : '✗'));
  console.log('Agents: ' + omcStatus.agents_registered);
  console.log('Skills: ' + omcStatus.skills_loaded);
  console.log('Multi-agent: ' + (omcStatus.multi_agent_ready ? 'Ready ✓' : '✗'));
  console.log('Backend priority: ' + omcStatus.backend_priority.join(' → '));
  console.log('Ollama primary: ' + (omcStatus.ollama_primary ? '✓' : '✗'));
  console.log('');
}

// ── Entry Point ───────────────────────────────────────────────────────
async function main() {
  var args = process.argv.slice(2);

  if (args.includes('--status')) {
    showStatus();
  } else if (args.includes('--config')) {
    console.log(JSON.stringify(omcAdapter.generateOmcConfig().config, null, 2));
  } else {
    await runSetup();
  }
}

main().catch(function(err) {
  console.error('[ERROR]', err.message);
  process.exit(1);
});
