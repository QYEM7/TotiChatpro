'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const root='app/';
const ui=fs.readFileSync(root+'phase5-music-ui.js','utf8');
const live=fs.readFileSync(root+'phase2-live-mode.js','utf8');
const html=fs.readFileSync(root+'index.html','utf8');
test('T23 saved track mutations use authenticated REST only',()=>{
 assert.match(ui,/auth\.requestData\('\/rest\/v1\/'/);
 assert(ui.includes("owner_id:uid,title,artist,reference_url:url||null"));
 assert(ui.includes("method:'POST'")&&ui.includes("method:'DELETE'"));
 assert(!ui.includes('localStorage'));
});
test('T23 no fake playing, audio transport or blind HTML interpolation',()=>{
 assert(!ui.includes('.play()'));
 assert(!ui.includes('new Audio('));
 assert(ui.includes('item.title'));
 assert(ui.includes('label.textContent=item.title'));
 assert(ui.includes("element.closest('.t23-music-form')"));
 assert(ui.includes('textContent'));
 assert(html.includes('phase5-music-ui.js'));
});
test('T23 signed-in app keeps room screen and mic; Owner queues songs',()=>{
 assert(live.includes("'musicPreview',...authScreens"));
 assert(ui.includes("screen==='room'&&getRoom()?.id"));
 assert(ui.includes('showSheet('));
 assert(ui.includes("if(!room?.isOwner"));
 assert(!ui.includes("go('musicPreview')"));
});
