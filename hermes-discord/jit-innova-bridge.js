'use strict';
/**
 * hermes-discord/jit-innova-bridge.js — Jit ↔ innova-bot MCP Bridge
 *
 * Jit (จิต) เป็นเจ้าของกาย → ใช้ innova-bot MCP tools ผ่าน HTTP
 * ดึง skills, memory, agents จาก innova-bot → รวมกับ Jit
 *
 * innova-bot MCP: http://localhost:7010/sse
 *
 * Functions:
 *   callMcpTool(tool, params)        — call any innova-bot MCP tool
 *   getInnovaMemory()                — pull psi/ memory state
 *   syncInnovaSkills()               — list + cache available tools
 *   spawnInnovaSubagent(task, role)  — spawn sub-agent via javis_spawn_team
 *   whatShouldIDo(role)              — orchestrator: what_should_i_do_next
 */

const http  = require('http');
const https = require('https');
const url   = require('url');
const fs    = require('fs');
const path  = require('path');

const MCP_HOST   = process.env.MCP_HOST || '127.0.0.1';
const MCP_PORT   = parseInt(process.env.MCP_PORT || '7010', 10);
const MCP_BASE   = `http://${MCP_HOST}:${MCP_PORT}`;
const PSI_ROOT   = process.env.PSI_DIR || path.join(__dirname, '..', '..', 'innova-bot-template', 'psi');

// Warn if PSI_ROOT doesn't exist — non-fatal, innova-bot may not be installed
if (!fs.existsSync(PSI_ROOT)) {
  process.stdout.write('[jit-innova-bridge] PSI_ROOT not found: ' + PSI_ROOT + ' — set PSI_DIR env var to fix\n');
}

// ── HTTP helper: POST to innova-bot MCP ─────────────────────────────
function mcpPost(endpoint, body, callback) {
  const bodyStr = JSON.stringify(body);
  const opts = {
    hostname: MCP_HOST,
    port:     MCP_PORT,
    path:     endpoint,
    method:   'POST',
    headers: {
      'Content-Type':   'application/json',
      'Content-Length': Buffer.byteLength(bodyStr),
    },
  };
  const req = http.request(opts, function(res) {
    let data = '';
    res.on('data', function(c) { data += c; });
    res.on('end', function() {
      if (res.statusCode >= 400) {
        return callback(new Error('MCP HTTP ' + res.statusCode + ': ' + data.slice(0, 200)));
      }
      try { callback(null, JSON.parse(data)); }
      catch (e) { callback(null, { raw: data }); }
    });
  });
  req.on('error', callback);
  req.setTimeout(60000, function() { req.destroy(new Error('MCP timeout')); });
  req.write(bodyStr);
  req.end();
}

function mcpGet(endpoint, callback) {
  const opts = { hostname: MCP_HOST, port: MCP_PORT, path: endpoint, method: 'GET' };
  const req = http.request(opts, function(res) {
    let data = '';
    res.on('data', function(c) { data += c; });
    res.on('end', function() {
      try { callback(null, JSON.parse(data)); }
      catch (e) { callback(null, { raw: data }); }
    });
  });
  req.on('error', callback);
  req.setTimeout(10000, function() { req.destroy(new Error('MCP GET timeout')); });
  req.end();
}

// ── Core: call any innova-bot MCP tool ───────────────────────────────
/**
 * callMcpTool(toolName, params) → Promise<result>
 * Sends a JSON-RPC tool call to innova-bot MCP
 */
function callMcpTool(toolName, params) {
  return new Promise(function(resolve, reject) {
    mcpPost('/tools/call', {
      jsonrpc: '2.0',
      method:  'tools/call',
      id:      Date.now(),
      params:  { name: toolName, arguments: params || {} },
    }, function(err, result) {
      if (err) return reject(err);
      // MCP result: { result: { content: [{ type: 'text', text: '...' }] } }
      var content = (result.result || result);
      if (content && content.content && Array.isArray(content.content)) {
        var text = content.content.map(function(c) { return c.text || ''; }).join('\n');
        resolve({ text: text.trim(), raw: content });
      } else {
        resolve({ text: JSON.stringify(content), raw: content });
      }
    });
  });
}

// ── Check if innova-bot is running ───────────────────────────────────
function checkMcpHealth() {
  return new Promise(function(resolve) {
    mcpGet('/health', function(err, data) {
      if (err) return resolve({ ok: false, error: err.message });
      resolve({ ok: true, data: data });
    });
  });
}

// ── List available tools ──────────────────────────────────────────────
function listMcpTools() {
  return new Promise(function(resolve, reject) {
    mcpPost('/tools/list', { jsonrpc: '2.0', method: 'tools/list', id: 1, params: {} },
      function(err, result) {
        if (err) return reject(err);
        var tools = (result.result && result.result.tools) || [];
        resolve(tools.map(function(t) { return { name: t.name, description: (t.description || '').slice(0, 80) }; }));
      }
    );
  });
}

// ── Pull innova psi/ memory files ────────────────────────────────────
function getInnovaMemory() {
  var summary = { psiRoot: PSI_ROOT, files: {}, available: false };
  if (!fs.existsSync(PSI_ROOT)) {
    summary.error = 'PSI_ROOT not found: ' + PSI_ROOT + '. Set PSI_DIR env var.';
    return summary;
  }
  try {
    var keyFiles = [
      'memory/soul_sync.md',
      'memory/javis_personality.md',
      'memory/oracle_skills_manifest.md',
      'memory/innova_bot_understanding.md',
      'HOME.md',
    ];
    keyFiles.forEach(function(f) {
      var full = path.join(PSI_ROOT, f);
      if (fs.existsSync(full)) {
        summary.files[f] = fs.readFileSync(full, 'utf8').slice(0, 600) + '...';
        summary.available = true;
      }
    });
  } catch (e) {
    summary.error = e.message;
  }
  return summary;
}

// ── Spawn innova sub-agent team ───────────────────────────────────────
function spawnInnovaSubagent(task, options) {
  var opts = options || {};
  return callMcpTool('javis_spawn_team', {
    task:       task,
    team_size:  opts.teamSize   || 2,
    project:    opts.project    || 'jit-session',
    model_hint: opts.modelHint  || 'fast',
  });
}

// ── Orchestrator: ทำต่อไป ─────────────────────────────────────────────
function whatShouldIDo(role, project) {
  return callMcpTool('what_should_i_do_next', {
    role:         role    || 'SA',
    project_name: project || 'jit-session',
  });
}

// ── Oracle recap/rrr from innova-bot ─────────────────────────────────
function oracleRecap() {
  return callMcpTool('oracle_recap', {});
}

function oracleLearnSkill(content, skillName) {
  return callMcpTool('oracle_learn_skill', {
    content:    content,
    skill_name: skillName || 'jit-auto-learn',
    tags:       ['jit', 'multiagent'],
  });
}

function oracleTrace(query) {
  return callMcpTool('oracle_trace', { query: query || 'jit multiagent' });
}

module.exports = {
  callMcpTool,
  checkMcpHealth,
  listMcpTools,
  getInnovaMemory,
  spawnInnovaSubagent,
  whatShouldIDo,
  oracleRecap,
  oracleLearnSkill,
  oracleTrace,
  MCP_BASE,
};
