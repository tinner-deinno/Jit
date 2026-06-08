const { callCommandCode } = require('../limbs/commandcode');
async function test() {
  console.log('Testing CommandCode Bridge...');
  try {
    const reply = await callCommandCode('deepseek/deepseek-v4-flash', 'Reply with: BRIDGE_OK');
    console.log('Reply:', reply);
    if (reply.includes('BRIDGE_OK')) {
      console.log('RESULT: SUCCESS');
      process.exit(0);
    } else {
      console.log('RESULT: FAILURE (unexpected reply)');
      process.exit(1);
    }
  } catch (e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
}
test();
