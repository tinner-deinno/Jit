'use strict';

/**
 * network/proxy-thai.js — Thai-Syllable Proxy (TICKET-008)
 *
 * HTTP proxy on port 4322 that uses deterministic Thai syllable splitting
 * to route /v1/chat/completions requests across the multi-backend pool.
 *
 * Dependencies:
 *   hermes-discord/model-router.js  — backend caller + rotation
 *   limbs/thai-splitter.js          — canonicalization + routing keys
 */

const http = require('http');
const url = require('url');
const path = require('path');

// Import existing modules
const router = require('../hermes-discord/model-router');
const splitter = require('../limbs/thai-splitter');

// ── Config ───────────────────────────────────────────────────────────
const CONFIG = {
  port: process.env.PROXY_THAI_PORT || 4322,
  enabled: process.env.PROXY_THAI_ENABLED !== 'false',
  splitter: {
    enabled: process.env.PROXY_SPLITTER_ENABLED !== 'false',
    fallbackOnError: true,
    cacheSize: parseInt(process.env.PROXY_ROUTE_CACHE_SIZE || '10000', 10)
  },
  cache: {
    enabled: process.env.PROXY_CACHE_ENABLED !== 'false',
    ttlSeconds: parseInt(process.env.PROXY_CACHE_TTL || '300', 10)
  },
  fallback: {
    onSplitterFailure: process.env.PROXY_SPLITTER_FALLBACK || 'hash',
    onBackendExhaustion: process.env.PROXY_BACKEND_FALLBACK || 'ollama_mdes'
  },
  logging: {
    level: process.env.PROXY_LOG_LEVEL || 'info'
  },
  timeout: {
    clientMs: parseInt(process.env.PROXY_CLIENT_TIMEOUT || '120000', 10),
    backendMs: parseInt(process.env.PROXY_BACKEND_TIMEOUT || '90000', 10)
  }
};

// ── Simple LRU Cache ───────────────────────────────────────────────────
class LRUCache {
  constructor(maxSize) {
    this.maxSize = maxSize;
    this.cache = new Map();
  }
  get(key) { return this.cache.get(key); }
  set(key, value) {
    if (this.cache.has(key)) this.cache.delete(key);
    else if (this.cache.size >= this.maxSize) {
      const first = this.cache.keys().next().value;
      this.cache.delete(first);
    }
    this.cache.set(key, value);
  }
  clear() { this.cache.clear(); }
}

const routeCache = CONFIG.cache.enabled ? new LRUCache(CONFIG.splitter.cacheSize) : null;

// ── Logging ────────────────────────────────────────────────────────────
function log(level, msg, meta) {
  const levels = { debug: 0, info: 1, warn: 2, error: 3 };
  if ((levels[level] || 0) < (levels[CONFIG.logging.level] || 1)) return;
  const entry = Object.assign({ time: new Date().toISOString(), level }, meta || {}, { msg });
  console.log(JSON.stringify(entry));
}

// ── Prompt extraction ──────────────────────────────────────────────────
function extractPromptText(body) {
  if (!body || !Array.isArray(body.messages)) return '';
  return body.messages.map(m => String(m.content || '')).join(' ');
}

// ── Routing key computation ────────────────────────────────────────────
function computeRoutingKey(text) {
  if (!CONFIG.splitter.enabled) return simpleHash(text);
  try {
    const canonical = router.thaiCanonicalize(text);
    // Derive routing key from canonical form directly.
    // router.routingKey() is for messages array + strips Thai chars; use simpleHash
    // on canonical to preserve syllable structure for deterministic routing.
    const key = simpleHash(canonical);
    return { key, canonical, source: 'splitter' };
  } catch (err) {
    log('warn', 'splitter failed, falling back', { error: err.message });
    if (CONFIG.splitter.fallbackOnError) {
      return { key: simpleHash(text), canonical: text, source: 'fallback-hash' };
    }
    throw err;
  }
}

function simpleHash(text) {
  let h = 5381;
  const s = String(text || '');
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) + h) + s.charCodeAt(i);
  }
  return (h >>> 0).toString(36);
}

// ── Backend selection ──────────────────────────────────────────────────
function pickBackend(keyObj, preferBackend) {
  const cacheKey = keyObj.key + '|' + (preferBackend || '');
  if (routeCache) {
    const cached = routeCache.get(cacheKey);
    if (cached) return { backend: cached, cached: true };
  }
  const be = router.pickBackendByKey(keyObj.key, router.status().order, preferBackend);
  if (routeCache) routeCache.set(cacheKey, be);
  return { backend: be, cached: false };
}

// ── JSON body parser ───────────────────────────────────────────────────
function parseBody(req, callback) {
  const chunks = [];
  let size = 0;
  const max = 2 * 1024 * 1024; // 2 MB
  req.on('data', chunk => {
    size += chunk.length;
    if (size > max) return callback(new Error('Payload too large'));
    chunks.push(chunk);
  });
  req.on('end', () => {
    const raw = Buffer.concat(chunks).toString('utf8');
    try {
      callback(null, JSON.parse(raw));
    } catch (e) {
      callback(new Error('Invalid JSON'));
    }
  });
}

// ── Proxy handler ────────────────────────────────────────────────────
function proxyHandler(req, res) {
  const started = Date.now();
  const reqId = `${process.pid}-${started}-${Math.random().toString(36).slice(2, 8)}`;

  res.setHeader('Content-Type', 'application/json');

  if (req.method !== 'POST' || req.url !== '/v1/chat/completions') {
    res.statusCode = 404;
    return res.end(JSON.stringify({ error: 'Not found', path: req.url, method: req.method }));
  }

  parseBody(req, (err, body) => {
    if (err) {
      res.statusCode = 400;
      log('warn', 'bad request', { reqId, error: err.message });
      return res.end(JSON.stringify({ error: 'invalid_payload', message: err.message }));
    }

    const promptText = extractPromptText(body);
    const keyObj = computeRoutingKey(promptText);
    const preferBackend = body.model ? router._normalizeBackendName ? 'ollama_mdes' : undefined : undefined;
    const pick = pickBackend(keyObj, preferBackend);

    log('info', 'routing', {
      reqId,
      key: keyObj.key,
      canonicalLength: (keyObj.canonical || '').length,
      source: keyObj.source,
      backend: pick.backend,
      cached: pick.cached,
      promptPreview: promptText.slice(0, 60).replace(/\n/g, ' ')
    });

    const routerOpts = {
      preferBackend: pick.backend,
      model: body.model || undefined,
      timeoutMs: CONFIG.timeout.backendMs
    };

    router.callModel(body.messages || [], routerOpts, (err2, result) => {
      const latencyMs = Date.now() - started;

      if (err2) {
        log('error', 'backend failure', {
          reqId,
          backend: pick.backend,
          latencyMs,
          error: err2.message,
          attempts: (err2.attempts || []).map(a => ({ backend: a.backend, ok: a.ok, error: a.error }))
        });

        // If all backends exhausted, return structured error
        if (/all backends exhausted/i.test(err2.message)) {
          res.statusCode = 503;
          return res.end(JSON.stringify({
            error: 'backends_exhausted',
            message: err2.message,
            attempts: err2.attempts || [],
            reqId
          }));
        }

        res.statusCode = 502;
        return res.end(JSON.stringify({
          error: 'backend_error',
          message: err2.message,
          backend: pick.backend,
          reqId
        }));
      }

      log('info', 'success', {
        reqId,
        backend: result.backend,
        latencyMs,
        replyLength: (result.reply || '').length
      });

      res.statusCode = 200;
      res.end(JSON.stringify({
        id: reqId,
        object: 'chat.completion',
        created: Math.floor(started / 1000),
        model: body.model || result.backend,
        choices: [{
          index: 0,
          message: { role: 'assistant', content: result.reply },
          finish_reason: 'stop'
        }],
        usage: {
          prompt_tokens: promptText.length / 4, // rough estimate
          completion_tokens: (result.reply || '').length / 4,
          total_tokens: (promptText.length + (result.reply || '').length) / 4
        },
        _jit_meta: {
          backend: result.backend,
          routingKey: keyObj.key,
          routingSource: keyObj.source,
          cached: pick.cached,
          latencyMs,
          attempts: result.attempts || []
        }
      }));
    });
  });
}

// ── Health check ───────────────────────────────────────────────────────
function healthHandler(req, res) {
  res.setHeader('Content-Type', 'application/json');
  const status = router.status();
  res.statusCode = 200;
  res.end(JSON.stringify({
    status: 'ok',
    proxy: 'thai-syllable',
    port: CONFIG.port,
    splitterEnabled: CONFIG.splitter.enabled,
    cacheEnabled: CONFIG.cache.enabled,
    backends: Object.keys(status.backends || {}).filter(k => status.backends[k].available)
  }));
}

// ── Server factory ───────────────────────────────────────────────────
function createServer() {
  return http.createServer((req, res) => {
    if (req.url === '/health') return healthHandler(req, res);
    proxyHandler(req, res);
  });
}

// ── Start ──────────────────────────────────────────────────────────────
function start(callback) {
  if (!CONFIG.enabled) {
    log('info', 'proxy disabled by config');
    if (callback) callback(null, null);
    return null;
  }
  const server = createServer();
  server.listen(CONFIG.port, () => {
    log('info', 'proxy listening', { port: CONFIG.port });
    if (callback) callback(null, server);
  });
  return server;
}

function stop(server, callback) {
  if (!server) return callback && callback();
  server.close(callback);
}

// ── Exports ──────────────────────────────────────────────────────────
module.exports = {
  start,
  stop,
  createServer,
  CONFIG,
  routeCache,
  computeRoutingKey,
  pickBackend,
  extractPromptText,
  log
};

// CLI direct run
if (require.main === module) {
  start();
}
