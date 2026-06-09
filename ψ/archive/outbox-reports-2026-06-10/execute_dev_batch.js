require('dotenv').config();
const { callCommandCode } = require('./limbs/commandcode');

const TICKETS = [
    { id: 'TICKET-001', model: 'claude-3-5-sonnet', format: 'anthropic', prompt: 'Audit the current innomcp routing logic for Thai Knowledge Routing. Find potential failure points.' },
    { id: 'TICKET-002', model: 'deepseek-v3', format: 'openai', prompt: 'Analyze and propose a deterministic routing strategy for Thai Knowledge in innomcp.' },
    { id: 'TICKET-003', model: 'gpt-4o', format: 'openai', prompt: 'Generate 20 difficult Thai language test cases (edge cases) for testing knowledge routing.' },
    { id: 'TICKET-004', model: 'gpt-4o', format: 'openai', prompt: 'Design a baseline test suite for Thai routing in innomcp. How should it be run?' },
    { id: 'TICKET-005', model: 'gpt-4o', format: 'openai', prompt: 'Create a comparison matrix between the current innomcp routing and a gold-standard LLM response.' },
];

async function run() {
    const results = [];
    for (const t of TICKETS) {
        console.log(`Executing ${t.id}...`);
        const res = await callCommandCode(t.model, t.prompt, t.format);
        results.push({ id: t.id, result: res });
    }
    fs.writeFileSync('TICKET_RESULTS.md', results.map(r => `## ${r.id}\n${r.result}\n---`).join('\n'));
    console.log('Batch complete. Results in TICKET_RESULTS.md');
}

const fs = require('fs');
run().catch(console.error);
