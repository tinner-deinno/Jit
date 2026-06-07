const axios = require('axios');
const fs = require('fs');
const path = require('path');

const API_KEY = process.env.CODEX_API_KEY || 'dummy';
const OPENAI_ENDPOINT = 'https://api.commandcode.ai/provider/v1/chat/completions';
const ANTHROPIC_ENDPOINT = 'https://api.commandcode.ai/provider/v1/messages';
const SIM_DIR = path.join(process.cwd(), 'ψ', 'simulation', 'dev_outputs');

async function callCommandCode(model, prompt, format = 'openai') {
    console.log(`[CommandCode] Calling model: ${model}...`);
    const endpoint = format === 'anthropic' ? ANTHROPIC_ENDPOINT : OPENAI_ENDPOINT;

    const payload = format === 'anthropic'
        ? { model: model, max_tokens: 4096, messages: [{ role: 'user', content: prompt }] }
        : { model: model, messages: [{ role: 'user', content: prompt }] };

    try {
        const response = await axios.post(endpoint, payload, {
            headers: { 'Authorization': `Bearer ${API_KEY}`, 'Content-Type': 'application/json' }
        });

        if (format === 'anthropic') {
            return response.data.content[0].text;
        } else {
            return response.data.choices[0].message.content;
        }
    } catch (e) {
        console.log(`[CommandCode] API Fail: ${e.message}. Falling back to Simulation...`);

        const files = fs.readdirSync(SIM_DIR);
        if (files.length === 0) return `Error: No simulation data available.`;

        const randomFile = files[Math.floor(Math.random() * files.length)];
        const data = JSON.parse(fs.readFileSync(path.join(SIM_DIR, randomFile), 'utf8'));

        return `[SIMULATED BY ${model}] ${data.result}\n(Tokens burned: ${data.tokens_burned}) | Dev Note: ${data.dev_note}`;
    }
}

module.exports = { callCommandCode };
