/* Reports presence only. Dashboard secrets cannot be inferred from local env. */
import fs from 'node:fs';
const env={...process.env};
if(fs.existsSync('.env.local')){
 for(const line of fs.readFileSync('.env.local','utf8').split(/\r?\n/)){
  const match=line.match(/^\s*(?:export\s+)?([A-Z][A-Z0-9_]*)\s*=\s*(.*)\s*$/);
  if(!match)continue;let value=match[2].trim();
  if((value.startsWith('"')&&value.endsWith('"'))||(value.startsWith("'")&&value.endsWith("'")))value=value.slice(1,-1);
  else value=value.replace(/\s+#.*$/,'');
  if(!env[match[1]])env[match[1]]=value;
 }
}
const groups={
 supabase:[['SUPABASE_URL'],['SUPABASE_PUBLISHABLE_KEY','SUPABASE_ANON_KEY'],['SUPABASE_SERVICE_ROLE_KEY']],
 google:[['GOOGLE_CLIENT_ID'],['GOOGLE_CLIENT_SECRET']],
 apple:[['APPLE_SERVICE_ID'],['APPLE_TEAM_ID'],['APPLE_KEY_ID'],['APPLE_PRIVATE_KEY','APPLE_PRIVATE_KEY_FILE']],
 facebook:[['FACEBOOK_APP_ID'],['FACEBOOK_APP_SECRET']],
 smtp:[['SMTP_HOST'],['SMTP_PORT'],['SMTP_USER'],['SMTP_PASS'],['SMTP_FROM']],
 voice:[['LIVEKIT_URL'],['LIVEKIT_API_KEY'],['LIVEKIT_API_SECRET'],['TURN_URL'],['TURN_USERNAME'],['TURN_CREDENTIAL']],
 rate_limit:[['UPSTASH_REDIS_REST_URL'],['UPSTASH_REDIS_REST_TOKEN'],['VOICE_RATE_LIMIT_SALT']],
 real_e2e:[['TEST_USER1_EMAIL'],['TEST_USER1_PASSWORD'],['TEST_USER2_EMAIL'],['TEST_USER2_PASSWORD']],
 android_signing:[['ANDROID_KEYSTORE_PATH'],['ANDROID_KEYSTORE_PASSWORD'],['ANDROID_KEY_ALIAS'],['ANDROID_KEY_PASSWORD']]
};
const report=Object.fromEntries(Object.entries(groups).map(([name,requirements])=>[name,{present:requirements.filter(keys=>keys.some(k=>Boolean(env[k]))).map(keys=>keys.join('|')),missing:requirements.filter(keys=>!keys.some(k=>Boolean(env[k]))).map(keys=>keys.join('|'))}]));
process.stdout.write(JSON.stringify({scope:'local environment; not a Dashboard secret audit',groups:report},null,2)+'\n');
if(Object.values(report).some(g=>g.missing.length))process.exitCode=1;
