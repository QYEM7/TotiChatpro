import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const voice=readFileSync(new URL('../app/phase2-voice-ui.js',import.meta.url),'utf8');
const start=voice.indexOf('async function muteToggle()');
const end=voice.indexOf('\nfunction syncPermission()',start);
assert(start>=0&&end>start,'Expected real voice mute handler');
const mute=voice.slice(start,end);

test('privacy: explicit mute stops the local microphone before contacting the backend',()=>{
 const local=mute.indexOf('await active.microphone(false)');
 const remote=mute.indexOf("await auth.requestData('/rest/v1/rpc/phase2_room_set_muted'");
 assert(local>=0,'local media must be stopped on mute');
 assert(remote>local,'local microphone stop must precede remote RPC');
 assert.match(mute,/if\(updated\)\s*\{[\s\S]*await active\.microphone\(false\)/);
});

test('privacy: if the local microphone cannot stop, audio disconnects, no server mute is attempted',()=>{
 const guard=mute.indexOf('await active.microphone(false)');
 const safe=mute.indexOf('await tearDown()',guard);
 const rpc=mute.indexOf("await auth.requestData('/rest/v1/rpc/phase2_room_set_muted'");
 assert(safe>guard&&safe<rpc,'fail-closed disconnect must happen before backend RPC');
 assert.match(mute,/await tearDown\(\);\s*notify\([^\n]*\);\s*return;/);
});

test('privacy: unmute is granted by server, and not republished after a remote mute',()=>{
 assert.match(mute,/if\(!updated&&grant\.canPublish\)/);
 assert.match(voice,/function syncPermission\(\)/);
 assert.match(voice,/void client\.microphone\(false\)\.catch\(\(\)=>\{void tearDown\(\);\}\)/);
});

test('privacy: failed unmute revokes any partially published track before database rollback',()=>{
 const failed=mute.slice(mute.indexOf(" }catch(e){\n  audioError=error(e);"));
 assert.match(failed,/if\(!updated\)\s*\{[\s\S]*await sdk\.microphone\(false\)/);
 const local=failed.indexOf('await sdk.microphone(false)');
 const rollback=failed.indexOf("await auth.requestData('/rest/v1/rpc/phase2_room_set_muted'");
 assert(local>=0&&rollback>local,'stop partially published audio before server rollback');
 assert.match(failed,/await tearDown\(\)/,'disconnect if local microphone shutdown fails');
});
