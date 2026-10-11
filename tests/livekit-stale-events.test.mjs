import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const original=readFileSync(new URL('../app/phase2-livekit-sdk.mjs',import.meta.url),'utf8');
const adapterSource=original.replace(/^import \{Room,RoomEvent,ConnectionState\} from 'livekit-client';\s*$/m,'')
  .replace(/^export /gm,'');
const events={
 TrackSubscribed:'track-subscribed',TrackUnsubscribed:'track-unsubscribed',
 Disconnected:'disconnected',Reconnecting:'reconnecting',Reconnected:'reconnected'
};
function fixture(){
 const rooms=[],children=[],signals=[];
 const document={body:{appendChild(node){children.push(node);node.appended=true;}}};
 class Room{
  constructor(){
   this.state='idle';
   this.handlers=new Map();rooms.push(this);
   this.localParticipant={setMicrophoneEnabled:async()=>{}};
  }
  on(event,fn){this.handlers.set(event,fn);}
  emit(event,value){this.handlers.get(event)?.(value);}
  async disconnect(){this.state='disconnected';}
  async startAudio(){}
  connect(){
   this.state='connecting';
   return new Promise(resolve=>{this.finish=()=>{this.state='connected';resolve();};});
  }
 }
 const code=new Function('Room','RoomEvent','ConnectionState','document',
   "'use strict';\n"+adapterSource+"\nreturn {connect,disconnect,status,microphone};");
 const sdk=code(Room,events,{Connected:'connected'},document);
 const token='x'.repeat(100);
 const start=(name)=>sdk.connect('wss://voice.example.test',token,state=>signals.push({name,...state}));
 const audio=()=>({
  removed:false,play(){return Promise.resolve();},
  remove(){this.removed=true;},
  style:{},dataset:{},setAttribute(){},volume:1
 });
 return {sdk,rooms,signals,children,start,audio};
}
async function nextRoom(ctx,index){
 for(let i=0;i<12&&ctx.rooms.length<=index;i++)await Promise.resolve();
 assert(ctx.rooms[index], 'Room instance created');
 return ctx.rooms[index];
}

test('a disconnected LiveKit room cannot attach stale remote audio or publish late UI status',async()=>{
 const f=fixture();
 const opening=f.start('A');
 const room=await nextRoom(f,0);
 await f.sdk.disconnect();
 const before=f.signals.length;
 room.emit(events.TrackSubscribed,{kind:'audio',attach(){throw Error('stale track attached');}});
 room.emit(events.Reconnected);
 room.emit(events.Reconnecting);
 room.emit(events.Disconnected);
 assert.equal(f.children.length,0);
 assert.equal(f.signals.length,before,'late events cannot mutate the current UI state');
 room.finish();
 await opening;
});

test('old room events cannot remove audio or change connected state of the new LiveKit room',async()=>{
 const f=fixture();
 const first=f.start('A'),roomA=await nextRoom(f,0);
 const second=f.start('B'),roomB=await nextRoom(f,1);
 roomB.finish();
 await second;
 const media=f.audio();
 roomB.emit(events.TrackSubscribed,{kind:'audio',attach(){return media;}});
 assert.equal(f.children.length,1);
 const before=f.signals.length;
 roomA.emit(events.TrackUnsubscribed,{detach(){return [media];}});
 roomA.emit(events.Reconnected);
 roomA.emit(events.Disconnected);
 roomA.emit(events.TrackSubscribed,{kind:'audio',attach(){throw Error('stale audio attached');}});
 assert.equal(media.removed,false,'old room must not detach the current room audio');
 assert.equal(f.signals.length,before,'old reconnect must not override current room state');
 roomA.finish();await first;
 await f.sdk.disconnect();
});
