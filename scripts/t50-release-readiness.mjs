import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const tasks=JSON.parse(fs.readFileSync(path.join(root,'docs/50-task-verification.json'),'utf8'));
const ids=Array.from({length:50},(_,i)=>'T'+String(i+1).padStart(2,'0'));
if(tasks.length!==50||tasks.some((t,i)=>t.id!==ids[i]||!t.title||!t.status||!t.evidence))
 throw Error('T50: invalid 50-task inventory; refused to issue readiness report');
const allowed=new Set(['tested_local','partial','blocked','not_started']);
if(tasks.some(t=>!allowed.has(t.status)))throw Error('T50: invalid evidence status');
const stats=Object.fromEntries([...allowed].map(x=>[x,tasks.filter(t=>t.status===x).length]));
const blocks=tasks.filter(t=>t.status==='blocked'||t.status==='partial').map(t=>t.id);
const issue={releaseReady:false,reason:'Not signed/hosted two-phone E2E/backup verified; no 30-day beta acceptance',stats,blockedOrPartial:blocks,project:'QYEM7/TotiChatpro'};
process.stdout.write(JSON.stringify(issue,null,2)+'\n');
if(process.argv.includes('--strict')){console.error('BLOCKED release: owner acceptance, real two-device E2E, signed AAB, backups, payment compliance and providers not verified');process.exitCode=1}
