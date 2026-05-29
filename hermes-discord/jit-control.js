'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const https = require('https');
const os = require('os');
const path = require('path');

const JIT_ROOT = process.env.JIT_ROOT || path.resolve(__dirname, '..');
const BUS_ROOT = process.env.JIT_BUS_DIR || require('path').join(require('os').tmpdir(), 'manusat-bus');
const TOPOLOGY_FILE = process.env.JIT_TOPOLOGY_FILE || path.join(JIT_ROOT, 'config', 'jit-topology.json');
const ORACLE_URL = process.env.ORACLE_URL || ('http://127.0.0.1:' + (process.env.ORACLE_PORT || '47778'));
const OLLAMA_URL = process.env.OLLAMA_BASE_URL || 'https://ollama.mdes-innova.online';
const OLLAMA_TOKEN = process.env.OLLAMA_TOKEN || '';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'gemma4:e4b';
const CHAT_PREFIX = process.env.BOT_PREFIX || '!อนุ';
const COMMAND_PREFIX = process.env.JIT_COMMAND_PREFIX || '!jit';
const REPORT_CHANNEL_ID = process.env.JIT_REPORT_CHANNEL_ID || '';
const MAX_QUEUE_ITEMS = parsePositiveInt(process.env.JIT_STATUS_MAX_MESSAGES, 5);
const DEV_RECIPIENTS = splitCsv(process.env.JIT_DISCORD_DEV_RECIPIENTS || 'jit,soma,innova');

function deriveHealthUrl(targetUrl) {
  if (!targetUrl) return '';
  try {
    const parsed = new URL(targetUrl);
    parsed.pathname = '/health';
    parsed.search = '';
    return parsed.toString();
  } catch (_) {
    return '';
  }
}

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

function normalizeHostPath(rawValue) {
  let value = String(rawValue || '').trim();
  if (!value) return '';

  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    value = value.slice(1, -1);
  }

  if (value.startsWith('~/')) {
    return path.join(os.homedir(), value.slice(2));
  }

  if (/^[A-Za-z]:\\/.test(value)) {
    return '/mnt/' + value[0].toLowerCase() + '/' + value.slice(3).replace(/\\+/g, '/');
  }

  return value;
}

function joinUrl(baseUrl, suffix) {
  if (!baseUrl) return '';
  return String(baseUrl).replace(/\/+$/, '') + suffix;
}

function safeReadJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (_) {
    return null;
  }
}

function loadTopology() {
  return safeReadJson(TOPOLOGY_FILE) || {};
}

function resolveBodyCandidates(topology) {
  const candidates = [];
  const envPath = normalizeHostPath(process.env.INNOVA_BOT_PATH || '');
  if (envPath) candidates.push(envPath);

  if (Array.isArray(topology.body_repo_candidates)) {
    topology.body_repo_candidates.forEach(function(candidate) {
      const normalized = normalizeHostPath(candidate);
      if (normalized) candidates.push(normalized);
    });
  }

  if (topology.body_repo_path) {
    candidates.push(normalizeHostPath(topology.body_repo_path));
  }

  candidates.push(path.join(JIT_ROOT, 'innova-bot'));
  return dedupe(candidates);
}

function resolveBodyBridge(topology, selectedPath) {
  const explicitDir = normalizeHostPath(process.env.INNOVA_BOT_BRIDGE_DIR || '');
  const explicitFile = normalizeHostPath(process.env.INNOVA_BOT_BRIDGE_FILE || '');
  const bridgeUrl = process.env.INNOVA_BOT_BRIDGE_URL || topology.body_bridge_url || '';
  const topologyBridgeDir = topology.body_bridge_dir || '';

  let bridgeDir = explicitDir;
  if (!bridgeDir && topologyBridgeDir) {
    if (path.isAbsolute(topologyBridgeDir)) {
      bridgeDir = normalizeHostPath(topologyBridgeDir);
    } else if (selectedPath) {
      bridgeDir = path.join(selectedPath, topologyBridgeDir);
    }
  }
  if (!bridgeDir && selectedPath) {
    bridgeDir = path.join(selectedPath, '.jit-bridge', 'inbox');
  }

  return {
    bridgeDir: normalizeHostPath(bridgeDir),
    bridgeFile: explicitFile,
    bridgeUrl: bridgeUrl,
    bridgeExplicit: Boolean(explicitDir || explicitFile),
  };
}

function resolveBodyPath(topology) {
  const candidates = resolveBodyCandidates(topology);
  const selectedPath = candidates.find(function(candidate) {
    return candidate && fs.existsSync(candidate);
  }) || candidates[0] || '';
  const repoPresent = Boolean(selectedPath) && fs.existsSync(selectedPath);
  const gitPresent = repoPresent && fs.existsSync(path.join(selectedPath, '.git'));
  const bridge = resolveBodyBridge(topology, selectedPath);

  return {
    rawEnvPath: process.env.INNOVA_BOT_PATH || '',
    candidates: candidates,
    selectedPath: selectedPath,
    repoPresent: repoPresent,
    gitPresent: gitPresent,
    bridgeDir: bridge.bridgeDir,
    bridgeFile: bridge.bridgeFile,
    bridgeUrl: bridge.bridgeUrl,
    bridgeExplicit: bridge.bridgeExplicit,
  };
}

function requestUrl(targetUrl, options) {
  return new Promise(function(resolve) {
    if (!targetUrl) {
      resolve({ ok: false, skipped: true, error: 'not configured' });
      return;
    }

    let parsed;
    try {
      parsed = new URL(targetUrl);
    } catch (error) {
      resolve({ ok: false, error: 'invalid URL: ' + error.message });
      return;
    }

    const transport = parsed.protocol === 'https:' ? https : http;
    const requestOptions = {
      method: (options && options.method) || 'GET',
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      headers: Object.assign({ Accept: 'application/json' }, (options && options.headers) || {}),
    };

    const request = transport.request(requestOptions, function(response) {
      let payload = '';
      response.on('data', function(chunk) { payload += chunk; });
      response.on('end', function() {
        let json = null;
        try { json = payload ? JSON.parse(payload) : null; } catch (_) {}
        resolve({
          ok: Boolean(response.statusCode && response.statusCode >= 200 && response.statusCode < 300),
          statusCode: response.statusCode || 0,
          data: payload,
          json: json,
        });
      });
    });

    request.on('error', function(error) {
      resolve({ ok: false, error: error.message });
    });

    request.setTimeout((options && options.timeoutMs) || 3500, function() {
      request.destroy(new Error('timeout'));
    });

    if (options && options.body) request.write(options.body);
    request.end();
  });
}

function collectBusStats(busRoot) {
  if (!fs.existsSync(busRoot)) {
    return { exists: false, agentCount: 0, totalPending: 0, agents: [] };
  }

  const agents = fs.readdirSync(busRoot, { withFileTypes: true })
    .filter(function(entry) { return entry.isDirectory(); })
    .map(function(entry) {
      const inboxPath = path.join(busRoot, entry.name);
      const names = fs.readdirSync(inboxPath).filter(function(name) { return !name.startsWith('.'); });
      const pending = names.filter(function(name) {
        return name.endsWith('.msg') && !name.startsWith('read_');
      }).length;
      const read = names.filter(function(name) {
        return name.startsWith('read_') || name.endsWith('.read');
      }).length;
      return { agent: entry.name, pending: pending, read: read };
    })
    .sort(function(left, right) { return left.agent.localeCompare(right.agent); });

  return {
    exists: true,
    agentCount: agents.length,
    totalPending: agents.reduce(function(sum, item) { return sum + item.pending; }, 0),
    agents: agents,
  };
}

function parseMessageFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const parts = content.split('\n---\n');
  const headers = {};
  parts[0].split('\n').forEach(function(line) {
    const index = line.indexOf(':');
    if (index === -1) return;
    headers[line.slice(0, index)] = line.slice(index + 1).trim();
  });

  return {
    fileName: path.basename(filePath),
    from: headers.from || '?',
    to: headers.to || '?',
    subject: headers.subject || '(no subject)',
    timestamp: headers.timestamp || '',
    correlationId: headers['correlation-id'] || '',
    body: parts.slice(1).join('\n---\n').trim(),
  };
}

function listPendingMessages(busRoot, agent, limit) {
  const maxItems = parsePositiveInt(limit, MAX_QUEUE_ITEMS);
  const inboxPath = path.join(busRoot, agent);
  if (!fs.existsSync(inboxPath)) return [];

  return fs.readdirSync(inboxPath)
    .filter(function(name) {
      return name.endsWith('.msg') && !name.startsWith('read_');
    })
    .sort()
    .reverse()
    .slice(0, maxItems)
    .map(function(name) {
      return parseMessageFile(path.join(inboxPath, name));
    });
}

function createCorrelationId() {
  if (typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID().split('-')[0];
  }
  return Date.now().toString(36) + crypto.randomBytes(2).toString('hex');
}

function ensureDirectory(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function writeBusMessage(options) {
  const correlationId = options.correlationId || createCorrelationId();
  const toAgent = options.to;
  const messageDir = path.join(BUS_ROOT, toAgent);
  ensureDirectory(messageDir);

  const fileName = Date.now().toString() + '_' + correlationId + '_from-' + (options.from || 'hermes-discord') + '.msg';
  const filePath = path.join(messageDir, fileName);
  const body = String(options.body || '').trim();
  const timestamp = new Date().toISOString().replace(/\.\d{3}Z$/, '');

  const content = [
    'from:' + (options.from || 'hermes-discord'),
    'to:' + toAgent,
    'subject:' + options.subject,
    'timestamp:' + timestamp,
    'correlation-id:' + correlationId,
    '---',
    body,
    '',
  ].join('\n');

  fs.writeFileSync(filePath, content, 'utf8');
  return { correlationId: correlationId, filePath: filePath };
}

function devSubjectForAgent(agent) {
  switch (agent) {
    case 'soma':
      return 'think:discord-dev-plan';
    case 'innova':
      return 'task:discord-dev-execute';
    case 'neta':
      return 'request:discord-dev-review';
    case 'chamu':
      return 'request:discord-dev-test';
    case 'pada':
      return 'request:discord-dev-deploy-check';
    default:
      return 'task:discord-dev-request';
  }
}

function buildCommandBody(commandName, payload, meta, bodyInfo) {
  const lines = [
    'origin: discord',
    'command: ' + commandName,
    'discord_user: ' + (meta.userTag || meta.username || 'unknown'),
    'discord_channel: ' + (meta.channelName || meta.channelId || 'unknown'),
    'discord_guild: ' + (meta.guildId || 'dm'),
    'body_path: ' + (bodyInfo.selectedPath || '-'),
    '',
    payload,
  ];
  return lines.join('\n').trim();
}

async function mirrorToBody(payload, bodyInfo) {
  const result = {
    file: null,
    webhook: null,
    skipped: [],
  };

  const explicitTarget = bodyInfo.bridgeExplicit;
  if (bodyInfo.bridgeFile) {
    try {
      ensureDirectory(path.dirname(bodyInfo.bridgeFile));
      fs.writeFileSync(bodyInfo.bridgeFile, JSON.stringify(payload, null, 2), 'utf8');
      result.file = { ok: true, path: bodyInfo.bridgeFile };
    } catch (error) {
      result.file = { ok: false, path: bodyInfo.bridgeFile, error: error.message };
    }
  } else if (bodyInfo.bridgeDir && (bodyInfo.repoPresent || explicitTarget)) {
    const filePath = path.join(bodyInfo.bridgeDir, Date.now().toString() + '-' + payload.correlation_id + '.json');
    try {
      ensureDirectory(bodyInfo.bridgeDir);
      fs.writeFileSync(filePath, JSON.stringify(payload, null, 2), 'utf8');
      result.file = { ok: true, path: filePath };
    } catch (error) {
      result.file = { ok: false, path: filePath, error: error.message };
    }
  } else {
    result.skipped.push('file-bridge not configured');
  }

  if (bodyInfo.bridgeUrl) {
    const response = await requestUrl(bodyInfo.bridgeUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      timeoutMs: 5000,
    });
    result.webhook = {
      ok: response.ok,
      url: bodyInfo.bridgeUrl,
      statusCode: response.statusCode || 0,
      error: response.error || '',
    };
  } else {
    result.skipped.push('webhook bridge not configured');
  }

  return result;
}

async function dispatchDevTask(task, meta) {
  const topology = loadTopology();
  const bodyInfo = resolveBodyPath(topology);
  const correlationId = createCorrelationId();
  const recipients = DEV_RECIPIENTS.length ? DEV_RECIPIENTS : ['jit', 'soma', 'innova'];
  const busWrites = [];
  const errors = [];

  recipients.forEach(function(recipient) {
    try {
      busWrites.push(writeBusMessage({
        to: recipient,
        from: meta.from || 'hermes-discord',
        subject: devSubjectForAgent(recipient),
        correlationId: correlationId,
        body: buildCommandBody('dev', 'task:\n' + task.trim(), meta, bodyInfo),
      }));
    } catch (error) {
      errors.push(recipient + ': ' + error.message);
    }
  });

  const payload = {
    type: 'jit-discord-dev-task',
    correlation_id: correlationId,
    created_at: new Date().toISOString(),
    source: 'hermes-discord',
    task: task.trim(),
    recipients: recipients,
    discord: {
      user_id: meta.userId || '',
      user_tag: meta.userTag || meta.username || '',
      channel_id: meta.channelId || '',
      channel_name: meta.channelName || '',
      guild_id: meta.guildId || '',
    },
    body_path: bodyInfo.selectedPath || '',
  };

  const bridge = await mirrorToBody(payload, bodyInfo);
  return {
    correlationId: correlationId,
    recipients: recipients,
    busWrites: busWrites,
    bridge: bridge,
    body: bodyInfo,
    errors: errors,
    task: task.trim(),
  };
}

function sendDirectBusMessage(agent, subject, messageBody, meta) {
  const topology = loadTopology();
  const bodyInfo = resolveBodyPath(topology);
  const correlationId = createCorrelationId();
  const busWrite = writeBusMessage({
    to: agent,
    from: meta.from || 'hermes-discord',
    subject: subject,
    correlationId: correlationId,
    body: buildCommandBody('tell', 'body:\n' + messageBody.trim(), meta, bodyInfo),
  });

  return {
    correlationId: correlationId,
    agent: agent,
    subject: subject,
    busWrite: busWrite,
  };
}

async function collectStatus(options) {
  const topology = loadTopology();
  const bodyInfo = resolveBodyPath(topology);
  const bus = collectBusStats(BUS_ROOT);

  const bodyGuiUrl = process.env.INNOVA_BOT_GUI_URL || topology.body_gui_url || '';
  const bodyMcpHealthUrl = process.env.INNOVA_BOT_HEALTH_URL || (topology.body_mcp_port ? ('http://127.0.0.1:' + topology.body_mcp_port + '/mcp/health') : '');
  const bodyBridgeHealthUrl = process.env.JIT_BODY_BRIDGE_HEALTH_URL || deriveHealthUrl(bodyInfo.bridgeUrl);
  const thoughtLoopChannels = dedupe(splitCsv(process.env.JIT_THOUGHT_LOOP_CHANNELS || ''));
  const thoughtLoopEnabled = process.env.JIT_THOUGHT_LOOP_ENABLED !== 'false';
  const thoughtLoopIntervalMs = parsePositiveInt(process.env.JIT_THOUGHT_LOOP_INTERVAL_MS, 300000);

  const requests = await Promise.all([
    requestUrl(joinUrl(ORACLE_URL, '/api/health'), { timeoutMs: 3500 }),
    requestUrl(joinUrl(OLLAMA_URL, '/api/tags'), {
      headers: OLLAMA_TOKEN ? { Authorization: 'Bearer ' + OLLAMA_TOKEN } : {},
      timeoutMs: 5000,
    }),
    requestUrl(bodyGuiUrl, { timeoutMs: 3000 }),
    requestUrl(bodyMcpHealthUrl, { timeoutMs: 3000 }),
    requestUrl(bodyBridgeHealthUrl, { timeoutMs: 3000 }),
  ]);

  const oracleResponse = requests[0];
  const ollamaResponse = requests[1];
  const bodyGuiResponse = requests[2];
  const bodyMcpResponse = requests[3];
  const bodyBridgeResponse = requests[4];

  return {
    now: new Date().toISOString(),
    host: os.hostname(),
    jitRoot: JIT_ROOT,
    topologyLoaded: Object.keys(topology).length > 0,
    discord: {
      readyTag: (options && options.readyTag) || '',
      chatPrefix: CHAT_PREFIX,
      commandPrefix: COMMAND_PREFIX,
      reportChannelId: REPORT_CHANNEL_ID,
      reportConfigured: Boolean(REPORT_CHANNEL_ID),
      thoughtLoop: {
        enabled: thoughtLoopEnabled,
        intervalMs: thoughtLoopIntervalMs,
        channels: thoughtLoopChannels,
      },
    },
    devRecipients: DEV_RECIPIENTS,
    body: {
      selectedPath: bodyInfo.selectedPath,
      rawEnvPath: bodyInfo.rawEnvPath,
      candidates: bodyInfo.candidates,
      repoPresent: bodyInfo.repoPresent,
      gitPresent: bodyInfo.gitPresent,
      bridgeDir: bodyInfo.bridgeDir,
      bridgeFile: bodyInfo.bridgeFile,
      bridgeUrl: bodyInfo.bridgeUrl,
      bridgeHealthUrl: bodyBridgeHealthUrl,
      bridgeReachable: bodyBridgeResponse.ok,
      bridgeStatusCode: bodyBridgeResponse.statusCode || 0,
      guiUrl: bodyGuiUrl,
      guiReachable: bodyGuiResponse.ok,
      guiStatusCode: bodyGuiResponse.statusCode || 0,
      mcpHealthUrl: bodyMcpHealthUrl,
      mcpReachable: bodyMcpResponse.ok,
      mcpStatusCode: bodyMcpResponse.statusCode || 0,
    },
    bus: bus,
    oracle: {
      url: joinUrl(ORACLE_URL, '/api/health'),
      connected: Boolean(oracleResponse.json) && (oracleResponse.json.oracle === 'connected' || oracleResponse.json.status === 'ok'),
      reachable: oracleResponse.ok,
      statusCode: oracleResponse.statusCode || 0,
      version: oracleResponse.json && oracleResponse.json.version ? oracleResponse.json.version : '',
      error: oracleResponse.error || '',
    },
    ollama: {
      url: joinUrl(OLLAMA_URL, '/api/tags'),
      model: OLLAMA_MODEL,
      reachable: ollamaResponse.ok,
      tokenConfigured: Boolean(OLLAMA_TOKEN),
      statusCode: ollamaResponse.statusCode || 0,
      modelCount: ollamaResponse.json && Array.isArray(ollamaResponse.json.models) ? ollamaResponse.json.models.length : 0,
      error: ollamaResponse.error || '',
    },
  };
}

function formatProbe(label, reachable, url, statusCode, fallback) {
  const prefix = reachable ? 'online' : (fallback || 'offline');
  const code = statusCode ? ' [' + statusCode + ']' : '';
  return '- ' + label + ': ' + prefix + code + (url ? ' @ ' + url : '');
}

function formatStatusReport(status) {
  const busyAgents = status.bus.agents
    .filter(function(item) { return item.pending > 0; })
    .sort(function(left, right) { return right.pending - left.pending; })
    .slice(0, 5)
    .map(function(item) { return item.agent + ':' + item.pending; });

  const lines = [
    'Jit control status',
    'host: ' + status.host,
    'jit root: ' + status.jitRoot,
    'discord: chat ' + status.discord.chatPrefix + ' | command ' + status.discord.commandPrefix,
    'thought loop: ' + (status.discord.thoughtLoop.enabled ? 'enabled' : 'disabled') + ' | interval ' + Math.round(status.discord.thoughtLoop.intervalMs / 60000) + 'm | channels ' + (status.discord.thoughtLoop.channels.length ? status.discord.thoughtLoop.channels.join(', ') : '(runtime only)'),
    'dev recipients: ' + (status.devRecipients.length ? status.devRecipients.join(', ') : '(none)'),
    '',
    'body:',
    '- repo: ' + (status.body.repoPresent ? 'present' : 'missing') + ' @ ' + (status.body.selectedPath || '-'),
    '- bridge dir: ' + (status.body.bridgeDir || 'not configured'),
    '- bridge url: ' + (status.body.bridgeUrl || 'not configured'),
    formatProbe('bridge', status.body.bridgeReachable, status.body.bridgeHealthUrl, status.body.bridgeStatusCode),
    formatProbe('GUI', status.body.guiReachable, status.body.guiUrl, status.body.guiStatusCode),
    formatProbe('MCP', status.body.mcpReachable, status.body.mcpHealthUrl, status.body.mcpStatusCode),
    '',
    'oracle:',
    formatProbe('health', status.oracle.connected, status.oracle.url, status.oracle.statusCode, 'offline'),
    '',
    'ollama:',
    '- status: ' + (status.ollama.reachable ? 'online' : (status.ollama.tokenConfigured ? 'unreachable' : 'token not set')) + ' | model ' + status.ollama.model + ' | models ' + status.ollama.modelCount,
    '- url: ' + status.ollama.url,
    '',
    'bus:',
    '- inboxes: ' + status.bus.agentCount + ' | pending: ' + status.bus.totalPending,
    '- busiest: ' + (busyAgents.length ? busyAgents.join(', ') : 'no pending messages'),
  ];

  if (status.body.candidates.length > 1) {
    lines.push('- candidates: ' + status.body.candidates.join(' | '));
  }

  return lines.join('\n');
}

function formatBodyReport(status) {
  return [
    'innova-bot body binding',
    '- selected path: ' + (status.body.selectedPath || '-'),
    '- repo present: ' + (status.body.repoPresent ? 'yes' : 'no'),
    '- git repo: ' + (status.body.gitPresent ? 'yes' : 'no'),
    '- bridge dir: ' + (status.body.bridgeDir || 'not configured'),
    '- bridge file: ' + (status.body.bridgeFile || 'not configured'),
    '- bridge url: ' + (status.body.bridgeUrl || 'not configured'),
    formatProbe('bridge', status.body.bridgeReachable, status.body.bridgeHealthUrl, status.body.bridgeStatusCode),
    formatProbe('GUI', status.body.guiReachable, status.body.guiUrl, status.body.guiStatusCode),
    formatProbe('MCP', status.body.mcpReachable, status.body.mcpHealthUrl, status.body.mcpStatusCode),
  ].join('\n');
}

function formatQueueReport(agent, busStats, items) {
  const lines = [
    'bus queue',
    '- total inboxes: ' + busStats.agentCount,
    '- total pending: ' + busStats.totalPending,
  ];

  if (agent) {
    lines.push('- agent: ' + agent);
    if (!items.length) {
      lines.push('- pending: 0');
    } else {
      lines.push('- pending: ' + items.length + ' shown');
      items.forEach(function(item) {
        lines.push('  • ' + item.fileName + ' | from ' + item.from + ' | ' + item.subject);
      });
    }
  } else {
    const withPending = busStats.agents.filter(function(item) { return item.pending > 0; });
    if (!withPending.length) {
      lines.push('- pending agents: none');
    } else {
      withPending.forEach(function(item) {
        lines.push('  • ' + item.agent + ' | pending ' + item.pending + ' | read ' + item.read);
      });
    }
  }

  return lines.join('\n');
}

function formatDispatchReport(result) {
  const lines = [
    'ส่ง dev task เข้า Jit แล้ว',
    '- correlation: ' + result.correlationId,
    '- recipients: ' + result.recipients.join(', '),
    '- bus writes: ' + result.busWrites.length,
  ];

  result.busWrites.forEach(function(item) {
    lines.push('  • ' + item.filePath);
  });

  if (result.bridge.file) {
    lines.push('- bridge file: ' + (result.bridge.file.ok ? 'ok' : 'error') + ' | ' + result.bridge.file.path + (result.bridge.file.error ? ' | ' + result.bridge.file.error : ''));
  }
  if (result.bridge.webhook) {
    lines.push('- bridge webhook: ' + (result.bridge.webhook.ok ? 'ok' : 'error') + ' | ' + result.bridge.webhook.url + (result.bridge.webhook.statusCode ? ' [' + result.bridge.webhook.statusCode + ']' : '') + (result.bridge.webhook.error ? ' | ' + result.bridge.webhook.error : ''));
  }
  if (result.errors.length) {
    lines.push('- warnings: ' + result.errors.join(' | '));
  }

  lines.push('', 'task:', result.task);
  return lines.join('\n');
}

function formatDirectSendReport(result, messageBody) {
  return [
    'ส่ง message เข้า bus แล้ว',
    '- correlation: ' + result.correlationId,
    '- agent: ' + result.agent,
    '- subject: ' + result.subject,
    '- file: ' + result.busWrite.filePath,
    '',
    'body:',
    messageBody.trim(),
  ].join('\n');
}

function formatStartupReport(status) {
  return [
    'Hermes พร้อมเป็น Discord front-end ของ Jit แล้ว',
    '- ready: ' + (status.discord.readyTag || 'unknown bot'),
    '- command: ' + status.discord.commandPrefix + ' | chat: ' + status.discord.chatPrefix,
    '- thought loop: ' + (status.discord.thoughtLoop.enabled ? 'enabled' : 'disabled') + ' | channels ' + (status.discord.thoughtLoop.channels.length ? status.discord.thoughtLoop.channels.join(', ') : '(runtime only)'),
    '- body: ' + (status.body.repoPresent ? 'present' : 'missing') + ' @ ' + (status.body.selectedPath || '-'),
    '- oracle: ' + (status.oracle.connected ? 'online' : 'offline'),
    '- ollama: ' + (status.ollama.reachable ? 'online' : (status.ollama.tokenConfigured ? 'unreachable' : 'token not set')),
    '- bus pending: ' + status.bus.totalPending,
    '',
    'commands:',
    status.discord.commandPrefix + ' status',
    status.discord.commandPrefix + ' body',
    status.discord.commandPrefix + ' queue innova',
    status.discord.commandPrefix + ' dev <task>',
    status.discord.commandPrefix + ' loop on|off|status|now',
    status.discord.commandPrefix + ' report',
  ].join('\n');
}

function getHelpText() {
  return [
    'Hermes ↔ Jit control',
    '- ' + COMMAND_PREFIX + ' status    ดูสถานะรวมของ Jit/body/oracle/ollama/bus',
    '- ' + COMMAND_PREFIX + ' body      ดู binding ไปยัง innova-bot body',
    '- ' + COMMAND_PREFIX + ' queue [agent]  ดู queue ของ bus',
    '- ' + COMMAND_PREFIX + ' dev <task>     ส่งงาน dev เข้า jit+soma+innova และ mirror ไป body bridge',
    '- ' + COMMAND_PREFIX + ' loop on|off|status|now  ควบคุม thought loop ของ Hermes ใน channel นี้',
    '- ' + COMMAND_PREFIX + ' tell <agent> <subject> <body>  ส่ง message ตรงเข้า bus',
    '- ' + COMMAND_PREFIX + ' report    ส่งรายงานสถานะไปยัง channel รายงานหรือ channel ปัจจุบัน',
    '- @mention jit status  ใช้แบบ mention ได้เช่นกัน',
    '- ' + CHAT_PREFIX + ' ...  โหมดคุยกับ Ollama ตามปกติ',
  ].join('\n');
}

function splitMessage(text, limit) {
  const maxLength = parsePositiveInt(limit, 1900);
  if (!text || text.length <= maxLength) return [text];

  const chunks = [];
  let current = '';

  text.split('\n').forEach(function(line) {
    const candidate = current ? current + '\n' + line : line;
    if (candidate.length <= maxLength) {
      current = candidate;
      return;
    }

    if (current) chunks.push(current);
    if (line.length <= maxLength) {
      current = line;
      return;
    }

    for (let index = 0; index < line.length; index += maxLength) {
      chunks.push(line.slice(index, index + maxLength));
    }
    current = '';
  });

  if (current) chunks.push(current);
  return chunks.filter(Boolean);
}

module.exports = {
  COMMAND_PREFIX: COMMAND_PREFIX,
  REPORT_CHANNEL_ID: REPORT_CHANNEL_ID,
  BUS_ROOT: BUS_ROOT,
  collectBusStats: collectBusStats,
  collectStatus: collectStatus,
  dispatchDevTask: dispatchDevTask,
  formatBodyReport: formatBodyReport,
  formatDirectSendReport: formatDirectSendReport,
  formatDispatchReport: formatDispatchReport,
  formatQueueReport: formatQueueReport,
  formatStartupReport: formatStartupReport,
  formatStatusReport: formatStatusReport,
  getHelpText: getHelpText,
  listPendingMessages: listPendingMessages,
  loadTopology: loadTopology,
  resolveBodyPath: resolveBodyPath,
  sendDirectBusMessage: sendDirectBusMessage,
  splitMessage: splitMessage,
};