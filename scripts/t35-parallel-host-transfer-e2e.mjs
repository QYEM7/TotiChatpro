/* T06/T35 - disposable local Supabase AUTH+PostgREST concurrency tests for host agencies.
 * Never uses a production account, branch, finance balance or APK builder.
 */
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const die=m=>{throw Error('T35 local concurrency test: '+m)};
if(process.env.T35_DISPOSABLE_ONLY!=='YES'||
 ['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST','PGPORT','PGUSER','PGPASSWORD'].some(k=>process.env[k]))die('local-only credentials firewall');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{die('local Supabase status JSON missing')}
let url;try{url=new URL(cfg.API_URL)}catch{die('invalid local API URL')}
if(url.protocol!=='http:'||!['localhost','127.0.0.1'].includes(url.hostname)||
 url.username||url.password||url.pathname!=='/'||url.search||url.hash)die('non-loopback API forbidden');
const anon=String(cfg.ANON_KEY||'');if(!anon.startsWith('eyJ'))die('local JWT missing');
const run=(args,input)=>{
 const r=spawnSync('docker',args,{input,encoding:'utf8',timeout:15000});
 if(r.error||r.status!==0)die('disposable docker SQL failed: '+r.status);
 return r.stdout.trim();
};
const containers=run(['ps','--format','{{.Names}}']).split('\n').filter(n=>/^supabase_db_[a-zA-Z0-9_-]+$/.test(n));
if(containers.length!==1)die('expected exactly one local PostgreSQL container');
const sql=q=>run(['exec','-i',containers[0],'psql','-X','-At','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres'],q+'\n');
async function post(path,jwt,body){
 const r=await fetch(new URL(path,url.origin),{method:'POST',
  headers:{apikey:anon,Authorization:'Bearer '+jwt,'Content-Type':'application/json'},
  body:JSON.stringify(body),signal:AbortSignal.timeout(45000),cache:'no-store'});
 const t=await r.text();let data;try{data=JSON.parse(t)}catch{data=null}
 return {status:r.status,data};
}
const message=r=>String(r.data?.message||r.data?.error||r.data?.error_description||'');
const ok=(r,where)=>{
 if(r.status<200||r.status>=300)die(where+' HTTP '+r.status+': '+message(r).slice(0,110));
 return r.data;
};
const nonce=randomBytes(8).toString('hex'),accounts=[];
for(let n=0;n<5;n++){
 const s=ok(await post('/auth/v1/signup',anon,{email:'t35-host-'+nonce+'-'+n+'@example.test',
  password:randomBytes(32).toString('base64url')}),'temporary real GoTrue signup');
 if(!s?.access_token||!/^[a-f0-9-]{36}$/i.test(s.user?.id||''))die('missing verified GoTrue access token');
 accounts.push({id:s.user.id,jwt:s.access_token});
}
const [owner,oldAgent,newAgent,host,outsider]=accounts;
sql(`update phase3.system_authority set owner_id='${owner.id}'::uuid,main_partner_id=null where singleton;`);
const act=(who,action,data,key=randomUUID())=>post('/rest/v1/rpc/phase4_agency_action',who.jwt,
 {p_action:action,p_data:data,p_request_id:key});
const aData={kind:'host',name:'T35 Old Hosts',contact:'Local testing',reason:'QA sandbox request'};
const registerKey=randomUUID();
const submitted=await Promise.all(Array.from({length:6},()=>act(oldAgent,'register',aData,registerKey)));
const reg=submitted[0].data;
if(!reg?.id||submitted.some(r=>r.status!==200||r.data?.id!==reg.id))
 die('six same-key concurrent registrations not idempotent');
const count=Number(sql(`select count(*) from public.agency_registrations where applicant_id='${oldAgent.id}'::uuid and kind='host';`));
if(count!==1)die('more than one registration persisted');
const second=ok(await act(newAgent,'register',{kind:'host',name:'T35 New Hosts',contact:'Local testing',
 reason:'QA separate host agency'}),'new-host registration');
const firstApproved=ok(await act(owner,'approve_registration',{id:reg.id,
 note:'QA Owner authorizes first host group',commission_percent:10}),'Owner first approval');
const secondApproved=ok(await act(owner,'approve_registration',{id:second.id,
 note:'QA Owner authorizes second host group',commission_percent:20}),'Owner second approval');
const oldId=firstApproved.agency_id,newId=secondApproved.agency_id;
if(!oldId||!newId||oldId===newId)die('Owner failed to create distinct agencies');
const firstJoin=ok(await act(host,'join',{agency_id:oldId,reason:'QA join old hosts'}),'host first join');
ok(await act(oldAgent,'accept_join',{id:firstJoin.id}),'old agent accepts first join');
const move=ok(await act(host,'join',{agency_id:newId,reason:'QA controlled transfer'}),'host transfer request');
if(move.status!=='pending_old'||move.old_agency_id!==oldId)die('old-agent consent step bypassed');
const early=await act(newAgent,'accept_join',{id:move.id});
if(early.status>=200&&early.status<300)die('new agency accepted host without old approval');
for(const actor of [outsider,host]){
 const unauthorized=await act(actor,'approve_old',{id:move.id});
 if(unauthorized.status>=200&&unauthorized.status<300)die('unrelated user approved old agency decision');
}
const approveKey=randomUUID();
const oldApprovals=await Promise.all(Array.from({length:6},()=>act(oldAgent,'approve_old',{id:move.id},approveKey)));
if(oldApprovals.some(r=>r.status!==200||r.data?.status!=='pending_new')||
 new Set(oldApprovals.map(r=>r.data?.id)).size!==1)
 die('concurrent old-agency consent was not idempotent');
const acceptKey=randomUUID();
const acceptances=await Promise.all(Array.from({length:6},()=>act(newAgent,'accept_join',{id:move.id},acceptKey)));
if(acceptances.some(r=>r.status!==200||r.data?.status!=='completed')||
 new Set(acceptances.map(r=>r.data?.id)).size!==1)
 die('concurrent new-agency acceptance did not complete exactly once');
const record=JSON.parse(sql(`select json_build_object(
 'members',(select count(*) from public.agency_members where user_id='${host.id}'::uuid),
 'agency',(select agency_id from public.agency_members where user_id='${host.id}'::uuid),
 'status',(select status from public.agency_join_requests where id='${move.id}'::uuid),
 'oldApprovedBy',(select old_approved_by from public.agency_join_requests where id='${move.id}'::uuid),
 'acceptedBy',(select accepted_by from public.agency_join_requests where id='${move.id}'::uuid),
 'oldRegistrations',(select count(*) from public.agency_registrations where applicant_id='${oldAgent.id}'::uuid)
)::text;`));
if(record.members!==1||record.agency!==newId||record.status!=='completed'||
 record.oldApprovedBy!==oldAgent.id||record.acceptedBy!==newAgent.id||
 record.oldRegistrations!==1)die('agency member/audit history mismatch');
const secondAccept=await act(newAgent,'accept_join',{id:move.id});
if(secondAccept.status>=200&&secondAccept.status<300)
 die('new request-id was able to reaccept a finished transfer');
// Two Owner registration approvals already counted. 28 concurrent edits = exactly 30.
const edits=await Promise.all(Array.from({length:28},(_,i)=>act(owner,'edit',{
 id:oldId,name:'QA host audit '+String(i).padStart(2,'0'),commission_percent:10
})));
if(edits.some(r=>r.status<200||r.status>=300))
 die('28 Owner edits raced or wrongly hit quota: '+edits.map(r=>r.status).join(','));
const over=await act(owner,'edit',{id:oldId,name:'QA host over-limit',commission_percent:10});
if(over.status>=200&&over.status<300||!message(over).includes('Rate limit exceeded'))
 die('31st Owner action escaped 30/min cap');
const oldCount=Number(sql(`select count(*) from phase3.agency_requests where actor_id='${owner.id}'::uuid;`));
if(oldCount!==30)die('exactly 30 Owner audit actions expected');
console.log('PASS T35: six simultaneous same-key host registrations created one application; Owner opened distinct host agencies.');
console.log('PASS T35: host transfer needed old-agent consent, then new-agent approval; outsider/host and premature approvals blocked.');
console.log('PASS T35: six concurrent duplicate old approvals and six new acceptances preserved one membership and historical old/new approvers.');
console.log('PASS T06/T35: 28 simultaneous Owner edits plus two reviews yielded 30 recorded operations; 31st blocked.');
console.log('PASS T35: every identity and row is temporary LOCAL Supabase QA; no production agency, payroll, or role changed.');
