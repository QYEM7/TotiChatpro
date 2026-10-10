/* T06/T42: REAL concurrent HTTP requests through disposable Supabase Auth/PostgREST.
 * Strict localhost only. Tests per-actor atomic quota/idempotency and IDOR denial.
 * Uses real temporary GoTrue users; no production tokens, balances or logs.
 */
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
const stop=message=>{throw Error('T06 parallel local HTTP QA: '+message)};
if(process.env.T06_DISPOSABLE_ONLY!=='YES')stop('explicit T06_DISPOSABLE_ONLY flag required');
if(['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST'].some(k=>process.env[k]))
 stop('production/linked database credentials forbidden');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'));}catch{stop('no local Supabase status file');}
let root;try{root=new URL(String(cfg.API_URL||''));}catch{stop('local Supabase URL missing');}
if(root.protocol!=='http:'||!['localhost','127.0.0.1'].includes(root.hostname)||
 root.username||root.password||root.pathname!=='/'||root.search||root.hash)
 stop('ONLY unlinked loopback Supabase is supported');
const anon=String(cfg.ANON_KEY||'');
if(!anon.startsWith('eyJ'))stop('local anon JWT missing');
async function request(path,{jwt=anon,body,method='POST'}={}){
 if(!path.startsWith('/'))stop('relative endpoint required');
 const response=await fetch(new URL(path,root.origin),{method,
  headers:{apikey:anon,Authorization:'Bearer '+jwt,'Content-Type':'application/json'},
  ...(body===undefined?{}:{body:JSON.stringify(body)}),
  signal:AbortSignal.timeout(45000),cache:'no-store'});
 const content=await response.text();
 let value=null;try{value=JSON.parse(content);}catch{}
 return {status:response.status,value};
}
function ok(result,label){
 if(result.status<200||result.status>=300)
   stop(label+' failed HTTP '+result.status+' '+String(result.value?.message||result.value?.error||'').slice(0,110));
 return result.value;
}
function msg(r){return String(r.value?.message||r.value?.error_description||r.value?.error||'');}
const prefix=randomBytes(8).toString('hex'),users=[];
for(let i=0;i<2;i++){
 const answer=ok(await request('/auth/v1/signup',{body:{
  email:'t06-parallel-'+prefix+'-'+i+'@example.test',
  password:randomBytes(30).toString('base64url')
 }}),'real disposable signup');
 if(!answer?.user?.id||!answer?.access_token)stop('local GoTrue did not produce a real session');
 users.push({id:answer.user.id,jwt:answer.access_token});
}
const [user,other]=users;
const endpoint='/rest/v1/rpc/phase5_support_action';
const act=(who,operation,data,key)=>request(endpoint,{jwt:who.jwt,body:{
 p_action:operation,p_data:data,p_request_id:key
}});
const initialKey=randomUUID();
const initialData={category:'technical',subject:'T06 parallel HTTP rehearsal',message:'Temporary isolated QA request'};
const submissions=await Promise.all(Array.from({length:6},
 ()=>act(user,'create',initialData,initialKey)));
if(submissions.some(r=>r.status!==200))stop('concurrent same-idempotency-key create failed: '+submissions.map(x=>x.status).join(','));
const ticket=submissions[0].value?.id;
if(!ticket||submissions.some(r=>r.value?.id!==ticket))
 stop('parallel identical create generated multiple tickets');
const ticketPage=who=>request('/rest/v1/rpc/phase5_support_thread_page',{
 jwt:who.jwt,body:{p_ticket_id:ticket,p_offset:0,p_limit:50}});
let thread=ok(await ticketPage(user),'creator first thread');
if(thread.total!==1||thread.messages?.length!==1)
 stop('identical create generated duplicate messages');
const outsider=await ticketPage(other);
if(outsider.status>=200&&outsider.status<300)
 stop('cross-user thread IDOR accepted');
const outsiderReply=await act(other,'reply',{ticket_id:ticket,message:'Forbidden cross-account answer'},randomUUID());
if(outsiderReply.status>=200&&outsiderReply.status<300)
 stop('outsider replied to someone else\'s support thread');
const ownerRole=await act(user,'staff_grant',{user_id:other.id},randomUUID());
if(ownerRole.status>=200&&ownerRole.status<300)
 stop('ordinary customer granted staff access');
// Customer role denial and cross-account denials must not consume the quota.
const batches=Array.from({length:28},(_,i)=>({
 key:randomUUID(),
 data:{ticket_id:ticket,message:'Concurrent support load '+String(i+1)}
}));
const results=await Promise.all(batches.map(x=>act(user,'reply',x.data,x.key)));
const accepted=results.map((r,i)=>({r,i})).filter(x=>x.r.status>=200&&x.r.status<300);
const denied=results.filter(r=>r.status<200||r.status>=300);
if(accepted.length!==19||denied.length!==9)
 stop('quota race: 19 concurrent replies expected; accepted '+accepted.length+', rejected '+denied.length+
  '; rejected HTTP statuses '+denied.map(r=>r.status).join(','));
if(denied.some(r=>!msg(r).includes('Support rate limit exceeded')))
 stop('unexpected concurrent HTTP failure instead of server quota');
thread=ok(await ticketPage(user),'creator after simultaneous replies');
if(thread.total!==20||thread.messages?.length!==20)
 stop('support thread must have exactly 20 messages, observed total '+thread.total);
const first=accepted[0];
if(!first)stop('no successful concurrent mutation to replay');
const cached=ok(await act(user,'reply',batches[first.i].data,batches[first.i].key),'retry past quota');
if(cached.id!==ticket)
 stop('idempotent replay after quota was not accepted');
const clash=await act(user,'reply',{ticket_id:ticket,message:'changed idempotency content'},batches[first.i].key);
if(clash.status>=200&&clash.status<300||!msg(clash).includes('Idempotency key conflict'))
 stop('different payload with same idempotency key was not refused');
const over=await act(user,'reply',{ticket_id:ticket,message:'post-limit new request'},randomUUID());
if(over.status>=200&&over.status<300||!msg(over).includes('Support rate limit exceeded'))
 stop('post-limit new support mutation escaped rate budget');
thread=ok(await ticketPage(user),'final read-only message query');
if(thread.total!==20)stop('replay or denied actions mutated support messages');
// Ensure a completely separate verified actor has their OWN budget; one saturated
// customer must never block creation for another account.
const otherKey=randomUUID();
const otherPayload={category:'technical',subject:'Independent actor budget check',
 message:'Second account verifies separate user rate budget'};
const otherCreated=ok(await act(other,'create',otherPayload,otherKey),'unrelated actor action after quota');
if(!otherCreated?.id||otherCreated.id===ticket)
 stop('second account ticket creation was not independent');
const otherThread=ok(await request('/rest/v1/rpc/phase5_support_thread_page',{
 jwt:other.jwt,body:{p_ticket_id:otherCreated.id,p_offset:0,p_limit:20}
}),'other actor independently owned thread');
if(otherThread.total!==1||otherThread.ticket?.creator_id!==other.id)
 stop('second actor thread owner mismatch');
const firstByOther=await ticketPage(other);
if(firstByOther.status>=200&&firstByOther.status<300)
 stop('independent rate limit did not preserve first actor private ticket');
console.log('PASS T06: a second GoTrue user retained a separate quota after first user hit the 20/min ceiling; ticket privacy preserved.');
console.log('PASS T06: genuine disposable GoTrue users + PostgREST; six parallel identical create requests committed ONE ticket, ONE first message.');
console.log('PASS T06: 28 concurrent replies => 19 accepted and 9 bounded denials; total 20 messages; replay after limit retained same ticket.');
console.log('PASS T06: outsider thread/reply denied, staff privilege escalation denied, conflicting idempotency key denied.');
console.log('PASS T06: all checks LOCAL and temporary; no actual production concurrency or finance wallet stress is claimed.');
