import 'package:flutter/material.dart';
import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

class DmInbox extends StatefulWidget {
  const DmInbox({super.key, required this.api});
  final TotiChatServices api;
  @override
  State<DmInbox> createState() => _DmInboxState();
}

class _DmInboxState extends State<DmInbox> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() => setState(() => _future = widget.api.inbox());

  @override
  Widget build(BuildContext context) => ServerPanel<List<Map<String,dynamic>>>(
    future:_future,retry:_refresh,builder:(context,rows) => rows.isEmpty ?
      const NoRecords('لا توجد رسائل خاصة بعد. اختر مستخدماً من البحث أو أعضاء الغرفة.') :
      RefreshIndicator(onRefresh: () async {_refresh();await _future;},
        child: ListView.builder(itemCount:rows.length,itemBuilder:(context,index){
          final item=rows[index], id=item['other_user_id']?.toString()??'';
          return recordCard(context,title:item['other_display_name']?.toString()??'عضو',
            description:item['last_body']?.toString(),
            icon: Icons.mark_chat_unread_outlined,
            trailing:(item['unread_count'] as num? ?? 0)>0 ?
              const Icon(Icons.circle,size:12,color:Colors.deepPurple) : null,
            onTap: id.isEmpty?null:() async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DmThread(api:widget.api,peerId:id,
                  title:item['other_display_name']?.toString()??'محادثة')));
              if(mounted)_refresh();
            });
        })),
  );
}

class DmThread extends StatefulWidget {
  const DmThread({super.key,required this.api,required this.peerId,required this.title});
  final TotiChatServices api;
  final String peerId,title;
  @override
  State<DmThread> createState()=>_DmThreadState();
}

class _DmThreadState extends State<DmThread> {
  late Future<List<Map<String,dynamic>>> _future;
  final _text=TextEditingController();
  bool _sending=false;
  String? _pendingId;
  @override
  void initState(){super.initState();_refresh();}
  void _refresh()=>setState(()=>_future=widget.api.thread(widget.peerId));

  Future<void> _send() async {
    if(_sending||_text.text.trim().isEmpty)return;
    setState(()=>_sending=true);
    _pendingId??=TotiChatServices.requestId();
    try{
      await widget.api.sendDm(widget.peerId,_text.text,_pendingId!);
      if(!mounted)return;
      _pendingId=null;_text.clear();_refresh();
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_sending=false);}
  }

  @override
  void dispose(){_text.dispose();super.dispose();}

  @override
  Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(
      appBar:AppBar(title:Text(widget.title),actions:[
        IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),
      body:Column(children:[
        Expanded(child:ServerPanel<List<Map<String,dynamic>>>(
          future:_future,retry:_refresh,builder:(context,items){
            if(items.isEmpty)return const NoRecords('المحادثة خالية من الرسائل.');
            final last=(items.last['id'] as num).toInt();
            WidgetsBinding.instance.addPostFrameCallback((_){
              widget.api.markDmRead(widget.peerId,last).catchError((Object _) {});
            });
            return ListView.builder(
              padding:const EdgeInsets.all(14),
              itemCount:items.length,
              itemBuilder:(context,i){
                final msg=items[i],mine=msg['sender_id']==widget.api.userId;
                return Align(
                  alignment:mine?Alignment.centerRight:Alignment.centerLeft,
                  child:Card(color:mine?const Color(0xFFEDE7FA):Colors.white,
                    child:Padding(padding:const EdgeInsets.all(12),
                      child:Text(msg['body']?.toString()??''))));
              },
            );
          })),
        SafeArea(child:Padding(padding:const EdgeInsets.all(10),
          child:Row(children:[
            Expanded(child:TextField(controller:_text,maxLength:2000,
              decoration:const InputDecoration(hintText:'رسالة نصية…',counterText:''))),
            IconButton.filled(onPressed:_sending?null:_send,icon:const Icon(Icons.send))
          ]))),
      ]),
    ),
  );
}
