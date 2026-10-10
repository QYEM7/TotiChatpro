/* T06/T29/T30 true parallel Owner cash-issuance integration test.
 * ONLY disposable local Supabase with temporary GoTrue accounts and local Docker PostgreSQL.
 * Never executes against production, never reports real cash receipt, never builds APK.
 */
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';

const die=s=>{throw Error('T06 parallel finance QA: '+s)};
if(process.env.T06_DISPOSABLE_ONLY!=='YES')die('explicit disposable-only flag required');
if(['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST','PGPORT','PGUSER','PGPASSWORD'].some(k=>process.env[k]))
 die('refusing linked/remote Postgres credentials');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'));}catch{die('local Supabase status JSON missing')}
let origin;try{origin=new URL(String(cfg.API_URL||''));}catch{die('invalid Supabase URL')}
if(origin.protocol!=='http:'||!['localhost','127.0.0.1'].includes(origin.hostname)||
 origin.username||origin.password||origin.pathname!=='/'||origin.search||origin.hash)
 die('refusing non-loopback API');
const anon=String(cfg.ANON_KEY||'');
if(!anon.startsWith('eyJ'))die('missing local anon JWT');
const runDocker=(args,options={})=>{
 const r=spawnSync('docker',args,{encoding:'utf8',timeout:10000,...options});
 if(r.error||r.status!==0)die('disposable Docker PostgreSQL access failed; exit '+r.status);
 return r.stdout;
};
const containers=runDocker(['ps','--format','{{.Names}}']).trim().split('\n')
 .filter(x=>/^supabase_db_[a-zA-Z0-9_-]+$/.test(x));
if(containers.length!==1)die('exactly one unlinked local Supabase Postgres container is required');
const db=containers[0];
async function rpc(path,{jwt=anon,body={}}={}){
 if(!path.startsWith('/'))die('unexpected outbound route');
 const response=await fetch(new URL(path,origin.origin),{
  method:'POST',
  headers:{apikey:anon,Authorization:'Bearer '+jwt,'Content-Type':'application/json'},
  body:JSON.stringify(body),signal:AbortSignal.timeout(45000),cache:'no-store'});
 const content=await response.text();
 let value=null;try{value=JSON.parse(content)}catch{}
 return {status:response.status,value};
}
const err=r=>String(r.value?.message||r.value?.error_description||r.value?.error||'');
const good=(r,what)=>{
 if(r.status<200||r.status>=300)die(what+' HTTP '+r.status+' '+err(r).slice(0,140));
 return r.value;
};
const nonce=randomBytes(9).toString('hex'),accounts=[];
for(let i=0;i<2;i++){
 const data=good(await rpc('/auth/v1/signup',{body:{
  email:'t06-treasury-'+nonce+'-'+i+'@example.test',
  password:randomBytes(32).toString('base64url')
 }}),'local signup');
 if(!data?.access_token||!/^[0-9a-f-]{36}$/i.test(data.user?.id||''))
  die('genuine local GoTrue session missing');
 accounts.push({id:data.user.id,jwt:data.access_token});
}
const [owner,outsider]=accounts;
// Set the project's unique Owner only inside disposable LOCAL PostgreSQL.
// UUID is generated/returned by real local GoTrue and validated; no production link.
runDocker(['exec','-i',db,'psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres'],{
 input:`update phase3.system_authority set owner_id='${owner.id}'::uuid,main_partner_id=null where singleton;\n`
});
const state=who=>rpc('/rest/v1/rpc/phase4_recharge_state',{jwt:who.jwt});
const action=(who,key,coins,ref)=>rpc('/rest/v1/rpc/phase4_recharge_action',{jwt:who.jwt,body:{
 p_action:'issue',
 p_data:{coins,note:'Disposable QA simulated cash issuance; not an actual payment',cash_reference:ref},
 p_request_id:key
}});
const initial=good(await state(owner),'Owner treasury state');
if(initial.isOwner!==true)die('local Owner role elevation failed');
const beforeTreasury=BigInt(initial.treasury),beforeIssued=BigInt(initial.issued);
const unauthorized=await action(outsider,randomUUID(),3,'T06-UNAUTHORIZED-'+nonce);
if(unauthorized.status>=200&&unauthorized.status<300)
 die('ordinary user issued Owner coins');
// One Owner key sent SIX times in parallel: exactly one accounting operation.
const firstKey=randomUUID(),firstRef='T06-ONE-'+nonce;
const first=await Promise.all(Array.from({length:6},()=>action(owner,firstKey,11,firstRef)));
if(first.some(r=>r.status<200||r.status>=300))die('same-key parallel issuance was rejected: '+first.map(r=>r.status).join(','));
const firstId=first[0].value?.id;
if(!firstId||first.some(r=>r.value?.id!==firstId))
 die('same-key issuance was not stable/idempotent');
// Same cash receipt reference but DIFFERENT idempotency keys must not mint 4x.
const secondRef='T06-REF-'+nonce;
const receiptRace=await Promise.all(Array.from({length:4},
 ()=>action(owner,randomUUID(),7,secondRef)));
const receiptGood=receiptRace.filter(r=>r.status>=200&&r.status<300);
const receiptBad=receiptRace.filter(r=>r.status<200||r.status>=300);
if(receiptGood.length!==1||receiptBad.length!==3||
 receiptBad.some(r=>!err(r).includes('Cash issuance reference already used')))
 die('concurrent repeated cash reference minted twice or returned unexpected failure');
// 28 distinct, concurrent receipt operations -> total of 30 successful action rows.
const tasks=Array.from({length:28},(_,i)=>({
 key:randomUUID(),ref:'T06-LOAD-'+nonce+'-'+String(i)
}));
const outcomes=await Promise.all(tasks.map(x=>action(owner,x.key,1,x.ref)));
if(outcomes.some(r=>r.status<200||r.status>=300))
 die('29th/30th within per-actor quota failed: '+outcomes.map(r=>r.status).join(','));
const after=good(await state(owner),'Owner final treasury state');
const deltaTreasury=BigInt(after.treasury)-beforeTreasury;
const deltaIssued=BigInt(after.issued)-beforeIssued;
if(deltaTreasury!==46n||deltaIssued!==46n)
 die('COIN INFLATION / loss: expected 46 issued and funded, saw '+deltaIssued+'/'+deltaTreasury);
const ledger=after.ledger;
if(!Array.isArray(ledger)||ledger.length<30)
 die('at least 30 durable treasury ledger entries expected');
const ids=new Set(ledger.slice(0,30).map(x=>x.operation_id));
if(ids.size!==30||ledger.slice(0,30).reduce((v,x)=>v+BigInt(x.amount),0n)!==46n)
 die('treasury ledger operations duplicate or fail to conserve 46 coins');
const over=await action(owner,randomUUID(),1,'T06-OVER-'+nonce);
if(over.status>=200&&over.status<300||!err(over).includes('Rate limit exceeded'))
 die('31st new issuance escaped 30/min rate limit');
const same=good(await action(owner,firstKey,11,firstRef),'same-key after quota');
if(same.id!==firstId)die('Owner replay did not keep its operation ID');
const clash=await action(owner,firstKey,12,firstRef);
if(clash.status>=200&&clash.status<300||!err(clash).includes('Idempotency key conflict'))
 die('same idempotency key with changed coins was not rejected');
const unchanged=good(await state(owner),'Owner state after rejected operations');
if(BigInt(unchanged.treasury)!==BigInt(after.treasury)||
 BigInt(unchanged.issued)!==BigInt(after.issued))
 die('replay/rejections changed issued coins');
console.log('PASS T06/T29: six parallel identical Owner issue requests committed ONE operation; same-key retry after quota preserved idempotency.');
console.log('PASS T06/T29: four parallel distinct-key attempts with ONE cash reference minted exactly once; three collisions denied.');
console.log('PASS T06/T29: 28 other parallel cash references completed 30 unique operations; 46 fake coins balanced in treasury and issuance ledger.');
console.log('PASS T06/T29: 31st new issue denied, changed same-key payload denied, regular user denied Owner issuance.');
console.log('PASS T06/T29: actual local GoTrue/PostgREST/PostgreSQL test only; NEVER real cash, production wallets or external top-ups.');
