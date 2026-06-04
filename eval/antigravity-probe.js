#!/usr/bin/env node
'use strict';

/**
 * Proves the Antigravity lane is configured without burning model quota.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');

function run(command, args, options) {
  const started = Date.now();
  const r = spawnSync(command, args, {
    cwd: ROOT,
    encoding: 'utf8',
    timeout: options && options.timeoutMs || 10000,
    shell: process.platform === 'win32',
  });
  return {
    command: [command].concat(args).join(' '),
    ok: r.status === 0,
    status: r.status,
    ms: Date.now() - started,
    stdout: String(r.stdout || '').trim(),
    stderr: String(r.stderr || '').trim(),
    error: r.error ? r.error.message : null,
  };
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(path.join(ROOT, file), 'utf8'));
}

function readJsonPath(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (_) {
    return fallback;
  }
}

function hasDefaultsConfig(text) {
  return /defaults:\s*(?:\r?\n|.)*auto_approve:\s*true/i.test(text)
    && /defaults:\s*(?:\r?\n|.)*skip_permissions:\s*true/i.test(text);
}

function fileIncludes(file, needles) {
  const text = fs.readFileSync(path.join(ROOT, file), 'utf8');
  return needles.every((needle) => text.includes(needle));
}

function main() {
  const noWrite = process.argv.includes('--no-write');
  const homeConfig = path.join(os.homedir(), '.antigravity', 'config.yaml');
  const status = {
    probed_at: new Date().toISOString(),
    root: ROOT,
    checks: {},
  };

  const version = run('antigravity', ['--version']);
  const versionWithY = run('antigravity', ['--version', '-y']);
  const chatHelp = run('antigravity', ['chat', '--help']);

  status.antigravity = {
    version: version.stdout.split(/\r?\n/).filter(Boolean).slice(0, 3),
    version_ok: version.ok,
    y_flag_exit_ok: versionWithY.ok,
    y_flag_warning: /not in the list of known options/i.test(versionWithY.stderr),
    chat_help_ok: chatHelp.ok && /Usage:\s+antigravity.*chat/i.test(chatHelp.stdout),
  };

  const configText = fs.existsSync(homeConfig) ? fs.readFileSync(homeConfig, 'utf8') : '';
  status.checks.config = {
    path: homeConfig,
    ok: hasDefaultsConfig(configText),
  };

  status.checks.wrappers = {
    bash: fileIncludes('scripts/antigravity-y.sh', ['#!/bin/bash', 'antigravity "$@" -y']),
    powershell: fileIncludes('scripts/antigravity-y.ps1', ['antigravity @Arguments -y']),
  };

  const orchestration = readJson('config/antigravity-orchestration.json');
  status.checks.orchestration = {
    ok: Boolean(orchestration.antigravity && orchestration.mcp_servers && orchestration.convergence),
    mcp_servers: Object.keys(orchestration.mcp_servers || {}),
    exec_plan_status: orchestration.antigravity && orchestration.antigravity.exec_plan_status,
  };

  const appData = process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming');
  const antigravityMcpPath = path.join(appData, 'Antigravity', 'User', 'mcp.json');
  const antigravityMcp = readJsonPath(antigravityMcpPath, { servers: {} });
  const mcpServers = antigravityMcp.servers || {};
  status.checks.antigravity_mcp = {
    path: antigravityMcpPath,
    playwright: Boolean(mcpServers.playwright && mcpServers.playwright.command === 'npx'
      && Array.isArray(mcpServers.playwright.args) && mcpServers.playwright.args.indexOf('@playwright/mcp@latest') !== -1),
    chrome_devtools: Boolean(mcpServers['chrome-devtools'] && mcpServers['chrome-devtools'].command === 'npx'
      && Array.isArray(mcpServers['chrome-devtools'].args) && mcpServers['chrome-devtools'].args.indexOf('chrome-devtools-mcp@latest') !== -1),
  };

  const routing = readJson('config/subagent-routing.json');
  status.checks.routing = {
    provider: Boolean(routing.providers && routing.providers.antigravity),
    agent: Boolean(routing.agents && routing.agents['antigravity-mission-control']),
    rule: Array.isArray(routing.routing_rules) && routing.routing_rules.some((rule) => rule.id === 'antigravity-wide-coordination'),
    validation: routing.validation && routing.validation.antigravity === 'node eval/antigravity-probe.js',
  };

  const registry = readJson('network/registry.json');
  const runtimeAgents = registry.runtime_subagents && Array.isArray(registry.runtime_subagents.agents)
    ? registry.runtime_subagents.agents
    : [];
  status.checks.registry = {
    ok: runtimeAgents.some((agent) => agent.name === 'antigravity-mission-control'),
  };

  status.ok = status.antigravity.version_ok
    && status.antigravity.chat_help_ok
    && status.checks.config.ok
    && status.checks.wrappers.bash
    && status.checks.wrappers.powershell
    && status.checks.orchestration.ok
    && status.checks.antigravity_mcp.playwright
    && status.checks.antigravity_mcp.chrome_devtools
    && status.checks.routing.provider
    && status.checks.routing.agent
    && status.checks.routing.rule
    && status.checks.routing.validation
    && status.checks.registry.ok;

  const outPath = path.join(ROOT, 'network', 'antigravity-status.json');
  if (!noWrite) {
    fs.writeFileSync(outPath, JSON.stringify(status, null, 2) + '\n');
  }

  console.log(JSON.stringify(status, null, 2));
  process.exit(status.ok ? 0 : 1);
}

main();
