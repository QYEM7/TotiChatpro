import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const js=readFileSync(new URL('../app/phase5-special-id-ui.js',import.meta.url),'utf8');
const css=readFileSync(new URL('../app/phase5-special-id-ui.css',import.meta.url),'utf8');
const loader=readFileSync(new URL('../app/phase2-backend-controls.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../app/index.html',import.meta.url),'utf8');
test('special ID always comes from validated signed-in server response',()=>{
 assert(js.includes('phase5_special_id_status'));
 assert(js.includes('phase5_special_id_grant'));
 assert(js.includes("isOwner=result?.isOwner===true"));
 assert(js.includes("auth.state().signedIn===true"));
 assert(js.includes("if(stamp!==epoch||!signed()||ref!==user)return"));
 assert(js.includes("'ID مميز: '+code"));
 assert(js.includes("crypto.randomUUID()"));
 assert(!js.includes('Math.random()'));
});
test('manual owner approval is isolated from original approved HTML',()=>{
 assert(loader.includes('phase5-special-id-ui.js'));
 assert(loader.includes('phase5-special-id-ui.css'));
 assert(!html.includes('phase5-special-id-ui.js'));
 assert(css.includes('.tc-special-id-form'));
 assert(js.includes('data-tc-special-id-open'));
});
