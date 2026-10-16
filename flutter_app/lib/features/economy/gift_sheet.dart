import 'package:flutter/material.dart';
import '../../data/totichat_services.dart';
import '../../models/room_models.dart';
import '../../ui/server_panel.dart';
import 'lucky_gift_panel.dart';

class GiftSheet extends StatefulWidget {
  const GiftSheet({
    super.key,required this.api,required this.roomId,required this.members,
  });
  final TotiChatServices api;
  final String roomId;
  final List<RoomMember> members;
  @override State<GiftSheet> createState()=>_GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet>{
  late Future<List<Map<String,dynamic>>> _catalog;
  Map<String,dynamic>? _selected;
  String? _recipient,_pendingId,_pendingSignature;
  bool _showLucky=false;
  int _quantity=1;
  bool _busy=false;
  @override void initState(){super.initState();_catalog=widget.api.gifts();}

  Future<void> _send() async{
    final item=_selected,recipient=_recipient;
    if(_busy||item==null||recipient==null)return;
    final price=(item['price'] as num?)?.toInt();
    if(price==null||price<1)return;
    final total=price*_quantity;
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>
      AlertDialog(title:const Text('تأكيد الهدية'),
        content:Text('إرسال ${item['name']} × $_quantity بقيمة $total كوين؟'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال')),
        ]));
    if(confirmed!=true||!mounted)return;
    final signature = [
      widget.roomId, recipient, item['id'], _quantity, price,
    ].join('|');
    if(_pendingSignature!=null && _pendingSignature!=signature){
      showApiError(context,'The earlier gift needs verification before '
        'changing its recipient, amount or item.');
      return;
    }
    _pendingSignature=signature;
    setState(()=>_busy=true);
    _pendingId??=TotiChatServices.requestId();
    try{
      await widget.api.sendGift(roomId:widget.roomId,recipientId:recipient,
        gift:item,quantity:_quantity,requestId:_pendingId!);
      _pendingId=null;_pendingSignature=null;
      if(mounted)Navigator.pop(context,true);
    }catch(error){if(mounted)showApiError(context,error);}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context){
    final participants=widget.members.where((m)=>m.seatNo!=null).toList();
    return SafeArea(child:Padding(
      padding:EdgeInsets.fromLTRB(16,20,16,16+MediaQuery.viewInsetsOf(context).bottom),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('صندوق الهدايا الحقيقية',
          style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
        const SizedBox(height:10),
        Wrap(spacing:8,children:[
          ChoiceChip(label:const Text('Regular gifts'),
            selected:!_showLucky,
            onSelected:_busy?null:(_)=>setState(()=>_showLucky=false)),
          ChoiceChip(label:const Text('Lucky Gifts'),
            selected:_showLucky,
            onSelected:_busy?null:(_)=>setState(()=>_showLucky=true)),
        ]),
        const SizedBox(height:10),
        if(_showLucky)
          LuckyGiftPanel(api:widget.api)
        else ...[
        SizedBox(height:165,child:ServerPanel<List<Map<String,dynamic>>>(
          future:_catalog,retry:()=>setState(()=>_catalog=widget.api.gifts()),
          builder:(context,items){
            final available=items.where((g)=>g['is_active']==true &&
              g['diamond_source_type']!='LUCKY_GIFT').toList();
            if(available.isEmpty)return const NoRecords('ماكو هدايا متاحة حالياً.');
            return ListView(scrollDirection:Axis.horizontal,children:available.map((g)=>
              Padding(padding:const EdgeInsets.all(5),
                child:ChoiceChip(
                  selected:_selected?['id']==g['id'],
                  onSelected:_busy||_pendingId!=null?null:(_){
                    setState(() {_selected=g;});
                  },
                  avatar:const Icon(Icons.card_giftcard_rounded),
                  label:Column(mainAxisSize:MainAxisSize.min,children:[
                    Text(g['name']?.toString()??'هدية'),
                    Text('${g['price']} كوين'),
                  ]),
                ))).toList());
          })),
        if(participants.isEmpty)const NoRecords('لا يوجد مستلم جالس على مقعد.') else
          DropdownButtonFormField<String>(
            initialValue:participants.any((m)=>m.userId==_recipient)?_recipient:null,
            hint:const Text('اختر المستلم من المقاعد'),
            items:participants.map((m)=>DropdownMenuItem(value:m.userId,
              child:Text(m.displayName,maxLines:1))).toList(),
            onChanged:_busy||_pendingId!=null?null:(v)=>setState((){_recipient=v;}),
          ),
        const SizedBox(height:8),
        const Text('العدد'),
        Wrap(spacing:8,children:[1,7,17,77,777].map((n)=>
          ChoiceChip(selected:_quantity==n,label:Text('$n'),
            onSelected:_busy||_pendingId!=null?null:(_)=>setState((){_quantity=n;}))).toList()),
        const SizedBox(height:12),
        FilledButton.icon(
          onPressed:_busy||_selected==null||_recipient==null?null:_send,
          icon:_busy?const SizedBox(height:15,width:15,child:CircularProgressIndicator(strokeWidth:2)):
            const Icon(Icons.send_rounded),
          label:const Text('إرسال بعد موافقة الخادم'),
        ),
        ],
      ]),
    ));
  }
}
