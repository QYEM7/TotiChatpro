/* T03: inspect tracked files only. Never display matched secret values. */
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {basename} from 'node:path';
const credentialNames=[/^\.env(?:\..+)?$/i,/\.pem$/i,/\.p12$/i,/\.pfx$/i,/\.key$/i,/\.keystore$/i,/\.jks$/i,/^id_rsa$/i,/^id_ed25519$/i];
const signatures=[
 ['supabase-secret',/sb_secret_[A-Za-z0-9_-]{16,}/],
 ['github-token',/(?:ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{25,}|github_pat_[A-Za-z0-9_]{30,}/],
 ['cloud-key',/AKIA[A-Z0-9]{16}/],
 ['openai-secret',/sk-(?:proj-)?[A-Za-z0-9_-]{30,}/],
 ['pem-private-key',/-{5}BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-{5}/]
];
export function detectCredential(path,content){
 const file=basename(path);
 if(file!=='.env.example'&&credentialNames.some(re=>re.test(file)))return 'credential-file';
 if(content.includes('\0'))return null;
 for(const [reason,re] of signatures)if(re.test(content))return reason;
 if(file==='.env.example'){
  for(const line of content.split(/\r?\n/)){
   if(/^\s*(?:SUPABASE_SERVICE_ROLE_KEY|SUPABASE_DB_PASSWORD|LIVEKIT_API_SECRET|SMTP_PASS|TURN_CREDENTIAL|UPSTASH_REDIS_REST_TOKEN|TEST_USER[12]_PASSWORD|ANDROID_KEYSTORE_PASSWORD|ANDROID_KEY_PASSWORD)\s*=\s*\S/.test(line))return 'nonempty-private-template';
  }
 }
 return null;
}
export function auditTrackedFiles(){
 const entries=execFileSync('git',['ls-files','-z'],{maxBuffer:5_000_000}).toString('utf8').split('\0').filter(Boolean);
 const findings=[];
 for(const path of entries){
  if(path.startsWith('assets/')||path==='package-lock.json')continue;
  let contents;
  try{contents=readFileSync(path,'utf8')}catch{findings.push({path,reason:'unreadable'});continue}
  const problem=detectCredential(path,contents);
  if(problem)findings.push({path,reason:problem});
 }
 return {filesScanned:entries.length,findings};
}
if(process.argv[1]&&import.meta.url===new URL('file://'+process.argv[1]).href){
 const results=auditTrackedFiles();
 if(results.findings.length){for(const f of results.findings)console.error('BLOCKED T03 '+f.reason+' in '+f.path);process.exitCode=1;}
 else console.log('PASS T03: '+results.filesScanned+' tracked paths checked for high-confidence private credentials; no secret material printed.');
}
