/* T30: simulate Owner-to-agent-to-customer coins on a DISPOSABLE local Supabase only.
 * Real GoTrue / PostgREST / PostgreSQL balances, never cash or production.
 */
import {readFileSync} from 'node:fs';
import {randomBytes,randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const fail=s=>{throw Error('T30 local reseller QA: '+s)};
if(process.env.T06_DISPOSABLE_ONLY!=='YES'||['SUPABASE_ACCESS_TOKEN','SUPABASE_DB_PASSWORD','DATABASE_URL','PGHOST','PGPORT','PGUSER','PGPASSWORD'].some(k=>process.env[k]))
 fail('disposable mode and empty linked credentials required');
let cfg;try{cfg=JSON.parse(readFileSync(process.argv[2],'utf8'))}catch{fail('missing local status')}
const base=new URL(cfg.API_URL||'http://invalid');
if(base.protocol!=='http:'||!['127.0.0.1','localhost'].includes(base.hostname)||base.username||base.password||base.pathname!=='/'||base.search||base.hash)
 fail('remote Supabase forbidden');
const anon=String(cfg.ANON_KEY||'');if(!anon.startsWith('eyJ'))fail('local auth key required');
const docker=(args,input)=>{
 const r=spawnSync('docker',args,{input,encoding:'utf8',timeout:10000});
 if(r.error||r.status!==0)fail('disposable docker local database unavailable, exit '+r.status);
 return r.stdout.trim();
};
const names=docker(['ps','--format','{{.Names}}']).split('\n').filter(x=>/^supabase_db_[a-zA-Z0-9_-]+$/.test(x));
if(names.length!==1)fail('need exactly one local Supabase DB');
const db=names[0];
const sql=q=>docker(['exec','-i',db,'psql','-X','-At','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres'],q+'\n');
async function call(route,who,body={}){
 const r=await fetch(new URL(route,base.origin),{
  method:'POST',headers:{apikey:anon,Authorization:'Bearer '+(who?.jwt||anon),'Content-Type':'application/json'},
  body:JSON.stringify(body),signal:AbortSignal.timeout(45000),cache:'no-store'});
 const text=await r.text();let value=null;try{value=JSON.parse(text)}catch{}
 return {code:r.status,value};
}
const error=r=>String(r.value?.message||r.value?.error||r.value?.error_description||'');
const ok=(r,step)=>{if(r.code<200||r.code>=300)fail(step+' '+r.code+' '+error(r).slice(0,100));return r.value;};
const nonce=randomBytes(9).toString('hex'),people=[];
for(let i=0;i<3;i++){
 const session=ok(await call('/auth/v1/signup',null,{
  email:'t30-reseller-'+nonce+'-'+i+'@example.test',
  password:randomBytes(32).toString('base64url')
 }),'local auth signup');
 if(!/^[a-f0-9-]{36}$/i.test(session.user?.id||'')||!session.access_token)fail('real GoTrue token missing');
 people.push({id:session.user.id,jwt:session.access_token});
}
const [owner,agent,customer]=people,packageId=randomUUID();
sql(`update phase3.system_authority set owner_id='${owner.id}'::uuid,main_partner_id=null where singleton;
insert into public.recharge_packages(id,price_usd,gold_amount) values('${packageId}'::uuid,0.01,7);`);
const agencyRpc='/rest/v1/rpc/phase4_agency_action',rechargeRpc='/rest/v1/rpc/phase4_recharge_action';
const agency=(actor,action,data,key=randomUUID())=>call(agencyRpc,actor,{p_action:action,p_data:data,p_request_id:key});
const cash=(actor,action,data,key=randomUUID())=>call(rechargeRpc,actor,{p_action:action,p_data:data,p_request_id:key});
const registration=ok(await agency(agent,'register',{
 kind:'recharge',name:'Local Reseller QA',contact:'local test only',
 reason:'Disposable no-real-money agency registration'
}),'agent registration');
if(!registration?.id)fail('agent registration id missing');
const ownApprove=await agency(agent,'approve_registration',{
 id:registration.id,note:'agent self review forbidden',commission_percent:0
});
if(ownApprove.code>=200&&ownApprove.code<300)fail('agent self-authorized recharge agency');
const reviewed=ok(await agency(owner,'approve_registration',{
 id:registration.id,note:'Owner approves simulated agency only',commission_percent:0
}),'Owner registration approval');
if(!reviewed.agency_id)fail('approved recharge agency id missing');
const ag=reviewed.agency_id;
const agentMint=await cash(agent,'issue',{coins:50,note:'Not an owner request',cash_reference:'T30-FAIL-'+nonce});
if(agentMint.code>=200&&agentMint.code<300)fail('non-Owner issued coins');
ok(await cash(owner,'issue',{coins:500,note:'Simulated receipt: no external cash paid',cash_reference:'T30-ISSUE-'+nonce}),'Owner issue');
ok(await cash(owner,'allocate',{coins:500,note:'Local only agent allocation',agency_id:ag}),'Owner allocation');
const state=ok(await call('/rest/v1/rpc/phase4_recharge_state',agent),'agent state after allocation');
if(BigInt(state.treasury)!==500n)fail('agent did not receive 500 coins');
const req=ok(await cash(customer,'request',{
 agency_id:ag,package_id:packageId,expected_coins:7,expected_price_usd:0.01
}),'customer cash recharge request');
if(!req.id||req.status!=='pending')fail('no pending customer request');
const decision={id:req.id,note:'QA simulated cash receipt from customer only',cash_reference:'T30-AGENT-'+nonce};
const wrongDecision=await cash(customer,'approve',decision);
if(wrongDecision.code>=200&&wrongDecision.code<300)fail('customer approved their own request');
const key=randomUUID();
const responses=await Promise.all(Array.from({length:6},()=>cash(agent,'approve',decision,key)));
if(responses.some(r=>r.code<200||r.code>=300)||responses.some(r=>r.value?.id!==responses[0].value?.id))
 fail('six identical concurrent agent approvals were not idempotent');
const answer=responses[0].value;
if(answer.status!=='completed'||Number(answer.coins)!==7)fail('agent approval result not confirmed');
const credit=BigInt(answer.coins)+BigInt(answer.bonus_coins||0);
const dbJson=sql(`select json_build_object(
 'ownerCoins',(select coins from phase3.treasury_accounts where user_id='${owner.id}'::uuid),
 'agentCoins',(select coins from phase3.treasury_accounts where user_id='${agent.id}'::uuid),
 'customerCoins',(select coins from public.wallets where user_id='${customer.id}'::uuid),
 'customerLedger',(select coalesce(sum(amount_change),0) from public.wallet_ledger where user_id='${customer.id}'::uuid and currency='coins' and kind='agent_topup'),
 'status',(select status from public.recharge_requests where id='${req.id}'::uuid),
 'cashReference',(select cash_reference from public.recharge_requests where id='${req.id}'::uuid),
 'topupRows',(select count(*) from public.wallet_ledger where user_id='${customer.id}'::uuid and kind='agent_topup'),
 'agencyType',(select kind from public.agencies where id='${ag}'::uuid)
)::text;`);
let snapshot;try{snapshot=JSON.parse(dbJson)}catch{fail('local SQL accounting readback invalid')}
if(BigInt(snapshot.ownerCoins)!==0n||BigInt(snapshot.agentCoins)!==500n-credit||
 BigInt(snapshot.customerCoins)!==credit||BigInt(snapshot.customerLedger)!==credit||
 snapshot.topupRows!==1||snapshot.status!=='completed'||snapshot.cashReference!==decision.cash_reference||
 snapshot.agencyType!=='recharge')
 fail('reseller transfer/accounting conservation error');
const next=await cash(agent,'approve',decision,randomUUID());
if(next.code>=200&&next.code<300||!error(next).includes('Request already resolved'))
 fail('resolved request credited second time');
console.log('PASS T30: real local GoTrue agent registered recharge agency; Owner-only reviewed agency and issued/allocated 500 synthetic coins.');
console.log('PASS T30: customer request persisted; wrong-person approvals and agent mint denied; six concurrent identical cash confirmations credited ONCE.');
console.log('PASS T30: customer wallet and ledger credited '+credit+' coins, Owner 0, agent '+(500n-credit)+'; exact 500-coin conservation, cash reference and recharge agency verified.');
console.log('PASS T30: repeat approval with different idempotency key refused; no live bank receipts, real reseller accounts or production balance changes.');
