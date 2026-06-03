const fs = require('fs');
const path = require('path');
const { spawnAgent, spawnAgentParallel, spawnAgentChain } = require('../hermes-discord/agent-spawner');
const { execSync } = require('child_process');
const InnovaBotBridge = require('./innova-bot-bridge');
const eventLog = require('./event-log');
const leaderboardDB = require('./leaderboard-db');

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
    this.hydrateLeaderboard();
    this.liveProvider = this.pickLiveProvider();

    this.setupBotEventListeners();
    this.botBridge.connect().catch(e => console.warn(`[Mother] Initial bot connection failed: ${e.message}`));
  }

  /**
   * Pick the fastest usable backend from the last provider probe so the squad
   * dispatches to a LIVE provider instead of burning timeouts on dead ones
   * (most agents are statically configured to ollama_mdes, which may be down).
   * Returns null if no probe exists — callers then fall back to router rotation.
   */
  pickLiveProvider() {
    try {
      const ps = JSON.parse(fs.readFileSync(path.join(__dirname, '../network/provider-status.json'), 'utf8'));
      // Exclude anything the probe saw as rate-limited even if it once answered.
      const usable = (ps.usable || []).filter(b => ps.results?.[b]?.status !== 'RATE_LIMITED');
      if (!usable.length) return null;
      // Budget-aware + reliability-weighted: prefer CHEAPEST usable lane, then
      // the one with the best learned success rate (Iteration 6), then fastest.
      // Keeps the expensive frontier provider (openai/gpt-5.5) out of the squad
      // while routing away from lanes that historically fail.
      const costRank = { local: 0, low: 1, medium: 2, high: 3 };
      const cost = b => costRank[this.routing?.providers?.[b]?.cost_tier] ?? 2;
      let stats = {};
      try { stats = leaderboardDB.getProviderStats(); } catch (_) { /* DB optional */ }
      // Reliability: only trust it once a lane has >=3 calls; else neutral (1).
      const reliability = b => { const s = stats[b]; return (s && s.calls >= 3) ? s.success_rate : 1; };
      const ranked = usable.slice().sort((a, b) =>
        (cost(a) - cost(b)) ||
        (reliability(b) - reliability(a)) ||
        ((ps.results?.[a]?.ms ?? 1e9) - (ps.results?.[b]?.ms ?? 1e9)));
      const backend = ranked[0];
      // CRITICAL: a backend only accepts its own model. Routing config holds the
      // correct default_model per provider; passing the agent's model verbatim
      // (e.g. gemma4:26b) to ollama_cloud yields 404 model-not-found.
      const model = this.routing?.providers?.[backend]?.default_model || null;
      console.log(`[Mother] Live providers (fastest-first): ${ranked.join(', ')} -> using ${backend} (model=${model || 'backend-default'})`);
      return { backend, model };
    } catch (e) {
      console.warn(`[Mother] No provider-status probe found (${e.message}); falling back to router rotation.`);
      return null;
    }
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
   * Phase 36.5: durable leaderboard. On first run, seed the DB from the JSON
   * fleet. Thereafter the DB is the source of truth: hydrate memory from it and
   * rewrite the JSON mirror so scores survive a leaderboard.json reset/revert.
   */
  hydrateLeaderboard() {
    try {
      if (leaderboardDB.count() > 0) {
        this.leaderboard.fleet = leaderboardDB.hydrate();
        fs.writeFileSync(this.leaderboardPath, JSON.stringify(this.leaderboard, null, 2));
        console.log(`[Mother] Leaderboard hydrated from DB (${Object.keys(this.leaderboard.fleet).length} agents).`);
      } else {
        const n = leaderboardDB.persist(this.leaderboard.fleet);
        console.log(`[Mother] Leaderboard DB seeded from JSON (${n} agents).`);
      }
    } catch (e) {
      console.warn(`[Mother] Leaderboard DB unavailable (${e.message}); using JSON only.`);
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
    const startTime = Date.now();

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
          message: `Goal: ${goal}. Context: Phase ${phaseName}. Provide your specialized output.`,
          options: this.liveProvider ? { overrideBackend: this.liveProvider.backend, overrideModel: this.liveProvider.model } : {}
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
          message: `Review results for phase ${phaseName}. Score it 0-100. Goal was: ${goal}. Results: ${JSON.stringify(results)}`,
          options: this.liveProvider ? { overrideBackend: this.liveProvider.backend, overrideModel: this.liveProvider.model } : {}
        })),
        `Phase ${phaseName} Verification`
      );
    } catch (e) {
      console.error(`[Mother] Verification failed for phase ${phaseName}: ${e.message}`);
      verifications = []; // Fallback to empty
    }

    // 4. Rank Update
    const verdictScores = await this.updateLeaderboard(squadNames, verifications);

    // 5. Atomic Commit
    this.atomicCommit(phaseName, goal, results);

    const durationMs = Date.now() - startTime;

    // 5b. Phase 38: append a dispatch event to the append-only event log.
    eventLog.record({
      phase: phaseName,
      goal: goal,
      provider: this.liveProvider ? this.liveProvider.backend : 'router-rotation',
      squad: squadNames,
      verdicts: verdictScores,
      durationMs,
      committed: true,
    });

    // 5c. Iteration 6: learn provider reliability from this dispatch. Attribute
    // by the backend that actually answered (results[].backend), success =
    // non-empty reply. Lets pickLiveProvider favor lanes that really deliver.
    try {
      const perCallMs = Array.isArray(results) && results.length ? Math.round(durationMs / results.length) : durationMs;
      for (const r of (Array.isArray(results) ? results : [])) {
        const ok = !!(r && typeof r.reply === 'string' && r.reply.trim().length > 0);
        leaderboardDB.recordProviderResult(r && r.backend, ok, perCallMs);
      }
    } catch (e) { console.warn(`[Mother] provider-stats record failed: ${e.message}`); }

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
    const scores = [];

    squad.forEach((name, idx) => {
      const verdict = verifications[idx]?.reply || "0";
      let score = parseInt(verdict.match(/\d+/) ? verdict.match(/\d+/)[0] : "50", 10);
      score = Math.max(0, Math.min(100, isNaN(score) ? 50 : score)); // clamp 0..100
      scores.push(score);

      if (fleet[name]) {
        fleet[name].completed_tasks++;
        const ema = (fleet[name].correctness_score * 0.8) + (score * 0.2);
        fleet[name].correctness_score = Math.max(0, Math.min(100, ema)); // cap at 100
        fleet[name].success_rate = score >= 80 ? 1 : 0; // simplistic binary
      }
    });

    this.rankFleet();
    fs.writeFileSync(this.leaderboardPath, JSON.stringify(this.leaderboard, null, 2));
    try { leaderboardDB.persist(fleet); } catch (e) { console.warn(`[Mother] DB persist failed: ${e.message}`); }
    return scores;
  }

  /**
   * Tasks-gated ranking so seeded agents with ~0 completed tasks can't sit at
   * the top with a default 100. Proven agents (>= MIN_TASKS) rank first by EMA;
   * the rest are flagged provisional. Keeps the leaderboard trustworthy.
   */
  rankFleet(minTasks = 5) {
    const fleet = this.leaderboard.fleet || {};
    const rows = Object.keys(fleet).map(k => ({ k, v: fleet[k] }));
    rows.sort((a, b) => {
      const ap = (a.v.completed_tasks || 0) >= minTasks;
      const bp = (b.v.completed_tasks || 0) >= minTasks;
      if (ap !== bp) return ap ? -1 : 1;
      return (b.v.correctness_score || 0) - (a.v.correctness_score || 0);
    });
    rows.forEach((r, i) => { r.v.rank = i + 1; r.v.provisional = (r.v.completed_tasks || 0) < minTasks; });
  }

  atomicCommit(phase, goal, results) {
    // Commit ONLY the phase artifacts — NOT `git add .`, which sweeps unrelated
    // working-tree changes into the phase commit and breaks atomicity.
    const artifacts = [this.leaderboardPath, path.join(__dirname, '../network/provider-status.json')]
      .filter(f => fs.existsSync(f));
    // Shell-safe, single-line subject (strip quotes/newlines, cap length).
    const subject = `mother: complete phase ${phase} - ${goal}`
      .replace(/[\r\n"]+/g, ' ').slice(0, 140);
    try {
      execSync(`git add ${artifacts.map(f => `"${f}"`).join(' ')}`, { stdio: 'ignore' });
      // Skip the commit if nothing was actually staged (avoids spurious failures).
      const staged = execSync('git diff --cached --name-only', { encoding: 'utf8' }).trim();
      if (!staged) { console.log(`[Mother] No artifact changes to commit for phase ${phase}`); return; }
      execSync(`git commit -m "${subject}"`, { stdio: 'ignore' });
      console.log(`[Mother] Atomic commit successful for phase ${phase} (${staged.split(/\n/).length} file(s))`);
    } catch (e) {
      console.error(`[Mother] Commit failed: ${e.message}`);
    }
  }
}

module.exports = MotherEngine;
