import assert from 'node:assert/strict';
import {test} from 'node:test';
import {readFileSync} from 'node:fs';
const core=readFileSync('app/reborn/core.js','utf8');
const features=readFileSync('app/reborn/features.js','utf8');
const auth=readFileSync('app/phase2-auth.js','utf8');
const html=readFileSync('app/index.html','utf8');
test('native OAuth callback is unique and cold start is supported',()=>{
 assert.equal((core.match(/app\.addListener\('appUrlOpen'/g)||[]).length,1);
 assert.equal((auth.match(/app\.addListener\('appUrlOpen'/g)||[]).length,0);
 assert.match(core,/app\.getLaunchUrl\(/);
 assert.match(core,/await auth\.handleOAuthCallback\(url\)/);
 assert.match(core,/try\{await bindNativeOAuth\(\);\}catch/);
});
test('outages are never disguised as real empty rooms',()=>{
 assert.match(core,/roomsStatus:'loading'/);
 assert.match(core,/roomsStatus='error'/);
 assert.match(core,/تعذّر الاتصال بالغرف/);
 assert.match(core,/جارٍ تحميل الغرف/);
});
test('room refresh does not erase unfinished user message',()=>{
 assert.match(core,/const value=draft\?\.value\|\|''/);
 assert.match(core,/next\.value=value/);
 assert.match(core,/next\.setSelectionRange\(caret,caret\)/);
});
test('Google Play build cannot steer users from coin wallet into reseller checkout',()=>{
 assert.ok(!core.includes('الشحن يتم عبر وكلاء الشحن'));
 assert.ok(!core.includes('باقات شحن'));
 assert.match(core,/لا يتوفر شراء العملات أو توجيه إلى وسائل دفع أخرى/);
});
test('account deletion request is real support RPC and is not an immediate destructive operation',()=>{
 assert.match(features,/data-act="requestDeletion"/);
 assert.match(features,/p_action:'create'/);
 assert.match(features,/subject:'Account and personal data deletion request'/);
 assert.match(features,/phase5_support_action/);
 assert.ok(!/delete\s+from\s+auth\.users/i.test(features));
});
test('Android entry contains only real auth and current frontend modules',()=>{
 assert.match(html,/phase2-auth\.js/);
 assert.match(html,/reborn\/core\.js/);
 assert.match(html,/reborn\/features\.js/);
 assert.ok(!html.includes('mock'));
});
