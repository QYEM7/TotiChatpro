import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const js=readFileSync(new URL('../app/phase5-room-games-ui.js',import.meta.url),'utf8');
const css=readFileSync(new URL('../app/phase5-room-games-ui.css',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const live=readFileSync(new URL('../app/phase2-live-mode.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('approved room game icon invokes real backend and refuses fake sheet',()=>{
 assert.match(html,/act\('sheet','games'\).*aria-label="الألعاب"/);
 assert.match(live,/window\.TotiRoomGames\?\.isInstalled\?\.\(\)===true/);
 assert.match(live,/window\.TotiRoomGames\.open\(\)/);
 assert.match(live,/screen==='room'&&op==='sheet'&&route==='games'/);
 assert(loader.includes('phase5-room-games-ui.js'));
 assert(loader.includes('phase5-room-games-ui.css'));
 assert(!html.includes('phase5-room-games-ui.js'),'approved HTML must stay unchanged');
});
test('real two-user match is authenticated, tied to active room and no demo opponents',()=>{
 assert.match(js,/if\(!auth\|\|!rooms\|\|!window\.TotiLiveMode\?\.enabled\)return/);
 assert.match(js,/rooms\.getRoomSummary\?\.\(\)\?\.id===roomId/);
 assert.match(js,/auth\.state\(\)\.signedIn===true/);
 assert.match(js,/rpc\('phase5_room_game_state'/);
 assert.match(js,/rpc\('phase5_room_game_action'/);
 assert.match(js,/p_request_id:crypto\.randomUUID\(\)/);
 assert.match(js,/Number\.isInteger\(value\.turnNo\)/);
 assert.match(js,/\^\[XO\.\]\{9\}\$/);
 assert.match(js,/window\.addEventListener\('totichat-phase2-auth'/);
 assert(!/fakeGame|sampleOpponent|demoMatch|localStorage|Math\.random/.test(js));
});
test('game controls are isolated overlay and cannot change microphone, finances or 15 seats',()=>{
 assert.match(js,/showSheet\(/);
 assert.match(js,/getMembers\?\.\(\)/);
 assert.match(js,/root\.replaceChildren\(\)/);
 assert(css.includes('.tc-ttt-board'));
 assert.doesNotMatch(js,/(?:\.disconnect\(|\.microphone\(|\.mute\(|phase2_room_take_seat|wallet_|coin|diamond|LIVEKIT_SECRET)/i);
 assert(html.includes('room-seats-finish.css'));
});
