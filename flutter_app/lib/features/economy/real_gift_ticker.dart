import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real server events only: global strip is absent unless a recent verified
/// gift announcement of at least 7,000 coins exists.
class RealGiftTicker extends StatefulWidget {
  const RealGiftTicker({super.key,required this.client});
  final SupabaseClient client;
  @override State<RealGiftTicker> createState()=>_RealGiftTickerState();
}
class _RealGiftTickerState extends State<RealGiftTicker>{
  Map<String,dynamic>? _event;
  Timer? _timer;
  bool _loading=false;
  @override void initState(){
    super.initState();
    _load();
    _timer=Timer.periodic(const Duration(seconds:15),(_)=>_load());
  }
  Future<void> _load() async{
    if(_loading||widget.client.auth.currentUser==null)return;
    _loading=true;
    try{
      final rows=await widget.client.from('gift_global_announcements')
        .select('id,gift_name,gift_icon,sender_name,recipient_name,'
          'quantity,total_coins,created_at')
        .gte('total_coins',7000).order('created_at',ascending:false).limit(1);
      Map<String,dynamic>? result;
      if(rows.isNotEmpty){
        final row=Map<String,dynamic>.from(rows.first);
        final created=DateTime.tryParse(row['created_at']?.toString()??'');
        if(created!=null &&
            DateTime.now().toUtc().difference(created.toUtc()).inSeconds < 25 &&
            (row['total_coins'] as num?)!=null &&
            (row['total_coins'] as num)>=(7000)){
          result=row;
        }
      }
      if(mounted)setState(()=>_event=result);
    }catch(_){
      // Fail closed: do not show an outdated or imaginary gift on network errors.
      if(mounted)setState(()=>_event=null);
    }finally{_loading=false;}
  }
  @override void dispose(){_timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){
    final e=_event;
    if(e==null)return const SizedBox.shrink();
    return Material(
      color:const Color(0xFF3A295E),
      child:SafeArea(bottom:false,top:false,child:Padding(
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
