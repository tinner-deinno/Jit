<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: C04 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":206,"completion_tokens":1367,"total_tokens":1573} | 16s
 generated: 2026-06-12T19:33:27.741Z -->
#!/usr/bin/env node
// Claude Code PreToolUse hook: blocks edits to protected config files (Edit/Write tools)
const f=require('fs'),p=require('path');
const raw=f.readFileSync(0,'utf8').trim();
if(!raw)process.exit(0);
let ev;
try{ev=JSON.parse(raw)}catch{process.exit(0)}
const tool=ev.tool, inp=ev.input||ev.params||{};
if(tool!=='Edit'&&tool!=='Write')process.exit(0);
const fp=inp.filePath||inp.file_path||inp.target;
if(!fp)process.exit(0);
const base=p.basename(fp);
const patterns=['.eslintrc*','.prettierrc*','tsconfig.json','.gitleaks.toml','.gitignore','eslint.config.*','commitlint.config.*'];
const match=(pat,b)=>new RegExp('^'+pat.replace(/[.+^${}()|[\]\\]/g,'\\$&').replace(/\*/g,'.*')+'$').test(b);
if(process.env.ECC_CONFIG_PROTECTION==='off')process.exit(0);
if(patterns.some(pat=>match(pat,base))){
  process.stderr.write(`Protected config file detected: ${fp}\nSet ECC_CONFIG_PROTECTION=off to override, or ask a human to fix code instead.\n`);
  process.exit(2);
}
process.exit(0);
