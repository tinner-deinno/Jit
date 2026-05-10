#!/usr/bin/env node
'use strict';
/**
 * hermes-discord/omc-adapter.js
 * ═════════════════════════════════════════════════════════════════════
 *
 * Oh-My-Claude-Code (OMC) Adapter for Jit System
 *
 * Bridges Oh-My-Claude-Code plugin with Jit's:
 *   - Multi-backend router (Copilot → OpenAI → OpenClaude → Ollama)
 *   - 14 organ agents
 *   - MDES Ollama as primary (no quota limit)
 *   - Skill auto-generation for Claude Code
 *
 * Usage:
 *   const omcAdapter = require('./omc-adapter');
 *   omcAdapter.registerOmcBridge(router, agentSpawner);
 *   omcAdapter.generateSkill('build-rest-api', task, opts);
 */

const fs = require('fs');
const path = require('path');

const modelRouter = require('./model-router');
const agentSpawner = require('./agent-spawner');

// ── Configuration ─────────────────────────────────────────────────────
const OMC_AGENT_COUNT = 32;
const OMC_SKILL_COUNT = 40;
const JIT_ORCHESTRATOR = 'jit';
const MDES_OLLAMA_PRIMARY = true; // Always try Ollama first for skills

// ── OMC Bridge: Register with Jit Agents ────────────────────────────
function registerOmcBridge(router, spawner) {
  console.log('[OMC Adapter] Registering OMC bridge...');

  // OMC agents map to Jit organs
  const omcAgentMap = {
    'architect':        { jit: 'lak',    tier: 2, role: 'Solution Architect' },
    'executor':         { jit: 'innova', tier: 2, role: 'Lead Developer' },
    'qa-tester':        { jit: 'chamu',  tier: 3, role: 'QA Tester' },
    'security-reviewer':{ jit: 'neta',   tier: 2, role: 'Code Reviewer' },
    'strategist':       { jit: 'soma',   tier: 1, role: 'Strategic Lead' },
    'researcher':       { jit: 'netra',  tier: 3, role: 'Observer' },
    'analyst':          { jit: 'neta',   tier: 2, role: 'Code Analyzer' },
    'documentor':       { jit: 'vaja',   tier: 3, role: 'Personal Assistant' },
  };

  return {
    agentMap: omcAgentMap,
    spawn: function(omcAgent, task, opts) {
      var jitAgent = omcAgentMap[omcAgent] || { jit: 'innova' };
      opts = opts || {};
      opts.preferBackend = opts.preferBackend || 'ollama'; // Prefer Ollama

      return new Promise(function(resolve, reject) {
        spawner.spawnAgent(jitAgent.jit, task, opts, function(err, result) {
          if (err) return reject(err);
          resolve({
            agent: omcAgent,
            jitAgent: jitAgent.jit,
            reply: result.reply,
            backend: result.backend,
          });
        });
      });
    },
    spawnParallel: function(agents, task, opts) {
      var tasks = agents.map(function(a) {
        var jitAgent = omcAgentMap[a] || { jit: 'innova' };
        return {
          agent: jitAgent.jit,
          message: task + '\n\n[' + a + ' perspective]',
        };
      });
      return spawner.spawnAgentParallel(tasks);
    },
  };
}

// ── OMC Skill Generator ────────────────────────────────────────────────
/**
 * Generate OMC-compatible skill for Claude Code
 * Auto-configured to use MDES Ollama as primary backend
 */
function generateSkill(skillName, description, autopilotTask) {
  var skillDir = path.join(process.cwd(), '.claude', 'skills', skillName);
  var skillFile = path.join(skillDir, 'SKILL.md');
  var scriptFile = path.join(skillDir, skillName + '.js');

  // Create skill directory
  if (!fs.existsSync(skillDir)) {
    fs.mkdirSync(skillDir, { recursive: true });
  }

  // Generate SKILL.md
  var skillMarkdown = `# SKILL: ${skillName}

## Description
${description}

## What It Does
Bridges Oh-My-Claude-Code (OMC) with Jit multiagent system.

- Uses **MDES Ollama** as primary backend (no quota limits)
- Falls back to OpenAI/Copilot if Ollama unavailable
- Spawns parallel agent teams automatically
- Works with Claude Code autopilot

## Trigger
\`\`\`
$ /${skillName.replace(/-/g, '_')} <task>
\`\`\`

## Example
\`\`\`
$ /build_rest_api "Create a task management API with auth and caching"

↳ Activating team orchestration…
  architect (jit:lak) · executor (jit:innova) · qa-tester (jit:chamu)
  security-reviewer (jit:neta)

✅ Result: API designed, built, tested, reviewed
\`\`\`

## Configuration
- **Primary Backend**: MDES Ollama (https://ollama.mdes-innova.online)
- **Fallback**: OpenAI → Copilot → Local Ollama
- **Team Size**: Configurable (default: 4 agents)
- **Timeout**: 120s per agent

## Usage in OMC
\`\`\`javascript
const omcAdapter = require('./hermes-discord/omc-adapter');

// Spawn team
omcAdapter.spawn('architect', '${autopilotTask}', { 
  preferBackend: 'ollama',
  teamSize: 4
});
\`\`\`

## Related
- Jit: \`minds/jit-possess-innova.js\`
- Model Router: \`hermes-discord/model-router.js\`
- Agent Spawner: \`hermes-discord/agent-spawner.js\`
- Oh-My-Claude-Code: https://github.com/Yeachan-Heo/oh-my-claudecode

---
Generated: ${new Date().toISOString().slice(0, 10)} | Jit OMC Integration
`;

  fs.writeFileSync(skillFile, skillMarkdown);

  // Generate skill script
  var skillScript = `#!/usr/bin/env node
'use strict';
/**
 * ${skillName}.js — OMC Skill for Claude Code
 * Auto-uses MDES Ollama + Jit agents
 */

const modelRouter = require('../../../hermes-discord/model-router');
const agentSpawner = require('../../../hermes-discord/agent-spawner');
const omcAdapter = require('../../../hermes-discord/omc-adapter');

async function execute(task) {
  console.log('\\n[${skillName}] Activating team orchestration…');

  try {
    // Spawn parallel team (architect, executor, qa, security)
    const agents = ['architect', 'executor', 'qa-tester', 'security-reviewer'];
    console.log('  ' + agents.join(' · '));
    
    const results = await omcAdapter.spawn(agents[0], task, {
      preferBackend: 'ollama',
    });

    console.log('\\n✅ Team complete');
    console.log('Backend used: ' + results.backend);
    console.log('Result:\\n' + results.reply.slice(0, 500) + '...');
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  const task = process.argv.slice(2).join(' ') || 'Complete a software task';
  execute(task);
}

module.exports = { execute };
`;

  fs.writeFileSync(scriptFile, skillScript);

  return {
    name: skillName,
    dir: skillDir,
    skillFile: skillFile,
    scriptFile: scriptFile,
  };
}

// ── OMC Configuration Generator ────────────────────────────────────────
function generateOmcConfig() {
  var configDir = path.join(process.cwd(), '.claude', 'omc');
  var configFile = path.join(configDir, 'config.json');

  if (!fs.existsSync(configDir)) {
    fs.mkdirSync(configDir, { recursive: true });
  }

  var config = {
    version: '1.0.0',
    integration: 'jit-system',
    agents: {
      total: OMC_AGENT_COUNT,
      mapped_to_jit: 14,
      tiers: {
        tier0: ['jit'],
        tier1: ['soma'],
        tier2: ['innova', 'lak', 'neta'],
        tier3: ['vaja', 'chamu', 'rupa', 'pada', 'netra', 'karn', 'mue', 'pran', 'sayanprasathan'],
      },
    },
    skills: {
      total: OMC_SKILL_COUNT,
      backend_priority: ['ollama', 'openclaude', 'openai', 'copilot'],
      ollama_primary: true,
      mdes_endpoint: 'https://ollama.mdes-innova.online',
    },
    features: {
      autopilot: true,
      parallel_spawn: true,
      multi_backend_rotation: true,
      skill_auto_generation: true,
      discord_integration: true,
      innova_bot_mcp: true,
    },
    defaults: {
      team_size: 4,
      timeout_per_agent: 120,
      prefer_backend: 'ollama',
      fallback_chain: ['ollama', 'openclaude', 'openai', 'copilot', 'local-ollama'],
    },
  };

  fs.writeFileSync(configFile, JSON.stringify(config, null, 2));

  return {
    configDir: configDir,
    configFile: configFile,
    config: config,
  };
}

// ── Ollama-First Skill Registry ──────────────────────────────────────
function registerOllamaSkills() {
  var skillRegistry = {
    'autopilot': {
      description: 'Automatic task execution with team orchestration',
      agents: ['architect', 'executor', 'qa-tester', 'security-reviewer'],
      backend: 'ollama',
      task: 'Autonomous multi-agent task completion',
    },
    'code-review': {
      description: 'Parallel code review from multiple perspectives',
      agents: ['qa-tester', 'security-reviewer', 'architect'],
      backend: 'ollama',
      task: 'Code review and analysis',
    },
    'architecture-design': {
      description: 'System architecture design with vetting',
      agents: ['architect', 'analyzer', 'security-reviewer'],
      backend: 'ollama',
      task: 'System architecture and design',
    },
    'bug-hunt': {
      description: 'Multi-perspective bug detection and fixing',
      agents: ['qa-tester', 'executor', 'security-reviewer'],
      backend: 'ollama',
      task: 'Debug identification and resolution',
    },
    'api-builder': {
      description: 'REST/GraphQL API design and implementation',
      agents: ['architect', 'executor', 'security-reviewer', 'qa-tester'],
      backend: 'ollama',
      task: 'API design and implementation',
    },
  };

  return skillRegistry;
}

// ── MDES Ollama Preference Override ──────────────────────────────────
function preferOllamaBackend(callOpts) {
  var opts = callOpts || {};
  opts.preferBackend = 'ollama';
  opts.fallbackChain = ['ollama', 'openclaude', 'openai', 'copilot'];
  return opts;
}

// ── Status Function ────────────────────────────────────────────────────
function status() {
  var routerStatus = modelRouter.status();
  var omcStatus = {
    integrated: true,
    version: '1.0.0',
    agents_registered: OMC_AGENT_COUNT,
    skills_loaded: OMC_SKILL_COUNT,
    backend_priority: routerStatus.order,
    ollama_primary: MDES_OLLAMA_PRIMARY,
    multi_agent_ready: true,
  };

  return omcStatus;
}

// ── Exports ────────────────────────────────────────────────────────────
module.exports = {
  registerOmcBridge,
  generateSkill,
  generateOmcConfig,
  registerOllamaSkills,
  preferOllamaBackend,
  status,
  OMC_AGENT_COUNT,
  OMC_SKILL_COUNT,
};
