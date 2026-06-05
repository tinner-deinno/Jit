#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const LOOP_DIR = path.join(ROOT, 'network', 'loop');
const LATEST_JSON = path.join(LOOP_DIR, 'latest-visual.json');

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

function intArg(name, fallback, min, max) {
  const n = Math.floor(Number(arg(name, fallback)));
  if (!Number.isFinite(n)) return fallback;
  return Math.max(min, Math.min(max, n));
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

const TARGET_URL = arg('--url', process.env.INNOVA_VISUAL_URL || 'http://127.0.0.1:7010/gui');
const RUN_ID = arg('--run-id', 'visual-probe-' + new Date().toISOString().replace(/[:.]/g, '-'));
const TIMEOUT_MS = intArg('--timeout-ms', 90000, 5000, 300000);
const ARTIFACT_DIR = path.join(ROOT, 'network', 'artifacts', RUN_ID);

async function captureWithPlaywright() {
  const { chromium } = require('playwright');
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    const response = await page.goto(TARGET_URL, {
      waitUntil: 'domcontentloaded',
      timeout: Math.min(TIMEOUT_MS, 60000),
    });
    await page.waitForTimeout(1200);
    const title = await page.title();
    const screenshotPath = path.join(ARTIFACT_DIR, 'playwright-shot.png');
    await page.screenshot({ path: screenshotPath, fullPage: false });
    const pageStats = await page.evaluate(() => ({
      buttons: document.querySelectorAll('button,[role="button"]').length,
      headings: document.querySelectorAll('h1,h2,h3').length,
      forms: document.querySelectorAll('form').length,
      textLength: (document.body && document.body.innerText ? document.body.innerText.length : 0),
    }));
    return {
      ok: true,
      title,
      status: response ? response.status() : 0,
      finalUrl: page.url(),
      screenshot: path.relative(ROOT, screenshotPath).replace(/\\/g, '/'),
      stats: pageStats,
    };
  } finally {
    await browser.close();
  }
}

function chromeCall(fnName, ...args) {
  return new Promise((resolve, reject) => {
    const chromeTools = require('../hermes-discord/chrome-tools');
    chromeTools[fnName](...args, (error, result) => {
      if (error) reject(error);
      else resolve(result);
    });
  });
}

async function captureWithChromeTools() {
  const navigate = await chromeCall('navigate', TARGET_URL);
  const analyzeUI = await chromeCall('analyzeUI', TARGET_URL);
  return { ok: true, navigate, analyzeUI };
}

async function main() {
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
  const summary = {
    runId: RUN_ID,
    url: TARGET_URL,
    startedAt: new Date().toISOString(),
    ok: false,
  };

  try {
    summary.playwright = await captureWithPlaywright();
  } catch (error) {
    summary.playwright = { ok: false, error: String(error && error.message || error).slice(0, 300) };
  }

  try {
    summary.devtools = await captureWithChromeTools();
  } catch (error) {
    summary.devtools = { ok: false, error: String(error && error.message || error).slice(0, 300) };
  }

  summary.finishedAt = new Date().toISOString();
  summary.ok = Boolean(summary.playwright && summary.playwright.ok) || Boolean(summary.devtools && summary.devtools.ok);
  summary.signal = {
    title: summary.playwright && summary.playwright.title ? summary.playwright.title : '',
    status: summary.playwright && summary.playwright.status ? summary.playwright.status : 0,
    hasDomStats: Boolean(summary.playwright && summary.playwright.stats),
    hasDevtoolsAnalysis: Boolean(summary.devtools && summary.devtools.analyzeUI),
  };

  writeJson(path.join(ARTIFACT_DIR, 'visual-summary.json'), summary);
  writeJson(LATEST_JSON, summary);
  console.log(JSON.stringify(summary, null, 2));
  process.exit(summary.ok ? 0 : 1);
}

main().catch(error => {
  const summary = {
    runId: RUN_ID,
    url: TARGET_URL,
    ok: false,
    fatal: String(error && error.message || error).slice(0, 400),
    finishedAt: new Date().toISOString(),
  };
  writeJson(LATEST_JSON, summary);
  console.log(JSON.stringify(summary, null, 2));
  process.exit(1);
});
