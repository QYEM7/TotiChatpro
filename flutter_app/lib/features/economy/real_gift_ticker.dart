import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A real inserted, authenticated announcement triggers the banner.
/// No periodic DB reads or fake marketing events.
class RealGiftTicker extends StatefulWidget {
  const RealGiftTicker({super.key, required this.client});
  final SupabaseClient client;
  @override State<RealGiftTicker> createState() => _RealGiftTickerState();
}

class _RealGiftTickerState extends State<RealGiftTicker> {
  Map<String,dynamic>? _event;
  late final RealtimeChannel _channel;
  Timer? _expiry;

  @override void initState(){
    super.initState();
    _channel=widget.client.channel('totichat-global-gifts')
      .onPostgresChanges(
        event:PostgresChangeEvent.insert,
        schema:'public',
        table:'gift_global_announcements',
        callback:(payload){
          final row=Map<String,dynamic>.from(payload.newRecord);
          final total=(row['total_coins'] as num?)?.toInt()??0;
          final created=DateTime.tryParse(row['created_at']?.toString()??'');
          if(total<7000||created==null||
              DateTime.now().toUtc().difference(created.toUtc()).inSeconds>30){
            return;
          }
          if(!mounted)return;
          _expiry?.cancel();
          setState(()=>_event=row);
          _expiry=Timer(const Duration(seconds:11),(){
            if(mounted)setState(()=>_event=null);
          });
        },
      ).subscribe();
  }

  @override void dispose(){
    _expiry?.cancel();
    unawaited(widget.client.removeChannel(_channel));
    super.dispose();
  }

  @override Widget build(BuildContext context){
    final e=_event;
    if(e==null)return const SizedBox.shrink();
    return Material(
      color:const Color(0xFF3A295E),
      child:SafeArea(top:false,bottom:false,child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
        child:Row(children:[
          const Icon(Icons.auto_awesome,color:Color(0xFFFFD77A)),
          const SizedBox(width:10),
          Expanded(child:Text(
            '${e['sender_name']??'عضو'} أرسل ${e['gift_name']??'هدية'}'
            ' × ${e['quantity']??1} إلى ${e['recipient_name']??'عضو'}',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700))),
        ]),
      )),
    );
  }
}
