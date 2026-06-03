const fs = require('fs');
const path = require('path');
const { spawnAgent, spawnAgentParallel, spawnAgentChain } = require('../hermes-discord/agent-spawner');
const { execSync } = require('child_process');
const InnovaBotBridge = require('./innova-bot-bridge');

class MotherEngine {
  constructor() {
    this.registryPath = path.join(__dirname, '../network/registry.json');
    this.leaderboardPath = path.join(__dirname, '../network/leaderboard.json');
    this.routingPath = path.join(__dirname, '../config/subagent-routing.json');
    this.botBridge = new InnovaBotBridge();
    this.loadState();
  }

  loadState() {
    this.registry = JSON.parse(fs.readFileSync(this.registryPath, 'utf8'));
    this.leaderboard = JSON.parse(fs.readFileSync(this.leaderboardPath, 'utf8'));
    this.routing = JSON.parse(fs.readFileSync(this.routingPath, 'utf8'));

    this.setupBotEventListeners();
    this.botBridge.connect().catch(e => console.warn(`[Mother] Initial bot connection failed: ${e.message}`));
  }

  setupBotEventListeners() {
    this.botBridge.on('connected', (sessionID) => {
      console.log(`[Mother] Confirmed connectivity to innova-bot. Session: ${sessionID}`);
    });

    this.botBridge.on('bot_event', (event) => {
      this.handleBotEvent(event);
    });
  }

  async handleBotEvent(event) {
    console.log(`[Mother] Processing bot event: ${event.event || 'unknown'}`);

    switch (event.event) {
      case 'task_update':
        console.log(`[Mother] Bot Task Update: ${event.data?.status} - ${event.data?.message}`);
        break;
      case 'emergency_stop':
        console.error(`[Mother] EMERGENCY STOP received from bot: ${event.data?.reason}`);
        // Implement emergency stop logic here (e.g., stop all current spawnAgentParallel)
        break;
      case 'insight':
        console.log(`[Mother] Bot provided an insight: ${event.data?.content}`);
        // Possibly persist this insight to Oracle
        break;
      default:
        console.log(`[Mother] Unhandled bot event: ${JSON.stringify(event)}`);
    }
  }

  /**
   * Selects the top 5 agents for a given goal based on leaderboard scores
   * and capability matching.
   */
  async selectSquad(goal, phase) {
    console.log(`[Mother] Designing squad for phase: ${phase} - Goal: ${goal}`);

    // 1. Find all agents that have relevant capabilities
    const candidates = this.registry.agents.filter(agent => {
      return agent.capabilities.some(cap => goal.toLowerCase().includes(cap.toLowerCase()));
    });

    // 2. Sort by leaderboard correctness score (descending)
    const rankedCandidates = candidates.sort((a, b) => {
      const scoreA = this.leaderboard.fleet[a.name]?.correctness_score || 0;
      const scoreB = this.leaderboard.fleet[b.name]?.correctness_score || 0;
      return scoreB - scoreA;
    });

    // 3. Take top 5, or fallback to core agents if not enough candidates
    let squad = rankedCandidates.slice(0, 5);
    if (squad.length < 5) {
      const fillers = this.registry.agents.filter(a => !squad.find(s => s.name === a.name));
      squad = [...squad, ...fillers.slice(0, 5 - squad.length)];
    }

    return squad.map(a => a.name);
  }

  /**
   * The core "Infinity Loop" phase execution.
   */
  async executePhase(phaseName, goal) {
    console.log(`\n--- Starting Phase: ${phaseName} ---`);

    // 0. Notify innova-bot about the new phase
    try {
      await this.botBridge.connect();
      await this.botBridge.dispatchTask(`Mother has started phase: ${phaseName}. Goal: ${goal}`);
    } catch (e) {
      console.warn(`[Mother] Could not notify innova-bot: ${e.message}`);
    }

    // 1. Design Squad
    const squadNames = await this.selectSquad(goal, phaseName);
    console.log(`[Mother] Squad Selected: ${squadNames.join(', ')}`);

    // 2. Parallel Execution
    let results = [];
    try {
      results = await spawnAgentParallel(
        squadNames.map(name => ({
          agent: name,
          message: `Goal: ${goal}. Context: Phase ${phaseName}. Provide your specialized output.`
        })),
        `Phase ${phaseName} Execution`
      );
    } catch (e) {
      console.error(`[Mother] Execution failed for phase ${phaseName}: ${e.message}`);
      return { error: 'Execution failed', details: e.message };
    }

    // 3. Adversarial Verification (Spawn a Verifier Squad)
    console.log(`[Mother] Verifying results via Reviewer Squad...`);
    let verifications = [];
    try {
      const verifierSquad = await this.selectSquad(`Verify and audit the following results: ${JSON.stringify(results)}`, 'Verification');
      verifications = await spawnAgentParallel(
        verifierSquad.map(name => ({
          agent: name,
          message: `Review results for phase ${phaseName}. Score it 0-100. Goal was: ${goal}. Results: ${JSON.stringify(results)}`
        })),
        `Phase ${phaseName} Verification`
      );
    } catch (e) {
      console.error(`[Mother] Verification failed for phase ${phaseName}: ${e.message}`);
      verifications = []; // Fallback to empty
    }

    // 4. Rank Update
    await this.updateLeaderboard(squadNames, verifications);

    // 5. Atomic Commit
    this.atomicCommit(phaseName, goal, results);

    // 6. Final Report to innova-bot
    try {
      await this.botBridge.dispatchTask(`Phase ${phaseName} completed successfully. Squad: ${squadNames.join(', ')}. Results pushed to git.`);
    } catch (e) {
      console.warn(`[Mother] Could not report completion to innova-bot: ${e.message}`);
    }

    return results;
  }

  async updateLeaderboard(squad, verifications) {
    console.log(`[Mother] Updating Leaderboard based on performance...`);
    const fleet = this.leaderboard.fleet;

    squad.forEach((name, idx) => {
      const verdict = verifications[idx]?.reply || "0";
      let score = parseInt(verdict.match(/\d+/) ? verdict.match(/\d+/)[0] : "50", 10);
      score = Math.max(0, Math.min(100, isNaN(score) ? 50 : score)); // clamp 0..100

      if (fleet[name]) {
        fleet[name].completed_tasks++;
        const ema = (fleet[name].correctness_score * 0.8) + (score * 0.2);
        fleet[name].correctness_score = Math.max(0, Math.min(100, ema)); // cap at 100
        fleet[name].success_rate = score >= 80 ? 1 : 0; // simplistic binary
      }
    });

    fs.writeFileSync(this.leaderboardPath, JSON.stringify(this.leaderboard, null, 2));
  }

  atomicCommit(phase, goal, results) {
    const commitMsg = `mother: complete phase ${phase} - ${goal}\n\nResults summary: ${JSON.stringify(results).substring(0, 200)}...`;
    try {
      execSync(`git add . && git commit -m "${commitMsg}"`);
      console.log(`[Mother] Atomic commit successful for phase ${phase}`);
    } catch (e) {
      console.error(`[Mother] Commit failed: ${e.message}`);
    }
  }
}

module.exports = MotherEngine;
