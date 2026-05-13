#!/usr/bin/env node
'use strict';
/**
 * skills/vaja-thai-tts/listener.js
 * Real-time Jit Bus Listener for Thai TTS
 * Continuously monitors agent outputs and generates Thai audio summaries
 */

const fs   = require('fs');
const path = require('path');
const http = require('http');
const { spawn } = require('child_process');

const BUS_ROOT   = process.env.MANUSAT_BUS_DIR || '/tmp/manusat-bus';
const CACHE_DIR  = process.env.VAJA_CACHE_DIR  || '/tmp/vaja-tts';
const LOG_FILE   = process.env.VAJA_LOG_FILE   || '/tmp/vaja-tts.log';

// ALL 14 organ agents — listen to every agent
const ALL_AGENTS = new Set([
  'jit', 'soma',
  'innova', 'lak', 'neta',
  'vaja', 'chamu', 'rupa', 'pada', 'netra', 'karn', 'mue', 'pran', 'sayanprasathan',
]);

// External service endpoints
const INNOVA_BOT_URL = process.env.INNOVA_BOT_URL || 'http://localhost:7010';
const INNOMCP_URL    = process.env.INNOMCP_URL    || 'http://localhost:3012';

// Speak queue — prevents overlapping speech
const speakQueue = [];
let isSpeaking   = false;

// Track processed messages (dedup)
const processedMessages = new Set();

// Ensure directories exist
[CACHE_DIR].forEach(dir => {
  try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
});
ALL_AGENTS.forEach(a => {
  try { fs.mkdirSync(path.join(BUS_ROOT, a), { recursive: true }); } catch (_) {}
});

const log = (msg) => {
  const timestamp = new Date().toISOString();
  const logMsg = `[${timestamp}] ${msg}\n`;
  process.stdout.write(logMsg);
  try { fs.appendFileSync(LOG_FILE, logMsg); } catch (_) {}
};

log('🎤 Vaja Thai TTS Listener v2 — All-Agents Mode');
log(`🎯 Monitoring ALL ${ALL_AGENTS.size} organ agents on bus: ${BUS_ROOT}`);
log(`🌐 innova-bot: ${INNOVA_BOT_URL} | innomcp: ${INNOMCP_URL}`);

/**
 * Parse a message file into headers and body
 * @param {string} content - Raw message content
 * @returns {{headers: Object, body: string}}
 */
function parseMessage(content) {
  const parts = content.split('\n---\n');
  if (parts.length < 2) {
    return { headers: {}, body: content };
  }

  const headersText = parts[0];
  const body = parts.slice(1).join('\n---\n'); // In case there are multiple "---" in body

  const headers = {};
  headersText.split('\n').forEach(line => {
    const [key, ...valueParts] = line.split(':');
    if (key !== undefined && valueParts.length > 0) {
      const value = valueParts.join(':').trim();
      headers[key.toLowerCase().trim()] = value;
    }
  });

  return { headers, body: body.trim() };
}

/**
 * Generate Thai summary using Ollama
 * @param {string} text - Text to summarize
 * @returns {Promise<string>} Thai summary
 */
async function generateThaiSummary(text) {
  return new Promise((resolve, reject) => {
    // Call limbs/ollama.sh translate function for Thai summarization
    // We'll ask it to summarize in Thai
    const prompt = `กรุณาสรุปข้อความต่อไปนี้เป็นภาษาไทยอย่างกระชับและชัดเจน ไม่เกิน 2 ประโยค:${text.slice(0, 800)}`;

    const ollamaScript = path.join(__dirname, '..', '..', 'limbs', 'ollama.sh');

    const ollamaProcess = spawn('bash', [ollamaScript, 'ask', prompt], {
      maxBuffer: 1024 * 1024 // 1MB buffer
    });

    let output = '';
    let error = '';

    ollamaProcess.stdout.on('data', (data) => {
      output += data.toString();
    });

    ollamaProcess.stderr.on('data', (data) => {
      error += data.toString();
    });

    ollamaProcess.on('close', (code) => {
      if (code !== 0) {
        log(`  ⚠ Ollama error (code ${code}): ${error.trim()}`);
        // Fallback: simple truncation as mock
        const fallback = `สรุป: ${text.substring(0, Math.min(100, text.length))}...`;
        resolve(fallback);
        return;
      }

      const summary = output.trim();
      if (summary) {
        resolve(summary);
      } else {
        // Fallback if empty response
        const fallback = `สรุป: ${text.substring(0, Math.min(100, text.length))}...`;
        resolve(fallback);
      }
    });

    ollamaProcess.on('error', (err) => {
      log(`  ⚠ Ollama process error: ${err.message}`);
      // Fallback: simple truncation as mock
      const fallback = `สรุป: ${text.substring(0, Math.min(100, text.length))}...`;
      resolve(fallback);
    });
  });
}

/**
 * Speak Thai text using Windows PowerShell TTS
 * @param {string} thaiText - Thai text to speak
 */
async function speakThai(thaiText) {
  return new Promise((resolve, reject) => {
    const powershellScript = `
      Add-Type -AssemblyName System.Speech;
      $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer;
      $speak.SelectVoiceByHints(2); // Thai voice
      $speak.Rate = 0; // Normal speed
      $speak.Volume = 80; // 80% volume
      $speak.Speak("${thaiText.replace(/"/g, '\\"')}");`;

    const powershellProcess = spawn('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-Command',
      powershellScript
    ]);

    let error = '';

    powershellProcess.stderr.on('data', (data) => {
      error += data.toString();
    });

    powershellProcess.on('close', (code) => {
      if (code !== 0) {
        log(`  ⚠ TTS error (code ${code}): ${error.trim()}`);
        resolve(false);
        return;
      }
      resolve(true);
    });

    powershellProcess.on('error', (err) => {
      log(`  ⚠ TTS process error: ${err.message}`);
      resolve(false);
    });
  });
}

// ── Speak queue — one at a time -----------------------------------------------
function enqueueSpeech(text) {
  speakQueue.push(text);
  processNextSpeech();
}

async function processNextSpeech() {
  if (isSpeaking || speakQueue.length === 0) return;
  isSpeaking = true;
  const text = speakQueue.shift();
  try {
    await speakThai(text);
  } catch (e) {
    log(`  ⚠ Speech error: ${e.message}`);
  } finally {
    isSpeaking = false;
    if (speakQueue.length > 0) processNextSpeech();
  }
}

/**
 * Process a message: check sender, summarize in Thai, and speak
 */
async function processMessage(msgFile) {
  const msgId = path.basename(msgFile);
  if (processedMessages.has(msgId)) return;
  processedMessages.add(msgId);

  try {
    const content = fs.readFileSync(msgFile, 'utf8');
    const { headers, body } = parseMessage(content);

    const fromAgent = headers.from || headers.agent || '';
    const subject   = headers.subject || 'no subject';

    // Skip messages from vaja itself (avoid echo)
    if (fromAgent === 'vaja' || !body) return;

    log(`📨 Received from ${fromAgent}: ${subject}`);
    log(`  📄 Content length: ${body.length} chars`);

    // Summarize in Thai
    log('  🌐 Generating Thai summary...');
    const thaiSummary = await generateThaiSummary(
      `จาก agent ${fromAgent}: ${subject}. ${body}`
    );
    log(`  📝 ไทย: ${thaiSummary.slice(0, 100)}`);

    // Enqueue for speech (non-blocking, queued)
    enqueueSpeech(thaiSummary);

    // Save summary
    const ts = Date.now();
    const summaryFile = path.join(CACHE_DIR, `summary-${fromAgent}-${ts}.txt`);
    fs.writeFileSync(summaryFile, `from:${fromAgent}\nsubject:${subject}\n\n${thaiSummary}`, 'utf8');

    // Archive processed message
    const processedFile = msgFile.replace(/\.msg$/, '.processed');
    try { fs.renameSync(msgFile, processedFile); } catch (_) {}
    log(`  📬 แอร์คไว: ${path.basename(processedFile)}`);

  } catch (err) {
    log(`  ✗ Error processing message: ${err.message}`);
  }
}

/**
 * Watch for new messages from ALL agents on the bus
 */
function watchInbox() {
  const checkAllAgents = () => {
    ALL_AGENTS.forEach(agentName => {
      const inboxDir = path.join(BUS_ROOT, agentName);
      try {
        if (!fs.existsSync(inboxDir)) return;
        const files = fs.readdirSync(inboxDir).filter(f => f.endsWith('.msg'));
        files.forEach(f => processMessage(path.join(inboxDir, f)));
      } catch (_) {}
    });
  };

  setInterval(checkAllAgents, 2000);
  checkAllAgents(); // Initial check
  log(`👀 Watching ${ALL_AGENTS.size} agent inboxes (every 2s)`);
}

// ── Poll innova-bot HTTP events ------------------------------------------
let lastInnovaEventId = 0;

function pollInnovaBot() {
  const req = http.get(
    `${INNOVA_BOT_URL}/api/events?since=${lastInnovaEventId}`,
    { timeout: 5000 },
    (res) => {
      let data = '';
      res.on('data', c => { data += c; });
      res.on('end', () => {
        if (res.statusCode !== 200) return;
        try {
          const events = JSON.parse(data);
          if (!Array.isArray(events) || events.length === 0) return;
          events.forEach(evt => {
            if (evt.id) lastInnovaEventId = Math.max(lastInnovaEventId, evt.id);
            const text = evt.message || evt.text || evt.content || '';
            if (text.length > 20) {
              log(`📡 [innova-bot] event: ${text.slice(0, 60)}`);
              generateThaiSummary(`innova-bot รายงาน: ${text}`)
                .then(s => enqueueSpeech(s));
            }
          });
        } catch (_) {}
      });
    }
  );
  req.on('error', () => {}); // Silent if offline
}

// ── Poll innomcp ----------------------------------------------------------
function pollInnomcp() {
  const req = http.get(
    `${INNOMCP_URL}/health`,
    { timeout: 5000 },
    (res) => {
      let data = '';
      res.on('data', c => { data += c; });
      res.on('end', () => {
        try {
          const status = JSON.parse(data);
          if (status && status._newResults) {
            const text = JSON.stringify(status._newResults).slice(0, 200);
            generateThaiSummary(`innomcp มีผลลัพธ์ใหม่: ${text}`)
              .then(s => enqueueSpeech(s));
          }
        } catch (_) {}
      });
    }
  );
  req.on('error', () => {}); // Silent if offline
}

/**
 * Status reporting every minute
 */
function reportStatus() {
  setInterval(() => {
    try {
      let totalPending = 0;
      ALL_AGENTS.forEach(agent => {
        const d = path.join(BUS_ROOT, agent);
        try {
          totalPending += fs.readdirSync(d).filter(f => f.endsWith('.msg')).length;
        } catch (_) {}
      });
      log(`📊 Status: ${totalPending} pending | ${processedMessages.size} processed | queue:${speakQueue.length} | speaking:${isSpeaking}`);
    } catch (_) {}
  }, 60000);
}

// Start
log('🚀 Starting Vaja All-Agents Listener...');
watchInbox();
setInterval(pollInnovaBot, 10000);
setInterval(pollInnomcp,    15000);
reportStatus();

// Handle shutdown
process.on('SIGINT',  () => { log('🛑 Vaja listener shutting down');  process.exit(0); });
process.on('SIGTERM', () => { log('🛑 Vaja listener terminated');     process.exit(0); });

// Keep process alive
setInterval(() => {}, 3600000);