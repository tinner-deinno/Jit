const InnovaBotBridge = require('./innova-bot-bridge');

async function main() {
  const bridge = new InnovaBotBridge();
  try {
    console.log('Connecting to innova-bot...');
    await bridge.connect();

    const message = "Mother has awakened. Infrastructure Surge Complete. Leaderboard initialized. Bus optimized. Synchronizing soul-state.";
    console.log(`Dispatching task: ${message}`);
    const result = await bridge.dispatchTask(message);

    console.log('Response from innova-bot:', JSON.stringify(result, null, 2));
  } catch (e) {
    console.error('Bridge failure:', e.message);
    process.exit(1);
  } finally {
    await bridge.disconnect();
  }
}

main();
