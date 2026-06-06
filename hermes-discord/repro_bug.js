const tools = require('./chrome-tools');

async function run() {
  try {
    const script = 'Array.from(document.fonts.list()).map(f => f.family)';
    const result = await new Promise((resolve, reject) => {
      tools.runJS('http://localhost:3000', script, (err, res) => err ? reject(err) : resolve(res));
    });
    console.log('Loaded Fonts:', JSON.stringify(result.result, null, 2));
  } catch (e) {
    console.error('Error:', e);
  }
}

run();
