<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C01 role=dev model=commandcode/deepseek/deepseek-v4-pro
 finish_reason: end_turn | tokens: {"prompt_tokens":199,"completion_tokens":3059,"total_tokens":3258} | 27s
 generated: 2026-06-12T19:29:04.398Z -->
#!/usr/bin/env node
// Claude Code SessionStart hook: loads bounded prior context (handoff, retrospectives, git) into session

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

const MAX_CHARS = parseInt(process.env.ECC_SESSION_START_MAX_CHARS || '8000', 10);

function findMostRecentFile(dir) {
  if (!fs.existsSync(dir)) return null;
  let best = null, bestTime = 0;
  try {
    for (const name of fs.readdirSync(dir)) {
      const fp = path.join(dir, name);
      try {
        const st = fs.statSync(fp);
        if (st.isFile() && st.mtimeMs > bestTime) { bestTime = st.mtimeMs; best = fp; }
      } catch {}
    }
  } catch {}
  return best;
}

function readFileHead(filePath, maxLen) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    if (content.length <= maxLen) return content;
    return content.slice(0, maxLen) + '\n…[truncated]';
  } catch { return null; }
}

function getLastCommitLine() {
  try {
    return execSync('git log -1 --oneline', {
      encoding: 'utf8', timeout: 5000, cwd: process.cwd(), stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
  } catch { return null; }
}

try {
  // Read hook JSON from stdin if available (Claude Code provides session info)
  let hookData = null;
  try {
    const raw = fs.readFileSync(0, 'utf8').trim(); // fd 0 = stdin
    if (raw) hookData = JSON.parse(raw);
  } catch { /* stdin unavailable or not JSON; proceed without */ }

  const cwd = (hookData && hookData.project_path) || process.cwd();
  const parts = [];
  let remaining = MAX_CHARS;

  // 1. Most recent handoff file
  const handoffDir = path.join(cwd, 'ψ', 'inbox', 'handoff');
  const latestHandoff = findMostRecentFile(handoffDir);
  if (latestHandoff && remaining > 40) {
    const text = readFileHead(latestHandoff, remaining - 30);
    if (text) {
      parts.push('## Recent Handoff (' + path.basename(latestHandoff) + ')\n' + text);
      remaining -= text.length + 30;
    }
  }

  // 2. Latest retrospective entry
  const retroDir = path.join(cwd, 'ψ', 'memory', 'retrospectives');
  const latestRetro = findMostRecentFile(retroDir);
  if (latestRetro && remaining > 60) {
    const text = readFileHead(latestRetro, remaining - 30);
    if (text) {
      parts.push('## Recent Retrospective (' + path.basename(latestRetro) + ')\n' + text);
      remaining -= text.length + 30;
    }
  }

  // 3. Git last-commit line
  if (remaining > 60) {
    const commitLine = getLastCommitLine();
    if (commitLine) {
      parts.push('## Last Commit\n' + commitLine);
      remaining -= commitLine.length + 18;
    }
  }

  if (parts.length > 0) {
    const header = '── Session Context ──\n';
    const footer = '\n── End Context ──';
    const output = header + parts.join('\n\n') + footer;
    process.stdout.write(output.slice(0, MAX_CHARS));
  }
  // If nothing found, output nothing (empty success)
} catch {
  // Fail-safe: never throw, empty output on any error
}
