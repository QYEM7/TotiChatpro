import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Agent operations only. End users are never steered to external payment
/// inside the Google Play client. Every operation is reauthorized by server.
class ChargingAgentScreen extends StatefulWidget{
  const ChargingAgentScreen({super.key,required this.api});
  final TotiChatServices api;

  @override State<ChargingAgentScreen> createState()=>_ChargingAgentScreenState();
}

class _ChargingAgentScreenState extends State<ChargingAgentScreen>{
  late Future<Map<String,dynamic>> _state;
  bool _busy=false;
  String? _pendingId,_pendingOp,_pendingAction;
  String? _submittedNote,_submittedRef;

  @override void initState(){super.initState();_refresh();}
  void _refresh()=>setState(()=>_state=widget.api.rechargeState());

  Future<void> _decide(String requestId,String action) async {
    if(_busy)return;
    final note=TextEditingController();
    final receipt=TextEditingController();
    final data=await showDialog<({String note,String? reference})>(
      context:context,builder:(ctx)=>AlertDialog(
        title:Text(action=='approve'?'تأكيد شحن موثق':'رفض طلب الشحن'),
        content:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            const Text('تأكد من استلام المبلغ خارج هذه الشاشة وفق إجراءات الوكالة. '
              'لا يوجد تحصيل مباشر للأموال هنا.'),
            const SizedBox(height:12),
            TextField(controller:note,maxLength:500,
              decoration:const InputDecoration(labelText:'سبب القرار / الملاحظة')),
            if(action=='approve')TextField(controller:receipt,maxLength:120,
              decoration:const InputDecoration(labelText:'مرجع وصل الدفع الحقيقي')),
          ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,(
            note:note.text.trim(),
            reference:action=='approve'?receipt.text.trim():null,
          )),child:const Text('إرسال للخادم')),
        ],
      ));
    note.dispose();receipt.dispose();
    if(data==null||!mounted)return;
    if(_pendingOp!=null&&(_pendingOp!=requestId||_pendingAction!=action)){
      showApiError(context,'An unresolved earlier operation must be verified '
        'before changing the request or action.');
      return;
    }
    if(_pendingOp==null){
      _pendingId=null;_pendingOp=requestId;_pendingAction=action;
      _submittedNote=null;_submittedRef=null;
    }
    _submittedNote??=data.note;
    _submittedRef??=data.reference;
    if(_submittedNote!=data.note||_submittedRef!=data.reference){
      showApiError(context,'لا يمكن تغيير بيانات نفس العملية بعد محاولة سابقة. '
        'إعادة المحاولة تتطلب نفس مرجع العملية تماماً.');
      return;
    }
    _pendingId??=TotiChatServices.requestId();
    setState(()=>_busy=true);
    try{
      await widget.api.decideAgentRequest(
        operationId:requestId,action:action,note:data.note,
        cashReference:data.reference,requestId:_pendingId!);
      _pendingId=null;_pendingOp=null;_pendingAction=null;
      _submittedNote=null;_submittedRef=null;
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('تم تأكيد قرار الوكيل من الخادم')));
        _refresh();
      }
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }

  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:Scaffold(
      appBar:AppBar(title:const Text('عمليات وكيل الشحن'),
        actions:[IconButton(onPressed:_refresh,icon:const Icon(Icons.refresh))]),
      body:ServerPanel<Map<String,dynamic>>(
        future:_state,retry:_refresh,builder:(context,state){
          final uid=widget.api.userId;
          final agencies=(state['agencies'] as List? ?? [])
              .whereType<Map>().where((a)=>a['owner_id']==uid &&
                a['is_active']==true).toList();
          final owner=state['isOwner']==true;
          final canManage=state['canManage']==true;
          if(agencies.isEmpty&&!owner&&!canManage){
            return const NoRecords('لا توجد صلاحية وكيل شحن لهذا الحساب.');
          }
          final agencyIds=agencies.map((e)=>e['id'].toString()).toSet();
          final requests=(state['requests'] as List? ?? []).whereType<Map>()
              .where((r)=>agencyIds.contains(r['agency_id'].toString()))
              .toList();
          return ListView(padding:const EdgeInsets.all(15),children:[
            const Text('لوحة الشحن — عمليات موثقة',
              style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),
            const SizedBox(height:10),
            const Text('هذه شاشة تشغيل الوكيل وليست واجهة شراء للعملاء. '
              'الصلاحيات والخصومات والتسوية يحسمها Backend.'),
            const SizedBox(height:14),
            recordCard(context,
              title:'Verified agency treasury: ${state['treasury']??'Unavailable'}',
              description:'Balances are read from Staging. No client write access.',
              icon:Icons.account_balance_wallet_outlined),
            for(final a in agencies)recordCard(context,
              title:a['name']?.toString()??'وكالة شحن',
              description:'الحالة: فعالة'),
            const SizedBox(height:16),
            const Text('طلبات مرتبطة بوكالاتك',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)),
            if(requests.isEmpty)const NoRecords('لا توجد طلبات شحن مرتبطة بوكالتك.'),
            ...requests.map((r){
              final pending=r['status']=='pending',id=r['id']?.toString()??'';
              return Card(child:Padding(padding:const EdgeInsets.all(13),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('طلب: $id',maxLines:2,
                    style:const TextStyle(fontWeight:FontWeight.w700)),
                  Text('الحالة: ${r['status']??'غير معروفة'}'),
                  Text('الكوينز: ${r['coins']??'—'}'),
                  Text('السعر المسجل: ${r['price_usd']??'—'}'),
                  if(pending&&id.isNotEmpty)
                    Wrap(spacing:8,children:[
                      FilledButton.tonal(onPressed:_busy?null:()=>_decide(id,'approve'),
                        child:const Text('تأكيد وصل حقيقي')),
                      OutlinedButton(onPressed:_busy?null:()=>_decide(id,'reject'),
                        child:const Text('رفض مع سبب')),
                    ]),
                ])));
            }),
          ]);
        }),
    ));
}
