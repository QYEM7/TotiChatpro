/* Source-only beta preflight: no SQL, external write, account creation or APK. */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export function inspect(root=ROOT){
 const read=p=>fs.readFileSync(path.join(root,p),'utf8');
 const pkg=JSON.parse(read('package.json'));
 const fb=JSON.parse(read('firebase/google-services.json'));
 const gate=JSON.parse(read('docs/release-readiness.json'));
 const auth=read('app/phase2-auth.js');
 const voice=read('supabase/functions/phase2-voice-token/index.ts');
 const limit=read('supabase/functions/phase2-voice-token/rate-limit.mjs');
 const voiceBudget=read('supabase/migrations/20261011000202_phase2_voice_token_preflight.sql');
 const voiceWrappers=read('supabase/migrations/20261011000300_secure_social_rpc_wrappers.sql');
 const cap=read('capacitor.config.ts');
 const googleSource=auth.includes('code_challenge_method=s256')&&auth.includes('grant_type=pkce')&&auth.includes('appUrlOpen')&&auth.includes('com.totichat.beta://auth/callback');
 // Voice token issuance is now budgeted durably by the Staging PostgreSQL
 // preflight, not exclusively by the older optional Upstash helper.
 // Both supported architectures must fail closed when throttling is absent.
 const legacyLimiter=voice.includes('rateVoiceRequest')&&limit.includes('VOICE_RATE_LIMIT_UNCONFIGURED');
 const durableLimiter=voice.includes("'phase2_voice_token_preflight'")&&
  voiceBudget.includes('voice_token_rate_limits')&&
  voiceBudget.includes('VOICE_RATE_LIMITED')&&
  voiceBudget.includes('old.hits>=20')&&
  voiceWrappers.includes('phase2_voice_token_preflight')&&
  voiceWrappers.includes('phase3.actor()');
 const voiceSource=voice.includes('ROOM_MEMBERSHIP_REQUIRED')&&
  voice.includes('LIVEKIT_API_SECRET')&&
  voice.includes('LIVEKIT_NOT_CONFIGURED')&&
  voice.includes('auth.getUser')&&Boolean(legacyLimiter||durableLimiter);
 const fbMatch=fb.client?.some(x=>x.client_info?.android_client_info?.package_name==='com.totichat.beta')&&cap.includes("appId: 'com.totichat.beta'");
 const pushPlugin=Boolean(pkg.dependencies?.['@capacitor/push-notifications']);
 return {
  disclaimer:'SOURCE ONLY: never proves hosted parity, real users, physical audio or FCM delivery',
  google:{pkce_android_callback_in_source:googleSource,hosted_provider:'check public Auth flags separately',real_login_passed:false},
  livekit:{server_token_and_limiter_in_source:voiceSource,hosted_function_parity:'UNVERIFIED',two_phone_audio_passed:false},
  firebase:{android_registered:Boolean(fbMatch),push_plugin_installed:pushPlugin,real_fcm_passed:false},
  migrations:{github_sql_files:fs.readdirSync(path.join(root,'supabase/migrations')).filter(x=>x.endsWith('.sql')).length,hosted_applied_count:'CHECK_WITH_SUPABASE'},
  release:{release_allowed:gate.release_allowed===true,engineering_percent:gate.engineering_percent,beta_percent:gate.beta_readiness_percent,missing_proofs:Object.entries(gate.evidence||{}).filter(([,v])=>v?.passed!==true).map(([k])=>k),apk_authorized:false},
  source_contracts_ok:Boolean(googleSource&&voiceSource&&fbMatch)
 };
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const status=inspect();console.log(JSON.stringify(status,null,2));
  if(process.argv.includes('--strict-source')&&!status.source_contracts_ok)process.exitCode=1;
 }catch(err){console.error('Source preflight failed:',err.message);process.exitCode=1;}
}
