const https = require('https');
const fs = require('fs');
const path = require('path');

// Load .env if not already loaded
const envPath = path.join(__dirname, '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

const logFile = 'C:\\Users\\admin\\Jit\\node_out.txt';

const data = JSON.stringify({
  model: 'gemma4:26b',
  messages: [{ role: 'user', content: 'สวัสดีครับ ช่วยแนะนำตัวหน่อย' }],
  stream: false
});

const options = {
  hostname: 'ollama.mdes-innova.online',
  path: '/v1/chat/completions',
  method: 'POST',
  headers: {
    'Authorization': 'Bearer ' + (process.env.OLLAMA_TOKEN || ''),
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

fs.writeFileSync(logFile, 'Starting test...\n');

const req = https.request(options, (res) => {
  fs.appendFileSync(logFile, `STATUS: ${res.statusCode}\n`);
  res.on('data', (d) => {
    fs.appendFileSync(logFile, d.toString());
  });
  res.on('end', () => {
    fs.appendFileSync(logFile, '\nEnd of test.\n');
  });
});

req.on('error', (e) => {
  fs.appendFileSync(logFile, `ERROR: ${e.message}\n`);
});

req.write(data);
req.end();
