import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/reference_visuals.dart';
import '../core/ui_text.dart';

/// Approved notification screen #12. Strictly read user's real records.
class ReferenceNotificationsScreen extends StatefulWidget {
  const ReferenceNotificationsScreen({super.key});
  @override
  State<ReferenceNotificationsScreen> createState() => _ReferenceNotificationsState();
}

class _ReferenceNotificationsState extends State<ReferenceNotificationsScreen> {
  bool _unread = false;
  late Future<List<Map<String, dynamic>>> _future = _read();

  Future<List<Map<String, dynamic>>> _read() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('No authenticated user');
    final data = await Supabase.instance.client
      .from('user_notifications')
      .select('id,event_type,created_at,read_at')
      .eq('recipient_id', userId)
      .order('created_at', ascending: false)
      .limit(70);
    return (data as List).map((row) =>
      Map<String, dynamic>.from(row as Map)).toList(growable: false);
  }

  Future<void> _refresh() async {
    final next = _read();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder displays an error.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ReferencePalette.canvas,
    appBar: AppBar(
      title: Text(UiText.get('reference_notifications_title'),
        style: const TextStyle(fontWeight: FontWeight.w900)),
      actions: [IconButton(
        tooltip: UiText.get('refresh'),
        icon: const Icon(Icons.refresh),
        onPressed: _refresh,
      )],
    ),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        child: Row(children: [
          _filter(UiText.get('notifications_all_reference'), false),
          const SizedBox(width: 10),
          _filter(UiText.get('notifications_unread_reference'), true),
        ]),
      ),
      Expanded(child: FutureBuilder<List<Map<String,dynamic>>>(
        future: _future,
        builder: (context,snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: ReferencePalette.teal));
          }
          if (snapshot.hasError) {
            return Center(child: Text(UiText.get('notifications_failed_reference')));
          }
          final rows = snapshot.requireData.where((record) =>
            !_unread || record['read_at'] == null).toList(growable:false);
          if (rows.isEmpty) {
            return RefreshIndicator(onRefresh:_refresh,
              child: ListView(children: [
                const SizedBox(height: 60),
                const Icon(Icons.notifications_none_rounded,
                  size: 66, color: ReferencePalette.teal),
                const SizedBox(height: 16),
                Text(UiText.get('notifications_empty_reference'),
                  textAlign:TextAlign.center,
                  style:const TextStyle(color:ReferencePalette.ink,fontSize:17)),
              ]));
          }
          return RefreshIndicator(
            onRefresh:_refresh,
            child: ListView.separated(
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
              itemCount:rows.length,
              separatorBuilder:(_,_)=>const SizedBox(height:8),
              itemBuilder:(context,index) {
                final record=rows[index];
                return Material(
                  color: Colors.white,
                  borderRadius:BorderRadius.circular(16),
                  child: Padding(
                    padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
                    child:Row(children:[
                      CircleAvatar(radius:24,backgroundColor:ReferencePalette.mint,
                        child:Icon(_icon(record['event_type']?.toString()),
                          color:ReferencePalette.teal,size:24)),
                      const SizedBox(width:10),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(record['event_type']?.toString() ?? '',
                          style:const TextStyle(fontSize:13,
                            color:ReferencePalette.ink,fontWeight:FontWeight.w800)),
                        Text(record['created_at']?.toString().replaceFirst('T',' ').split('.').first ?? '',
                          maxLines:1,overflow:TextOverflow.ellipsis,
                          style:const TextStyle(fontSize:11,color:Color(0xFF84968C))),
                      ])),
                      if(record['read_at']==null)
                        const CircleAvatar(radius:5,backgroundColor:Color(0xFFDA505F)),
                    ]),
                  ),
                );
              },
            ),
          );
        },
      )),
    ]),
  );

  Widget _filter(String label,bool target) => Expanded(
    child:ChoiceChip(
      selected:_unread==target,
      label:Center(child:Text(label,
        style:const TextStyle(fontWeight:FontWeight.w700))),
      onSelected:(_)=>setState(()=>_unread=target),
      selectedColor:ReferencePalette.teal,
      labelStyle:TextStyle(color:_unread==target?Colors.white:ReferencePalette.ink),
      backgroundColor:Colors.white,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
    ),
  );

  IconData _icon(String? event) {
    if(event==null)return Icons.notifications_none_rounded;
    if(event.contains('gift'))return Icons.card_giftcard;
    if(event.contains('message'))return Icons.chat_bubble_outline;
    if(event.contains('follow'))return Icons.person_add_alt;
    return Icons.notifications_none_rounded;
  }
}
