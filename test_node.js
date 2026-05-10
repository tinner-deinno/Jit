const https = require('https');
const fs = require('fs');
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
    'Authorization': 'Bearer 9e34679b9d60d8b984005ec46508579c',
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
