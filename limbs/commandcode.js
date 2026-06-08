const fs = require('fs');
const path = require('path');

// ── Load .env if not already loaded ───────────────────────────────────
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}

// ── Delegate to model-router for circuit breaker, rotation, and consistency ──
// Previously: used axios directly, duplicating _callCommandCode in model-router.js.
// Now: routes through callModelPromise so callers get circuit breaker, backend
// rotation on failure, and consistent error/auth handling.
const SIM_DIR = path.join(process.cwd(), 'ψ', 'simulation', 'dev_outputs');
let _modelRouter = null;
function _getModelRouter() {
  if (!_modelRouter) _modelRouter = require('../hermes-discord/model-router');
  return _modelRouter;
}

/**
 * callCommandCode(model, prompt, format)
 *   Routes through model-router's callModelPromise for the 'commandcode' backend.
 *   Gains: circuit breaker, backend rotation on failure, consistent error handling.
 *
 *   model:  model string (e.g. 'deepseek/deepseek-v4-flash', 'claude-3-5-sonnet')
 *   prompt: user prompt string (auto-wrapped into messages array)
 *   format: 'openai' (default) or 'anthropic' — selects /chat/completions vs /messages
 *           Note: model-router auto-detects Anthropic models by /^claude/i prefix,
 *           so format is now informational; the router handles routing internally.
 */
async function callCommandCode(model, prompt, format = 'openai') {
    const router = _getModelRouter();
    const messages = [{ role: 'user', content: prompt }];

    try {
        const result = await router.callModelPromise(messages, {
            preferBackend: 'commandcode',
            noRotate: false,   // allow rotation to other backends on failure
            model: model,
            maxTokens: format === 'anthropic' ? 4096 : 512,
        });
        return result.reply;
    } catch (e) {
        // Fallback: simulation directory (only if psi/simulation/dev_outputs exists)
        console.log(`[CommandCode] API Fail: ${e.message}. Falling back to Simulation...`);
        try {
            if (fs.existsSync(SIM_DIR)) {
                const files = fs.readdirSync(SIM_DIR);
                if (files.length > 0) {
                    const randomFile = files[Math.floor(Math.random() * files.length)];
                    const data = JSON.parse(fs.readFileSync(path.join(SIM_DIR, randomFile), 'utf8'));
                    return `[SIMULATED BY ${model}] ${data.result}\n(Tokens burned: ${data.tokens_burned}) | Dev Note: ${data.dev_note}`;
                }
            }
        } catch (simErr) {
            // Simulation fallback failed too
        }
        throw new Error(`CommandCode unavailable (all backends exhausted): ${e.message}`);
    }
}

module.exports = { callCommandCode };