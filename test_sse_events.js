const { EventSource } = require('eventsource');

const endpoint = 'http://127.0.0.1:7010/sse';
console.log(`Connecting to SSE endpoint: ${endpoint}...`);

const es = new EventSource(endpoint);

es.onopen = () => {
  console.log('SSE Connection opened.');
};

es.onmessage = (event) => {
  console.log('Event received:');
  console.log(event.data);
};

es.onerror = (err) => {
  console.error('SSE Error:', err);
};

// Set a timeout to exit after 15 seconds if no events are received
setTimeout(() => {
  console.log('Test timed out after 15 seconds.');
  es.close();
  process.exit(0);
}, 15000);
