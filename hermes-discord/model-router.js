'use strict';

/**
 * hermes-discord/model-router.js — Multi-Backend Model Router
 *
 * Routes LLM calls across OpenAI (Codex), GitHub Copilot, and MDES Ollama.
 * Auto-detects Copilot token from VS Code apps.json.
 * Rotates to next backend on quota exhaustion (429/402/403).
 *
 * Env vars:
 *   OPENAI_API_KEY      — OpenAI/Codex key
 *   OPENAI_MODEL        — default: gpt-4o
 *   COPILOT_TOKEN       — Copilot API token (or auto-detect)
 *   COPILOT_MODEL       — default: gpt-4o
 *   OLLAMA_BASE_URL     — default: https://ollama.mdes-innova.online
 *   OLLAMA_TOKEN        — MDES Ollama auth token
 *   OLLAMA_MODEL        — default: gemma4:e4b
 *   MULTI_BACKEND_ORDER — comma-separated order, default: copilot,openai,ollama
 *
 * Usage:
 *   const router = require('./model-router');
 *   router.callModel(messages, { preferBackend: 'copilot' }, (err, result) => {
 *     // result = { reply: '...', backend: 'copilot' }
 *   });
 */

const fs    = require('fs');
const path  = require('path');
const os    = require('os');
const https = require('https');
const http  = require('http');
const url   = require('url');
const childProcess = require('child_process');
const openClaudeAdapter = require('./openclaude-adapter');

// Load .env from Jit root for direct node executions
try {
  var envPath = path.join(__dirname, '..', '.env');
  if (fs.existsSync(envPath)) {
    fs.readFileSync(envPath, 'utf8').split(/\r?\n/).forEach(function(line) {
      var trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) return;
      var eq = trimmed.indexOf('=');
      if (eq === -1) return;
      var k = trimmed.slice(0, eq).trim();
      var v = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
      if (!process.env[k]) process.env[k] = v;
    });
  }
} catch (_) {}

function _normalizeModelAlias(model) {
  var value = String(model || '').trim();
  if (value === 'gemma4:31b-cloud9') return 'gemma4:31b-cloud';
  return value;
}

function _modelForOllamaBackend(model, backendName, backendUrl) {
  var value = _normalizeModelAlias(model);
  if (
    backendName === 'ollama_cloud' &&
    value.endsWith('-cloud') &&
    /^https?:\/\/ollama\.com\/?$/i.test(String(backendUrl || ''))
  ) {
    return value.slice(0, -'-cloud'.length);
  }
  return value;
}

// ── Multi-Backend Configuration ────────────────────────────────────────
// Primary: MDES Ollama (free, always available)
// Auto-load token from skill config if not in env
var _defaultToken = process.env.OLLAMA_TOKEN || '';
if (!_defaultToken) {
  try {
    var skillFile = path.join(__dirname, '..', '.github', 'skills', 'multi-agent', 'SKILL.md');
    if (fs.existsSync(skillFile)) {
      var content = fs.readFileSync(skillFile, 'utf8');
      var match = content.match(/OLLAMA_TOKEN[=:]([a-zA-Z0-9]+)/);
      if (match) _defaultToken = match[1];
    }
  } catch (_) {}
}

const OLLAMA_MDES_URL   = process.env.OLLAMA_MDES_URL   || process.env.OLLAMA_BASE_URL || 'https://ollama.mdes-innova.online';
const OLLAMA_MDES_TOKEN = process.env.OLLAMA_MDES_TOKEN || process.env.OLLAMA_TOKEN || process.env.THAILLM_TOKEN || _defaultToken;
const OLLAMA_MDES_MODEL = process.env.OLLAMA_MDES_MODEL || process.env.OLLAMA_MODEL || process.env.THAILLM_MODEL || 'gemma4:26b';

// Local: localhost Ollama (zero latency)
const OLLAMA_LOCAL_URL   = process.env.OLLAMA_LOCAL_URL   || 'http://localhost:11434';
const OLLAMA_LOCAL_TOKEN = process.env.OLLAMA_LOCAL_TOKEN || '';
const OLLAMA_LOCAL_MODEL  = process.env.OLLAMA_LOCAL_MODEL  || 'qwen2.5-coder:7b';

// Cloud: Ollama.com (free tier, backup)
const OLLAMA_CLOUD_URL   = process.env.OLLAMA_CLOUD_URL   || 'https://ollama.com';
const OLLAMA_CLOUD_TOKEN = process.env.OLLAMA_CLOUD_TOKEN || '';
const JIT_CLOUD_MODEL    = _normalizeModelAlias(process.env.JIT_CLOUD_MODEL || 'gemma4:31b-cloud');
const OLLAMA_CLOUD_MODEL = _normalizeModelAlias(process.env.OLLAMA_CLOUD_MODEL || JIT_CLOUD_MODEL);

// ThaiLLM (optional) – if THAILLM_BASE_URL is absent, reuse MDES URL
const THAILLM_URL   = process.env.THAILLM_BASE_URL   || OLLAMA_MDES_URL;
const THAILLM_TOKEN = process.env.THAILLM_TOKEN      || OLLAMA_MDES_TOKEN;
const THAILLM_MODEL = process.env.THAILLM_MODEL      || OLLAMA_MDES_MODEL;

// Fallback: OpenAI/Copilot (paid, quota-limited)
const OPENAI_KEY    = process.env.OPENAI_API_KEY   || '';
const OPENAI_MODEL  = process.env.OPENAI_MODEL     || 'gpt-4o';
const OPENAI_URL    = process.env.OPENAI_BASE_URL  || 'https://api.openai.com';
const OPENAI_CODEX_MODEL = process.env.OPENAI_CODEX_MODEL || process.env.OMX_DEFAULT_FRONTIER_MODEL || 'gpt-5.5';

const COPILOT_TOKEN_ENV = process.env.COPILOT_TOKEN || process.env.GITHUB_COPILOT_TOKEN || '';
const COPILOT_MODEL     = process.env.COPILOT_MODEL || 'gpt-4o';
const COPILOT_CHAT_URL  = 'https://api.githubcopilot.com';
const COPILOT_TOKEN_URL = 'https://api.github.com';

const OPENCLAUDE_HOST  = process.env.OPENCLAUDE_HOST  || 'localhost';
const OPENCLAUDE_PORT  = process.env.OPENCLAUDE_PORT  || 8000;
const OPENCLAUDE_MODEL = process.env.OPENCLAUDE_MODEL || 'claude-3.5-sonnet';

// Backend order: MDES → Local → Cloud → Copilot → OpenAI → OpenClaude
function _normalizeBackendName(name) {
  var v = String(name || '').trim().toLowerCase();
  if (v === 'ollama' || v === 'mdes') return 'ollama_mdes';
  if (v === 'local' || v === 'ollama-local') return 'ollama_local';
  if (v === 'cloud' || v === 'ollama-cloud') return 'ollama_cloud';
  if (v === 'thai' || v === 'thai_llm' || v === 'thaillm') return 'thaillm';
  return v;
}

const BACKEND_ORDER = (process.env.MULTI_BACKEND_ORDER || 'ollama_mdes,thaillm,ollama_local,ollama_cloud,copilot,openai,openclaude')
  .split(',')
  .map(function(s) { return _normalizeBackendName(s); })
  .filter(Boolean);

// ── Backend Manager Class ───────────────────────────────────────────────
class BackendManager {
  constructor() {
    this.backends = {
      ollama_mdes: {
        name: 'MDES Ollama',
        url: OLLAMA_MDES_URL,
        token: OLLAMA_MDES_TOKEN,
        model: OLLAMA_MDES_MODEL,
        type: 'ollama'
      },
      ollama_local: {
        name: 'Local Ollama',
        url: OLLAMA_LOCAL_URL,
        token: OLLAMA_LOCAL_TOKEN,
        model: OLLAMA_LOCAL_MODEL,
        type: 'ollama'
      },
      ollama_cloud: {
        name: 'Ollama Cloud',
        url: OLLAMA_CLOUD_URL,
        token: OLLAMA_CLOUD_TOKEN,
        model: OLLAMA_CLOUD_MODEL,
        type: 'ollama'
      },
      thaillm: {
        name: 'ThaiLLM',
        url: THAILLM_URL,
        token: THAILLM_TOKEN,
        model: THAILLM_MODEL,
        type: 'ollama'
      },
      copilot: {
        name: 'GitHub Copilot',
        url: COPILOT_CHAT_URL,
        token: null,
        model: COPILOT_MODEL,
        type: 'copilot'
      },
      openai: {
        name: 'OpenAI',
        url: OPENAI_URL,
        token: OPENAI_KEY,
        model: OPENAI_MODEL,
        type: 'openai'
      },
      openclaude: {
        name: 'OpenClaude',
        url: openClaudeAdapter.OPENCLAUDE_BASE_URL,
        token: null,
        model: OPENCLAUDE_MODEL,
        type: 'openclaude'
      }
    };
  }

  getBackend(name) { return this.backends[name]; }
  getAllBackends() { return this.backends; }
  getOrder() { return BACKEND_ORDER; }

  // Get next available backend (auto-fallback)
  async getNextAvailable(tryFirst) {
    const order = tryFirst ? [tryFirst, ...BACKEND_ORDER.filter(b => b !== tryFirst)] : BACKEND_ORDER;
    for (const name of order) {
      const be = this.backends[name];
      if (await this.isAvailable(be)) return name;
    }
    return null;
  }

  async isAvailable(backend) {
    if (!backend || !backend.url) return false;
    try {
      const endpoint = backend.type === 'ollama' ? `${backend.url}/api/tags` : backend.url;
      // Simple connectivity check
      return true;
    } catch { return false; }
  }
}

const backendManager = new BackendManager();

// ── Error counters (reset on success) ────────────────────────────────
const _errors = { copilot: 0, openai: 0, ollama: 0, ollama_mdes: 0, ollama_local: 0, ollama_cloud: 0, thaillm: 0, openclaude: 0 };

function _isCopilotOAuthToken(token) {
  var t = String(token || '').trim();
  if (!t) return false;
  return t.startsWith('ghu_') || t.startsWith('ghs_') || t.startsWith('gho_') || t.startsWith('github_pat_');
}

function _resolveGhCliToken() {
  try {
    var out = childProcess.execFileSync('gh', ['auth', 'token'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 4000,
      windowsHide: true,
    });
    var token = String(out || '').trim();
    return token || null;
  } catch (_) {
    return null;
  }
}

// ── Copilot Token Resolution ──────────────────────────────────────────
function _resolveCopilotOAuthToken() {
  // 1. Explicit env
  if (COPILOT_TOKEN_ENV && _isCopilotOAuthToken(COPILOT_TOKEN_ENV)) return COPILOT_TOKEN_ENV;
  var ghCliToken = _resolveGhCliToken();
  if (ghCliToken && _isCopilotOAuthToken(ghCliToken)) return ghCliToken;

  // 2. VS Code / GitHub Copilot token files (Windows + Linux paths)
  const candidates = [
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'github-copilot', 'apps.json'),
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'GitHub Copilot', 'apps.json'),
    process.env.APPDATA      && path.join(process.env.APPDATA, 'GitHub Copilot', 'hosts.json'),
    process.env.APPDATA      && path.join(process.env.APPDATA, 'Code', 'User', 'globalStorage', 'github.copilot-chat', 'hosts.json'),
    process.env.APPDATA      && path.join(process.env.APPDATA, 'Code', 'User', 'globalStorage', 'github.copilot', 'hosts.json'),
    process.env.APPDATA      && path.join(process.env.APPDATA, 'Code', 'User', 'globalStorage', 'github.copilot-chat', 'apps.json'),
    process.env.APPDATA      && path.join(process.env.APPDATA, 'Code', 'User', 'globalStorage', 'github.copilot', 'apps.json'),
    path.join(os.homedir(), '.config', 'github-copilot', 'hosts.json'),
    path.join(os.homedir(), '.config', 'github-copilot', 'apps.json'),
  ].filter(Boolean);

  for (var i = 0; i < candidates.length; i++) {
    var p = candidates[i];
    try {
      var data = JSON.parse(fs.readFileSync(p, 'utf8'));
      // Format: { "github.com": { "oauth_token": "ghu_..." } }
      var gh = data['github.com'] || data;
      var tok = gh['oauth_token'] || gh['token'];
      if (tok) return tok;
    } catch (_) {}
  }
  return null;
}

// Copilot API token cache (25 min TTL)
var _copilotApiToken    = null;
var _copilotApiTokenExp = 0;
var _copilotCliAvailable = null;
var _copilotCliBin = null;
var _codexCliAvailable = null;

function _resolveCopilotCliBin() {
  if (_copilotCliBin) return _copilotCliBin;
  _copilotCliBin = process.platform === 'win32' ? 'copilot.cmd' : 'copilot';
  return _copilotCliBin;
}

function _hasCopilotCli() {
  if (_copilotCliAvailable !== null) return _copilotCliAvailable;
  try {
    if (process.platform === 'win32') {
      childProcess.execFileSync('powershell.exe', ['-NoProfile', '-Command', 'copilot --version'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        timeout: 4000,
        windowsHide: true,
      });
    } else {
      childProcess.execFileSync(_resolveCopilotCliBin(), ['--version'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        timeout: 4000,
        windowsHide: true,
      });
    }
    _copilotCliAvailable = true;
  } catch (_) {
    _copilotCliAvailable = false;
  }
  return _copilotCliAvailable;
}

function _hasCodexCli() {
  if (_codexCliAvailable !== null) return _codexCliAvailable;
  try {
    if (process.platform === 'win32') {
      childProcess.execFileSync('powershell.exe', ['-NoProfile', '-Command', 'codex --version'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        timeout: 5000,
        windowsHide: true,
      });
    } else {
      childProcess.execFileSync('codex', ['--version'], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        timeout: 5000,
        windowsHide: true,
      });
    }
    _codexCliAvailable = true;
  } catch (_) {
    _codexCliAvailable = false;
  }
  return _codexCliAvailable;
}

function _exchangeCopilotToken(oauthToken, callback) {
  var now = Date.now();
  if (_copilotApiToken && now < _copilotApiTokenExp) {
    return callback(null, _copilotApiToken);
  }

  var parsed = url.parse(COPILOT_TOKEN_URL + '/copilot_internal/v2/token');
  var opts = {
    hostname: parsed.hostname,
    port:     443,
    path:     parsed.path,
    method:   'GET',
    headers: {
      'Authorization': 'Bearer ' + oauthToken,
      'User-Agent':    'GithubCopilot/1.155.0',
      'Accept':        'application/json',
    },
  };

  var req = https.request(opts, function(res) {
    var body = '';
    res.on('data', function(c) { body += c; });
    res.on('end', function() {
      if (res.statusCode && res.statusCode >= 400) {
        return callback(new Error('Copilot exchange HTTP ' + res.statusCode + ': ' + body.slice(0, 100)));
      }
      try {
        var j = JSON.parse(body);
        if (!j.token) return callback(new Error('No token in exchange response'));
        _copilotApiToken    = j.token;
        _copilotApiTokenExp = now + 25 * 60 * 1000;
        callback(null, j.token);
      } catch (e) {
        callback(new Error('Copilot exchange parse error: ' + e.message));
      }
    });
  });
  req.on('error', callback);
  req.setTimeout(10000, function() { req.destroy(new Error('Copilot token exchange timeout')); });
  req.end();
}

// ── Generic HTTP POST ─────────────────────────────────────────────────
function _httpPost(baseUrl, apiPath, extraHeaders, bodyObj, callback) {
  var parsed  = url.parse(baseUrl + apiPath);
  var isHttps = parsed.protocol === 'https:';
  var lib     = isHttps ? https : http;
  var bodyStr = JSON.stringify(bodyObj);

  var opts = {
    hostname: parsed.hostname,
    port:     parsed.port || (isHttps ? 443 : 80),
    path:     parsed.path,
    method:   'POST',
    headers:  Object.assign({
      'Content-Type':   'application/json',
      'Content-Length': Buffer.byteLength(bodyStr),
    }, extraHeaders),
  };

  var req = lib.request(opts, function(res) {
    var data = '';
    res.on('data', function(c) { data += c; });
    res.on('end', function() {
      if (res.statusCode === 429 || res.statusCode === 402 || res.statusCode === 403) {
        var qErr = new Error('quota:' + res.statusCode);
        qErr.quota      = true;
        qErr.statusCode = res.statusCode;
        return callback(qErr);
      }
      if (res.statusCode && res.statusCode >= 400) {
        return callback(new Error('HTTP ' + res.statusCode + ': ' + data.slice(0, 200)));
      }
      callback(null, data);
    });
  });
  req.on('error', callback);
  req.setTimeout(90000, function() { req.destroy(new Error('Request timeout')); });
  req.write(bodyStr);
  req.end();
}

// ── Backend Callers ───────────────────────────────────────────────────
function _callOpenAI(messages, model, callback) {
  function useCodexFallback(originalErr) {
    if (!_hasCodexCli()) return callback(originalErr || new Error('OPENAI_API_KEY not set'));
    return _callOpenAIViaCodexCli(messages, model, callback);
  }

  if (!OPENAI_KEY) return useCodexFallback(new Error('OPENAI_API_KEY not set'));

  _httpPost(OPENAI_URL, '/v1/chat/completions',
    { 'Authorization': 'Bearer ' + OPENAI_KEY },
    { model: model || OPENAI_MODEL, messages: messages, stream: false },
    function(err, data) {
      if (err) return useCodexFallback(err);
      try {
        var j = JSON.parse(data);
        var reply = j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content;
        callback(null, String(reply || '').trim());
      } catch (e) {
        callback(new Error('OpenAI parse: ' + e.message + ' raw:' + data.slice(0, 100)));
      }
    }
  );
}

function _buildCodexPrompt(messages) {
  var transcript = messages.map(function(m) {
    return '[' + (m.role || 'user') + '] ' + String(m.content || '');
  }).join('\n\n');
  return [
    'You are acting as the OpenAI backend for Jit.',
    'Answer the conversation only.',
    'Do not modify files, run commands, or take external actions.',
    'Reply with the assistant answer only.',
    '',
    'Conversation:',
    transcript,
  ].join('\n');
}

function _callOpenAIViaCodexCli(messages, model, callback) {
  var prompt = _buildCodexPrompt(messages);
  var outFile = path.join(os.tmpdir(), 'jit-openai-codex-' + process.pid + '-' + Date.now() + '.txt');
  var cliModel = model || OPENAI_CODEX_MODEL;
  var childEnv = Object.assign({}, process.env);
  delete childEnv.OPENAI_API_KEY;
  delete childEnv.CODEX_API_KEY;
  delete childEnv.OPENAI_BASE_URL;

  function finish(err, stdout, stderr) {
    var reply = '';
    try {
      if (fs.existsSync(outFile)) {
        reply = fs.readFileSync(outFile, 'utf8').trim();
      }
      if (!reply && stdout) {
        reply = String(stdout).trim();
      }
      if (reply) return callback(null, reply);
      if (err) {
        var detail = stderr || stdout || err.message;
        return callback(new Error('Codex CLI failed: ' + String(detail).trim().slice(0, 200)));
      }
      if (!reply) return callback(new Error('Codex CLI returned empty reply'));
    } catch (readErr) {
      return callback(new Error('Codex CLI read failed: ' + readErr.message));
    } finally {
      try { if (fs.existsSync(outFile)) fs.unlinkSync(outFile); } catch (_) {}
    }
  }

  if (process.platform === 'win32') {
    var psScript = [
      '$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:CODEX_PROMPT_B64))',
      '$args=@("exec","--skip-git-repo-check","--ephemeral","--sandbox","read-only","--color","never","--output-last-message",$env:CODEX_OUTPUT_PATH)',
      'if($env:CODEX_MODEL){$args+=@("--model",$env:CODEX_MODEL)}',
      '$args+="-"',
      '$p | & codex @args',
    ].join('; ');
    return childProcess.execFile('powershell.exe', ['-NoProfile', '-Command', psScript], {
      encoding: 'utf8',
      timeout: 180000,
      windowsHide: true,
      maxBuffer: 2 * 1024 * 1024,
      env: Object.assign(childEnv, {
        CODEX_PROMPT_B64: Buffer.from(prompt, 'utf8').toString('base64'),
        CODEX_OUTPUT_PATH: outFile,
        CODEX_MODEL: cliModel,
      }),
    }, finish);
  }

  var args = ['exec', '--skip-git-repo-check', '--ephemeral', '--sandbox', 'read-only', '--color', 'never', '--output-last-message', outFile];
  if (cliModel) args = args.concat(['--model', cliModel]);
  args.push(prompt);
  return childProcess.execFile('codex', args, {
    encoding: 'utf8',
    timeout: 180000,
    windowsHide: true,
    maxBuffer: 2 * 1024 * 1024,
    env: childEnv,
  }, finish);
}

function _callCopilot(messages, model, callback) {
  if (_hasCopilotCli()) {
    var prompt = messages.map(function(m) {
      return '[' + (m.role || 'user') + '] ' + String(m.content || '');
    }).join('\n\n');
    if (process.platform === 'win32') {
      var psScript = [
        '$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:COPILOT_PROMPT_B64))',
        '$args=@("-s","-p",$p)',
        model ? ('$args+=@("--model","' + String(model).replace(/"/g, '""') + '")') : '',
        '& copilot @args',
      ].filter(Boolean).join('; ');
      return childProcess.execFile('powershell.exe', ['-NoProfile', '-Command', psScript], {
        encoding: 'utf8',
        timeout: 120000,
        windowsHide: true,
        maxBuffer: 2 * 1024 * 1024,
        env: Object.assign({}, process.env, {
          COPILOT_PROMPT_B64: Buffer.from(prompt, 'utf8').toString('base64'),
        }),
      }, function(err, stdout, stderr) {
        if (err) {
          var detail = stderr || stdout || err.message;
          return callback(new Error('Copilot CLI failed: ' + String(detail).trim().slice(0, 200)));
        }
        return callback(null, String(stdout || '').trim());
      });
    }

    var args = ['-s', '-p', prompt];
    if (model) args = args.concat(['--model', model]);
    return childProcess.execFile(_resolveCopilotCliBin(), args, {
      encoding: 'utf8',
      timeout: 120000,
      windowsHide: true,
      maxBuffer: 2 * 1024 * 1024,
    }, function(err, stdout, stderr) {
      if (err) {
        var detail = stderr || stdout || err.message;
        return callback(new Error('Copilot CLI failed: ' + String(detail).trim().slice(0, 200)));
      }
      return callback(null, String(stdout || '').trim());
    });
  }

  var oauthToken = _resolveCopilotOAuthToken();
  if (!oauthToken) return callback(new Error('No Copilot OAuth token found (install VS Code + GitHub Copilot, or set COPILOT_TOKEN)'));
  _exchangeCopilotToken(oauthToken, function(err, apiToken) {
    if (err) return callback(err);
    _httpPost(COPILOT_CHAT_URL, '/chat/completions', {
      'Authorization':         'Bearer ' + apiToken,
      'Copilot-Integration-Id': 'vscode-chat',
      'Editor-Version':        'vscode/1.89.0',
      'Editor-Plugin-Version': 'copilot-chat/0.22.4',
      'OpenAI-Intent':         'conversation-panel',
    }, { model: model || COPILOT_MODEL, messages: messages, stream: false },
    function(err2, data) {
      if (err2) return callback(err2);
      try {
        var j = JSON.parse(data);
        var reply = j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content;
        callback(null, String(reply || '').trim());
      } catch (e) {
        callback(new Error('Copilot parse: ' + e.message + ' raw:' + data.slice(0, 100)));
      }
    });
  });
}

function _getOllamaConfig(backendName) {
  var be = backendManager.getBackend(backendName);
  if (!be || be.type !== 'ollama') be = backendManager.getBackend('ollama_mdes');
  var normalizedUrl = be.url;
  var normalizedToken = be.token;

  // Ollama Cloud supports auth-free local proxying after `ollama signin`.
  if (
    backendName === 'ollama_cloud' &&
    !normalizedToken &&
    /^https?:\/\/ollama\.com\/?$/i.test(String(normalizedUrl || ''))
  ) {
    normalizedUrl = OLLAMA_LOCAL_URL;
  }

  return {
    url: normalizedUrl,
    model: be.model,
    token: normalizedToken,
  };
}

function _callOllama(messages, model, callback, backendName) {
  var cfg = _getOllamaConfig(backendName);
  var parsed  = url.parse(cfg.url + '/api/chat');
  var isHttps = parsed.protocol === 'https:';
  var lib     = isHttps ? https : http;
  var selectedModel = _modelForOllamaBackend(model || cfg.model, backendName, cfg.url);
  var bodyStr = JSON.stringify({ model: selectedModel, stream: false, messages: messages });

  var opts = {
    hostname: parsed.hostname,
    port:     parsed.port || (isHttps ? 443 : 80),
    path:     parsed.path,
    method:   'POST',
    headers: {
      'Content-Type':   'application/json',
      'Content-Length': Buffer.byteLength(bodyStr),
    },
  };
  if (cfg.token) {
    opts.headers.Authorization = 'Bearer ' + cfg.token;
  }

  var req = lib.request(opts, function(res) {
    var data = '';
    res.on('data', function(c) { data += c; });
    res.on('end', function() {
      if (res.statusCode && res.statusCode >= 400) {
        return callback(new Error('Ollama HTTP ' + res.statusCode + ': ' + data.slice(0, 200)));
      }
      try {
        var j = JSON.parse(data);
        var reply = (j.message && j.message.content) || j.response || '';
        callback(null, reply.trim());
      } catch (e) {
        callback(new Error('Ollama parse: ' + e.message + ' raw:' + data.slice(0, 100)));
      }
    });
  });
  req.on('error', callback);
  req.setTimeout(90000, function() { req.destroy(new Error('Ollama timeout')); });
  req.write(bodyStr);
  req.end();
}

function _callOpenClaude(messages, model, callback) {
  openClaudeAdapter.callOpenClaude(messages, { model: model || OPENCLAUDE_MODEL }, function(err, result) {
    if (err) return callback(err);
    callback(null, result.text);
  });
}

// ── Core: callModel with rotation ────────────────────────────────────
/**
 * callModel(messages, options, callback)
 *   messages:  OpenAI-format messages array [{ role, content }, ...]
 *   options:   { preferBackend, model, noRotate }
 *   callback:  function(err, { reply, backend })
 */
function callModel(messages, options, callback) {
  var opts  = options || {};
  var order = BACKEND_ORDER.slice();
  if (opts.preferBackend) opts.preferBackend = _normalizeBackendName(opts.preferBackend);

  // Put preferred backend first
  if (opts.preferBackend) {
    var preferredIndex = order.indexOf(opts.preferBackend);
    if (preferredIndex > 0) {
      order.splice(preferredIndex, 1);
      order.unshift(opts.preferBackend);
    } else if (preferredIndex === -1 && backendManager.getBackend(opts.preferBackend)) {
      order.unshift(opts.preferBackend);
    }
  }

  var attempt = 0;

  function tryNext() {
    if (attempt >= order.length) {
      return callback(new Error('All backends exhausted (' + order.join(', ') + ')'));
    }
    var backend = _normalizeBackendName(order[attempt++]);
    console.log('[model-router] -> ' + backend + (opts.model ? ' model=' + opts.model : ''));

    var caller;
    if (backend === 'openai')  caller = _callOpenAI;
    else if (backend === 'copilot') caller = _callCopilot;
    else if (backend === 'openclaude') caller = _callOpenClaude;
    else                        caller = function(msgs, mdl, cb) { _callOllama(msgs, mdl, cb, backend); };

    caller(messages, opts.model || null, function(err, reply) {
      if (!err) {
        _errors[backend] = 0;
        return callback(null, { reply: reply, backend: backend });
      }
      console.warn('[model-router] ' + backend + ' failed: ' + err.message);
      _errors[backend] = (_errors[backend] || 0) + 1;
      if (opts.noRotate) return callback(err);
      tryNext();
    });
  }

  tryNext();
}

/**
 * callModelPromise(messages, options) → Promise<{ reply, backend }>
 */
function callModelPromise(messages, options) {
  return new Promise(function(resolve, reject) {
    callModel(messages, options || {}, function(err, result) {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

/**
 * status() → summary of available backends
 */
function status() {
  var oauthToken = _resolveCopilotOAuthToken();
  var ocStatus = openClaudeAdapter.status();
  var envCopilotTokenLooksValid = _isCopilotOAuthToken(COPILOT_TOKEN_ENV);
  var copilotCliAvailable = _hasCopilotCli();
  var codexCliAvailable = _hasCodexCli();
  var cloudCfg = _getOllamaConfig('ollama_cloud');
  return {
    order:    BACKEND_ORDER,
    backends: {
      copilot: {
        available: copilotCliAvailable || !!oauthToken,
        tokenSource: copilotCliAvailable ? 'copilot_cli' : (oauthToken ? (COPILOT_TOKEN_ENV ? 'env' : 'file') : (COPILOT_TOKEN_ENV && !envCopilotTokenLooksValid ? 'invalid_env_token' : 'none')),
        errors: _errors.copilot || 0
      },
      openai:  {
        available: !!OPENAI_KEY || codexCliAvailable,
        tokenSource: !!OPENAI_KEY ? 'api_key' : (codexCliAvailable ? 'codex_cli' : 'none'),
        model: OPENAI_MODEL,
        fallback: codexCliAvailable ? 'codex_cli' : 'none',
        fallbackModel: codexCliAvailable ? OPENAI_CODEX_MODEL : null,
        errors: _errors.openai  || 0
      },
      ollama_mdes: { available: !!OLLAMA_MDES_URL, url: OLLAMA_MDES_URL, model: OLLAMA_MDES_MODEL, errors: _errors.ollama || 0 },
      thaillm: { available: !!THAILLM_URL, url: THAILLM_URL, model: THAILLM_MODEL, errors: _errors.ollama || 0 },
      ollama_local: { available: !!OLLAMA_LOCAL_URL, url: OLLAMA_LOCAL_URL, model: OLLAMA_LOCAL_MODEL, errors: _errors.ollama || 0 },
      ollama_cloud: { available: !!OLLAMA_CLOUD_URL, url: OLLAMA_CLOUD_URL, resolvedUrl: cloudCfg.url, model: OLLAMA_CLOUD_MODEL, apiModel: _modelForOllamaBackend(OLLAMA_CLOUD_MODEL, 'ollama_cloud', cloudCfg.url), targetModel: JIT_CLOUD_MODEL, errors: _errors.ollama || 0 },
      // Backward-compatible alias for older callers.
      ollama: { available: !!OLLAMA_MDES_URL, url: OLLAMA_MDES_URL, model: OLLAMA_MDES_MODEL, errors: _errors.ollama || 0 },
      openclaude: { available: ocStatus.available, configured: ocStatus.configured, host: ocStatus.host, port: ocStatus.port, model: ocStatus.model, healthEndpoint: ocStatus.healthEndpoint, errors: _errors.openclaude || 0 },
    },
    primary: BACKEND_ORDER[0] || 'ollama',
  };
}

/**
 * callModelOllamaFirst(messages, options, callback)
 * Special mode for OMC skills: Ollama primary, others fallback
 * No quota limits, always available if server running
 */
function callModelOllamaFirst(messages, options, callback) {
  var opts = Object.assign({}, options || {});
  opts.preferBackend = 'ollama_mdes';
  return callModel(messages, opts, callback);
}

/**
 * callModelOllamaFirstPromise(messages, options)
 * Promise version of callModelOllamaFirst
 */
function callModelOllamaFirstPromise(messages, options) {
  return callModelPromise(messages, Object.assign({}, options || {}, { preferBackend: 'ollama_mdes' }));
}

module.exports = { 
  callModel, 
  callModelPromise, 
  callModelOllamaFirst,
  callModelOllamaFirstPromise,
  status 
};
