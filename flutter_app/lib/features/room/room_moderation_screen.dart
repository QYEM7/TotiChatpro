import 'package:flutter/material.dart';
import '../../data/totichat_services.dart';
import '../../models/room_models.dart';
import '../../ui/server_panel.dart';

/// Owner-only room governance. Each change is checked and audited by Supabase.
class RoomModerationScreen extends StatefulWidget {
  const RoomModerationScreen({super.key,required this.api,
    required this.roomId,required this.members});
  final TotiChatServices api;
  final String roomId;
  final List<RoomMember> members;

  @override State<RoomModerationScreen> createState()=>_RoomModerationScreenState();
}

class _RoomModerationScreenState extends State<RoomModerationScreen>{
  late Future<Map<String,dynamic>> _state;
  bool _busy=false;
  String? _pendingId,_pendingTarget,_pendingAction;

  @override void initState(){super.initState();_refresh();}
  void _refresh()=>setState(() { _state=widget.api.roomModerationState(widget.roomId); });

  Future<void> _act(String peer,String action)async{
    if(_busy||peer==widget.api.userId)return;
    String? reason;
    if(action=='ban'){
      final controller=TextEditingController();
      reason=await showDialog<String>(context:context,builder:(ctx)=>
        AlertDialog(
          title:const Text('حظر عضو وتسجيل السبب'),
          content:TextField(controller:controller,maxLength:300,
            maxLines:3,decoration:const InputDecoration(
              labelText:'سبب الحظر (5–300 حرف)')),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),
              child:const Text('تأكيد الحظر')),
          ],
        ));
      controller.dispose();
      if(reason==null||reason.length<5||!mounted)return;
    }
    final confirm=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(title:const Text('تأكيد إجراء إشرافي'),
        content:Text('الإجراء: $action. سيتم حفظ العملية بسجل الخادم.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('تنفيذ')),
        ]));
    if(confirm!=true||!mounted)return;
    if(_pendingTarget!=peer||_pendingAction!=action){
      _pendingTarget=peer;_pendingAction=action;_pendingId=null;
    }
    _pendingId??=TotiChatServices.requestId();
    setState(()=>_busy=true);
    try{
      await widget.api.moderateRoom(
        roomId:widget.roomId,targetId:peer,action:action,
        reason:reason,requestId:_pendingId!);
      _pendingId=null;_pendingTarget=null;_pendingAction=null;
      if(mounted)_refresh();
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,child:Scaffold(
      appBar:AppBar(title:const Text('إدارة الغرفة'),
        actions:[IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),
      body:ServerPanel<Map<String,dynamic>>(
        future:_state,retry:_refresh,builder:(context,state){
          final mods=(state['moderators'] as List? ?? []).whereType<Map>().toList();
          final bans=(state['bans'] as List? ?? []).whereType<Map>().toList();
          return ListView(padding:const EdgeInsets.all(12),children:[
            const Text('الأعضاء الموجودون',style:TextStyle(
              fontSize:20,fontWeight:FontWeight.w800)),
            const SizedBox(height:8),
            if(widget.members.where((m)=>m.userId!=widget.api.userId).isEmpty)
              const NoRecords('لا يوجد أعضاء آخرون لإدارتهم.'),
            ...widget.members.where((m)=>m.userId!=widget.api.userId).map((m){
              final isMod=mods.any((x)=>x['userId']==m.userId);
              return Card(child:ExpansionTile(
                title:Text(m.displayName),
                subtitle:Text(m.seatNo==null?'مستمع':'مقعد ${m.seatNo}'),
                children:[
                  Wrap(spacing:7,runSpacing:4,children:[
                    _action(m.userId,'mute','كتم'),
                    _action(m.userId,'allow_mic','إلغاء الكتم'),
                    _action(m.userId,'release_seat','إنزال من المقعد'),
                    _action(m.userId,'kick','إخراج'),
                    _action(m.userId,'ban','حظر'),
                    _action(m.userId,isMod?'revoke_moderator':'grant_moderator',
                      isMod?'إلغاء إشراف':'منح مشرف'),
                  ]),
                ],
              ));
            }),
            const SizedBox(height:18),
            const Text('المحظورون',style:TextStyle(
              fontSize:20,fontWeight:FontWeight.w800)),
            if(bans.isEmpty)const NoRecords('ماكو حظر مسجّل.'),
            ...bans.map((b)=>recordCard(context,
              title:b['userId']?.toString()??'مستخدم',
              description:b['reason']?.toString(),
              trailing:TextButton(
                onPressed:_busy||b['userId']==null?null:
                  ()=>_act(b['userId'].toString(),'unban'),
                child:const Text('رفع الحظر')))),
          ]);
        }),
    ),
  );

  Widget _action(String id,String action,String label)=>
    OutlinedButton(onPressed:_busy?null:()=>_act(id,action),
      child:Text(label));
}
