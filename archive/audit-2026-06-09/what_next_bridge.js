const fs = require('fs');
const path = require('path');
const InnovaBotBridge = require('../limbs/innova-bot-bridge');

async function run() {
    const bridge = new InnovaBotBridge();
    try {
        await bridge.connect();
        const result = await bridge.callTool('what_should_i_do_next', {
            role: 'Quality_Evaluator',
            meta: { project: 'workspace' }
        });
        const outPath = path.join(__dirname, 'what_next_output.json');
        fs.writeFileSync(outPath, JSON.stringify(result, null, 2), 'utf8');
        console.log('Saved output to:', outPath);
    } catch (e) {
        console.error('Error:', e);
    } finally {
        await bridge.disconnect();
        process.exit(0);
    }
}

run();
