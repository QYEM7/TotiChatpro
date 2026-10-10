import test from 'node:test';
import assert from 'node:assert/strict';
import {rateVoiceRequest} from '../supabase/functions/phase2-voice-token/rate-limit.mjs';
const credentials={url:'https://example-bucket.upstash.io',token:'a_very_long_private_redis_token_for_testing',salt:'a'.repeat(64),now:1791630000000};
function mockReply(counts){
 const calls=[];
 return {calls,fetcher:async(url,opts)=>{calls.push({url,opts});return {ok:true,json:async()=>({result:counts})};}};
}
test('T06 voice limiter uses HMAC-only keys and independent atomic global+token budgets',async()=>{
 const m=mockReply([1,1]);
 const x=await rateVoiceRequest('Bearer private_user_jwt',{...credentials,fetcher:m.fetcher});
 assert.equal(x.allowed,true);
 assert.equal(m.calls.length,1);
 const payload=JSON.parse(m.calls[0].opts.body);
 assert.equal(payload[0],'EVAL');
 assert.equal(payload[2],'2');
 assert.match(payload[3],/^totichat:voice:global:/);
 assert.match(payload[4],/^totichat:voice:actor:/);
 assert(!m.calls[0].opts.body.includes('private_user_jwt'),'raw bearer must not appear in Redis payload');
});
test('T06 voice limiter blocks token 13th, global 601st, and misconfigured/failed Redis',async()=>{
 const a=await rateVoiceRequest('Bearer x',{...credentials,fetcher:mockReply([22,13]).fetcher});
 assert.deepEqual(a,{allowed:false,status:429,code:'VOICE_RATE_LIMITED'});
 const b=await rateVoiceRequest('Bearer x',{...credentials,fetcher:mockReply([601,2]).fetcher});
 assert.equal(b.status,429);
 const c=await rateVoiceRequest('Bearer x',{...credentials,token:'too-short',fetcher:mockReply([1,1]).fetcher});
 assert.equal(c.status,503);
 const d=await rateVoiceRequest('Bearer x',{...credentials,url:'http://example-bucket.upstash.io',fetcher:mockReply([1,1]).fetcher});
 assert.equal(d.status,503);
 const e=await rateVoiceRequest('Bearer x',{...credentials,fetcher:async()=>{throw Error('redis down')}});
 assert.equal(e.status,503);
});
test('T06 voice limiter rejects unauthenticated and Redis malformed responses',async()=>{
 assert.equal((await rateVoiceRequest('',credentials)).status,401);
 const a=await rateVoiceRequest('Bearer x',{...credentials,fetcher:async()=>({ok:true,json:async()=>({result:null})})});
 assert.equal(a.status,503);
});
test('T06 source explicitly fails closed before issuing LiveKit tokens',async()=>{
 const {readFileSync}=await import('node:fs');
 const src=readFileSync(new URL('../supabase/functions/phase2-voice-token/index.ts',import.meta.url),'utf8');
 assert(src.indexOf('const budget=await rateVoiceRequest')>=0);
 assert(src.indexOf('const budget=await rateVoiceRequest')<src.indexOf('const token=new AccessToken'));
 assert(src.includes("if(!budget.allowed)return json(budget.status,{error:budget.code});"));
});
