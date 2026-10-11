// Owner development-only guard: continue coding & source QA WITHOUT
// requiring any launch checklist, building versions, uploading artifacts,
// publishing previews, or touching production. No network or build command.
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=new URL('../',import.meta.url);
const read=path=>readFileSync(new URL(path,root),'utf8');
export function verifyDevelopmentMode(policy,workflows){
 const errors=[];
 if(policy?.work_mode!=='development_only'||policy?.development_allowed!==true)
  errors.push('Coding not explicitly enabled');
 if(policy?.launch_conditions_active!==false||policy?.release_requirements_apply_to_development!==false)
  errors.push('Launch requirements still gate coding');
 for(const key of ['web_build_allowed','apk_aab_build_allowed','deployment_allowed','release_allowed']){
  if(policy?.[key]!==false)errors.push('Prohibited version or release action: '+key);
 }
 if(!Array.isArray(policy?.gates)||policy.gates.some(g=>g.required!==false))
  errors.push('Historical launch gates must be optional in development');
 const mandatoryJobs={
  '.github/workflows/live-preview-staging.yml':['source-check','publish-preview'],
  '.github/workflows/phase2-android-beta.yml':['build-android-debug'],
  '.github/workflows/free-landing-preview.yml':['build-static-landing-only']
 };
 for(const [path,jobNames] of Object.entries(mandatoryJobs)){
  const src=workflows[path]||'';
  for(const job of jobNames){
   const expr=new RegExp('^  '+job+':\\n(?:    [^\\n]*\\n){0,5}?    if: \\$\\{\\{ false \\}\\}', 'm');
   if(!expr.test(src))errors.push('Build/deploy workflow remains enabled: '+path+'#'+job);
  }
 }
 const comprehensive=workflows['.github/workflows/comprehensive-staging-qa.yml']||'';
 for(const step of [
  'Build approved app and registered STAGING-only browser preview',
  'Verify preview contains no Android APK or production backend',
  'Preserve inspected STAGING web artifact for QA only'
 ]){
  const anchor=comprehensive.indexOf('      - name: '+step);
  const next=comprehensive.slice(anchor,anchor+220);
  if(anchor<0||!next.includes('if: ${{ false }}'))
   errors.push('Application version creation is active in source QA: '+step);
 }
 if(!comprehensive.includes('Run ALL offline repository test files sequentially')||
  !comprehensive.includes('node scripts/check-development-only-mode.mjs'))
  errors.push('Source QA must remain active without launch requirements');
 const royal=workflows['.github/workflows/royal-preview-qa.yml']||'';
 for(const step of ['T09 responsive live login on six device widths',
  'Verify Capacitor Android startup renders the actual Home page']){
  const anchor=royal.indexOf('      - name: '+step);
  if(anchor<0||!royal.slice(anchor,anchor+250).includes('if: ${{ false }}'))
   errors.push('App build still enabled during browser QA: '+step);
 }
 return {valid:errors.length===0,mode:'development_only',
  development_allowed:policy?.development_allowed===true,
  builds_allowed:false,deployment_allowed:false,
  historical_checks:(policy?.gates||[]).length,errors};
}
export function checkRepository(){
 const data=JSON.parse(read('docs/BACKEND_PRELAUNCH_ACCEPTANCE_2026-10-11.json'));
 const paths=['.github/workflows/live-preview-staging.yml',
  '.github/workflows/comprehensive-staging-qa.yml',
  '.github/workflows/royal-preview-qa.yml',
  '.github/workflows/phase2-android-beta.yml',
  '.github/workflows/free-landing-preview.yml'];
 const sources=Object.fromEntries(paths.map(p=>[p,read(p)]));
 return verifyDevelopmentMode(data,sources);
}
if(process.argv[1]===fileURLToPath(import.meta.url)){
 const result=checkRepository();
 console.log(JSON.stringify(result,null,2));
 if(!result.valid)process.exitCode=1;
}
