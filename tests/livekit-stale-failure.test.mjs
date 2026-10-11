import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const adapter=readFileSync(new URL('../app/phase2-livekit-sdk.mjs',import.meta.url),'utf8')
 .replace(/^import \{Room,RoomEvent,ConnectionState\} from 'livekit-client';\s*$/m,'')
 .replace(/^export /gm,'');
function fixture(){
 const rooms=[],signals=[],media=[];
 class Room{
  constructor(){this.state='idle';this.handlers=new Map();rooms.push(this);}
  on(event,fn){this.handlers.set(event,fn)}
  connect(){
   this.state='connecting';
   return new Promise((resolve,reject)=>{
    this.finish=()=>{this.state='connected';resolve()};
    this.fail=()=>reject(new Error('Old RTC handshake failed'));
   });
  }
  async disconnect(){this.state='disconnected';}
  async startAudio(){}
 }
 const fakeDocument={body:{appendChild(m){media.push(m)}}};
 const events={TrackSubscribed:'TrackSubscribed',TrackUnsubscribed:'TrackUnsubscribed',
  Disconnected:'Disconnected',Reconnecting:'Reconnecting',Reconnected:'Reconnected'};
 const f=new Function('Room','RoomEvent','ConnectionState','document',
  "'use strict';\n"+adapter+"\nreturn {connect,disconnect,status};");
 const sdk=f(Room,events,{Connected:'connected'},fakeDocument);
 const connect=name=>sdk.connect('wss://voice.test','t'.repeat(110),s=>signals.push({name,...s}));
 return {sdk,rooms,media,signals,connect};
}
async function untilRoom(f,n){
 for(let i=0;i<25&&f.rooms.length<=n;i++)await Promise.resolve();
 assert(f.rooms[n],'The intended RTC room was created');
 return f.rooms[n];
}
test('rejected old LiveKit handshake cannot disconnect newer connected room',async()=>{
 const f=fixture();
 const stale=f.connect('old');const a=await untilRoom(f,0);
 const next=f.connect('new');const b=await untilRoom(f,1);
 b.finish();await next;
 assert.equal(f.sdk.status().connected,true);
 const before=f.signals.length;
 a.fail();await assert.rejects(stale,/Old RTC handshake failed/);
 assert.equal(f.sdk.status().connected,true,'new room must stay connected');
 assert.equal(b.state,'connected');
 assert.equal(a.state,'disconnected');
 assert.equal(f.signals.length,before,'late failure must not report disconnected to UI');
 await f.sdk.disconnect();
});
test('failure of current room disconnects only itself and reports correct UI state',async()=>{
 const f=fixture();
 const request=f.connect('failing');const a=await untilRoom(f,0);
 a.fail();await assert.rejects(request,/Old RTC handshake failed/);
 assert.equal(f.sdk.status().connected,false);
 assert.equal(a.state,'disconnected');
 assert(f.signals.some(s=>s.connected===false));
});
