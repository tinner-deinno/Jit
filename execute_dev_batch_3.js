require('dotenv').config();
const { callCommandCode } = require('./limbs/commandcode');
const fs = require('fs');

const TICKETS = [
    { id: 'TICKET-011', model: 'MiniMaxAI/MiniMax-M3', format: 'openai', prompt: 'Complete the final integration of the Thai-Syllable-Splitter into the innomcp core routing logic. Ensure no regressions.' },
    { id: 'TICKET-012', model: 'gpt-5.5', format: 'openai', prompt: 'Fix the infinite spinner issue in src/jit-dashboard.html. Ensure the loading state resolves once the task is complete.' },
    { id: 'TICKET-013', model: 'deepseek/deepseek-v4-pro', format: 'openai', prompt: 'Run full regression tests on the 20 Thai routing edge cases. Verify 100% determinism.' },
    { id: 'TICKET-014', model: 'Qwen/Qwen3.7-Max', format: 'openai', prompt: 'Audit the current token consumption of the Thai Routing flow and propose an optimization strategy.' },
    { id: 'TICKET-015', model: 'claude-opus-4-8', format: 'openai', prompt: 'Write a technical specification for the Thai-Syllable-Splitter and persist it to the Oracle Knowledge Base.' },
];

async function run() {
    const results = [];
    for (const t of TICKETS) {
        console.log(`Executing ${t.id} with ${t.model}...`);
        const res = await callCommandCode(t.model, t.prompt, t.format);
        results.push({ id: t.id, result: res });
    }
    fs.writeFileSync('TICKET_RESULTS_B3.md', results.map(r => `## ${r.id}\n${r.result}\n---`).join('\n'));
    console.log('Batch 3 complete. Real results in TICKET_RESULTS_B3.md');
}
run().catch(console.error);
