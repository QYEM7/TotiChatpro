import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';
import 'dm_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key,required this.api});
  final TotiChatServices api;
  @override
  Widget build(BuildContext context)=>DefaultTabController(
    length:5,
    child:Column(children:[
      const Padding(padding:EdgeInsets.all(16),
        child:Row(children:[
          Icon(Icons.groups_rounded,size:30),
          SizedBox(width:10),
          Text('مجتمع TotiChat',style:TextStyle(fontSize:22,fontWeight:FontWeight.w800)),
        ])),
      const TabBar(isScrollable:true,tabs:[
        Tab(text:'الرسائل'),Tab(text:'الأصدقاء'),
        Tab(text:'علاقات CP'),Tab(text:'الوكالات'),Tab(text:'الدعم'),
      ]),
      Expanded(child:TabBarView(children:[
        DmInbox(api:api),_PeopleTab(api:api),_CpTab(api:api),
        _AgencyTab(api:api),_SupportTab(api:api),
      ])),
    ]),
  );
}

class _PeopleTab extends StatefulWidget{
  const _PeopleTab({required this.api});final TotiChatServices api;
  @override State<_PeopleTab> createState()=>_PeopleTabState();
}
class _PeopleTabState extends State<_PeopleTab>{
  final _search=TextEditingController();
  Future<List<Map<String,dynamic>>>? _results;
  bool _busy=false;
  String? _pendingId;
  void _lookup(){
    if(_search.text.trim().length<2)return;
    setState(()=>_results=widget.api.socialSearch(_search.text));
  }
  Future<void> _follow(String peer) async{
    if(_busy)return;setState(()=>_busy=true);
    _pendingId??=TotiChatServices.requestId();
    try{await widget.api.follow(peer,enabled:true,requestId:_pendingId!);
      _pendingId=null;
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('تم تسجيل المتابعة على الخادم')));
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override void dispose(){_search.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[
      Expanded(child:TextField(controller:_search,maxLength:35,
        decoration:const InputDecoration(hintText:'ابحث عن مستخدم حقيقي',counterText:''),
        onSubmitted:(_)=>_lookup())),
      IconButton.filled(onPressed:_lookup,icon:const Icon(Icons.search))
    ])),
    Expanded(child:_results==null?const NoRecords('ابدأ بالبحث عن مستخدم.') :
      ServerPanel<List<Map<String,dynamic>>>(future:_results!,
        retry:_lookup,builder:(context,rows)=>rows.isEmpty?
          const NoRecords('لا يوجد مستخدم مطابق.') :
          ListView.builder(itemCount:rows.length,itemBuilder:(context,i){
            final p=rows[i],id=TotiChatServices.verifiedSocialUserId(p);
            return recordCard(context,title:p['display_name']?.toString()??'عضو',
              description:id,
              trailing:PopupMenuButton<String>(
                enabled:!_busy&&id.isNotEmpty&&id!=widget.api.userId,
                onSelected:(cmd){
                  if(cmd=='follow'){_follow(id);}
                  if(cmd=='dm'){Navigator.push(context,MaterialPageRoute(
                    builder:(_)=>DmThread(api:widget.api,peerId:id,
                      title:p['display_name']?.toString()??'محادثة')));}
                },
                itemBuilder:(_)=>const [
                  PopupMenuItem(value:'follow',child:Text('متابعة')),
                  PopupMenuItem(value:'dm',child:Text('رسالة خاصة')),
                ]),
            );
          }))),
  ]);
}

class _CpTab extends StatefulWidget {
  const _CpTab({required this.api});final TotiChatServices api;
  @override State<_CpTab> createState()=>_CpTabState();
}
class _CpTabState extends State<_CpTab>{
  late Future<Map<String,dynamic>> _future;
  Future<List<Map<String,dynamic>>>? _people;
  final _query=TextEditingController();
  String? _peer,_type,_pendingId;
  bool _busy=false;
  @override void initState(){super.initState();_refresh();}
  void _refresh()=>setState(()=>_future=widget.api.cpState());
  Future<void> _send(String peer,String type,String action) async{
    if(_busy)return;
    setState(()=>_busy=true);_pendingId??=TotiChatServices.requestId();
    try{await widget.api.cpAction(peer:peer,type:type,action:action,requestId:_pendingId!);
      _pendingId=null;if(mounted)_refresh();
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override void dispose(){_query.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>
    ServerPanel<Map<String,dynamic>>(future:_future,retry:_refresh,builder:(context,data){
      final types=(data['types'] as List? ?? []).whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
      final relations=(data['relations'] as List? ?? []).whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
      return ListView(padding:const EdgeInsets.all(14),children:[
        const Text('العلاقات الحقيقية',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
        if(relations.isEmpty)const NoRecords('ما عندك علاقات أو طلبات حالياً.'),
        ...relations.map((r){
          final peer=r['partner'] is Map?Map<String,dynamic>.from(r['partner'] as Map):<String,dynamic>{};
          final peerId=peer['id']?.toString()??'';
          final type=r['type_id']?.toString()??'';
          final waiting=r['accepted_at']==null && r['requested_by']!=widget.api.userId;
          return recordCard(context,title:'${r['type_label']??type} — ${peer['display_name']??'عضو'}',
            description:r['accepted_at']==null?'بانتظار الموافقة':'علاقة مؤكدة',
            trailing:waiting?TextButton(onPressed:_busy?null:()=>_send(peerId,type,'accept'),
              child:const Text('قبول')):null);
        }),
        const SizedBox(height:18),
        const Text('إرسال طلب CP',style:TextStyle(fontWeight:FontWeight.w700)),
        const SizedBox(height:8),
        TextField(controller:_query,decoration:const InputDecoration(labelText:'اسم المستخدم')),
        const SizedBox(height:9),
        OutlinedButton.icon(onPressed:(){
          if(_query.text.trim().length>=2)setState(()=>
            _people=widget.api.socialSearch(_query.text));
        },icon:const Icon(Icons.search),label:const Text('بحث')),
        if(_people!=null)ServerPanel<List<Map<String,dynamic>>>(
          future:_people!,retry:()=>setState(()=>
            _people=widget.api.socialSearch(_query.text)),
          builder:(context,rows)=>DropdownButtonFormField<String>(
            initialValue:rows.any((p)=>p['user_id']==_peer)?_peer:null,
            hint:const Text('اختر الشخص'),
            items:rows.where((p)=>p['user_id']!=widget.api.userId)
              .map((p)=>DropdownMenuItem(value:TotiChatServices.verifiedSocialUserId(p),
                child:Text(p['display_name']?.toString()??'عضو'))).toList(),
            onChanged:(v)=>setState(()=>_peer=v))),
        DropdownButtonFormField<String>(
          initialValue:types.any((t)=>t['id']==_type)?_type:null,
          hint:const Text('نوع العلاقة'),
          items:types.map((t)=>DropdownMenuItem(value:t['id'].toString(),
            child:Text(t['label']?.toString()??'CP'))).toList(),
          onChanged:(v)=>setState(()=>_type=v)),
        const SizedBox(height:12),
        FilledButton(onPressed:_busy||_peer==null||_type==null?null:
          ()=>_send(_peer!,_type!,'request'),child:const Text('إرسال الطلب الحقيقي')),
      ]);
    });
}

class _AgencyTab extends StatefulWidget{
  const _AgencyTab({required this.api});final TotiChatServices api;
  @override State<_AgencyTab> createState()=>_AgencyTabState();
}
class _AgencyTabState extends State<_AgencyTab>{
  late Future<Map<String,dynamic>> _future;
  @override void initState(){super.initState();_refresh();}
  void _refresh()=>setState(()=>_future=widget.api.agencyState());
  @override Widget build(BuildContext context)=>ServerPanel<Map<String,dynamic>>(
    future:_future,retry:_refresh,builder:(context,data){
      final regs=(data['registrations'] as List? ?? []).whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
      final agencies=(data['agencies'] as List? ?? []).whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
      return ListView(padding:const EdgeInsets.all(14),children:[
        const Text('وكالاتي وطلباتي',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
        if(regs.isEmpty&&agencies.isEmpty)const NoRecords('لا توجد وكالات أو طلبات مرتبطة بحسابك.'),
        ...agencies.map((r)=>recordCard(context,title:r['name']?.toString()??'وكالة',
          description:r['kind']?.toString())),
        ...regs.map((r)=>recordCard(context,title:r['name']?.toString()??'طلب',
          description:'الحالة: ${r['status']??'بانتظار المراجعة'}')),
        const SizedBox(height:12),
        FilledButton.icon(onPressed:()=>_openAgencyDialog(),icon:const Icon(Icons.add_business),
          label:const Text('طلب فتح وكالة')),
      ]);
    });
  Future<void> _openAgencyDialog() async {
    final name=TextEditingController(),contact=TextEditingController(),reason=TextEditingController();
    var kind='host',busy=false;
    String? pendingId;
    await showDialog<void>(context:context,builder:(dialogContext)=>
      StatefulBuilder(builder:(context,update)=>AlertDialog(
        title:const Text('طلب وكالة حقيقية'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<String>(initialValue:kind,
            items:const [DropdownMenuItem(value:'host',child:Text('وكالة مضيفين')),
              DropdownMenuItem(value:'recharge',child:Text('وكالة شحن'))],
            onChanged:(v)=>update(()=>kind=v??'host')),
          TextField(controller:name,maxLength:80,decoration:const InputDecoration(labelText:'اسم الوكالة')),
          TextField(controller:contact,maxLength:100,decoration:const InputDecoration(labelText:'وسيلة التواصل')),
          TextField(controller:reason,maxLength:500,maxLines:3,
            decoration:const InputDecoration(labelText:'سبب فتح الوكالة')),
        ])),
        actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),
          child:const Text('إلغاء')),
        FilledButton(onPressed:busy?null:()async{
          update(()=>busy=true);pendingId??=TotiChatServices.requestId();
          try{
            await widget.api.applyAgency(kind:kind,name:name.text,
              contact:contact.text,reason:reason.text,requestId:pendingId!);
            if(dialogContext.mounted)Navigator.pop(dialogContext);
            if(mounted)_refresh();
          }catch(e){if(dialogContext.mounted)showApiError(dialogContext,e);}
          finally{if(dialogContext.mounted)update(()=>busy=false);}
        },child:const Text('إرسال الطلب'))],
      )));
    name.dispose();contact.dispose();reason.dispose();
  }
}

class _SupportTab extends StatefulWidget {
  const _SupportTab({required this.api});final TotiChatServices api;
  @override State<_SupportTab> createState()=>_SupportTabState();
}
class _SupportTabState extends State<_SupportTab>{
  late Future<List<Map<String,dynamic>>> _future;
  final _subject=TextEditingController(),_message=TextEditingController();
  String _category='technical';bool _sending=false;String? _pendingId;
  @override void initState(){super.initState();_refresh();}
  void _refresh()=>setState(()=>_future=widget.api.supportTickets());
  @override void dispose(){_subject.dispose();_message.dispose();super.dispose();}
  Future<void> _submit() async {
    if(_sending)return;setState(()=>_sending=true);
    _pendingId??=TotiChatServices.requestId();
    try{
      final id=await widget.api.supportRequest(category:_category,subject:_subject.text,
        message:_message.text,requestId:_pendingId!);
      _pendingId=null;_subject.clear();_message.clear();
      if(mounted){_refresh();ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('تم تسجيل التذكرة: $id')));}
    }catch(e){if(mounted)showApiError(context,e);}
    finally{if(mounted)setState(()=>_sending=false);}
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[
    const Text('الدعم الفني الرسمي',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18)),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(initialValue:_category,
      onChanged:(v)=>setState(()=>_category=v??'technical'),
      items:const [
        DropdownMenuItem(value:'technical',child:Text('مشكلة تقنية')),
        DropdownMenuItem(value:'account',child:Text('الحساب')),
        DropdownMenuItem(value:'recharge',child:Text('الشحن')),
        DropdownMenuItem(value:'general',child:Text('استفسار عام')),
      ]),
    const SizedBox(height:8),
    TextField(controller:_subject,maxLength:120,
      decoration:const InputDecoration(labelText:'عنوان الطلب')),
    TextField(controller:_message,maxLength:2500,maxLines:3,
      decoration:const InputDecoration(labelText:'تفاصيل الطلب')),
    FilledButton(onPressed:_sending?null:_submit,child:const Text('إرسال تذكرة حقيقية')),
    const SizedBox(height:18),
    const Text('تذاكري',style:TextStyle(fontWeight:FontWeight.w700)),
    ServerPanel<List<Map<String,dynamic>>>(future:_future,retry:_refresh,
      builder:(context,rows)=>rows.isEmpty?const NoRecords('ليس عندك تذاكر.') :
        Column(children:rows.map((r)=>recordCard(context,
          title:r['subject']?.toString()??r['category']?.toString()??'تذكرة',
          description:r['status']?.toString())).toList())),
  ]);
}
