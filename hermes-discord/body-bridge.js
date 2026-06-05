'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const jitControl = require('./jit-control');

const JIT_ROOT = process.env.JIT_ROOT || path.resolve(__dirname, '..');
const BUS_ROOT = process.env.JIT_BUS_DIR || require('path').join(require('os').tmpdir(), 'manusat-bus');
const BRIDGE_POLL_MS = parsePositiveInt(process.env.JIT_BODY_BRIDGE_POLL_MS, 5000);
const BRIDGE_PORT = parsePositiveInt(process.env.JIT_BODY_BRIDGE_PORT, 7011);
const BRIDGE_BIND_HOST = process.env.JIT_BODY_BRIDGE_HOST || '127.0.0.1';
const EXECUTOR_COMMAND = process.env.JIT_BODY_EXECUTOR_COMMAND || ('bash ' + path.join(JIT_ROOT, 'scripts', 'discord-dev-executor.sh'));
const ROUTE_RECIPIENTS = dedupe(splitCsv(process.env.JIT_BODY_ROUTE_RECIPIENTS || 'mue,innova,jit'));

function parsePositiveInt(value, fallback) {
  const parsed = parseInt(value || '', 10);
  if (Number.isFinite(parsed) && parsed > 0) return parsed;
  return fallback;
}

function splitCsv(value) {
  return String(value || '')
    .split(',')
    .map(function(item) { return item.trim(); })
    .filter(Boolean);
}

function dedupe(items) {
  const seen = new Set();
  return items.filter(function(item) {
    if (!item || seen.has(item)) return false;
    seen.add(item);
    return true;
  });
}

function nowIso() {
  return new Date().toISOString();
}

function ensureDirectory(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function createCorrelationId() {
  if (typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID().split('-')[0];
  }
  return Date.now().toString(36) + crypto.randomBytes(2).toString('hex');
}

function writeBusMessage(options) {
  const correlationId = options.correlationId || createCorrelationId();
  const messageDir = path.join(BUS_ROOT, options.to);
  ensureDirectory(messageDir);

  const fileName = Date.now().toString() + '_' + correlationId + '_from-' + (options.from || 'innova-body-bridge') + '.msg';
  const filePath = path.join(messageDir, fileName);
  const content = [
    'from:' + (options.from || 'innova-body-bridge'),
    'to:' + options.to,
    'subject:' + options.subject,
    'timestamp:' + nowIso().replace(/\.\d{3}Z$/, ''),
    'correlation-id:' + correlationId,
    '---',
    String(options.body || '').trim(),
    '',
  ].join('\n');

  fs.writeFileSync(filePath, content, 'utf8');
  return { correlationId: correlationId, filePath: filePath, agent: options.to };
}

function buildBridgeState() {
  const topology = jitControl.loadTopology();
  const bodyInfo = jitControl.resolveBodyPath(topology);
  const bridgeDir = process.env.INNOVA_BOT_BRIDGE_DIR || bodyInfo.bridgeDir || path.join(JIT_ROOT, '.jit-bridge', 'inbox');
  const bridgeRoot = path.dirname(bridgeDir);
  return {
    topology: topology,
    bodyInfo: bodyInfo,
    bridgeDir: bridgeDir,
    processedDir: process.env.JIT_BODY_BRIDGE_PROCESSED_DIR || path.join(bridgeRoot, 'processed'),
    failedDir: process.env.JIT_BODY_BRIDGE_FAILED_DIR || path.join(bridgeRoot, 'failed'),
    ackDir: process.env.JIT_BODY_BRIDGE_ACK_DIR || path.join(bridgeRoot, 'acks'),
    tempDir: process.env.JIT_BODY_BRIDGE_TMP_DIR || path.join(bridgeRoot, 'tmp'),
    logFile: process.env.JIT_BODY_BRIDGE_LOG || path.join(require('os').tmpdir(), 'innova-body-bridge.log'),
    pidFile: process.env.JIT_BODY_BRIDGE_PID || path.join(require('os').tmpdir(), 'innova-body-bridge.pid'),
    healthPath: process.env.JIT_BODY_BRIDGE_HEALTH_PATH || '/health',
    webhookPath: process.env.JIT_BODY_BRIDGE_WEBHOOK_PATH || '/api/jit/discord',
  };
}

const bridgeState = buildBridgeState();
ensureDirectory(bridgeState.bridgeDir);
ensureDirectory(bridgeState.processedDir);
ensureDirectory(bridgeState.failedDir);
ensureDirectory(bridgeState.ackDir);
ensureDirectory(bridgeState.tempDir);

function logLine(message) {
  fs.appendFileSync(bridgeState.logFile, '[' + nowIso() + '] ' + message + '\n', 'utf8');
}

function bridgeSubjectFor(agent) {
  if (agent === 'mue') return 'task:execute-discord-dev';
  if (agent === 'innova') return 'task:body-bridge-sync';
  if (agent === 'jit') return 'report:body-bridge-received';
  return 'task:body-bridge-dispatch';
}

function buildBridgeBody(payload, sourceTag, agent) {
  const discord = payload.discord || {};
  return [
    'origin: body-bridge',
    'source: ' + sourceTag,
    'payload_type: ' + (payload.type || 'unknown'),
    'discord_user: ' + (discord.user_tag || ''),
    'discord_channel: ' + (discord.channel_name || discord.channel_id || ''),
    'discord_guild: ' + (discord.guild_id || ''),
    'body_path: ' + (payload.body_path || bridgeState.bodyInfo.selectedPath || '-'),
    'target_agent: ' + agent,
    '',
    'task:',
    String(payload.task || '').trim(),
  ].join('\n').trim();
}

function writeAck(correlationId, ack) {
  const filePath = path.join(bridgeState.ackDir, correlationId + '.json');
  fs.writeFileSync(filePath, JSON.stringify(ack, null, 2), 'utf8');
  return filePath;
}

function writeTempPayload(payload, correlationId) {
  const filePath = path.join(bridgeState.tempDir, correlationId + '.json');
  fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf8');
  return filePath;
}

function shellQuote(value) {
  const text = String(value || '');
  if (!text) return '""';
  if (process.platform === 'win32') {
    return /[\s"&|<>^()]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
  }
  return /[\s"'\\$`]/.test(text) ? `'${text.replace(/'/g, `'\\''`)}'` : text;
}

function runExecutor(payload, correlationId) {
  if (!EXECUTOR_COMMAND) {
    return { skipped: true, reason: 'executor command not configured' };
  }

  const payloadFile = writeTempPayload(payload, correlationId);
  try {
    const commandLine = EXECUTOR_COMMAND + ' ' + shellQuote(payloadFile);
    const child = spawn(commandLine, [], {
      cwd: JIT_ROOT,
      detached: true,
      shell: true,
      stdio: 'ignore',
      env: Object.assign({}, process.env, {
        JIT_ROOT: JIT_ROOT,
        JIT_BRIDGE_PAYLOAD_FILE: payloadFile,
        JIT_BRIDGE_CORRELATION_ID: correlationId,
      }),
    });
    child.unref();
    return { skipped: false, pid: child.pid || 0, command: commandLine, payloadFile: payloadFile };
  } catch (error) {
    return { skipped: false, error: error.message, command: EXECUTOR_COMMAND, payloadFile: payloadFile };
  }
}

function normalizePayload(payload) {
  return Object.assign({}, payload, {
    type: payload.type || 'jit-discord-dev-task',
    correlation_id: payload.correlation_id || createCorrelationId(),
    created_at: payload.created_at || nowIso(),
    task: String(payload.task || '').trim(),
    recipients: Array.isArray(payload.recipients) ? payload.recipients : [],
    discord: payload.discord || {},
  });
}

function routeRecipients(payload) {
  return dedupe(ROUTE_RECIPIENTS.concat(payload.recipients || []));
}

function processPayload(payload, sourceTag) {
  const normalized = normalizePayload(payload);
  const recipients = routeRecipients(normalized);
  const writes = recipients.map(function(agent) {
    return writeBusMessage({
      to: agent,
      from: 'innova-body-bridge',
      subject: bridgeSubjectFor(agent),
      correlationId: normalized.correlation_id,
      body: buildBridgeBody(normalized, sourceTag, agent),
    });
  });

  const executor = runExecutor(normalized, normalized.correlation_id);
  const ack = {
    ok: true,
    correlation_id: normalized.correlation_id,
    source: sourceTag,
    received_at: nowIso(),
    recipients: recipients,
    bus_writes: writes,
    executor: executor,
    host: os.hostname(),
  };
  ack.ack_path = writeAck(normalized.correlation_id, ack);
  logLine('processed ' + normalized.correlation_id + ' via ' + sourceTag + ' -> ' + recipients.join(', '));
  return ack;
}

function moveProcessed(filePath, targetDir) {
  const targetPath = path.join(targetDir, path.basename(filePath));
  fs.renameSync(filePath, targetPath);
  return targetPath;
}

function processInboxFile(filePath) {
  try {
    const payload = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    const ack = processPayload(payload, 'inbox:' + path.basename(filePath));
    ack.processed_path = moveProcessed(filePath, bridgeState.processedDir);
    return ack;
  } catch (error) {
    const failedPath = moveProcessed(filePath, bridgeState.failedDir);
    logLine('failed ' + path.basename(filePath) + ' error=' + error.message);
    return { ok: false, error: error.message, failed_path: failedPath, received_at: nowIso() };
  }
}

function processInboxOnce() {
  const files = fs.readdirSync(bridgeState.bridgeDir)
    .filter(function(name) { return name.endsWith('.json'); })
    .sort();

  const results = files.map(function(name) {
    return processInboxFile(path.join(bridgeState.bridgeDir, name));
  });

  return { ok: true, bridge_dir: bridgeState.bridgeDir, processed: results.length, results: results };
}

function buildHealthPayload() {
  const bus = jitControl.collectBusStats(BUS_ROOT);
  return {
    ok: true,
    host: os.hostname(),
    now: nowIso(),
    bridge_dir: bridgeState.bridgeDir,
    processed_dir: bridgeState.processedDir,
    failed_dir: bridgeState.failedDir,
    ack_dir: bridgeState.ackDir,
    executor_command: EXECUTOR_COMMAND,
    route_recipients: ROUTE_RECIPIENTS,
    body_path: bridgeState.bodyInfo.selectedPath || '',
    body_repo_present: bridgeState.bodyInfo.repoPresent,
    bus_pending: bus.totalPending,
  };
}

function jsonResponse(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  response.end(JSON.stringify(body, null, 2));
}

function startServer() {
  const server = http.createServer(function(request, response) {
    if (request.method === 'OPTIONS') {
      response.writeHead(204, {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      });
      response.end();
      return;
    }

    if (request.method === 'GET' && request.url === bridgeState.healthPath) {
      jsonResponse(response, 200, buildHealthPayload());
      return;
    }

    if (request.method === 'POST' && (request.url === bridgeState.webhookPath || request.url === '/jit/discord')) {
      let raw = '';
      request.on('data', function(chunk) { raw += chunk; });
      request.on('end', function() {
        try {
          jsonResponse(response, 200, processPayload(JSON.parse(raw || '{}'), 'webhook'));
        } catch (error) {
          jsonResponse(response, 400, { ok: false, error: error.message });
        }
      });
      return;
    }

    jsonResponse(response, 404, { ok: false, error: 'not found' });
  });

  server.listen(BRIDGE_PORT, BRIDGE_BIND_HOST, function() {
    logLine('webhook listening on http://' + BRIDGE_BIND_HOST + ':' + BRIDGE_PORT + bridgeState.webhookPath);
    console.log('✅ innova body bridge webhook listening on http://' + BRIDGE_BIND_HOST + ':' + BRIDGE_PORT + bridgeState.webhookPath);
  });

  return server;
}

function runDaemon() {
  fs.writeFileSync(bridgeState.pidFile, String(process.pid), 'utf8');
  logLine('daemon started pid=' + process.pid + ' bridge_dir=' + bridgeState.bridgeDir);
  const server = startServer();
  processInboxOnce();
  const timer = setInterval(function() {
    try {
      processInboxOnce();
    } catch (error) {
      logLine('poll error ' + error.message);
    }
  }, BRIDGE_POLL_MS);

  function cleanup() {
    clearInterval(timer);
    if (server) server.close();
    try { fs.unlinkSync(bridgeState.pidFile); } catch (_) {}
  }

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);
}

function runTestPayload() {
  console.log(JSON.stringify(processPayload({
    type: 'jit-discord-dev-task',
    task: 'test bridge dispatch from CLI',
    recipients: ['jit', 'innova', 'mue'],
    discord: { user_tag: 'tester#0000', channel_name: 'cli-test', channel_id: 'local' },
    body_path: bridgeState.bodyInfo.selectedPath || '',
  }, 'test'), null, 2));
}

switch (process.argv[2] || '--status') {
  case '--once':
    console.log(JSON.stringify(processInboxOnce(), null, 2));
    break;
  case '--daemon':
    runDaemon();
    break;
  case '--test-payload':
    runTestPayload();
    break;
  case '--status':
  default:
    console.log(JSON.stringify(buildHealthPayload(), null, 2));
    break;
}
