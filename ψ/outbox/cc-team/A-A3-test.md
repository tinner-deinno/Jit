<!-- cc-team deliverable
 group: A (TICKET-002: Thai Knowledge Routing Audit — produce test corpus, harness, and hardening proposals)
 member: A3 role=test model=deepseek/deepseek-v4-flash
 finish_reason: stop | tokens: {"prompt_tokens":159,"completion_tokens":3253,"total_tokens":3412,"prompt_tokens_details":{"cached_tokens":0,"audio_tokens":0,"video_tokens":0},"completion_tokens_details":{"reasoning_tokens":2697,"image_tokens":0},"cache_creation_input_tokens":0} | 33s
 generated: 2026-06-10T19:20:33.802Z -->
```javascript
import { describe, test } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Import the routing function
// Expected signature: routeLane(prompt: string) => string (routing key)
import { routeLane } from '../limbs/route-lane.js';

// Resolve path to the corpus file (same directory as this test)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const corpusPath = path.join(__dirname, 'thai-routing-prompts.json');

let corpus;
try {
  corpus = JSON.parse(fs.readFileSync(corpusPath, 'utf-8'));
} catch (err) {
  console.error(`Failed to load corpus from ${corpusPath}:`, err.message);
  process.exit(1);
}

test('Thai Routing Audit', () => {
  const tableRows = [];

  for (const promptObj of corpus) {
    const { id, prompt } = promptObj;
    let pass = true;
    let errorMsg = '';

    try {
      // Determinism: call routeLane 5 times and assert all identical
      const results = [];
      for (let i = 0; i < 5; i++) {
        results.push(routeLane(prompt));
      }

      for (let i = 1; i < results.length; i++) {
        assert.strictEqual(
          results[i],
          results[0],
          `Determinism failure for prompt ${id}: call 0 returned "${results[0]}", call ${i} returned "${results[i]}"`
        );
      }

      // Non‑empty routing key
      const key = results[0];
      assert.ok(
        typeof key === 'string' && key.length > 0,
        `Routing key for prompt ${id} is empty or not a string (got: ${JSON.stringify(key)})`
      );
    } catch (err) {
      pass = false;
      errorMsg = err.message;
    }

    tableRows.push({ id, pass: pass ? 'PASS' : 'FAIL', error: errorMsg });
  }

  // Print summary table
  console.table(tableRows);

  // Fail the test if any prompt failed
  const failures = tableRows.filter(r => r.pass === 'FAIL');
  if (failures.length > 0) {
    throw new Error(`${failures.length} prompt(s) failed the routing audit`);
  }
});
```
