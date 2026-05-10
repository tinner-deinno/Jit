const https = require('https');

const data = JSON.stringify({
  model: 'gemma4:26b',
  messages: [{ role: 'user', content: 'hi. tell me a joke' }],
  stream: true
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

const req = https.request(options, (res) => {
  console.log(`STATUS: ${res.statusCode}`);
  res.on('data', (d) => {
    process.stdout.write(d);
  });
});

req.on('error', (e) => {
  console.error(e);
});

req.write(data);
req.end();
