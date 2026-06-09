const fs = require('fs');
const path = require('path');
const { callCommandCode } = require('../limbs/commandcode');

const JIT_ROOT = path.resolve(__dirname, '..');
const INNOVA_BOT_ROOT = 'C:/Users/USER-NT/DEV/innova-bot-template/devtools/innova-bot';

// Define the files to scan
const TARGET_FILES = [
  { name: 'Jit Mother Engine', path: path.join(JIT_ROOT, 'limbs/mother-engine.js') },
  { name: 'Jit Model Router', path: path.join(JIT_ROOT, 'hermes-discord/model-router.js') },
  { name: 'Jit Innova-Bot Bridge', path: path.join(JIT_ROOT, 'limbs/innova-bot-bridge.js') },
  { name: 'Innova-Bot Model Router (Python)', path: path.join(INNOVA_BOT_ROOT, 'innova_bot/utils/model_router.py') },
  { name: 'Innova-Bot Ask Tools (Python)', path: path.join(INNOVA_BOT_ROOT, 'innova_bot/tools/ask_tools.py') },
  { name: 'Innova-Bot Event Watcher (Python)', path: path.join(INNOVA_BOT_ROOT, 'innova_bot/utils/event_watcher.py') },
  { name: 'Innova-Bot BigBoss Agent (Python)', path: path.join(INNOVA_BOT_ROOT, 'innova_bot/agents/bigboss_agent.py') },
  { name: 'Innova-Bot Swarm Manager (Python)', path: path.join(INNOVA_BOT_ROOT, 'innova_bot/utils/swarm_manager.py') },
  { name: 'Innova-Bot Supervisor Loop (Python)', path: path.join(INNOVA_BOT_ROOT, 'innova_bot/utils/supervisor_loop.py') },
  { name: 'Innova-Bot RPG TUI (Python)', path: path.join(INNOVA_BOT_ROOT, 'innova_bot/gui/rpg_tui.py') }
];

// Define the 11 sub-agent roles and their focus
const AGENT_ROLES = [
  { name: 'SA_Architect', focus: 'Audits design patterns, separation of concerns, architectural violations, and modularity.' },
  { name: 'Bug_Hunter', focus: 'Audits potential runtime bugs, edge-case failures, crash vectors, and variable typing issues.' },
  { name: 'Security_Auditor', focus: 'Audits prompt injection risks, secret leakage, directory traversal, and permission verification.' },
  { name: 'QA_Planner', focus: 'Audits code testability, boundary coverage, and mock suitability for unit and E2E testing.' },
  { name: 'Refactoring_Expert', focus: 'Audits readability, DRY violations, dead code, naming conventions, and code smells.' },
  { name: 'Concurrency_Analyst', focus: 'Audits async lock safety, potential deadlocks, infinite loop risks, and thread blockages.' },
  { name: 'Error_Handler', focus: 'Audits exception handling (e.g., bare excepts), log tracing depth, and error recoverability.' },
  { name: 'Perf_Tuner', focus: 'Audits resource consumption, potential memory leaks, CPU spin loops, and sub-optimal calls.' },
  { name: 'Integration_Specialist', focus: 'Audits configuration resolution, path operations, environment dependencies, and inter-process boundaries.' },
  { name: 'Documentation_Validator', focus: 'Audits docstrings, comment accuracy, and docs-to-code sync (detects stale comments).' },
  { name: 'QE_Evaluator', focus: 'Consolidates all previous audits, eliminates noise, and compiles the final concrete list of bugs to fix.' }
];

const MODEL_TO_USE = 'deepseek/deepseek-v4-flash';

async function runSwarmAudit() {
  console.log(`Starting Swarm Audit using CommandCode gateway model: ${MODEL_TO_USE}`);
  console.log(`Scanning ${TARGET_FILES.length} files with ${AGENT_ROLES.length} agents each...\n`);

  let report = `# Swarm Audit Report\n\nGenerated: ${new Date().toISOString()}\n\n`;

  for (const fileObj of TARGET_FILES) {
    if (!fs.existsSync(fileObj.path)) {
      console.log(`Skipping missing file: ${fileObj.name} (${fileObj.path})`);
      continue;
    }

    console.log(`Analyzing file: ${fileObj.name} ...`);
    const fileContent = fs.readFileSync(fileObj.path, 'utf8');

    // Divide the analysis tasks: run the first 10 specialist agents in parallel
    const agentPromises = AGENT_ROLES.slice(0, 10).map(async (role) => {
      const prompt = `You are a specialist code auditor: ${role.name}. Focus: ${role.focus}
Analyze the following code file: "${fileObj.name}".
Identify bugs, code smells, or issues related to your focus area.
Be concise and list only real, actionable issues.

Code:\n\`\`\`\n${fileContent.slice(0, 15000)}\n\`\`\``;

      try {
        const reply = await callCommandCode(MODEL_TO_USE, prompt, 'openai');
        return { name: role.name, reply };
      } catch (err) {
        return { name: role.name, error: err.message };
      }
    });

    const specialistResults = await Promise.all(agentPromises);

    // Now run the 11th agent (QE_Evaluator) to synthesize the findings
    console.log(`Synthesizing findings for: ${fileObj.name} using QE_Evaluator...`);
    const synthesisPrompt = `You are the QE_Evaluator sub-agent.
Your task is to synthesize the specialist audit reports for the file: "${fileObj.name}".
Look at the findings from the other 10 agents, eliminate duplicates or low-priority noise, and output a clean, numbered list of CONCRETE BUGS or ISSUES that must be fixed. Do not include vague suggestions; focus on bugs, race conditions, compile errors, or security risks.

Specialist Reports:\n${specialistResults.map(r => `### Agent: ${r.name}\n${r.error ? `Error: ${r.error}` : r.reply}`).join('\n\n')}`;

    let synthesizedFindings = '';
    try {
      synthesizedFindings = await callCommandCode(MODEL_TO_USE, synthesisPrompt, 'openai');
    } catch (err) {
      synthesizedFindings = `Failed synthesis: ${err.message}`;
    }

    // Append to report
    report += `## File: ${fileObj.name}\n\n`;
    report += `**Path**: \`${fileObj.path}\`\n\n`;
    report += `### Synthesized Findings (QE Evaluator)\n\n${synthesizedFindings}\n\n`;
    report += `### Detailed Specialist Agent Audits\n\n`;
    for (const r of specialistResults) {
      report += `<details>\n<summary>Agent: ${r.name}</summary>\n\n${r.error ? `Error: ${r.error}` : r.reply}\n\n</details>\n\n`;
    }
    report += `---\n\n`;
  }

  const reportPath = path.join(JIT_ROOT, 'scratch/swarm_audit_report.md');
  fs.writeFileSync(reportPath, report, 'utf8');
  console.log(`\nSwarm Audit Completed! Report saved to: ${reportPath}`);
}

runSwarmAudit().catch(console.error);
