const InnovaBotBridge = require('../limbs/innova-bot-bridge');

async function run() {
    const bridge = new InnovaBotBridge();
    try {
        await bridge.connect();
        const result = await bridge.callTool('fetch_pending_events', {
            role: 'Quality_Evaluator'
        });
        console.log('PENDING_EVENTS:', JSON.stringify(result, null, 2));
    } catch (e) {
        console.error('Error:', e);
    } finally {
        await bridge.disconnect();
        process.exit(0);
    }
}

run();
