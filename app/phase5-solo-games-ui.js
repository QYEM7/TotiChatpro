/* TotiChat: real no-stakes single-player tic-tac-toe vs LOCAL algorithm.
 * Offline game logic is playable, not a fictitious online user. The verified
 * room voice session is never changed; no DB/media/wallet calls.
 */
(function(){
'use strict';
const auth=window.TotiPhase2Auth,rooms=window.TotiPhase2Rooms;
if(!auth||!rooms||!window.TotiLiveMode?.enabled)return;
const $=s=>document.querySelector(s);
const values=['X','O','.'];
let owner='',room='',board=Array(9).fill('.'),finished=false,result='',epoch=0;
function valid(){
 return auth.state().signedIn===true&&auth.state().user?.id===owner&&
   rooms.getRoomSummary?.()?.id===room&&
   $('#tc-ttt-solo-game')!==null&&
   $('#overlay')?.classList.contains('show')===true;
}
function won(b,symbol){
 for(const line of [[0,1,2],[3,4,5],[6,7,8],
  [0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]){
  if(line.every(i=>b[i]===symbol))return true;
 }
 return false;
}
function candidate(symbol){
 for(let i=0;i<9;i++){
  if(board[i]!=='.')continue;
  board[i]=symbol;
  const win=won(board,symbol);board[i]='.';
  if(win)return i;
 }
 return -1;
}
function botMove(){
 // A real deterministic game engine. Never calls an AI/chat service
 // or impersonates a real room user.
 const win=candidate('O');
 if(win>=0)return win;
 const block=candidate('X');
 if(block>=0)return block;
 for(const i of [4,0,2,6,8,1,3,5,7])if(board[i]==='.')return i;
 return -1;
}
function print(){
 if(!valid())return;
 const root=$('#tc-solo-board'),state=$('#tc-solo-state');
 if(!root||!state)return;
 root.replaceChildren();
 const marks=board.filter(x=>x!=='.').length;
 state.textContent=finished?result:
   'ألعب أنت بعلامة ✕، والخصم الآلي المحلي بعلامة ◯. النقلات: '+marks+'/9';
 for(let i=0;i<9;i++){
  const b=document.createElement('button');b.type='button';
  b.className='tc-ttt-cell';b.dataset.tcSoloCell=String(i);
  b.setAttribute('aria-label','خانة '+(i+1));
  b.textContent=board[i]==='X'?'✕':board[i]==='O'?'◯':'';
  b.disabled=finished||board[i]!=='.';root.appendChild(b);
 }
}
function restart(){
 board=Array(9).fill('.');finished=false;result='';print();
}
function move(i){
 if(!valid()||finished||!Number.isInteger(i)||i<0||i>8||board[i]!=='.')return;
 board[i]='X';
 if(won(board,'X')){finished=true;result='فزت بهذه الجولة!';print();return}
 if(!board.includes('.')){finished=true;result='تعادل — انتهت الجولة';print();return}
 const reply=botMove();
 if(reply>=0&&board[reply]==='.')board[reply]='O';
 if(won(board,'O')){finished=true;result='فاز الخصم الآلي المحلي';print();return}
 if(!board.includes('.')){finished=true;result='تعادل — انتهت الجولة'}
 print();
}
function open(){
 const user=auth.state().user?.id,roomState=rooms.getRoomSummary?.();
 if(!auth.state().signedIn||!user||!roomState?.id||typeof showSheet!=='function')return;
 owner=user;room=roomState.id;epoch++;
 showSheet('<section id="tc-ttt-solo-game" class="tc-ttt-solo-game" dir="rtl">'+
 '<header><h3>🎮 إكس-أو — فردي</h3><button type="button" data-a="close" aria-label="إغلاق">✕</button></header>'+
 '<p>تلعب ضد خوارزمية محلية، مو حساب وهمي. بدون جوائز أو رهانات. ما تنقطع من الغرفة.</p>'+
 '<p id="tc-solo-state" role="status" aria-live="polite"></p>'+
 '<div id="tc-solo-board" class="tc-ttt-board"></div>'+
 '<div class="tc-ttt-solo-actions"><button data-tc-solo-reset type="button">جولة جديدة</button>'+
 '<button data-tc-duo-launch type="button">اللعب الجماعي مع عضو</button></div></section>',true);
 restart();
}
document.addEventListener('click',e=>{
 const b=e.target?.closest?.('[data-tc-solo-launch],[data-tc-duo-launch],[data-tc-solo-reset],[data-tc-solo-cell]');
 if(!b)return;
 e.preventDefault();e.stopImmediatePropagation();
 if(b.hasAttribute('data-tc-solo-launch')){open();return}
 if(b.hasAttribute('data-tc-duo-launch')){
  if(valid())window.TotiRoomGames?.open?.();return;
 }
 if(!valid())return;
 if(b.hasAttribute('data-tc-solo-reset'))restart();
 else if(b.hasAttribute('data-tc-solo-cell'))move(Number(b.dataset.tcSoloCell));
},true);
window.addEventListener('totichat-phase2-auth',()=>{
 const next=auth.state().user?.id||'';
 if(next===owner)return;
 epoch++;owner=next;room='';board=Array(9).fill('.');result='';finished=false;
 if($('#tc-ttt-solo-game')&&typeof closeSheet==='function')closeSheet();
});
window.TotiSoloGames=Object.freeze({open,isInstalled:()=>true});
})();
