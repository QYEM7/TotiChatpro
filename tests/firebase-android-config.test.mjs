import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,writeFileSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {validateFirebaseConfig,patchRootGradle,patchAppGradle,configureFirebaseAndroid} from '../scripts/configure-firebase-android.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const config=readFileSync(path.join(root,'firebase/google-services.json'),'utf8');
test('registered Firebase config exactly matches TotiChatpro beta application',()=>{
 const result=validateFirebaseConfig(config);
 assert.equal(result.project_id,'totichatpro');
 assert.equal(result.package_name,'com.totichat.beta');
 assert.match(readFileSync(path.join(root,'capacitor.config.ts'),'utf8'),/appId: 'com\.totichat\.beta'/);
});
test('reject unrelated projects, package mismatches and Firebase Admin credentials',()=>{
 assert.throws(()=>validateFirebaseConfig(config,'com.other.app'),/matching/);
 assert.throws(()=>validateFirebaseConfig(config.replace('"project_id": "totichatpro"','"project_id": "other"')),/Wrong Firebase project/);
 assert.throws(()=>validateFirebaseConfig(JSON.stringify({...JSON.parse(config),type:'service_account'})),/Admin SDK/);
});
test('Google Services Gradle setup is repeatable and will not change unknown Android shells',()=>{
 const rootGradle="buildscript {\n repositories { google() }\n dependencies {\n classpath 'com.android.tools.build:gradle:8.13.0'\n }\n}";
 const appGradle="apply plugin: 'com.android.application'\nandroid { namespace 'com.totichat.beta' }";
 const r=patchRootGradle(rootGradle),a=patchAppGradle(appGradle);
 assert.match(r,/com\.google\.gms:google-services:4\.5\.0/);
 assert.match(a,/apply plugin: 'com\.google\.gms\.google-services'/);
 assert.equal(patchRootGradle(r),r);
 assert.equal(patchAppGradle(a),a);
 assert.throws(()=>patchRootGradle('plugins {}'),/manual review/);
 assert.throws(()=>patchAppGradle('android {}'),/manual review/);
});
test('dry-run generates ONLY Android Google Services files (no APK or live services)',()=>{
 const temp=mkdtempSync(path.join(tmpdir(),'totichat-firebase-'));
 try{
  mkdirSync(path.join(temp,'android/app'),{recursive:true});
  writeFileSync(path.join(temp,'capacitor.config.ts'),"const x={appId: 'com.totichat.beta'};");
  const gr="buildscript { dependencies { classpath 'com.android.tools.build:gradle:8.13.0' } }";
  const ga="apply plugin: 'com.android.application'";
  writeFileSync(path.join(temp,'android/build.gradle'),gr);
  writeFileSync(path.join(temp,'android/app/build.gradle'),ga);
  const target=configureFirebaseAndroid(temp,path.join(root,'firebase/google-services.json'));
  assert.equal(readFileSync(target,'utf8'),config);
  const next=configureFirebaseAndroid(temp,path.join(root,'firebase/google-services.json'));
  assert.equal(next,target);
  assert.equal(readFileSync(path.join(temp,'android/app/build.gradle'),'utf8').match(/apply plugin: 'com\.google\.gms\.google-services'/g)?.length,1);
 }finally{rmSync(temp,{force:true,recursive:true})}
});
