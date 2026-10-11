/* Real text-only DMs for TotiChat Staging. Works above the live room without
 * changing its microphone, LiveKit session, seat or navigation stack. */
(function(){
'use strict';
const auth=window.TotiPhase2Auth;
if(!auth||!window.TotiLiveMode?.enabled)return;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const $=s=>document.querySelector(s);
const getUser=()=>auth.state().user?.id||'';
let peer=null,peerName='',overlay=null,account=getUser(),epoch=0,sendBusy=false,pending=null,refreshing=null,inboxRefreshing=null,previousInbox=null;
const rpc=(name,args)=>auth.requestData('/rest/v1/rpc/phase2_dm_'+name,{method:'POST',body:args});
const toast=s=>typeof showToast==='function'&&showToast(String(s).slice(0,170));
const owns=(e,u)=>e===epoch&&getUser()===u&&auth.state().signedIn;
const msg=()=>$('#tc-dm-messages');
const status=s=>{const e=$('#tc-dm-status');if(e)e.textContent=s||'';};
function safeClose(){
 epoch++;peer=null;peerName='';sendBusy=false;pending=null;
 overlay?.remove();overlay=null;
}
function inboxView(){
 return '<div class="tc-dm-inbox" dir="rtl">'+
 '<div class="pagehead"><strong>الرسائل الخاصة</strong><span>💬</span></div>'+
 '<p class="tc-dm-explainer">مراسلات نصية حقيقية ومحفوظة. لا توجد مكالمات أو تسجيلات صوتية خاصة.</p>'+
 '<p data-tc-dm-inbox-status role="status">جارٍ تحميل المحادثات الحقيقية…</p>'+
 '<div id="tc-dm-inbox-list"></div>'+
 '<button type="button" class="tc-dm-reload" data-tc-dm-reload>تحديث المحادثات</button>'+
 '</div>';
}
const oldMsgs=typeof vMessages==='function'?vMessages:null;
const oldChat=typeof vChat==='function'?vChat:null;
if(oldMsgs)vMessages=function(){
 return auth.state().signedIn&&window.TotiLiveMode?.enabled?inboxView():oldMsgs.apply(this,arguments);
};
if(oldChat)vChat=function(){
 return auth.state().signedIn&&window.TotiLiveMode?.enabled?
 '<div class="tc-dm-inbox" dir="rtl"><h2>الرسائل الخاصة</h2><p>افتح محادثتك الحقيقية من قائمة الرسائل أو من أعضاء الغرفة.</p><button data-a="go" data-v="messages">قائمة الرسائل</button></div>':
 oldChat.apply(this,arguments);
};
const baseRender=render;
render=function(){
 const result=baseRender.apply(this,arguments);
 if(auth.state().signedIn&&screen==='messages')void loadInbox();
 return result;
};
function newNode(tag,cls,txt){
 const node=document.createElement(tag);if(cls)node.className=cls;
 if(txt!==undefined)node.textContent=String(txt);return node;
}
async function loadInbox(){
 const node=$('#tc-dm-inbox-list'),label=$('[data-tc-dm-inbox-status]');
 if(!node||!getUser())return;
 const stamp=epoch,owner=getUser();
 if(inboxRefreshing?.node===node&&inboxRefreshing?.owner===owner)return;
 const request={node,owner,stamp};
 inboxRefreshing=request;
 try{
  const rows=await rpc('inbox',{p_limit:40});
  if(!owns(stamp,owner)||!node.isConnected)return;
  if(!Array.isArray(rows))throw Error('استجابة المحادثات غير صالحة');
  previousInbox=rows;node.replaceChildren();
  if(!rows.length)node.appendChild(newNode('p','tc-dm-empty','ما عندك محادثات حالياً. اختار عضواً من قائمة الغرفة حتى تبدأ المحادثة.'));
  for(const row of rows){
   if(!uuid.test(row.other_user_id))continue;
   const b=newNode('button','tc-dm-contact');b.type='button';b.dataset.tcDmRecipient=row.other_user_id;
   b.dataset.tcDmName=row.other_display_name||'مستخدم';
   const title=newNode('b','',row.other_display_name||'مستخدم');
   const body=newNode('small','',row.last_body||'');
   const count=newNode('span','',Number(row.unread_count)>0?'● '+row.unread_count:'›');
   b.append(title,body,count);node.appendChild(b);
  }
  if(label)label.textContent=rows.length+' محادثة حقيقية';
 }catch(e){
  if(owns(stamp,owner)&&label?.isConnected)label.textContent='تعذّر تحميل الرسائل: '+String(e.message).slice(0,130);
 }finally{if(inboxRefreshing===request)inboxRefreshing=null;}
}
async function openConversation(id,name){
 if(!uuid.test(id)||!getUser()||id===getUser())return;
 if(overlay)overlay.remove();
 const stamp=++epoch,owner=getUser();
 peer=id;peerName=String(name||'مستخدم').slice(0,80);pending=null;sendBusy=false;
 overlay=newNode('section','tc-dm-overlay');
 overlay.id='tc-dm-overlay';overlay.dir='rtl';overlay.setAttribute('role','dialog');
 overlay.setAttribute('aria-modal','true');overlay.setAttribute('aria-label','محادثة خاصة كتابية مع '+peerName);
 overlay.innerHTML='<header class="tc-dm-head"><button type="button" data-tc-dm-close aria-label="إغلاق المحادثة">‹</button><strong></strong><span>✉️ نص فقط</span></header>'+
 '<p class="tc-dm-notice">محادثة خاصة نصية — تستمر الغرفة الصوتية والمقعد والمايك بالخلفية.</p>'+
 '<div id="tc-dm-status" role="status" aria-live="polite">جارٍ تحميل المحادثة…</div>'+
 '<div id="tc-dm-messages" class="tc-dm-messages"></div>'+
 '<form id="tc-dm-form" class="tc-dm-compose"><input name="text" maxlength="2000" autocomplete="off" placeholder="اكتب رسالة خاصة…" aria-label="الرسالة النصية" required><button type="submit">إرسال</button></form>'+
 '<footer class="tc-dm-footer"><button type="button" data-tc-dm-block>🚫 حظر المستخدم</button><button type="button" data-tc-dm-close>إغلاق والعودة</button></footer>';
 overlay.querySelector('strong').textContent=peerName;
 document.body.appendChild(overlay);
 overlay.querySelector('input').focus();
 await loadThread(stamp,owner);
}
async function loadThread(stamp=epoch,owner=getUser()){
 if(!peer||!owns(stamp,owner))return;
 const recipient=peer,request=stamp+'|'+owner+'|'+recipient;
 if(refreshing===request)return;
 refreshing=request;
 try{
  const rows=await rpc('thread',{p_other_user:recipient,p_before_id:null,p_limit:100});
  if(!owns(stamp,owner)||peer!==recipient||!overlay?.isConnected)return;
  if(!Array.isArray(rows))throw Error('استجابة المحادثة غير صالحة');
  const area=msg();if(!area)return;area.replaceChildren();
  for(const item of rows.slice().reverse()){
   const bubble=newNode('div','tc-dm-bubble'+(item.sender_id===owner?' own':''),item.body);
   const ts=newNode('small','tc-dm-time',new Date(item.created_at).toLocaleTimeString('ar-IQ',{hour:'2-digit',minute:'2-digit'}));
   bubble.appendChild(ts);area.appendChild(bubble);
  }
  if(!rows.length)area.appendChild(newNode('p','tc-dm-empty','لا توجد رسائل سابقة. اكتب أول رسالة.'));
  area.scrollTop=area.scrollHeight;
  status('');
  const unread=rows.filter(x=>x.recipient_id===owner&&!x.read_at);
  if(unread.length)void rpc('mark_read',{p_other_user:peer,p_through_id:unread[0].id}).catch(()=>{});
 }catch(e){if(owns(stamp,owner))status('تعذّر تحميل المحادثة: '+String(e.message).slice(0,150))}
 finally{if(refreshing===request)refreshing=null;}
}
async function sendMessage(form){
 if(sendBusy||!peer||!getUser())return;
 const field=form.querySelector('input');
 const text=String(field?.value||'').trim();
 if(text.length<1||text.length>2000){status('اكتب رسالة نصية من حرف إلى 2000 حرف');return;}
 const stamp=epoch,owner=getUser(),recipient=peer;
 if(!pending||pending.text!==text||pending.recipient!==recipient)pending={text,recipient,id:crypto.randomUUID()};
 sendBusy=true;
 const button=form.querySelector('button');button.disabled=true;status('جارٍ إرسال الرسالة…');
 try{
  const result=await rpc('send',{p_recipient_id:recipient,p_body:text,p_request_id:pending.id});
  if(!owns(stamp,owner)||peer!==recipient)return;
  if(result?.sent!==true)throw Error('الخادم لم يؤكد الرسالة');
  pending=null;field.value='';status('تم الإرسال');await loadThread(stamp,owner);
 }catch(e){
  if(owns(stamp,owner))status('فشل الإرسال: '+String(e.message).slice(0,130)+' — تگدر تعيد المحاولة بدون تكرار الرسالة.');
 }finally{sendBusy=false;if(button?.isConnected)button.disabled=false;}
}
document.addEventListener('click',e=>{
 const member=e.target.closest('[data-tc-dm-recipient]');
 if(member){
  e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();
  const id=member.dataset.tcDmRecipient;
  if(uuid.test(id))void openConversation(id,member.dataset.tcDmName||'مستخدم');
  return;
 }
 if(e.target.closest('[data-tc-dm-close]')){e.preventDefault();safeClose();if(screen==='messages')void loadInbox();return;}
 if(e.target.closest('[data-tc-dm-reload]')){e.preventDefault();void loadInbox();return;}
 if(e.target.closest('[data-tc-dm-block]')){
  e.preventDefault();const id=peer;
  if(!id||!confirm('حظر هذا المستخدم من الرسائل الخاصة؟'))return;
  void rpc('block',{p_other_user:id,p_block:true}).then(()=>{safeClose();toast('تم حظر المستخدم');}).catch(err=>status(String(err.message)));
 }
},true);
document.addEventListener('submit',event=>{
 if(event.target?.id!=='tc-dm-form')return;
 event.preventDefault();event.stopImmediatePropagation();
 void sendMessage(event.target);
},true);
window.addEventListener('totichat-private-message-update',()=>{
 if(!auth.state().signedIn)return;
 if(overlay&&peer)void loadThread();
 if(screen==='messages')void loadInbox();
});
window.addEventListener('totichat-phase2-auth',()=>{
 const id=getUser();
 if(id!==account){account=id;safeClose();previousInbox=null;}
});
document.addEventListener('visibilitychange',()=>{if(!document.hidden){if(overlay&&peer)void loadThread();if(screen==='messages')void loadInbox();}});
window.addEventListener('online',()=>{if(overlay&&peer)void loadThread();if(screen==='messages')void loadInbox();});
setInterval(()=>{if(!auth.state().signedIn||document.hidden)return;
 if(overlay&&peer)void loadThread();
 if(screen==='messages')void loadInbox();
},6500);
window.TotiPrivateMessages=Object.freeze({
 open:(userId,name)=>openConversation(userId,name),
 close:safeClose,
 refresh:()=>overlay?loadThread():loadInbox()
});
})();
