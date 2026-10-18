import 'package:flutter/material.dart';
import '../../data/totichat_services.dart';
import 'financial_retry_registry.dart';
import '../../ui/server_panel.dart';
import '../../ui/extracted_premium_panels.dart';
import '../../ui/toti_vip_tiers.dart';

class EconomyScreen extends StatelessWidget {
  const EconomyScreen({super.key,required this.api});
  final TotiChatServices api;

  @override
  Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:DefaultTabController(length:5,child:Scaffold(
      appBar:AppBar(title:const Text('متجر TotiChat'),
        bottom:const TabBar(isScrollable:true,tabs:[
          Tab(text:'المتجر'),Tab(text:'مقتنياتي'),Tab(text:'VIP'),
          Tab(text:'الهدايا'),Tab(text:'الإشعارات'),
        ])),
      body:TabBarView(children:[
        _StoreTab(api:api),_InventoryTab(api:api),
        _VipTab(api:api),_GiftHistoryTab(api:api),_NotificationsTab(api:api),
      ]),
    )),
  );
}

class _StoreTab extends StatefulWidget{
  const _StoreTab({required this.api});final TotiChatServices api;
  @override State<_StoreTab> createState()=>_StoreTabState();
}
class _StoreTabState extends State<_StoreTab>{
  late Future<List<Map<String,dynamic>>> _future;
  bool _busy=false, _confirming=false;
  late final FinancialRetryRegistry _retry;
  String get _retryScope => FinancialRetryRegistry.scopeFor(widget.api.client, 'store');
  @override void initState(){
    super.initState();
    _retry=FinancialRetryRegistry.forClient(widget.api.client);
    _refresh();
  }
  void _refresh()=>setState((){_future=widget.api.store();});
  Future<void> _buy(Map<String,dynamic> item) async{
    if(_busy||_confirming)return;
    late final int exactPrice;
    try {
      exactPrice = TotiChatServices.validatedStorePrice(item);
    } catch (error) {
      if (mounted) showApiError(context, error);
      return;
    }
    final name=item['name']?.toString()??'العنصر';
    final price=exactPrice.toString();
    setState(()=>_confirming=true);
    bool? confirmed;
    try {
      confirmed=await showDialog<bool>(context:context,builder:(context)=>
        AlertDialog(title:const Text('تأكيد شراء حقيقي'),
          content:Text('شراء $name مقابل $price ${item['currency']??'coin'} من رصيدك؟'),
          actions:[TextButton(onPressed:()=>Navigator.pop(context,false),
            child:const Text('إلغاء')),
            FilledButton(onPressed:()=>Navigator.pop(context,true),
              child:const Text('تأكيد'))]));
    } finally {
      if(mounted)setState(()=>_confirming=false);
    }
    if(confirmed!=true||!mounted)return;
    final signature=[
      item['id'], item['price'], item['currency'],
    ].join('|');
    // The same account and purchase family retain one unresolved request
    // across tab/screen disposal. A different selection cannot silently
    // create a second debit while the earlier outcome is uncertain.
    late final FinancialPendingIntent pending;
    try {
      pending=_retry.reserve(
        scope:_retryScope,
        signature:signature,
        newRequestId:TotiChatServices.requestId,
      );
    } catch(error) {
      if(mounted)showApiError(context,error);
      return;
    }
    setState(()=>_busy=true);
    try {
      await widget.api.buyItem(item,pending.requestId);
      _retry.confirm(scope:_retryScope,requestId:pending.requestId);
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:Text('أكد الخادم نجاح الشراء')));
        _refresh();
      }
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>ServerPanel<List<Map<String,dynamic>>>(
    future:_future,retry:_refresh,builder:(context,items)=>items.isEmpty?
      const NoRecords('لا توجد سلع مفعلة في المتجر الحقيقي.') :
      ListView.builder(padding:const EdgeInsets.all(12),itemCount:items.length,
        itemBuilder:(context,i){
          final item=items[i],reward=item['is_reward']==true;
          return recordCard(context,
            title:'${item['icon']??'◇'}  ${item['name']??'عنصر'}',
            description:'${item['category']??''}  ·  ${item['price']??'—'} ${item['currency']??'coin'}',
            trailing:FilledButton.tonal(onPressed:_busy||_confirming||reward?null:()=>_buy(item),
              child:Text(reward?'مكافأة':'شراء')));
        }),
  );
}

class _InventoryTab extends StatefulWidget{
  const _InventoryTab({required this.api});final TotiChatServices api;
  @override State<_InventoryTab> createState()=>_InventoryTabState();
}
class _InventoryTabState extends State<_InventoryTab>{
  late Future<List<Map<String,dynamic>>> _future;
  @override void initState(){super.initState();_reload();}
  void _reload()=>setState((){_future=widget.api.inventory();});
  @override Widget build(BuildContext context)=>ServerPanel<List<Map<String,dynamic>>>(
    future:_future,retry:_reload,builder:(context,rows)=>rows.isEmpty?
      const NoRecords('لا توجد مشتريات أو جوائز مسجلة بحسابك.') :
      ListView.builder(itemCount:rows.length,itemBuilder:(context,i){
        final item=rows[i];
        return recordCard(context,title:'العنصر: ${item['item_id']}',
          description:'${item['equipped']==true?'مجهز':'مملوك'}'
            '${item['expires_at']==null?'':' · ينتهي: ${item['expires_at']}'}',
          icon:Icons.inventory_2_outlined);
      }),
  );
}

class _VipTab extends StatefulWidget{
  const _VipTab({required this.api});final TotiChatServices api;
  @override State<_VipTab> createState()=>_VipTabState();
}
class _VipTabState extends State<_VipTab>{
  late Future<Map<String,dynamic>> _future;
  @override void initState(){super.initState();_reload();}
  void _reload()=>setState((){_future=widget.api.vip();});
  @override Widget build(BuildContext context)=>ServerPanel<Map<String,dynamic>>(
    future:_future,retry:_reload,builder:(context,data){
      final level=(data['tier'] as num?)?.toInt() ??
        (data['level'] as num?)?.toInt() ?? 0;
      return ListView(padding:const EdgeInsets.all(20),children:[
        TotiRoyalTopBanner(
          title: level>0 ? 'VIP المستوى $level' : 'نادي VIP',
          subtitle: level>0 ? 'عضويتك مؤكدة من الخادم' :
            'لا توجد عضوية VIP مفعّلة حالياً',
        ),
        const SizedBox(height:12),
        if(data['expiresAt']!=null)Text('انتهاء العضوية: ${data['expiresAt']}',
          textAlign:TextAlign.center),
        const SizedBox(height: 24),
        TotiVipTierGallery(currentTier: level),
      ]);
    },
  );
}

class _GiftHistoryTab extends StatefulWidget{
  const _GiftHistoryTab({required this.api});final TotiChatServices api;
  @override State<_GiftHistoryTab> createState()=>_GiftHistoryTabState();
}
class _GiftHistoryTabState extends State<_GiftHistoryTab>{
  late Future<List<Map<String,dynamic>>> _future;
  @override void initState(){super.initState();_reload();}
  void _reload()=>setState((){_future=widget.api.giftHistory();});
  @override Widget build(BuildContext context)=>ServerPanel<List<Map<String,dynamic>>>(
    future:_future,retry:_reload,builder:(context,items)=>items.isEmpty?
      const NoRecords('ماكو هدايا مستلمة حقيقية بحسابك.') :
      ListView.builder(itemCount:items.length,itemBuilder:(context,i){
        final item=items[i];
        return recordCard(context,title:item['gift_name']?.toString()??'هدية',
          description:'العدد: ${item['quantity']??'—'}  ·  القيمة: ${item['gift_coins']??'—'} كوين',
          icon:Icons.card_giftcard_rounded);
      }),
  );
}

class _NotificationsTab extends StatefulWidget{
  const _NotificationsTab({required this.api});final TotiChatServices api;
  @override State<_NotificationsTab> createState()=>_NotificationsTabState();
}
class _NotificationsTabState extends State<_NotificationsTab>{
  late Future<List<Map<String,dynamic>>> _future;bool _busy=false;
  @override void initState(){super.initState();_reload();}
  void _reload()=>setState((){_future=widget.api.notifications();});
  Future<void> _readAll()async{
    if(_busy)return;setState(()=>_busy=true);
    try{await widget.api.readNotifications();if(mounted)_reload();}
    catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context)=>Column(children:[
    Align(alignment:Alignment.centerLeft,child:TextButton.icon(
      onPressed:_busy?null:_readAll,
      icon:const Icon(Icons.done_all),label:const Text('تحديد الكل مقروء'))),
    Expanded(child:ServerPanel<List<Map<String,dynamic>>>(future:_future,
      retry:_reload,builder:(context,rows)=>rows.isEmpty?
        const NoRecords('ماكو إشعارات حقيقية حالياً.') :
        ListView.builder(itemCount:rows.length,itemBuilder:(context,i){
          final x=rows[i];
          return recordCard(context,
            title:x['title']?.toString()??x['event_type']?.toString()??'إشعار',
            description:x['body']?.toString()??x['created_at']?.toString(),
            icon:Icons.notifications_active_outlined);
        }))),
  ]);
}
