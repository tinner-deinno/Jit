#!/usr/bin/env node
/**
 * eval/commandcode-probe.js - CommandCode Provider Liveness Probe
 *
 * Dedicated probe for the CommandCode API (https://api.commandcode.ai/provider/v1).
 * Tests model list retrieval, OpenAI-format chat, and Anthropic-format messages.
 * Writes results to network/provider-status.json (merged with existing).
 *
 * Usage:
 *   node eval/commandcode-probe.js
 *   node eval/commandcode-probe.js --timeout 30000
 *   node eval/commandcode-probe.js --models deepseek/deepseek-v4-flash,MiniMaxAI/MiniMax-M3
 *   node eval/commandcode-probe.js --quick          (models list + 1 chat only)
 *   node eval/commandcode-probe.js --anthropic       (also test /messages endpoint)
 *
 * Exit codes:
 *   0  - at least one probe succeeded (ALIVE)
 *   1  - all probes failed
 *   2  - configuration error (no API key)
 */
'use strict';

const fs   = require('fs');
const path = require('path');
const https = require('https');
const http  = require('http');

// ── Load .env ──────────────────────────────────────────────────────────
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

// ── Configuration ──────────────────────────────────────────────────────
const BASE_URL = (process.env.COMMANDCODE_BASE_URL || 'https://api.commandcode.ai/provider/v1').replace(/\/+$/, '');
const API_KEY  = (process.env.COMMANDCODE_API_KEY || '').replace(/^Bearer\s+/i, '').trim();
const DEFAULT_MODELS = [
  'deepseek/deepseek-v4-flash',    // fast/cheap OpenAI-format model
  'MiniMaxAI/MiniMax-M3',          // open-weight model
  'Qwen/Qwen3.6-Plus',             // Alibaba Qwen
];
const ANTHROPIC_MODELS = [
  'claude-sonnet-4-6',              // Anthropic-format model
];
const PING_PROMPT = [{ role: 'user', content: 'Reply with exactly: OK' }];

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i > -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const TIMEOUT       = parseInt(arg('--timeout', '30000'), 10);
const QUICK         = process.argv.includes('--quick');
const DO_ANTHROPIC  = process.argv.includes('--anthropic');
const MODELS_ARG    = String(arg('--models', ''))
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);

const STATUS_FILE = path.join(__dirname, '..', 'network', 'provider-status.json');

// ── HTTP helpers ───────────────────────────────────────────────────────
function _httpGet(url, headers, timeoutMs) {
  return new Promise((resolve, reject) => {
    const parsed  = new URL(url);
    const isHttps = parsed.protocol === 'https:';
    const lib     = isHttps ? https : http;
    const opts = {
      hostname: parsed.hostname,
      port:     parsed.port || (isHttps ? 443 : 80),
      path:     parsed.pathname + parsed.search,
      method:   'GET',
      headers:  headers,
    };
    const req = lib.request(opts, (res) => {
      let data = '';
      res.on('data', c => { data += c; });
      res.on('end', () => {
        if (res.statusCode && res.statusCode >= 400) {
          const err = new Error('HTTP ' + res.statusCode + ': ' + data.slice(0, 200));
          err.statusCode = res.statusCode;
          return reject(err);
        }
        resolve({ status: res.statusCode, data: data });
      });
    });
    req.on('error', reject);
    req.setTimeout(timeoutMs || TIMEOUT, () => { req.destroy(new Error('timeout')); });
    req.end();
  });
}

function _httpPost(url, headers, body, timeoutMs) {
  return new Promise((resolve, reject) => {
    const parsed  = new URL(url);
    const isHttps = parsed.protocol === 'https:';
    const lib     = isHttps ? https : http;
    const bodyStr = JSON.stringify(body);
    const opts = {
      hostname: parsed.hostname,
      port:     parsed.port || (isHttps ? 443 : 80),
      path:     parsed.pathname + parsed.search,
      method:   'POST',
      headers: Object.assign({
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(bodyStr),
      }, headers),
    };
    const req = lib.request(opts, (res) => {
      let data = '';
      res.on('data', c => { data += c; });
      res.on('end', () => {
        if (res.statusCode === 429 || res.statusCode === 402 || res.statusCode === 403) {
          const err = new Error('quota:' + res.statusCode);
          err.quota = true;
          err.statusCode = res.statusCode;
          return reject(err);
        }
        if (res.statusCode && res.statusCode >= 400) {
          const err = new Error('HTTP ' + res.statusCode + ': ' + data.slice(0, 200));
          err.statusCode = res.statusCode;
          return reject(err);
        }
        resolve({ status: res.statusCode, data: data });
      });
    });
    req.on('error', reject);
    req.setTimeout(timeoutMs || TIMEOUT, () => { req.destroy(new Error('timeout')); });
    req.write(bodyStr);
    req.end();
  });
}

// ── Error classification ────────────────────────────────────────────────
function classify(err) {
  const msg = String(err && err.message || err || '').toLowerCase();
  if (/\b(429|402|403|quota|rate.?limit|exhaust|too many)\b/.test(msg)) return 'RATE_LIMITED';
  if (/\b(401|unauthor|invalid.*(key|token)|missing.*(key|token))\b/.test(msg)) return 'AUTH';
  if (/(econn|enotfound|etimedout|timeout|socket|network|fetch failed|refused)/.test(msg)) return 'UNREACHABLE';
  return 'ERROR';
}

// ── Probe: Models list ─────────────────────────────────────────────────
async function probeModelsList() {
  const startedAt = Date.now();
  try {
    const url = BASE_URL + '/models';
    const res = await _httpGet(url, { 'Authorization': 'Bearer ' + API_KEY });
    const data = JSON.parse(res.data);
    const models = (data.data || data.models || []).map(m => m.id || m);
    return {
      test: 'models_list',
      status: 'ALIVE',
      ms: Date.now() - startedAt,
      model_count: models.length,
      models: models.slice(0, 15),
      truncated: models.length > 15,
    };
  } catch (err) {
    return {
      test: 'models_list',
      status: classify(err),
      ms: Date.now() - startedAt,
      error: String(err && err.message || err).slice(0, 120),
    };
  }
}

// ── Probe: OpenAI-format chat completion ────────────────────────────────
async function probeOpenAIChat(model) {
  const startedAt = Date.now();
  try {
    const url = BASE_URL + '/chat/completions';
    const res = await _httpPost(url,
      { 'Authorization': 'Bearer ' + API_KEY },
      { model: model, messages: PING_PROMPT, max_tokens: 32, temperature: 0 },
    );
    const data = JSON.parse(res.data);
    const reply = (data.choices && data.choices[0] && data.choices[0].message &&
                   data.choices[0].message.content) || '';
    const usable = /\bok\b/i.test(reply.trim());
    return {
      test: 'openai_chat',
      model: model,
      status: usable ? 'ALIVE' : 'ERROR',
      ms: Date.now() - startedAt,
      reply: reply.trim().slice(0, 80),
      ...(usable ? {} : { error: 'non-usable reply: ' + reply.trim().slice(0, 80) }),
      usage: data.usage || null,
    };
  } catch (err) {
    return {
      test: 'openai_chat',
      model: model,
      status: classify(err),
      ms: Date.now() - startedAt,
      error: String(err && err.message || err).slice(0, 120),
    };
  }
}

// ── Probe: Anthropic-format messages ────────────────────────────────────
async function probeAnthropicMessages(model) {
  const startedAt = Date.now();
  try {
    const url = BASE_URL + '/messages';
    const res = await _httpPost(url,
      { 'Authorization': 'Bearer ' + API_KEY },
      { model: model, max_tokens: 32, messages: PING_PROMPT },
    );
    const data = JSON.parse(res.data);
    const reply = (data.content && data.content[0] && data.content[0].text) || '';
    const usable = /\bok\b/i.test(reply.trim());
    return {
      test: 'anthropic_messages',
      model: model,
      status: usable ? 'ALIVE' : 'ERROR',
      ms: Date.now() - startedAt,
      reply: reply.trim().slice(0, 80),
      ...(usable ? {} : { error: 'non-usable reply: ' + reply.trim().slice(0, 80) }),
      usage: data.usage || null,
    };
  } catch (err) {
    return {
      test: 'anthropic_messages',
      model: model,
      status: classify(err),
      ms: Date.now() - startedAt,
      error: String(err && err.message || err).slice(0, 120),
    };
  }
}

// ── Merge results into provider-status.json ─────────────────────────────
function writeStatus(probeResults) {
  let previous = { results: {}, usable: [] };
  try {
    previous = JSON.parse(fs.readFileSync(STATUS_FILE, 'utf8'));
  } catch (_) {}

  // Merge: update the commandcode entry with probe summary
  const ccAlive = probeResults.some(r => r.status === 'ALIVE');
  const ccResult = {
    backend: 'commandcode',
    status: ccAlive ? 'ALIVE' : (probeResults.some(r => r.status === 'RATE_LIMITED') ? 'RATE_LIMITED' : 'ERROR'),
    ms: Math.min(...probeResults.filter(r => r.status === 'ALIVE').map(r => r.ms).concat([99999])),
    served_by: 'commandcode',
    sample: (probeResults.find(r => r.status === 'ALIVE') || {}).reply || '',
    probed_at_ms: Date.now(),
    probe_detail: probeResults,
  };

  const mergedResults = { ...(previous.results || {}), commandcode: ccResult };
  const usable = Object.entries(mergedResults)
    .filter(([_, row]) => row && row.status === 'ALIVE' && row.served_by === row.backend)
    .map(([backend]) => backend)
    .sort();

  const out = {
    probed_at_ms: Date.now(),
    timeout_ms: TIMEOUT,
    full_probe: false,
    probed_backends: ['commandcode'],
    usable,
    cached_usable: previous.cached_usable || [],
    results: mergedResults,
  };

  fs.writeFileSync(STATUS_FILE, JSON.stringify(out, null, 2));
  return out;
}

// ── Main ────────────────────────────────────────────────────────────────
(async () => {
  if (!API_KEY) {
    console.error('[commandcode-probe] COMMANDCODE_API_KEY not set — cannot probe');
    process.exit(2);
  }

  console.log(`\n[commandcode-probe] base=${BASE_URL} timeout=${TIMEOUT}ms\n`);

  const probes = [];

  // 1. Models list
  console.log('[commandcode-probe] probing models list...');
  const modelsResult = await probeModelsList();
  probes.push(modelsResult);
  const icon = { ALIVE: 'ok', RATE_LIMITED: 'limit', AUTH: 'auth', UNREACHABLE: 'down', ERROR: 'bad' };
  console.log(`  models_list: ${icon[modelsResult.status] || ''} ${modelsResult.status} ${modelsResult.ms}ms` +
    (modelsResult.model_count ? ` (${modelsResult.model_count} models)` : '') +
    (modelsResult.error ? ` — ${modelsResult.error}` : ''));

  // 2. OpenAI-format chat probes
  const openAIModels = MODELS_ARG.length > 0
    ? MODELS_ARG.filter(m => !/^claude/i.test(m))
    : (QUICK ? [DEFAULT_MODELS[0]] : DEFAULT_MODELS);

  for (const model of openAIModels) {
    console.log(`[commandcode-probe] probing openai_chat model=${model}...`);
    const result = await probeOpenAIChat(model);
    probes.push(result);
    console.log(`  openai_chat (${model}): ${icon[result.status] || ''} ${result.status} ${result.ms}ms` +
      (result.reply ? ` "${result.reply}"` : '') +
      (result.usage ? ` tokens=${result.usage.total_tokens}` : '') +
      (result.error ? ` — ${result.error}` : ''));
  }

  // 3. Anthropic-format messages probes (opt-in)
  if (DO_ANTHROPIC) {
    const anthropicModels = MODELS_ARG.length > 0
      ? MODELS_ARG.filter(m => /^claude/i.test(m))
      : ANTHROPIC_MODELS;
    for (const model of anthropicModels) {
      console.log(`[commandcode-probe] probing anthropic_messages model=${model}...`);
      const result = await probeAnthropicMessages(model);
      probes.push(result);
      console.log(`  anthropic_messages (${model}): ${icon[result.status] || ''} ${result.status} ${result.ms}ms` +
        (result.reply ? ` "${result.reply}"` : '') +
        (result.usage ? ` tokens=${result.usage.total_tokens}` : '') +
        (result.error ? ` — ${result.error}` : ''));
    }
  }

  // Summary
  const alive = probes.filter(r => r.status === 'ALIVE');
  const failed = probes.filter(r => r.status !== 'ALIVE');
  console.log(`\n[commandcode-probe] results: ${alive.length}/${probes.length} ALIVE`);

  // Merge into provider-status.json
  const statusOut = writeStatus(probes);
  console.log(`[commandcode-probe] wrote ${path.relative(path.join(__dirname, '..'), STATUS_FILE)}`);
  console.log(`[commandcode-probe] usable backends: ${statusOut.usable.join(', ') || 'NONE'}`);

  // Table summary
  console.log('\n| test | model | status | latency | detail |');
  console.log('|---|---|---|---|---|');
  for (const r of probes) {
    const detail = r.status === 'ALIVE'
      ? `"${r.reply || ''}"${r.usage ? ' tokens=' + r.usage.total_tokens : ''}${r.model_count ? ' models=' + r.model_count : ''}`
      : (r.error || '');
    console.log(`| ${r.test} | ${r.model || '-'} | ${icon[r.status] || ''} ${r.status} | ${r.ms}ms | ${detail} |`);
  }

  process.exit(alive.length > 0 ? 0 : 1);
})();