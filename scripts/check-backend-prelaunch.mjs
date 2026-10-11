// Evidence-backed backend go/no-go check. No remote credentials or writes.
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const path=fileURLToPath(new URL('../docs/BACKEND_PRELAUNCH_ACCEPTANCE_2026-10-11.json',import.meta.url));
export function auditGate(m){
 const errors=[],pending=[],ids=new Set();
 if(m?.branch!=='develop/phase-2'||m?.staging_project!=='rziaedugbdwefbefcxjt')
  errors.push('Wrong project scope');
 if(!Array.isArray(m?.gates)||m.gates.length<20)errors.push('Missing acceptance checks');
 for(const g of m.gates||[]){
  if(!g.id||ids.has(g.id))errors.push('Duplicate or invalid gate');
  ids.add(g.id);
  if(g.passed!==true){pending.push(g.id);continue}
  let valid=false;
  try{const u=new URL(g.evidence);valid=u.protocol==='https:'&&!!u.hostname&&!u.username&&!u.password}catch{}
  if(!valid)errors.push('Passed check without verified link: '+g.id);
 }
 if(m.release_allowed===true){
  if(pending.length)errors.push('Release prohibited while checks are open');
  if(!m.reviewer||!m.reviewer_approved_at)errors.push('Independent approval missing');
 }
 return {valid:errors.length===0,release_allowed:m.release_allowed===true&&pending.length===0&&errors.length===0,
  passed:(m.gates||[]).length-pending.length,blocked:pending,errors};
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const a=auditGate(JSON.parse(readFileSync(path,'utf8')));
 console.log(JSON.stringify(a,null,2));
 if(!a.valid||process.argv.includes('--require-release')&&!a.release_allowed||
 process.argv.includes('--expect-blocked')&&a.release_allowed)process.exitCode=1;
}
