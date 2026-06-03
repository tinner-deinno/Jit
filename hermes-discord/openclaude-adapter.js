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
const url   = require('url');

// ── Configuration ─────────────────────────────────────────────────────
const OPENCLAUDE_HOST     = process.env.OPENCLAUDE_HOST     || 'localhost';
const OPENCLAUDE_PORT     = process.env.OPENCLAUDE_PORT     || 8000;
const OPENCLAUDE_API_KEY  = process.env.OPENCLAUDE_API_KEY  || '';
const OPENCLAUDE_MODEL    = process.env.OPENCLAUDE_MODEL    || 'claude-3.5-sonnet';
const OPENCLAUDE_BASE_URL = process.env.OPENCLAUDE_BASE_URL || 'http://localhost:8000';

const DEBUG = process.env.DEBUG_OPENCLAUDE === 'true';

// ── Status Check ──────────────────────────────────────────────────────
function isAvailable() {
  // OpenClaude is available if:
  // 1. Server is reachable at OPENCLAUDE_HOST:PORT
  // 2. API key is set (if required)
  return !!(OPENCLAUDE_HOST && OPENCLAUDE_PORT);
}

async function checkHealth() {
  return new Promise((resolve) => {
    const options = {
      hostname: OPENCLAUDE_HOST,
      port: OPENCLAUDE_PORT,
      path: '/health',
      method: 'GET',
      timeout: 5000,
    };

    const req = (http).request(options, (res) => {
      let data = '';
      res.on('data', (d) => { data += d; });
      res.on('end', () => {
        resolve({
          ok: res.statusCode === 200,
          status: res.statusCode,
          message: res.statusCode === 200 ? 'OpenClaude online' : 'OpenClaude error',
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

  if (DEBUG) {
    console.log('[openclaude-adapter] Calling:', {
      url: OPENCLAUDE_BASE_URL + '/v1/messages',
      model: model,
      messages: messages.length,
    });
  }

  const postOptions = {
    hostname: OPENCLAUDE_HOST,
    port: OPENCLAUDE_PORT,
    path: '/v1/messages',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(JSON.stringify(payload)),
    },
    timeout: 30000,
  };

  // Add API key if set
  if (OPENCLAUDE_API_KEY) {
    postOptions.headers['Authorization'] = 'Bearer ' + OPENCLAUDE_API_KEY;
  }

  const promiseHandler = new Promise((resolve, reject) => {
    let responseData = '';

    const req = http.request(postOptions, (res) => {
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

    req.write(JSON.stringify(payload));
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
