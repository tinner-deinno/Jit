'use strict';
// proxy-gen.cjs <model> <outfile> — reads prompt from stdin, calls local proxy :4322,
// writes ONLY the message content to outfile. Strips accidental ``` fences.
const fs = require('fs');
const model = process.argv[2];
const outfile = process.argv[3];
const prompt = fs.readFileSync(0, 'utf8');

fetch('http://127.0.0.1:4322/v1/chat/completions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ model, max_tokens: 3500, temperature: 0.1, messages: [{ role: 'user', content: prompt }] }),
  signal: AbortSignal.timeout(180000),
})
  .then(r => r.json())
  .then(d => {
    let c = (d.choices && d.choices[0] && d.choices[0].message && d.choices[0].message.content) || '';
    // strip leading/trailing ``` fence lines if a whole-doc fence slipped in
    c = c.replace(/^\s*```[a-zA-Z]*\s*\n/, '').replace(/\n```\s*$/, '');
    fs.writeFileSync(outfile, c);
    process.stderr.write('finish=' + (d.choices && d.choices[0] && d.choices[0].finish_reason) + ' chars=' + c.length + ' tokens=' + (d.usage && d.usage.total_tokens) + '\n');
  })
  .catch(e => { process.stderr.write('ERR ' + e.message + '\n'); process.exit(1); });
