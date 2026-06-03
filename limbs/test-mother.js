const MotherEngine = require('./mother-engine');
const fs = require('fs');
const path = require('path');

async function runTest() {
  console.log('Starting Mother Engine Simple Test...');
  const mother = new MotherEngine();

  try {
    const goal = 'Say hello to the user in Thai.';
    const results = await mother.executePhase('Greeting', goal);

    console.log('\n--- Test Results ---');
    console.log('Results received:', results.length, 'responses');

    const updatedLeaderboard = JSON.parse(fs.readFileSync(path.join(__dirname, '../network/leaderboard.json'), 'utf8'));
    console.log('Updated Leaderboard Snapshot:');
    console.table(updatedLeaderboard.fleet);

    console.log('\n✅ Mother Engine test passed!');
  } catch (e) {
    console.error('\n❌ Mother Engine test failed:');
    console.error(e);
    process.exit(1);
  }
}

runTest();
