const spawner = require('./hermes-discord/agent-spawner');

// Spawn 12 agent-commandcode instances to work on skill development
const tasks = [];
for (let i = 1; i <= 12; i++) {
  tasks.push({
    agent: 'agent-commandcode',
    message: `พัฒนาทักษะใหม่สำหรับระบบ Jit Oracle โดยมุ่งเน้นไปที่การสร้างทักษะที่เกี่ยวข้องกับการพัฒนา skills ทักษะที่  ${i} ของ 12 ทักษะ รวมถึงการสร้าง SKILL.md พร้อม frontmatter ที่เหมาะสม และตัวอย่างการใช้งาน`
  });
}

console.log('Spawning 12 agent-commandcode instances for skill development...');
spawner.spawnAgentParallel(tasks).then(results => {
  console.log('Results:');
  results.forEach((result, index) => {
    console.log(`Agent ${index + 1}:`);
    console.log(`  Backend: ${result.backend}`);
    console.log(`  Reply: ${result.reply.substring(0, 100)}...`);
    console.log('');
  });
}).catch(error => {
  console.error('Error:', error);
});