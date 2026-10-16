import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Tic-tac-toe is settled by the real server. The phone never awards wins.
class RoomGameScreen extends StatefulWidget {
  const RoomGameScreen({super.key,required this.api,required this.roomId});
  final TotiChatServices api;
  final String roomId;

  @override State<RoomGameScreen> createState()=>_RoomGameScreenState();
}

class _RoomGameScreenState extends State<RoomGameScreen>{
  late Future<Map<String,dynamic>> _state;
  Timer? _watch;
  bool _busy=false, _fetching=false;
  String? _pendingAction,_pendingId;
  int? _pendingCell;

  @override void initState(){
    super.initState();
    _refresh();
    _watch=Timer.periodic(const Duration(seconds:10),(_)=>_refreshSilently());
  }

  void _refresh()=>setState(()=>_state=widget.api.gameState(widget.roomId));

  Future<void> _refreshSilently()async{
    if(_fetching||_busy||!mounted)return;
    _fetching=true;
    try{
      final newState=await widget.api.gameState(widget.roomId);
      if(mounted)setState(()=>_state=Future.value(newState));
    }catch(_){
      // Offline data must not be interpreted as a fresh game result.
      if(mounted)setState(()=>_state=Future.error(
        StateError('Game update failed: retry connection')));
    }finally{_fetching=false;}
  }

  Future<void> _act(String action,{int? cell})async{
    if(_busy)return;
    if(_pendingAction!=action||_pendingCell!=cell){
      _pendingAction=action;_pendingCell=cell;_pendingId=null;
    }
    _pendingId??=TotiChatServices.requestId();
    setState(()=>_busy=true);
    try{
      final result=await widget.api.gameAction(
        widget.roomId,action,cell,_pendingId!);
      _pendingId=null;_pendingAction=null;_pendingCell=null;
      if(mounted)setState(()=>_state=Future.value(result));
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  @override void dispose(){_watch?.cancel();super.dispose();}

  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(
      appBar:AppBar(title:const Text('إكس-أو داخل الغرفة'),
        actions:[IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),
      body:ServerPanel<Map<String,dynamic>>(
        future:_state,retry:_refresh,builder:(context,game){
          final hasGame=game['hasGame']==true;
          if(!hasGame)return Center(child:Column(
            mainAxisSize:MainAxisSize.min,children:[
              const Icon(Icons.sports_esports_rounded,size:55),
              const SizedBox(height:16),
              const Text('لا توجد جولة حالياً على الخادم'),
              const SizedBox(height:16),
              FilledButton(onPressed:_busy?null:()=>_act('start'),
                child:const Text('ابدأ جولة حقيقية')),
            ]));
          final x=game['playerX']?.toString();
          final o=game['playerO']?.toString();
          final own=widget.api.userId;
          final mark=x==own?'X':o==own?'O':null;
          final board=game['board']?.toString()??'';
          final status=game['status']?.toString()??'unknown';
          final currentMark=game['nextMark']?.toString()??'';
          final myTurn=status=='active'&&mark==currentMark;
          final cells=board.length==9?board:'';
          return ListView(padding:const EdgeInsets.all(22),children:[
            Text('الحالة: $status',textAlign:TextAlign.center,
              style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
            const SizedBox(height:9),
            Text(mark==null?'مشاهد': 'أنت اللاعب $mark',
              textAlign:TextAlign.center),
            if(status=='active')
              Text(myTurn?'دورك الآن':'الدور: $currentMark',
                textAlign:TextAlign.center),
            if(status=='won')Text(
              game['winnerId']==own?'فزت بالجولة!':'انتهت الجولة بالفائز المؤكد',
              textAlign:TextAlign.center),
            if(status=='draw')const Text('تعادل مؤكد من الخادم',
              textAlign:TextAlign.center),
            const SizedBox(height:24),
            if(cells.length==9)
              Center(child:ConstrainedBox(
                constraints:const BoxConstraints(maxWidth:325),
                child:AspectRatio(aspectRatio:1,
                  child:GridView.builder(
                    physics:const NeverScrollableScrollPhysics(),
                    itemCount:9,
                    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:3,mainAxisSpacing:7,crossAxisSpacing:7),
                    itemBuilder:(context,i){
                      final value=cells[i];
                      return FilledButton.tonal(
                        onPressed:_busy||!myTurn||value!='.'?null:
                          ()=>_act('move',cell:i),
                        child:Text(value=='.'?'':value,
                          style:const TextStyle(fontSize:40,
                            fontWeight:FontWeight.w900)),
                      );
                    }),
                ))),
            const SizedBox(height:16),
            if(status=='waiting'&&x!=own)
              FilledButton(onPressed:_busy?null:()=>_act('join'),
                child:const Text('الانضمام كلاعب O')),
            if(status=='waiting'&&x==own)
              const Text('بانتظار خصم ينضم لهذه الجولة',
                textAlign:TextAlign.center),
            if((status=='waiting'||status=='active') &&
                (x==own||o==own))
              OutlinedButton(onPressed:_busy?null:()=>_act('cancel'),
                child:const Text('إلغاء الجولة')),
            if(['won','draw','cancelled'].contains(status))
              FilledButton(onPressed:_busy?null:()=>_act('start'),
                child:const Text('جولة جديدة')),
          ]);
        }),
    ));
}
