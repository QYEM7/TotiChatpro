/* TotiChat: real no-stakes two-person tic-tac-toe inside current VOICE room.
 * Uses the existing games button + approved room visuals. NO media disconnect,
 * microphone toggles, seat mutation, wallet writes or preview opponent data.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth,rooms=window.TotiPhase2Rooms;
if(!auth||!rooms||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[x]));
const validUUID=s=>/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s||'');
let owner='',roomId='',epoch=0,current=null,pending=false,failed=false,actionError='';
function signed(){return auth.state().signedIn===true&&auth.state().user?.id===owner}
function inside(){
 return signed()&&rooms.getRoomSummary?.()?.id===roomId&&
  $('#tc-real-room-game')!==null&&
  $('#overlay')?.classList.contains('show')===true;
}
function msg(message){const n=$('#tc-game-state');if(n)n.textContent=String(message||'').slice(0,200)}
const rpc=(functionName,body)=>auth.requestData('/rest/v1/rpc/'+functionName,{method:'POST',body});
function person(id){
 if(!validUUID(id))return 'بانتظار لاعب';
 if(id===owner)return 'أنت';
 const m=rooms.getMembers?.()?.find(m=>m.user_id===id);
 return m?.display_name||'عضو '+id.slice(0,8).toUpperCase();
}
function validate(value){
 if(!value||value.roomId!==roomId||typeof value.hasGame!=='boolean')
  throw Error('الخادم أعاد لعبة من غرفة أخرى');
 if(!value.hasGame)return;
 if(!validUUID(value.gameId)||!validUUID(value.playerX)||
  (value.playerO!==null&&!validUUID(value.playerO))||
  !/^[XO.]{9}$/.test(value.board)||!['X','O'].includes(value.nextMark)||
  !Number.isInteger(value.turnNo)||value.turnNo<0||value.turnNo>9||
  !['waiting','active','won','draw','cancelled'].includes(value.status)||
  (value.winnerId!==null&&!validUUID(value.winnerId)))
  throw Error('حالة اللعبة المرسلة من الخادم غير موثوقة');
}
function render(){
 if(!inside())return;
 const root=$('#tc-game-board'),actions=$('#tc-game-actions'),title=$('#tc-game-players');
 if(!root||!actions||!title)return;
 root.replaceChildren();actions.replaceChildren();
 if(failed){msg('تعذّر التحقق من اللعبة الحقيقية. اضغط تحديث.');return}
 if(!current){msg('جارٍ قراءة حالة اللعبة من خادم TotiChat…');return}
 if(!current.hasGame){
  title.textContent='لم يتم إنشاء مباراة في هذه الغرفة بعد';
  msg('لعبة جماعية حقيقية بين عضوين من الغرفة، بدون رهان أو جوائز.');
  makeAction(actions,'إنشاء مباراة','start',true);
  return;
 }
 const g=current;
 const isX=g.playerX===owner,isO=g.playerO===owner,isPlayer=isX||isO;
 title.textContent='❌ '+person(g.playerX)+' × ⭕ '+person(g.playerO);
 const finished=['won','draw','cancelled'].includes(g.status);
 if(g.status==='waiting')msg('بانتظار انضمام لاعب ثانٍ من أعضاء الغرفة.');
 else if(g.status==='active')
  msg(g.nextMark+' · '+(g.nextMark==='X'?person(g.playerX):person(g.playerO))+' عليه الدور');
 else if(g.status==='won')msg('انتهت المباراة. الفائز: '+person(g.winnerId));
 else if(g.status==='draw')msg('انتهت المباراة بالتعادل.');
 else msg('أُلغيت المباراة أو خرج أحد اللاعبين.');
 for(let i=0;i<9;i++){
  const b=document.createElement('button');b.type='button';b.className='tc-ttt-cell';
  const mark=g.board[i];b.textContent=mark==='.'?'':mark==='X'?'✕':'◯';
  b.setAttribute('aria-label','الخانة '+(i+1)+(mark==='.'?' فارغة':' '+mark));
  b.dataset.tcGameCell=String(i);
  const myMark=isX?'X':isO?'O':'';
  b.disabled=pending||g.status!=='active'||mark!=='.'||myMark!==g.nextMark;
  root.appendChild(b);
 }
 if(g.status==='waiting'&&!isX)makeAction(actions,'انضمام كلاعب ◯','join',true);
 if(!finished&&(isPlayer||rooms.getRoomSummary?.()?.isOwner))
  makeAction(actions,'إلغاء المباراة','cancel',true);
 if(finished)makeAction(actions,'إنشاء مباراة جديدة','start',true);
 if(actionError)msg(actionError);
}
function makeAction(parent,text,action,enabled){
 const b=document.createElement('button');b.type='button';b.dataset.tcGameAction=action;
 b.textContent=text;b.disabled=!enabled||pending;parent.appendChild(b);
}
async function refresh(){
 if(!inside()||pending)return;
 const id=owner,room=roomId,stamp=epoch;pending=true;
 try{
  const result=await rpc('phase5_room_game_state',{p_room_id:room});
  if(stamp!==epoch||id!==owner||!inside())return;
  validate(result);current=result;failed=false;actionError='';
 }catch(e){if(stamp===epoch&&inside()){failed=true;msg('تعذّر الوصول للعبة: '+String(e.message).slice(0,95))}}
 finally{pending=false;if(stamp===epoch)render()}
}
async function mutate(action,cell=null){
 if(!inside()||pending)return;
 if(!['start','join','move','cancel'].includes(action))return;
 if(action==='move'&&(!Number.isInteger(cell)||cell<0||cell>8))return;
 const oldRoom=roomId,oldOwner=owner,stamp=epoch;
 pending=true;msg('جارٍ تسجيل الدور على الخادم…');
 try{
  const data=await rpc('phase5_room_game_action',{
   p_room_id:oldRoom,p_action:action,p_cell:cell,p_request_id:crypto.randomUUID()
  });
  if(stamp!==epoch||owner!==oldOwner||!inside())return;
  validate(data);current=data;failed=false;actionError='';
 }catch(e){if(stamp===epoch&&inside())actionError='تعذّر تنفيذ الحركة: '+String(e.message||'').slice(0,130)}
 finally{pending=false;if(stamp===epoch)render()}
}
function open(){
 const room=rooms.getRoomSummary?.(),user=auth.state().user?.id;
 if(!auth.state().signedIn||!room?.id||!validUUID(room.id)||!user)return;
 owner=user;roomId=room.id;epoch++;current=null;pending=false;failed=false;actionError='';
 if(typeof showSheet!=='function')return;
 // An ordinary overlay is independent of the room's WebRTC connection.
 showSheet('<section id="tc-real-room-game" dir="rtl" class="tc-real-room-game">'+
  '<header><h3>🎮 لعبة إكس-أو داخل الغرفة</h3><button type="button" data-a="close" aria-label="إغلاق">✕</button></header>'+
  '<p>ابقَ على مقعدك وفي المكالمة. اللعب ما يغيّر المايك أو الصوت.</p>'+
  '<div id="tc-game-players" role="status"></div>'+
  '<p id="tc-game-state" aria-live="polite"></p>'+
  '<div id="tc-game-board" class="tc-ttt-board" aria-label="لوحة إكس أو"></div>'+
  '<div id="tc-game-actions" class="tc-ttt-actions"></div>'+
  '<button type="button" data-tc-solo-launch>اللعب الفردي ضد الكمبيوتر المحلي</button>'+
  '<button type="button" data-tc-game-refresh>تحديث الحالة</button>'+
  '</section>',true);
 void refresh();
}
document.addEventListener('click',event=>{
 const b=event.target?.closest?.('[data-tc-game-action],[data-tc-game-cell],[data-tc-game-refresh]');
 if(!b)return;
 event.preventDefault();event.stopImmediatePropagation();
 if(!inside())return;
 if(b.hasAttribute('data-tc-game-refresh'))void refresh();
 else if(b.hasAttribute('data-tc-game-action'))void mutate(b.dataset.tcGameAction);
 else if(b.hasAttribute('data-tc-game-cell')){
  const value=Number(b.dataset.tcGameCell);
  if(Number.isInteger(value)&&value>=0&&value<9)void mutate('move',value);
 }
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 const id=auth.state().user?.id||'';
 if(id!==owner){
  epoch++;owner=id;current=null;roomId='';failed=false;pending=false;actionError='';
  if($('#tc-real-room-game')&&typeof closeSheet==='function')closeSheet();
 }
});
document.addEventListener('visibilitychange',()=>{
 if(!document.hidden&&inside())void refresh();
});
setInterval(()=>{
 if(!document.hidden&&inside()&&!pending)void refresh();
},5000);
window.TotiRoomGames=Object.freeze({open,refresh,isInstalled:()=>true});
})();
