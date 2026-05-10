#!/usr/bin/env node
'use strict';
/**
 * skills/vaja-thai-tts/listener.js
 * Real-time Jit Bus Listener for Thai TTS
 * Continuously monitors agent outputs and generates Thai audio summaries
 */

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const INBOX_DIR = '/tmp/manusat-bus/vaja';
const CACHE_DIR = '/tmp/vaja-tts';
const LOG_FILE = '/tmp/vaja-tts.log';

// Target agents to listen for (from CLAUDE.md organ assignments)
const TARGET_AGENTS = new Set(['pran', 'soma', 'sayanprasathan', 'mue']);

// Ensure directories exist
[INBOX_DIR, CACHE_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

const log = (msg) => {
  const timestamp = new Date().toISOString();
  const logMsg = `[${timestamp}] ${msg}\n`;
  process.stdout.write(logMsg);
  fs.appendFileSync(LOG_FILE, logMsg);
};

log('🎤 Vaja Thai TTS Listener Started');
log(`🎯 Listening for messages from: ${Array.from(TARGET_AGENTS).join(', ')}`);

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
    const prompt = `กรุณาสรุปข้อความต่อไปนี้เป็นภาษาไทยอย่างกระชับและชัดเจน ไม่เกิน 3 ประโยค:\n\n${text}`;

    const ollamaScript = path.join(__dirname, '..', '..', '..', 'limbs', 'ollama.sh');

    const ollamaProcess = spawn('bash', [ollamaScript, 'translate', prompt], {
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

/**
 * Process a message: check sender, summarize in Thai, and speak
 */
async function processMessage(msgFile) {
  try {
    const content = fs.readFileSync(msgFile, 'utf8');
    const { headers, body } = parseMessage(content);

    const fromAgent = headers.from || '';
    const subject = headers.subject || 'no subject';

    // Check if message is from one of our target agents
    if (!TARGET_AGENTS.has(fromAgent)) {
      // Not a target agent, skip silently
      return;
    }

    log(`📨 Received from ${fromAgent}: ${subject}`);

    if (!body) {
      log('  ⚠ No content to summarize');
      return;
    }

    log(`  📄 Content length: ${body.length} characters`);

    // Summarize in Thai
    log('  🌐 Generating Thai summary...');
    const thaiSummary = await generateThaiSummary(body);
    log(`  📝 Thai summary: ${thaiSummary}`);

    // Speak the Thai summary
    log('  🔊 Speaking Thai summary...');
    const spoken = await speakThai(thaiSummary);
    if (spoken) {
      log('  ✓ Thai summary spoken successfully');
    } else {
      log('  ⚠ Failed to speak Thai summary');
    }

    // Optional: Save summary to cache for reference
    const timestamp = Date.now();
    const summaryFile = path.join(CACHE_DIR, `summary-${timestamp}.txt`);
    fs.writeFileSync(summaryFile, thaiSummary, 'utf8');

    // Mark message as processed by moving it
    const processedFile = msgFile.replace(/\.msg$/, '.processed');
    fs.renameSync(msgFile, processedFile);
    log(`  📬 Message archived as: ${path.basename(processedFile)}`);

  } catch (err) {
    log(`  ✗ Error processing message: ${err.message}`);
  }
}

/**
 * Watch for new messages in inbox
 */
function watchInbox() {
  const processedFiles = new Set();

  const checkMessages = () => {
    try {
      const files = fs.readdirSync(INBOX_DIR);

      files.forEach(file => {
        // Skip already processed files
        if (processedFiles.has(file)) return;

        // Only process .msg files (new messages)
        if (!file.endsWith('.msg')) return;

        const filepath = path.join(INBOX_DIR, file);
        processedFiles.add(file);

        processMessage(filepath);
      });
    } catch (err) {
      log(`Inbox watch error: ${err.message}`);
    }
  };

  // Check every 3 seconds for more responsiveness
  setInterval(checkMessages, 3000);
  checkMessages(); // Check immediately
}

/**
 * Status reporting
 */
function reportStatus() {
  setInterval(() => {
    try {
      const files = fs.readdirSync(INBOX_DIR).length;
      const msgFiles = fs.readdirSync(INBOX_DIR).filter(f => f.endsWith('.msg')).length;
      const processedFiles = fs.readdirSync(INBOX_DIR).filter(f => f.endsWith('.processed')).length;
      const summaryFiles = fs.readdirSync(CACHE_DIR).filter(f => f.startsWith('summary-') && f.endsWith('.txt')).length;
      log(`📊 Status: ${msgFiles} pending, ${processedFiles} processed, ${summaryFiles} summaries generated`);
    } catch (err) {
      // silently ignore
    }
  }, 30000); // Every 30 seconds
}

// Start listening
log('🚀 Starting inbox watcher...');
watchInbox();
log('📊 Starting status reporter...');
reportStatus();

// Handle shutdown
process.on('SIGINT', () => {
  log('🛑 Vaja TTS Listener Shutting Down');
  process.exit(0);
});

process.on('SIGTERM', () => {
  log('🛑 Vaja TTS Listener Terminated');
  process.exit(0);
});

// Keep process alive
setInterval(() => {}, 3600000);