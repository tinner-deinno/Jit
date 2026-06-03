#!/usr/bin/env node
'use strict';
/**
 * hermes-discord/openclaude-adapter.js
 * ═══════════════════════════════════════════════════════════════════════
 *
 * OpenClaude Backend Adapter for Jit Multi-Backend Router
 * 
 * OpenClaude = open-source Claude API wrapper (github.com/Gitlawb/openclaude)
 * Provides local/self-hosted Claude API compatibility
 *
 * Usage:
 *   const oca = require('./openclaude-adapter');
 *   const available = oca.isAvailable();
 *   const reply = await oca.callOpenClaude(messages, opts, callback);
 *   const status = oca.status();
 */

const https = require('https');
const http  = require('http');

// ── Configuration ─────────────────────────────────────────────────────
const OPENCLAUDE_HOST     = process.env.OPENCLAUDE_HOST     || 'localhost';
const OPENCLAUDE_PORT     = process.env.OPENCLAUDE_PORT     || 8000;
const OPENCLAUDE_API_KEY  = process.env.OPENCLAUDE_API_KEY  || '';
const OPENCLAUDE_MODEL    = process.env.OPENCLAUDE_MODEL    || 'claude-3.5-sonnet';
const OPENCLAUDE_BASE_URL = process.env.OPENCLAUDE_BASE_URL || `http://${OPENCLAUDE_HOST}:${OPENCLAUDE_PORT}`;

const DEBUG = process.env.DEBUG_OPENCLAUDE === 'true';

// ── Status Check ──────────────────────────────────────────────────────
function isAvailable() {
  // OpenClaude is available if:
  // 1. A base URL can be resolved
  // 2. API key is set (if required)
  return !!_buildOpenClaudeUrl('/health');
}

function _buildOpenClaudeUrl(endpointPath) {
  try {
    const target = new URL(OPENCLAUDE_BASE_URL);
    const basePath = target.pathname.replace(/\/$/, '');
    const requestPath = String(endpointPath || '').startsWith('/') ? endpointPath : '/' + endpointPath;
    target.pathname = basePath + requestPath;
    return target;
  } catch (_) {
    return null;
  }
}

function _requestOptions(target, method, headers, timeout) {
  return {
    hostname: target.hostname,
    port: target.port || (target.protocol === 'https:' ? 443 : 80),
    path: target.pathname + target.search,
    method: method,
    headers: headers || {},
    timeout: timeout,
  };
}

function _transport(target) {
  return target.protocol === 'https:' ? https : http;
}

async function checkHealth() {
  return new Promise((resolve) => {
    const target = _buildOpenClaudeUrl('/health');
    if (!target) return resolve({ ok: false, message: 'OpenClaude invalid base URL' });

    const req = _transport(target).request(_requestOptions(target, 'GET', {}, 5000), (res) => {
      let data = '';
      res.on('data', (d) => { data += d; });
      res.on('end', () => {
        resolve({
          ok: res.statusCode === 200,
          status: res.statusCode,
          message: res.statusCode === 200 ? 'OpenClaude online' : 'OpenClaude error',
          url: target.href,
        });
      });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({ ok: false, message: 'OpenClaude timeout' });
    });

    req.on('error', (e) => {
      resolve({ ok: false, message: 'OpenClaude unreachable: ' + e.message });
    });

    req.end();
  });
}

// ── Main Call Function ────────────────────────────────────────────────
function callOpenClaude(messages, opts, callback) {
  if (!isAvailable()) {
    const err = new Error('OpenClaude not available');
    if (callback) return callback(err, null);
    return Promise.reject(err);
  }

  opts = opts || {};
  const model = opts.model || OPENCLAUDE_MODEL;
  const temperature = opts.temperature !== undefined ? opts.temperature : 0.7;
  const maxTokens = opts.maxTokens || 2000;

  const payload = {
    model: model,
    messages: messages,
    temperature: temperature,
    max_tokens: maxTokens,
    stream: false,
  };
  const body = JSON.stringify(payload);
  const target = _buildOpenClaudeUrl('/v1/messages');
  if (!target) {
    const err = new Error('OpenClaude invalid base URL');
    if (callback) return callback(err, null);
    return Promise.reject(err);
  }

  if (DEBUG) {
    console.log('[openclaude-adapter] Calling:', {
      url: target.href,
      model: model,
      messages: messages.length,
    });
  }

  const postOptions = _requestOptions(target, 'POST', {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    }, 30000);

  // Add API key if set
  if (OPENCLAUDE_API_KEY) {
    postOptions.headers['Authorization'] = 'Bearer ' + OPENCLAUDE_API_KEY;
  }

  const promiseHandler = new Promise((resolve, reject) => {
    let responseData = '';

    const req = _transport(target).request(postOptions, (res) => {
      res.on('data', (chunk) => { responseData += chunk; });

      res.on('end', () => {
        if (res.statusCode !== 200) {
          const err = new Error('OpenClaude HTTP ' + res.statusCode);
          err.statusCode = res.statusCode;
          err.response = responseData;
          return reject(err);
        }

        try {
          const data = JSON.parse(responseData);
          if (data.error) {
            return reject(new Error('OpenClaude API: ' + data.error.message));
          }

          // Extract text from response
          let text = '';
          if (data.content && Array.isArray(data.content)) {
            text = data.content
              .filter((c) => c.type === 'text')
              .map((c) => c.text)
              .join('\n');
          } else if (data.message) {
            text = data.message;
          }

          if (DEBUG) {
            console.log('[openclaude-adapter] Response:', { tokens: data.usage });
          }

          const result = {
            text: text,
            model: model,
            backend: 'openclaude',
            usage: data.usage || {},
            rawResponse: data,
          };

          resolve(result);
        } catch (e) {
          reject(new Error('OpenClaude parse error: ' + e.message));
        }
      });
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('OpenClaude request timeout'));
    });

    req.on('error', (e) => {
      reject(new Error('OpenClaude request error: ' + e.message));
    });

    req.write(body);
    req.end();
  });

  // Handle callback-style (for compatibility with model-router)
  if (callback) {
    promiseHandler
      .then((result) => callback(null, result))
      .catch((err) => callback(err, null));
  } else {
    return promiseHandler;
  }
}

// ── Promise-based wrapper ─────────────────────────────────────────────
function callOpenClaudePromise(messages, opts) {
  return new Promise((resolve, reject) => {
    callOpenClaude(messages, opts, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

// ── Status function ──────────────────────────────────────────────────
function status() {
  const configured = isAvailable();
  return {
    // Legacy callers use `available` to mean "configured". Live readiness is
    // proven by /health or a real model call.
    available: configured,
    configured: configured,
    readiness: 'configured_unverified',
    host: OPENCLAUDE_HOST,
    port: OPENCLAUDE_PORT,
    baseUrl: OPENCLAUDE_BASE_URL,
    healthEndpoint: OPENCLAUDE_BASE_URL.replace(/\/$/, '') + '/health',
    model: OPENCLAUDE_MODEL,
    hasApiKey: !!OPENCLAUDE_API_KEY,
    environment: {
      OPENCLAUDE_HOST: process.env.OPENCLAUDE_HOST || '(default: localhost)',
      OPENCLAUDE_PORT: process.env.OPENCLAUDE_PORT || '(default: 8000)',
      OPENCLAUDE_MODEL: process.env.OPENCLAUDE_MODEL || '(default: claude-3.5-sonnet)',
      OPENCLAUDE_API_KEY: process.env.OPENCLAUDE_API_KEY ? '(set)' : '(not set)',
    },
  };
}

// ── Exports ───────────────────────────────────────────────────────────
module.exports = {
  isAvailable,
  checkHealth,
  callOpenClaude,
  callOpenClaudePromise,
  status,
  OPENCLAUDE_HOST,
  OPENCLAUDE_PORT,
  OPENCLAUDE_BASE_URL,
  OPENCLAUDE_MODEL,
};
