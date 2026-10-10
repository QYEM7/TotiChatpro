'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const s=fs.readFileSync('app/phase2-rooms.js','utf8');
test('T17 foreground and reconnect actively refresh authorized real rooms',()=>{
 assert(s.includes("document.addEventListener('visibilitychange',"));
 assert(s.includes("window.addEventListener('online',syncVisibleRoom)"));
 assert(s.includes("window.addEventListener('focus',syncVisibleRoom)"));
 assert(s.includes("if(!session().signedIn||document.hidden||Date.now()-lastForegroundSync<2500)return;"));
 assert(s.includes("if(screen==='room'&&active)void refreshRoom();"));
 assert(s.includes("else if(screen==='home'&&!loadingRooms)void listRooms();"));
 assert(s.includes("setInterval(()=>{"),'existing polling fallback is kept');
 assert(s.includes('},7500);'),'polling is not removed before hosted websocket acceptance');
});
