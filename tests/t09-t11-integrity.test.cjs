'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'..');
const app=p=>fs.readFileSync(path.join(root,'app',p),'utf8');
test('T09/T10 real Auth ignores query demo flag on Android or explicit live web',()=>{
 const s=app('phase2-ui.js');
 assert(s.includes('function previewOnly()'));
 assert(s.includes("params.get('mode')!=='live'"));
 assert(s.includes("!native&&!window.TotiLiveMode?.enabled"));
 assert(!s.includes('if(phase2Demo)return false'));
});
test('T11 legacy Royal controls cannot open sample rooms for authenticated users',()=>{
 const s=app('royal-visuals.js');
 const guarded=s.indexOf('if(window.TotiLiveMode?.enabled&&window.TotiPhase2Auth?.state()?.signedIn)');
 const demo=s.indexOf("if(cat==='games'){go('room')");
 assert(guarded>=0&&demo>guarded);
 assert(s.includes("['all','popular'].includes(el.dataset.cat)"));
 assert(s.includes("if(a==='create-room'||a==='hero'||a==='close')return"));
});
test('T11 network errors and stale fetches cannot masquerade as empty real directory',()=>{
 const s=app('phase2-rooms.js');
 assert(s.includes("if(!Array.isArray(data))throw new Error('استجابة قائمة الغرف غير صالحة')"));
 assert(s.includes("roomListError=failure(err);homeContent()"));
 assert(!s.includes("catch(err){if(before===sequence){rooms=[];homeContent()"));
 assert(s.includes('data-phase2="retry-rooms"'));
 assert(s.includes("if(kind==='retry-rooms')void listRooms()"));
 assert(s.includes("if(before===sequence)loadingRooms=null"));
 assert(s.includes("sequence++;loadingRooms=null;roomListError=''"));
});
test('T09 approved visual layers and 15-seat SQL range are preserved',()=>{
 const html=app('index.html'),rooms=app('phase2-rooms.js');
 for(const f of ['room-seats-finish.css','profile-stats-luxe.css','toti-nav-banner-refine.js'])assert(html.includes(f));
 assert(rooms.includes("const all=$$('.seats .seat',view);"));
 assert(rooms.includes('button.dataset.seat=String(slot)'));
 assert(rooms.includes("button.classList.toggle('occupied',!!p)"),'Real refresh preserves approved decorative seat classes');
 assert(rooms.includes("glyph.dataset.realSeatGlyph='';face.appendChild(glyph);"));
 assert(!rooms.includes("button.className='seat'+(p?' occupied':'')"));
 const sql=fs.readFileSync(path.join(root,'supabase/migrations/20261009223845_phase2_rooms_chat_seats.sql'),'utf8');
 assert(sql.includes('seat_no between 1 and 15'));
});
