const fs = require('fs');
const path = require('path');

const reportPath = path.join(__dirname, 'swarm_audit_report.md');
const outputPath = path.join(__dirname, 'clean_audit_findings.md');

if (!fs.existsSync(reportPath)) {
  console.error('Audit report not found');
  process.exit(1);
}

const content = fs.readFileSync(reportPath, 'utf8');
const lines = content.split('\n');

let cleanReport = '# Cleaned Swarm Audit Findings\n\n';
let currentFile = '';
let inFindings = false;
let findingsContent = [];

for (const line of lines) {
  if (line.startsWith('## File:')) {
    if (currentFile && findingsContent.length > 0) {
      cleanReport += `## File: ${currentFile}\n\n${findingsContent.join('\n')}\n\n---\n\n`;
    }
    currentFile = line.replace('## File:', '').trim();
    inFindings = false;
    findingsContent = [];
  } else if (line.startsWith('### Synthesized Findings (QE Evaluator)')) {
    inFindings = true;
  } else if (line.startsWith('### Detailed Specialist Agent Audits')) {
    inFindings = false;
  } else if (inFindings) {
    findingsContent.push(line);
  }
}

if (currentFile && findingsContent.length > 0) {
  cleanReport += `## File: ${currentFile}\n\n${findingsContent.join('\n')}\n\n---\n\n`;
}

fs.writeFileSync(outputPath, cleanReport, 'utf8');
console.log(`Cleaned report saved to: ${outputPath}`);
