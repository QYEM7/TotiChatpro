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
  String? _pendingId,_pendingText;
  final List<int?> _cursors = <int?>[null];
  int _page = 0;
  int? _lastConfirmedRead;
  bool _readReceiptError = false;

  @override
  void initState(){super.initState();_refresh();}

  Future<List<Map<String,dynamic>>> _loadPage(int? before) async {
    final items = await widget.api.thread(widget.peerId, before: before);
    final lastIncoming = TotiChatServices.lastIncomingDmId(
      items, widget.peerId);
    if (lastIncoming != null &&
        (_lastConfirmedRead == null || lastIncoming > _lastConfirmedRead!)) {
      try {
        await widget.api.markDmRead(widget.peerId, lastIncoming);
        _lastConfirmedRead = lastIncoming;
        _readReceiptError = false;
      } catch (_) {
        // A failed receipt never claims messages were read on the server.
        _readReceiptError = true;
      }
    }
    return items;
  }

  void _refresh({bool newest=false}) => setState(() {
    if (newest) {
      _page = 0;
      _cursors..clear()..add(null);
    }
    _future = _loadPage(_cursors[_page]);
  });

  void _older(List<Map<String,dynamic>> currentPage) {
    if (currentPage.length < TotiChatServices.dmPageLimit) return;
    final cursor = (currentPage.first['id'] as num).toInt();
    _cursors.removeRange(_page + 1, _cursors.length);
    _cursors.add(cursor);
    setState(() {
      _page++;
      _future = _loadPage(cursor);
    });
  }

  void _newer() {
    if (_page == 0) return;
    setState(() {
      _page--;
      _future = _loadPage(_cursors[_page]);
    });
  }

  Future<void> _send() async {
    final value=_text.text.trim();
    if(_sending||value.isEmpty)return;
    if(_pendingId!=null && _pendingText!=value){
      showApiError(context,'An earlier message has an unknown result. '
        'Retry exactly the same message before sending a new one.');
      return;
    }
    setState(()=>_sending=true);
    _pendingText=value;
    _pendingId??=TotiChatServices.requestId();
    try{
      await widget.api.sendDm(widget.peerId,value,_pendingId!);
      if(!mounted)return;
      _pendingId=null;_pendingText=null;_text.clear();_refresh(newest:true);
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
        IconButton(onPressed:()=>_refresh(newest:true),
          tooltip:'Show newest messages',
          icon:const Icon(Icons.refresh))]),
      body:Column(children:[
        Expanded(child:ServerPanel<List<Map<String,dynamic>>>(
          future:_future,retry:_refresh,builder:(context,items){
            return Column(children:[
              Padding(
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                child:Row(children:[
                  Expanded(child:Text('Messages · page ${_page + 1}',
                    style:const TextStyle(
                      fontSize:12,fontWeight:FontWeight.w700))),
                  TextButton(
                    onPressed:_page==0?null:_newer,
                    child:const Text('Newer')),
                  TextButton(
                    onPressed:items.length<TotiChatServices.dmPageLimit
                      ?null:()=>_older(items),
                    child:const Text('Older 80')),
                ])),
              if(_readReceiptError)
                const Padding(
                  padding:EdgeInsets.symmetric(horizontal:12),
                  child:Text('Read status could not be confirmed. '
                    'Messages remain available.',
                    style:TextStyle(fontSize:11,color:Colors.deepOrange))),
              Expanded(child:items.isEmpty
                ?const NoRecords('لا توجد رسائل في هذه الصفحة.')
                :ListView.builder(
                  padding:const EdgeInsets.all(14),
                  itemCount:items.length,
                  itemBuilder:(context,i){
                    final msg=items[i],mine=msg['sender_id']==widget.api.userId;
                    return Align(
                      alignment:mine?Alignment.centerRight:Alignment.centerLeft,
                      child:Card(
                        color:mine?const Color(0xFFEDE7FA):Colors.white,
                        child:Padding(padding:const EdgeInsets.all(12),
                          child:Text(msg['body']?.toString()??''))));
                  },
                )),
            ]);
          })),
        SafeArea(child:Padding(padding:const EdgeInsets.all(10),
          child:Row(children:[
            Expanded(child:TextField(controller:_text,maxLength:2000,
              readOnly:_sending||_pendingId!=null,
              decoration:const InputDecoration(hintText:'رسالة نصية…',counterText:''))),
            IconButton.filled(onPressed:_sending?null:_send,icon:const Icon(Icons.send))
          ]))),
      ]),
    ),
  );
}
