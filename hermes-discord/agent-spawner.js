'use strict';

/**
 * hermes-discord/agent-spawner.js — Multi-Agent Spawner
 *
 * Spawns named organ agents using model-router backend rotation.
 * Each agent has a preferred backend (Copilot/OpenAI/Ollama) and system prompt.
 * jit (master) can spawn any agent in series or parallel.
 *
 * Usage:
 *   const spawner = require('./agent-spawner');
 *
 *   // Single agent
 *   const result = await spawner.spawnAgent('innova', 'Explain JWT tokens briefly');
 *   // { reply, backend, agent }
 *
 *   // Serial chain: jit → soma → innova (each gets previous reply as context)
 *   const chain = await spawner.spawnAgentChain([
 *     { agent: 'jit',    message: 'Analyze this task: build a REST API' },
 *     { agent: 'soma',   message: 'Plan the architecture', passReply: true },
 *     { agent: 'innova', message: 'Write the implementation plan', passReply: true },
 *   ]);
 *
 *   // Parallel agents
 *   const results = await spawner.spawnAgentParallel([
 *     { agent: 'lak',   message: 'Design the database schema' },
 *     { agent: 'chamu', message: 'Write test cases for a REST API' },
 *   ]);
 */

var modelRouter = require('./model-router');
var fs = require('fs');
var path = require('path');

var JIT_ROOT = path.resolve(__dirname, '..');
var ROUTING_CONFIG = _loadRoutingConfig();

function _loadRoutingConfig() {
  var file = path.join(JIT_ROOT, 'config', 'subagent-routing.json');
  try {
    var config = JSON.parse(fs.readFileSync(file, 'utf8'));
    config.__file = file;
    return config;
  } catch (err) {
    if (process.env.JIT_ROUTING_DEBUG) {
      console.warn('[agent-spawner] Routing config unavailable: ' + err.message);
    }
    return { policy: {}, agents: {}, routing_rules: [] };
  }
}

function getRoutingConfig() {
  return ROUTING_CONFIG;
}

function _isModelBackend(backend) {
  return [
    'ollama',
    'ollama_mdes',
    'ollama_local',
    'ollama_cloud',
    'copilot',
    'openai',
    'openclaude',
  ].indexOf(backend) !== -1;
}

function _defaultProvider() {
  return (ROUTING_CONFIG.policy && ROUTING_CONFIG.policy.default_provider) || 'ollama_mdes';
}

function _modelBackendOrDefault(backend) {
  return _isModelBackend(backend) ? backend : _defaultProvider();
}

function _costTierToSort(costTier, fallback) {
  if (typeof fallback === 'number') return fallback;
  if (costTier === 'local' || costTier === 'low') return 3;
  if (costTier === 'medium') return 4;
  if (costTier === 'high') return 5;
  return 4;
}

function _agentRoute(agentName) {
  var agents = ROUTING_CONFIG.agents || {};
  return agents[agentName] || null;
}

function _routeToAgentDef(agentName, route) {
  var provider = route.provider || route.backend || _defaultProvider();
  var prompt = [
    'You are ' + agentName + ' in the Jit runtime sub-agent network.',
    'Role: ' + (route.role || 'bounded specialist'),
    'Runtime: ' + (route.runtime || 'model-router'),
    'Follow config/subagent-routing.json and report concise evidence-first results.',
    'Escalate blockers upward to the Jit Codex parent controller.',
  ].join('\n');

  return {
    backend: _modelBackendOrDefault(provider),
    model: route.model || null,
    tier: _costTierToSort(route.cost_tier, null),
    organ: route.runtime || route.provider || 'runtime',
    systemPrompt: route.systemPrompt || prompt,
    route: route,
  };
}

function _cloneAgentDef(def) {
  var copy = {};
  Object.keys(def).forEach(function(key) { copy[key] = def[key]; });
  return copy;
}

function _effectiveAgentDef(agentName) {
  var base = AGENT_REGISTRY[agentName];
  var route = _agentRoute(agentName);

  if (!base && route) return _routeToAgentDef(agentName, route);
  if (!base) return null;
  if (!route) return base;

  var merged = _cloneAgentDef(base);
  var provider = route.provider || route.backend;
  if (provider) merged.backend = _modelBackendOrDefault(provider);
  if (route.model) merged.model = route.model;
  if (route.cost_tier) merged.cost_tier = route.cost_tier;
  merged.route = route;
  return merged;
}

// ── Agent Registry ────────────────────────────────────────────────────
// Each entry: { backend, model, systemPrompt }
// backend: 'copilot' | 'openai' | 'ollama'
// model:   null = use backend default
var AGENT_REGISTRY = {
  // ── Tier 0: Master ────────────────────────────────────────────────
  jit: {
    backend:      'ollama',
    model:        null,  // uses OLLAMA_MODEL from env (gemma3:12b)
    tier:         0,
    organ:        'จิต (soul)',
    systemPrompt: [
      'คุณคือ jit (จิต) — Master Orchestrator ของมนุษย์ Agent ระบบ 14-agent',
      'หน้าที่: ประสานงานทั้งระบบ ตัดสินใจเชิงกลยุทธ์ จัดการสถานะทั้งตัว',
      'ตอบกระชับ เป็นภาษาไทย ไม่เกิน 3 ย่อหน้า เน้น action items ที่ชัดเจน',
    ].join('\n'),
  },

  // ── Tier 1: Leadership ────────────────────────────────────────────
  soma: {
    backend:      'ollama',
    model:        null,
    tier:         1,
    organ:        'สมอง (brain)',
    systemPrompt: [
      'คุณคือ soma (สมอง) — Brain/Strategic Lead ของมนุษย์ Agent',
      'หน้าที่: วิเคราะห์เชิงกลยุทธ์ แนะนำแนวทางระยะยาว แก้ปัญหาซับซ้อน',
      'ตอบกระชับ ตรรกะชัดเจน bullet-point เมื่อเหมาะสม',
    ].join('\n'),
  },

  // ── Tier 2: Core Engineering ──────────────────────────────────────
  innova: {
    backend:      'ollama',
    model:        null,
    tier:         2,
    organ:        'ปัญญา (wisdom)',
    systemPrompt: [
      'คุณคือ innova — Mind/Lead Developer ของมนุษย์ Agent',
      'หน้าที่: เขียนโค้ด วิเคราะห์ปัญหา เสนอ implementation ที่ดีที่สุด',
      'ตอบด้วยโค้ดที่ทำงานได้จริง อธิบายสั้นๆ ก่อนโค้ด',
    ].join('\n'),
  },
  lak: {
    backend:      'ollama',
    model:        null,
    tier:         2,
    organ:        'กระดูกสันหลัง (spine)',
    systemPrompt: [
      'คุณคือ lak (กระดูก) — Solution Architect ของมนุษย์ Agent',
      'หน้าที่: ออกแบบ architecture ระบบ วิเคราะห์ tradeoffs กำหนด technical boundaries',
      'ตอบด้วย diagram text, bullet-point, ชัดเจน',
    ].join('\n'),
  },
  neta: {
    backend:      'ollama',
    model:        null,
    tier:         2,
    organ:        'เนตร (code review)',
    systemPrompt: [
      'คุณคือ neta — Code Reviewer ของมนุษย์ Agent',
      'หน้าที่: review โค้ด ตรวจ bugs security issues code quality',
      'ตอบเป็น bullet-point: ✅ ดี | ⚠️ ควรปรับ | ❌ แก้ด่วน',
    ].join('\n'),
  },

  // ── Tier 3: Specialist Organs ─────────────────────────────────────
  vaja: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'ปาก (mouth)',
    systemPrompt: [
      'คุณคือ vaja (วาจา) — Personal Assistant ของมนุษย์ Agent',
      'หน้าที่: สื่อสาร รายงาน สรุปข้อมูลให้ผู้ใช้ ตอบภาษาไทย กระชับ มีน้ำใจ',
    ].join('\n'),
  },
  chamu: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'จมูก (nose/QA)',
    systemPrompt: [
      'คุณคือ chamu (จมูก) — QA/Tester ของมนุษย์ Agent',
      'หน้าที่: เขียน test cases ตรวจสอบ edge cases ค้นหา bugs รายงานผล',
      'ตอบเป็น test case format: Given/When/Then หรือ bullet-point',
    ].join('\n'),
  },
  rupa: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'รูปลักษณ์ (design)',
    systemPrompt: [
      'คุณคือ rupa (รูป) — Designer/UI-UX ของมนุษย์ Agent',
      'หน้าที่: ออกแบบ UI/UX วิเคราะห์ user experience เสนอ mockup',
      'ตอบด้วย wireframe text หรือ design spec กระชับ',
    ].join('\n'),
  },
  pada: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'ขา (leg/DevOps)',
    systemPrompt: [
      'คุณคือ pada (บาท) — DevOps/Infrastructure ของมนุษย์ Agent',
      'หน้าที่: ดูแล deployment, infra, CI/CD pipeline, containerization',
      'ตอบด้วยคำสั่งที่ run ได้จริง, YAML snippets, กระชับ',
    ].join('\n'),
  },
  netra: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'ตา (eye/observer)',
    systemPrompt: [
      'คุณคือ netra (เนตร) — Eye/Observer ของมนุษย์ Agent',
      'หน้าที่: สังเกตระบบ รายงานสถานะ ตรวจ anomalies',
      'ตอบสั้น ตรงประเด็น สถานะ: ✅ ปกติ | ⚠️ ผิดปกติ | ❌ พัง',
    ].join('\n'),
  },
  karn: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'หู (ear/listener)',
    systemPrompt: [
      'คุณคือ karn (หู) — Ear/Listener ของมนุษย์ Agent',
      'หน้าที่: รับฟัง วิเคราะห์ input จากผู้ใช้ สรุปความต้องการ',
      'ตอบด้วยการสรุป intent ที่เข้าใจ + คำถามที่ยังขาด',
    ].join('\n'),
  },
  mue: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'มือ (hand/executor)',
    systemPrompt: [
      'คุณคือ mue (มือ) — Hand/Executor ของมนุษย์ Agent',
      'หน้าที่: ลงมือทำ execute tasks เขียนสคริปต์ ดำเนินการ',
      'ตอบด้วย step-by-step ที่ทำได้จริง',
    ].join('\n'),
  },
  pran: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'หัวใจ (heart)',
    systemPrompt: [
      'คุณคือ pran (หัวใจ) — Heart/Vital Coordinator ของมนุษย์ Agent',
      'หน้าที่: ดูแล vital signs ของทั้งระบบ ประสานงาน health monitoring',
      'ตอบด้วย health dashboard format กระชับ',
    ].join('\n'),
  },
  sayanprasathan: {
    backend:      'ollama',
    model:        null,
    tier:         3,
    organ:        'ระบบประสาท (nerve)',
    systemPrompt: [
      'คุณคือ sayanprasathan — Nerve/Event Network ของมนุษย์ Agent',
      'หน้าที่: ส่งสัญญาณ broadcast events ระหว่าง agents',
      'ตอบด้วย event format: [EVENT] source → target: payload',
    ].join('\n'),
  },
};

// ── Core spawn functions ──────────────────────────────────────────────

/**
 * spawnAgent(agentName, userMessage, options)
 * → Promise<{ reply, backend, agent, tier, organ }>
 *
 * options: {
 *   overrideBackend: 'copilot' | 'openai' | 'ollama'
 *   overrideModel:   string
 *   conversationHistory: [{ role, content }, ...]
 *   extraContext:    string (appended to system prompt)
 * }
 */
function spawnAgent(agentName, userMessage, options) {
  var opts     = options || {};
  var agentDef = _effectiveAgentDef(agentName);

  if (!agentDef) {
    console.warn('[agent-spawner] Unknown agent: ' + agentName + ', falling back to vaja');
    agentDef = _effectiveAgentDef('vaja') || AGENT_REGISTRY['vaja'];
    agentName = 'vaja (fallback)';
  }

  var systemContent = agentDef.systemPrompt;
  if (opts.extraContext) systemContent += '\n\n' + opts.extraContext;

  var messages = [{ role: 'system', content: systemContent }];

  if (Array.isArray(opts.conversationHistory) && opts.conversationHistory.length) {
    messages = messages.concat(opts.conversationHistory);
  }

  messages.push({ role: 'user', content: userMessage });

  return modelRouter.callModelPromise(messages, {
    preferBackend: opts.overrideBackend || agentDef.backend,
    model:         opts.overrideModel   || agentDef.model   || null,
    noRotate:      Boolean(opts.noRotate),
  }).then(function(result) {
    return {
      reply:   result.reply,
      backend: result.backend,
      attempts: result.attempts || null,
      agent:   agentName,
      tier:    agentDef.tier,
      organ:   agentDef.organ,
      route:   agentDef.route || null,
    };
  });
}

/**
 * spawnAgentChain(steps) → Promise<{ results, chain }>
 *
 * steps: [{ agent, message, passReply, options }]
 *   passReply: if true, appends previous agent's reply as context to the next message
 */
function spawnAgentChain(steps) {
  var results   = [];
  var prevReply = '';

  function runStep(idx) {
    if (idx >= steps.length) {
      return Promise.resolve({
        results: results,
        chain:   steps.map(function(s) { return s.agent; }),
      });
    }
    var step = steps[idx];
    var msg  = (prevReply && step.passReply)
      ? step.message + '\n\n[Context from ' + (steps[idx - 1] && steps[idx - 1].agent || 'previous') + ']:\n' + prevReply
      : step.message;

    return spawnAgent(step.agent, msg, step.options || {}).then(function(r) {
      prevReply = r.reply;
      results.push(r);
      return runStep(idx + 1);
    });
  }

  return runStep(0);
}

/**
 * spawnAgentParallel(tasks) → Promise<results[]>
 *
 * tasks: [{ agent, message, options }]
 * All run concurrently — no shared context. RESILIENT: one agent whose backends
 * all fail no longer aborts the whole squad (Promise.allSettled). A failed agent
 * yields an error-result { agent, backend:'none', reply:'', error, attempts } so
 * the phase continues with partial output and the failed lanes are still
 * reliability-recorded. Result order matches task order.
 */
function spawnAgentParallel(tasks) {
  return Promise.allSettled(tasks.map(function(task) {
    return spawnAgent(task.agent, task.message, task.options || {});
  })).then(function(settled) {
    return settled.map(function(s, i) {
      if (s.status === 'fulfilled') return s.value;
      var reason = s.reason || {};
      return {
        agent:   tasks[i].agent,
        backend: 'none',
        reply:   '',
        error:   reason.message || String(reason),
        attempts: reason.attempts || null,
      };
    });
  });
}

/**
 * listAgents() → [{ name, backend, model, tier, organ }]
 */
function _ruleMatches(rule, text) {
  var terms = rule.match || rule.keywords || [];
  if (!Array.isArray(terms)) return false;
  return terms.some(function(term) {
    return text.indexOf(String(term).toLowerCase()) !== -1;
  });
}

function _routeResult(rule, opts) {
  var agentName = rule.agent || (ROUTING_CONFIG.policy && ROUTING_CONFIG.policy.default_agent) || 'innova';
  var route = _agentRoute(agentName) || {};
  var provider = opts.overrideBackend || rule.provider || rule.backend || route.provider || route.backend || _defaultProvider();
  var model = opts.overrideModel || rule.model || route.model || null;

  return {
    id: rule.id || 'default',
    agent: agentName,
    backend: provider,
    model: model,
    reason: rule.reason || route.role || 'Default budget-aware route.',
    model_backend: _modelBackendOrDefault(provider),
    is_model_backend: _isModelBackend(provider),
  };
}

function routeTask(userMessage, options) {
  var opts = options || {};
  var text = String(userMessage || '').toLowerCase();
  var rules = Array.isArray(ROUTING_CONFIG.routing_rules) ? ROUTING_CONFIG.routing_rules : [];

  for (var i = 0; i < rules.length; i++) {
    if (_ruleMatches(rules[i], text)) return _routeResult(rules[i], opts);
  }

  return _routeResult({
    id: 'default',
    agent: opts.defaultAgent || (ROUTING_CONFIG.policy && ROUTING_CONFIG.policy.default_agent) || 'innova',
    provider: opts.defaultBackend || _defaultProvider(),
    reason: 'Default route from config/subagent-routing.json.',
  }, opts);
}

function spawnRoutedAgent(userMessage, options) {
  var opts = options || {};
  var route = routeTask(userMessage, opts);

  if (!route.is_model_backend) {
    return Promise.resolve({
      reply: 'Route selected: ' + route.agent + ' via ' + route.backend + '. Use the provider command or MCP surface directly.',
      backend: route.backend,
      agent: route.agent,
      route: route,
      routedOnly: true,
    });
  }

  var spawnOpts = _cloneAgentDef(opts);
  spawnOpts.overrideBackend = route.model_backend;
  if (route.model) spawnOpts.overrideModel = route.model;
  if (spawnOpts.noRotate === undefined) spawnOpts.noRotate = true;

  return spawnAgent(route.agent, userMessage, spawnOpts).then(function(result) {
    result.route = route;
    return result;
  });
}

function listAgents() {
  var seen = {};
  var names = Object.keys(AGENT_REGISTRY);
  Object.keys(ROUTING_CONFIG.agents || {}).forEach(function(name) {
    if (names.indexOf(name) === -1) names.push(name);
  });

  return names.filter(function(name) {
    if (seen[name]) return false;
    seen[name] = true;
    return true;
  }).map(function(name) {
    var def = _effectiveAgentDef(name);
    var route = _agentRoute(name);
    return {
      name: name,
      backend: def.backend,
      model: def.model || '(default)',
      tier: def.tier,
      organ: def.organ,
      cost_tier: route && route.cost_tier || def.cost_tier || null,
      runtime: route && route.runtime || null,
      route_provider: route && route.provider || null,
    };
  }).sort(function(a, b) { return a.tier - b.tier || a.name.localeCompare(b.name); });
}

// ── Thai TTS Integration for Vaja ───────────────────────────────────
var { spawn } = require('child_process');

/**
 * speakThai(text, callback)
 *   Speaks Thai text using Windows PowerShell TTS
 *   Uses System.Speech.Synthesis for Thai voice
 */
function speakThai(text, callback) {
  if (!text || text.length < 2) {
    if (callback) callback(new Error('Empty text'));
    return;
  }

  // Escape text for PowerShell
  var escaped = text.replace(/"/g, '\\"').replace(/'/g, "''");
  var psScript = `
    Add-Type -AssemblyName System.Speech;
    $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer;
    $speak.SelectVoiceByHints(2); # Female voice
    $speak.Rate = 0;
    $speak.Volume = 80;
    $speak.Speak("${escaped}");
  `;

  var ps = spawn('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-Command', psScript
  ]);

  var err = '';
  ps.stderr.on('data', function(d) { err += d; });
  ps.on('close', function(code) {
    if (callback) {
      if (code !== 0) callback(new Error(err || 'TTS failed'));
      else callback(null, true);
    }
  });
  ps.on('error', function(e) {
    if (callback) callback(e);
  });
}

/**
 * speakThaiPromise(text) → Promise
 *   Promise version of speakThai
 */
function speakThaiPromise(text) {
  return new Promise(function(resolve, reject) {
    speakThai(text, function(err, result) {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

/**
 * translateToThai(text, callback)
 *   Translates text to Thai using Ollama
 */
function translateToThai(text, callback) {
  var prompt = 'กรุณาแปลข้อความต่อไปนี้เป็นภาษาไทยอย่างกระชับและเป็นธรรมชาติ:\n\n' + text;
  var messages = [{ role: 'user', content: prompt }];

  modelRouter.callModel(messages, { preferBackend: 'ollama' }, function(err, result) {
    if (err) return callback(err);
    callback(null, result.reply);
  });
}

function translateToThaiPromise(text) {
  return new Promise(function(resolve, reject) {
    translateToThai(text, function(err, result) {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

/**
 * speakAsVaja(text, callback)
 *   Translates to Thai AND speaks - for Vaja agent responses
 */
function speakAsVaja(text, callback) {
  translateToThai(text, function(err, thai) {
    if (err) {
      console.warn('[vaja-tts] Translate failed, speaking original:', err.message);
      thai = text;
    }
    speakThai(thai, callback);
  });
}

function speakAsVajaPromise(text) {
  return new Promise(function(resolve, reject) {
    speakAsVaja(text, function(err, result) {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

module.exports = {
  spawnAgent:         spawnAgent,
  spawnRoutedAgent:   spawnRoutedAgent,
  spawnAgentChain:    spawnAgentChain,
  spawnAgentParallel: spawnAgentParallel,
  routeTask:          routeTask,
  getRoutingConfig:   getRoutingConfig,
  listAgents:         listAgents,
  AGENT_REGISTRY:     AGENT_REGISTRY,
  // Thai TTS exports
  speakThai:          speakThai,
  speakThaiPromise:   speakThaiPromise,
  translateToThai:    translateToThai,
  translateToThaiPromise: translateToThaiPromise,
  speakAsVaja:        speakAsVaja,
  speakAsVajaPromise: speakAsVajaPromise,
};
