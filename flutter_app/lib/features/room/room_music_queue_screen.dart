import 'package:flutter/material.dart';

import '../../data/room_music_repository.dart';
import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';
import '../../ui/extracted_premium_panels.dart';

/// Shows only actual persisted bookmarks and queue metadata, not audio.
class RoomMusicQueueScreen extends StatefulWidget {
  const RoomMusicQueueScreen({
    super.key, required this.api, required this.roomId, this.roomOwnerId,
  });
  final TotiChatServices api;
  final String roomId;
  final String? roomOwnerId;

  @override
  State<RoomMusicQueueScreen> createState() => _RoomMusicQueueScreenState();
}

class _RoomMusicQueueScreenState extends State<RoomMusicQueueScreen> {
  late final RoomMusicRepository _repo =
    RoomMusicRepository(widget.api.client);
  late Future<List<Object?>> _future;
  bool _busy=false;
  String? _pendingId,_pendingKey;
  Future<void> Function(String)? _pendingAction;

  bool get _isOwner => widget.roomOwnerId == widget.api.userId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future=Future.wait<Object?>([
    _repo.queue(widget.roomId), _repo.savedTracks(),
  ]); });

  Future<void> _execute(String key,
      Future<void> Function(String id) action) async {
    if (_busy) return;
    if (_pendingKey!=null && _pendingKey!=key) {
      showApiError(context,'Retry the unconfirmed previous music change '
        'before starting another one.');
      return;
    }
    _pendingKey=key;
    _pendingAction=action;
    _pendingId??=RoomMusicRepository.newRequestId();
    setState(()=>_busy=true);
    try {
      await action(_pendingId!);
      _pendingKey=null;
      _pendingAction=null;
      _pendingId=null;
      if(mounted)_refresh();
    } catch(error) {
      if(mounted)showApiError(context,error);
    } finally {
      if(mounted)setState(()=>_busy=false);
    }
  }

  Future<void> _addBookmark() async {
    if(_busy)return;
    final title=TextEditingController();
    final artist=TextEditingController();
    final reference=TextEditingController();
    final choice=await showDialog<({String title,String artist,String? url})>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Save music reference'),
        content:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            const Text('Save a title and optional HTTPS reference only. '
              'No audio will be uploaded, downloaded or played.'),
            TextField(controller:title,maxLength:100,
              decoration:const InputDecoration(labelText:'Track title')),
            TextField(controller:artist,maxLength:80,
              decoration:const InputDecoration(labelText:'Artist')),
            TextField(controller:reference,maxLength:500,
              decoration:const InputDecoration(labelText:'HTTPS reference (optional)')),
          ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),
            child:const Text('Cancel')),
          FilledButton(onPressed:(){
            try {
              final values=RoomMusicRepository.validateBookmark(
                title:title.text,artist:artist.text,
                referenceUrl:reference.text);
              Navigator.pop(ctx,(
                title:values['title']!, artist:values['artist']!,
                url:values['reference_url']));
            } catch(error){showApiError(ctx,error);}
          },child:const Text('Save')),
        ]));
    title.dispose();
    artist.dispose();
    reference.dispose();
    if(choice==null||!mounted)return;
    final key='save|${choice.title}|${choice.artist}|${choice.url ?? ''}';
    await _execute(key,(requestId)async{
      await _repo.saveTrack(
        title:choice.title,artist:choice.artist,
        referenceUrl:choice.url,requestId:requestId);
    });
  }

  Future<void> _queueSaved(Map<String,dynamic> bookmark) async {
    if(!_isOwner||_busy)return;
    final bookmarkId=bookmark['id']?.toString()??'';
    if(bookmarkId.isEmpty)return;
    await _execute('queue|${widget.roomId}|$bookmarkId',(requestId)async {
      await _repo.queueTrack(roomId:widget.roomId,bookmark:bookmark,
        requestId:requestId);
    });
  }

  Future<void> _deleteQueue(String id) async {
    if(!_isOwner||_busy||id.isEmpty)return;
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(title:const Text('Remove track from room list?'),
        content:const Text('Only this saved queue entry will be removed.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Remove')),
        ]));
    if(accepted!=true||!mounted)return;
    await _execute('remove-queue|${widget.roomId}|$id',(_)async {
      await _repo.removeQueuedTrack(widget.roomId,id);
    });
  }

  Future<void> _deleteSaved(String id) async {
    if(_busy||id.isEmpty)return;
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(title:const Text('Delete saved track reference?'),
        content:const Text('This may unlink it from room queues. '
          'The queue title remains.'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:const Text('Cancel')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:const Text('Delete')),
        ]));
    if(accepted!=true||!mounted)return;
    await _execute('remove-saved|$id',(_)async{
      await _repo.deleteSavedTrack(id);
    });
  }

  @override
  Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(
      appBar:AppBar(title:const Text('Room music playlist'),
        actions:[IconButton(onPressed:_busy?null:_refresh,
          icon:const Icon(Icons.refresh))]),
      body:ServerPanel<List<Object?>>(future:_future,retry:_refresh,
        builder:(context,result){
          final queue=result[0] as List<Map<String,dynamic>>;
          final saved=result[1] as List<Map<String,dynamic>>;
          final alreadyQueued=queue.map((x)=>x['bookmark_id']).toSet();
          return RefreshIndicator(
            onRefresh:()async{_refresh();await _future;},
            child:ListView(
              physics:const AlwaysScrollableScrollPhysics(),
              padding:const EdgeInsets.all(14),children:[
                const TotiRoyalSectionHeading(
                  title:'قائمة الموسيقى المحفوظة',
                  subtitle:'المراجع محفوظة في الخادم، التشغيل المشترك لم يُفعّل بعد',
                  icon:Icons.queue_music_rounded,
                ),
                const Card(child:Padding(padding:EdgeInsets.all(12),
                  child:Text('This stores server-backed music references, '
                    'not playable tracks. Synchronized playback and '
                    'licensing are not ready. Room voice stays unchanged.'))),
                if(_pendingKey!=null)
                  Card(child:ListTile(
                    title:const Text('Previous operation not confirmed'),
                    subtitle:const Text('Retry the original request ID.'),
                    trailing:TextButton(
                      onPressed:_busy?null:(){
                        final key=_pendingKey,action=_pendingAction;
                        if(key!=null&&action!=null)_execute(key,action);
                      },child:const Text('Retry')))),
                const SizedBox(height:15),
                const Text('Room queue',
                  style:TextStyle(fontWeight:FontWeight.w800,fontSize:20)),
                if(queue.isEmpty)
                  const NoRecords('No room music references saved.'),
                ...queue.map((item)=>recordCard(context,
                  icon:Icons.queue_music_rounded,
                  title:item['title']?.toString()??'Untitled',
                  description:item['artist']?.toString()??'',
                  trailing:_isOwner?IconButton(
                    onPressed:_busy?null:()=>_deleteQueue(
                      item['id']?.toString()??''),
                    tooltip:'Remove room queue entry',
                    icon:const Icon(Icons.remove_circle_outline)):null)),
                const Divider(height:30),
                Row(children:[
                  const Expanded(child:Text('My saved music',
                    style:TextStyle(fontWeight:FontWeight.w800,fontSize:20))),
                  IconButton.filledTonal(
                    onPressed:_busy?null:_addBookmark,
                    icon:const Icon(Icons.add),
                    tooltip:'Save reference'),
                ]),
                if(saved.isEmpty)
                  const NoRecords('No personal music bookmarks yet.'),
                ...saved.map((item)=>recordCard(context,
                  icon:Icons.library_music_outlined,
                  title:item['title']?.toString()??'Untitled',
                  description:[
                    if(item['artist']?.toString().isNotEmpty==true)
                      item['artist'].toString(),
                    if(item['reference_url']!=null)
                      'HTTPS reference saved',
                  ].join(' · '),
                  trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                    if(_isOwner&&!alreadyQueued.contains(item['id']))
                      IconButton(onPressed:_busy?null:()=>_queueSaved(item),
                        icon:const Icon(Icons.playlist_add),
                        tooltip:'Add to this room'),
                    IconButton(onPressed:_busy?null:()=>_deleteSaved(
                      item['id']?.toString()??''),
                      icon:const Icon(Icons.delete_outline),
                      tooltip:'Delete personal bookmark'),
                  ]))),
              ]),
          );
        }),
    ));
}
