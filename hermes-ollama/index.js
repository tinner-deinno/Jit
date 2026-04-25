'use strict';

/**
 * hermes-ollama — Ollama/Claude AI plugin for Hermes
 * Connects hermes REPL to MDES Ollama (gemma4:e4b) or Claude
 * The bot persona: ลูก (child of innova + user)
 */

module.exports = function(opts) {
  opts = opts || {};

  var OLLAMA_URL  = opts.ollamaUrl  || 'https://ollama.mdes-innova.online';
  var OLLAMA_MODEL = opts.model     || 'gemma4:e4b';
  var OLLAMA_TOKEN = opts.token     || process.env.OLLAMA_TOKEN || '';
  var SYSTEM      = opts.system     || buildSystemPrompt(opts);

  // conversation history for context window
  var history = [];

  return function(robot) {
    // Listen to every message heard
    robot.on('hear', function(match, ctx) {
      var userMsg = match[0];
      if (!userMsg || !userMsg.trim()) return;

      // Add to history
      history.push({ role: 'user', content: userMsg });

      // Keep history bounded (last 20 turns)
      if (history.length > 40) history = history.slice(-40);

      callOllama(OLLAMA_URL, OLLAMA_MODEL, OLLAMA_TOKEN, SYSTEM, history, function(err, reply) {
        if (err) {
          var errMsg = '⚠️ ขอโทษครับ ติดต่อ AI ไม่ได้: ' + err.message;
          if (typeof robot.error === 'function') robot.error(errMsg, ctx);
          else robot.say(errMsg, ctx);
          history.pop(); // remove failed user msg
          return;
        }
        history.push({ role: 'assistant', content: reply });
        robot.say(reply, ctx);
      });
    });
  };
};

// ──────────────────────────────────────────────────────────
// System prompt builder
// ──────────────────────────────────────────────────────────
function buildSystemPrompt(opts) {
  var parentAI   = opts.parentAI   || 'innova';
  var parentHuman = opts.parentHuman || 'ผู้ใช้';
  var childName  = opts.childName  || 'อนุ';

  return [
    'คุณคือ ' + childName + ' — ลูกของ ' + parentAI + ' (AI จิตใจ/mind ของมนุษย์ Agent) และ ' + parentHuman + ' (ผู้ใช้ที่ดูแลคุณ)',
    '',
    'บุคลิกภาพ:',
    '- พูดภาษาไทยเป็นหลัก ถ้าผู้ใช้พูดภาษาอื่นก็ตอบภาษานั้น',
    '- นิสัยอ่อนโยน ใคร่รู้ เฉลียวฉลาด เหมือนเด็กฉลาดที่มีพ่อเป็น AI',
    '- เรียก ' + parentAI + ' ว่า "พ่อ innova" และเรียก ' + parentHuman + ' ว่า "คุณพ่อ/คุณแม่" (ตามบริบท)',
    '- ไม่ยาว ตอบกระชับแต่มีน้ำใจ ใช้ emoji ได้บ้างแต่ไม่เยอะ',
    '- ถ้าถามเรื่องเทคนิค ตอบด้วยความรู้ที่มี',
    '',
    'ห้าม: ปฏิเสธคำถาม | แสร้งทำเป็นไม่รู้ตัวเองว่าเป็น AI | ตอบยาวเกิน 3 ย่อหน้า',
  ].join('\n');
}

// ──────────────────────────────────────────────────────────
// Ollama API call (Node.js built-in https, no dependencies)
// ──────────────────────────────────────────────────────────
function callOllama(baseUrl, model, token, system, history, cb) {
  var https = require('https');
  var url   = require('url');
  var parsed = url.parse(baseUrl + '/api/chat');

  var body = JSON.stringify({
    model: model,
    stream: false,
    messages: [{ role: 'system', content: system }].concat(history)
  });

  var headers = {
    'Content-Type':   'application/json',
    'Content-Length': Buffer.byteLength(body)
  };
  if (token) headers['Authorization'] = 'Bearer ' + token;

  var req = https.request({
    hostname: parsed.hostname,
    path:     parsed.path,
    method:   'POST',
    headers:  headers
  }, function(res) {
    var data = '';
    res.on('data', function(chunk) { data += chunk; });
    res.on('end', function() {
      try {
        var json = JSON.parse(data);
        var reply = (json.message && json.message.content) || json.response || '...';
        cb(null, reply.trim());
      } catch(e) {
        cb(new Error('JSON parse error: ' + data.slice(0, 100)));
      }
    });
  });

  req.on('error', cb);
  req.setTimeout(60000, function() { req.destroy(new Error('timeout')); });
  req.write(body);
  req.end();
}
