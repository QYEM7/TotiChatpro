/* Install the owner-registered Firebase Android config into Capacitor's generated
 * native app. This script NEVER runs Gradle, builds an APK, modifies production,
 * registers a Firebase app, or creates a paid service.
 *
 * The JSON contains client-side public identifiers, NOT a server/service-account
 * private key. NEVER put server Admin SDK JSON here.
 */
import {readFileSync,writeFileSync,copyFileSync,existsSync,mkdirSync} from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const repoRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const PROJECT='totichatpro';
const PACKAGE='com.totichat.beta';
const GOOGLE_SERVICES_PLUGIN="com.google.gms:google-services:4.5.0";

export function validateFirebaseConfig(text,appId=PACKAGE){
 const config=JSON.parse(text);
 if(config?.project_info?.project_id!==PROJECT)throw Error('Wrong Firebase project; expected totichatpro');
 const matching=config?.client?.filter(x=>x?.client_info?.android_client_info?.package_name===appId)||[];
 if(matching.length!==1)throw Error('Firebase config must contain exactly one Android client matching '+appId);
 const android=matching[0];
 if(!/^1:[0-9]+:android:[a-zA-Z0-9]+$/.test(android?.client_info?.mobilesdk_app_id||''))throw Error('Firebase Android app ID missing');
 if(!/^AIza[0-9A-Za-z_-]{20,}$/.test(android?.api_key?.[0]?.current_key||''))throw Error('Firebase public Android API key missing or invalid');
 if(String(config.project_info.project_number).split(':')[0]!==android.client_info.mobilesdk_app_id.split(':')[1])
  throw Error('Firebase sender/project number mismatch');
 if(config.private_key||config.client_email||config.type==='service_account')throw Error('Admin SDK secrets must NEVER be packaged in Android');
 return {project_id:config.project_info.project_id,package_name:appId};
}

export function patchRootGradle(gradle){
 if(gradle.includes('com.google.gms:google-services:'))return gradle;
 const anchor=/classpath\s+['"]com\.android\.tools\.build:gradle:[^'"]+['"]/;
 if(!anchor.test(gradle))throw Error('Unknown Capacitor Gradle buildscript; manual review required before Firebase modification');
 return gradle.replace(anchor,match=>match+"\n        classpath '"+GOOGLE_SERVICES_PLUGIN+"'");
}

export function patchAppGradle(gradle){
 if(gradle.includes("apply plugin: 'com.google.gms.google-services'")||gradle.includes('id("com.google.gms.google-services")'))return gradle;
 const anchor=/apply plugin:\s*['"]com\.android\.application['"]/;
 if(!anchor.test(gradle))throw Error('Unknown Capacitor app Gradle; manual review required before Firebase modification');
 return gradle.replace(anchor,match=>match+"\napply plugin: 'com.google.gms.google-services'");
}

export function configureFirebaseAndroid(root=repoRoot,source=path.join(root,'firebase','google-services.json')){
 const manifest=readFileSync(path.join(root,'capacitor.config.ts'),'utf8');
 if(!manifest.includes("appId: 'com.totichat.beta'"))throw Error('Capacitor Android app package does not match Firebase');
 const content=readFileSync(source,'utf8');
 validateFirebaseConfig(content);
 const android=path.join(root,'android');
 const gradleRoot=path.join(android,'build.gradle');
 const gradleApp=path.join(android,'app','build.gradle');
 if(!existsSync(gradleRoot)||!existsSync(gradleApp))
  throw Error('Android Capacitor platform not generated: run npx cap add android BEFORE applying Firebase configuration');
 const rootContent=readFileSync(gradleRoot,'utf8');
 const appContent=readFileSync(gradleApp,'utf8');
 const patchedRoot=patchRootGradle(rootContent),patchedApp=patchAppGradle(appContent);
 // Compute and validate all changes before writing anything. No secret values logged.
 writeFileSync(gradleRoot,patchedRoot);
 writeFileSync(gradleApp,patchedApp);
 const target=path.join(android,'app','google-services.json');
 mkdirSync(path.dirname(target),{recursive:true});
 copyFileSync(source,target);
 console.log('PASS: Firebase Android configuration staged for com.totichat.beta (no build or deployment)');
 return target;
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{configureFirebaseAndroid();}catch(error){console.error('BLOCKED Firebase Android setup: '+error.message);process.exitCode=1;}
}
