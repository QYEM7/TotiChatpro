import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir,stat} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {createHash} from 'node:crypto';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const get=rel=>readFile(path.join(root,rel));
const digest=data=>createHash('sha256').update(data).digest('hex');

test('Android web payload uses exact approved HTML, CSS, JS and asset bytes',async()=>{
 execFileSync(process.execPath,[path.join(root,'scripts/build-approved-web.mjs')],{cwd:root});
 const core=[
  'app/index.html','app/config.js','app/home-banners.js',
  'app/royal-final.js','app/royal-visuals.js',
  'app/room-seats-finish.css','app/profile-stats-luxe.css',
  'app/toti-nav-banner-refine.css','app/toti-nav-banner-refine.js',
  'assets/images/toti_falcon_logo_1790422919580.jpg'
 ];
 for(const item of core){
   assert.equal(digest(await get(item)),digest(await get('dist/'+item)),item+' changed in packaging');
 }
 const manifest=await readdir(path.join(root,'assets','images'));
 for(const entry of manifest){
   if(!(await stat(path.join(root,'assets','images',entry))).isFile())continue;
   assert.equal(digest(await get('assets/images/'+entry)),
     digest(await get('dist/assets/images/'+entry)), 'asset modified: '+entry);
 }
 const entry=(await get('dist/index.html')).toString();
 const source=(await get('app/index.html')).toString();
 assert.match(entry,/<html lang="ar" dir="rtl"><head><base href="\.\/app\/">/);
 assert.equal(entry,source.replace('<html lang="ar" dir="rtl"><head>',
   '<html lang="ar" dir="rtl"><head><base href="./app/">'),
   'APK WebView root MUST contain the exact original approved app with only a base tag');
 assert.match(entry,/id="app"/);
 assert.match(entry,/royal-visuals\.js/);
 assert.match(entry,/phase2-voice-ui\.js/);
 const sdk=await stat(path.join(root,'dist/app/phase2-livekit-sdk.bundle.js'));
 assert.ok(sdk.size>100000,'Real LiveKit WebRTC library is not bundled into Android APK');
 const voice=(await get('dist/app/phase2-voice-ui.js')).toString();
 assert.match(voice,/requestVoiceToken/);
 assert.match(voice,/phase2_room_set_muted/);

 assert.doesNotMatch(entry,/http-equiv="refresh"|window\.location\.replace\('\.\/app\/'\)/i,
   'Never redirect Capacitor WebView to an unsupported /app/ directory');
 assert.doesNotMatch(entry,/jsjsnsnsnsn0-pixel\/TotiChat/);
});

test('New app points ONLY at independent Supabase and preserves official banner',async()=>{
 const config=(await get('dist/app/config.js')).toString();
 assert.match(config,/sqedsnyvjblvbjbizcay\.supabase\.co/);
 assert.doesNotMatch(config,/bfadhdnudmsggylunhlh/);
 assert.doesNotMatch(config.replace(/\/\*[\s\S]*?\*\//g,''),/service[_-]?role|sb_secret_/i);
 const banner=(await get('dist/app/home-banners.js')).toString();
 assert.match(banner,/home_banners/);
 const royalty=(await get('dist/app/royal-visuals.js')).toString();
 assert.match(royalty,/class="royal-hero"/);
 assert.doesNotMatch(royalty,/class="royal-official"/);
 const room=(await get('dist/app/royal-final.js')).toString();
 assert.doesNotMatch(room,/rf-room-royal-ribbon/);
 const html=(await get('dist/app/index.html')).toString();
 assert.match(html,/const seats=Array\.from\(\{length:15\}/);
});

test('Identity migration follows fail-closed minimum-security pattern',async()=>{
 const sql=(await get('supabase/migrations/20261010120000_phase2_identity_profiles.sql')).toString();
 assert.match(sql,/alter table public\.profiles enable row level security/);
 assert.match(sql,/grant update \(display_name, bio, avatar_url\)/);
 assert.match(sql,/phase2_after_auth_signup/);
 assert.doesNotMatch(sql,/\b(?:drop table|truncate|delete from)\b/i);
});
