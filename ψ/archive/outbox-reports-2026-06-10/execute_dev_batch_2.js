require('dotenv').config();
const { callCommandCode } = require('./limbs/commandcode');
const fs = require('fs');

const TICKETS = [
    { id: 'TICKET-006', model: 'gpt-4o', format: 'openai', prompt: 'Implement the Thai-Syllable-Splitter prototype.' },
    { id: 'TICKET-007', model: 'claude-3-5-sonnet', format: 'anthropic', prompt: 'Refactor the routing logic to use the new syllable-splitter.' },
    { id: 'TICKET-008', model: 'deepseek-v3', format: 'openai', prompt: 'Integrate the splitter with thaiKnowledgeTool.' },
    { id: 'TICKET-009', model: 'gpt-4o', format: 'openai', prompt: 'Run the regression tests on the 20 edge cases.' },
    { id: 'TICKET-010', model: 'gpt-4o', format: 'openai', prompt: 'Perform a performance audit on token usage.' },
];

async function run() {
    const results = [];
    for (const t of TICKETS) {
        console.log(`Executing ${t.id}...`);
        const res = await callCommandCode(t.model, t.prompt, t.format);
        results.push({ id: t.id, result: res });
    }
    fs.writeFileSync('TICKET_RESULTS_B2.md', results.map(r => `## ${r.id}\n${r.result}\n---`).join('\n'));
    console.log('Batch 2 complete. Results in TICKET_RESULTS_B2.md');
}
run().catch(console.error);
