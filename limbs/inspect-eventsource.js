const EventSource = require('eventsource');
console.log('Type of EventSource:', typeof EventSource);
console.log('Is it a function?', typeof EventSource === 'function');
console.log('Module keys:', Object.keys(EventSource));
if (EventSource.default) {
  console.log('Has .default property: Yes');
  console.log('Type of .default:', typeof EventSource.default);
} else {
  console.log('Has .default property: No');
}
