import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/notification_models.dart';
import '../../data/totichat_repository.dart';
import '../../data/totichat_services.dart';
import '../economy/economy_screen.dart';
import '../economy/recharge_activity_screen.dart';
import '../admin/admin_screen.dart';
import '../agency/charging_agent_screen.dart';
import '../notifications/notification_center_screen.dart';
import 'settings_screen.dart';
import '../../ui/toti_theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key, required this.repository, required this.walletOnly,
    this.roomActive = false,
  });
  final TotiChatRepository repository;
  final bool walletOnly;
  final bool roomActive;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Future<List<Object?>>? _data;
  Future<Map<String,dynamic>>? _vipStatus,_cpStatus;
  Future<NotificationPage>? _notificationSummary;

  @override
  void initState() { super.initState(); _refresh(); }

  void _refresh() {
    if (!widget.walletOnly) {
      final api=TotiChatServices(widget.repository.client);
      _vipStatus=api.vip();
      _cpStatus=api.cpState();
      _notificationSummary=api.notificationPage(limit: 1);
    }
    setState(() {
      _data = Future.wait<Object?>([
        widget.repository.ownProfile(),
        widget.repository.ownWallet(),
        widget.repository.ownAssignedId(),
      ]);
    });
  }

  String _coins(Object? value) {
    final n = value is num ? value : num.tryParse(value?.toString() ?? '');
    return n == null ? '—' : n.toInt().toString();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async { _refresh(); await _data; },
    child: ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        if (!widget.walletOnly)
          FutureBuilder<NotificationPage>(
            future: _notificationSummary,
            builder: (context, snapshot) {
              final unread = snapshot.data?.unreadCount;
              return IconButton(
                tooltip: unread == null ? 'Notifications' :
                  'Notifications, $unread unread',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NotificationCenterScreen(
                      api: TotiChatServices(widget.repository.client))));
                  if (mounted) _refresh();
                },
                icon: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.notifications_none_rounded, size: 27),
                  if (unread != null && unread > 0)
                    Positioned(
                      top: -9, right: -12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(unread > 99 ? '99+' : unread.toString(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w800))),
                    ),
                ]),
              );
            },
          ),
        const FalconMark(size: 55),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.walletOnly ? 'محفظتي' : 'ملفي',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800))),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
      ]),
      const SizedBox(height: 20),
      FutureBuilder<List<Object?>>(
        future: _data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return _error('تعذّر جلب بيانات الحساب الحقيقية');
            return const Padding(padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()));
          }
          final profile = snapshot.data![0] as Map<String, dynamic>?;
          final wallet = snapshot.data![1] as Map<String, dynamic>?;
          final id = snapshot.data![2] as Map<String, dynamic>?;
          final publicId = id?['assigned'] == true ?
            (id?['publicId']?.toString() ?? '—') : 'بانتظار منح ID من الإدارة';
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!widget.walletOnly) Card(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                FutureBuilder<Map<String,dynamic>>(
                  future:_vipStatus,
                  builder:(context,vipSnapshot){
                    final level=(vipSnapshot.data?['tier'] as num?)?.toInt()??0;
                    final ring=level<=3
                      ?const Color(0xFF55A5AD)
                      :level<=6?const Color(0xFF8C6CD1)
                      :const Color(0xFFC89A43);
                    return Column(children:[
                      Container(
                        padding:EdgeInsets.all(level>0?4:0),
                        decoration:BoxDecoration(
                          shape:BoxShape.circle,
                          border:level>0?Border.all(color:ring,width:3):null),
                        child:CircleAvatar(radius:34,
                          backgroundColor:TotiColors.lavender,
                          backgroundImage:profile?['avatar_url']?.toString()
                            .startsWith('https://')==true
                            ?NetworkImage(profile!['avatar_url'] as String):null,
                          child:profile?['avatar_url']==null
                            ?const Icon(Icons.person,size:34):null)),
                      if(level>0)Padding(padding:const EdgeInsets.only(top:7),
                        child:Chip(avatar:const Icon(Icons.workspace_premium,
                          size:17),label:Text('VIP $level'))),
                      if(vipSnapshot.hasError)const Text(
                        'VIP status unavailable',
                        style:TextStyle(fontSize:12,color:Colors.black54)),
                    ]);
                  }),
                const SizedBox(height: 14),
                Text(profile?['display_name']?.toString() ?? 'مستخدم TotiChat',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('ID: $publicId', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
                FutureBuilder<Map<String,dynamic>>(
                  future:_cpStatus,
                  builder:(context,cpSnapshot){
                    if(cpSnapshot.hasError) {
                      return const Text('CP status unavailable',
                        style:TextStyle(fontSize:12,color:Colors.black54));
                    }
                    final relations=(cpSnapshot.data?['relations'] as List? ?? [])
                      .whereType<Map>()
                      .where((r)=>r['accepted_at']!=null)
                      .toList();
                    return relations.isEmpty?const SizedBox.shrink()
                      :Column(children:[
                        const SizedBox(height:8),
                        ...relations.map((rel){
                          final partner=rel['partner'] is Map
                            ?rel['partner'] as Map:<String,dynamic>{};
                          final started=DateTime.tryParse(
                            rel['created_at']?.toString()??'');
                          final elapsed=started==null?null:
                            DateTime.now().difference(started).inDays+1;
                          return Chip(
                            avatar:const Icon(Icons.favorite,size:17),
                            label:Text(
                              '${rel['type_label']??'CP'} · '
                              '${partner['display_name']??'Member'}'
                              ' · L${rel['level']??1}'
                              '${elapsed!=null&&elapsed>0?' · $elapsed days':''}'),
                          );
                        }),
                      ]);
                  }),
                if (profile?['bio']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(profile!['bio'].toString(), textAlign: TextAlign.center),
                ],
              ]),
            )),
            const SizedBox(height: 16),
            const Text('الرصيد الحقيقي', style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 19)),
            const SizedBox(height: 12),
            if (wallet == null) const Card(child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('لم يرجع الخادم محفظة لهذا الحساب. لا نعرض رصيداً وهمياً.')))
            else Row(children: [
              Expanded(child: _metric('كوينز', _coins(wallet['coins']), Icons.toll)),
              const SizedBox(width: 8),
              Expanded(child: _metric('ألماس', _coins(wallet['diamonds']), Icons.diamond_outlined)),
              const SizedBox(width: 8),
              Expanded(child: _metric('فضة', _coins(wallet['silver']), Icons.stars_outlined)),
            ]),
            if (widget.walletOnly) ...[
              const SizedBox(height:16),
              Card(child:ListTile(
                leading:const Icon(Icons.receipt_long_outlined),
                title:const Text('سجل الشحن والمكافآت'),
                subtitle:const Text('اطلع على السجل المؤكد من الخادم'),
                onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                  builder:(_)=>RechargeActivityScreen(
                    api:TotiChatServices(widget.repository.client)))))),
            ],
            if (!widget.walletOnly) ...[
              const SizedBox(height: 22),
              Card(child:ListTile(
                leading:const Icon(Icons.storefront_outlined),
                title:const Text('المتجر والمقتنيات والهدايا وVIP'),
                onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                  builder:(_)=>EconomyScreen(api:TotiChatServices(widget.repository.client)))))),
              _AdminEntry(api:TotiChatServices(widget.repository.client)),
              _AgentEntry(api:TotiChatServices(widget.repository.client)),
              Card(child:ListTile(
                leading:const Icon(Icons.manage_accounts_outlined),
                title:const Text('تعديل الملف والخصوصية'),
                onTap:()=>Navigator.of(context).push(MaterialPageRoute(
                  builder:(_)=>ProfileSettings(repository:widget.repository))))),
              Card(child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('تسجيل Google'),
                subtitle: Text(Supabase.instance.client.auth.currentUser?.email ??
                  'حساب مصادق عليه'),
              )),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.roomActive ? null :
                  () async => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج'),
              ),
              if (widget.roomActive)
                const Text('Leave the current room before signing out.'),
            ],
          ]);
        },
      ),
    ]),
  );

  Widget _metric(String title, String value, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(12),
      child: Column(children: [
        Icon(icon, color: TotiColors.plum),
        const SizedBox(height: 7),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ])));

  Widget _error(String message) => Column(children: [
    Text(message, textAlign: TextAlign.center),
    const SizedBox(height: 10),
    OutlinedButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
  ]);
}

class _AdminEntry extends StatefulWidget {
  const _AdminEntry({required this.api});
  final TotiChatServices api;
  @override State<_AdminEntry> createState()=>_AdminEntryState();
}

class _AdminEntryState extends State<_AdminEntry> {
  late final Future<Map<String,dynamic>> _role=widget.api.authority();
  late final Future<Map<String,dynamic>> _support=widget.api.supportTicketPage();

  Widget _entry(BuildContext context) => Card(child:ListTile(
    leading:const Icon(Icons.admin_panel_settings_outlined),
    title:const Text('مركز الإدارة'),
    subtitle:const Text('متاح حسب صلاحية الخادم'),
    onTap:()=>Navigator.of(context).push(MaterialPageRoute(
      builder:(_)=>AdminScreen(api:widget.api)))));

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:_role,builder:(context,snapshot){
      final role=snapshot.data;
      if(role==null)return const SizedBox.shrink();
      if(canOpenAdmin(role))return _entry(context);
      // A support handler may have no generic admin role. The server verifies
      // this narrow capability without granting access to other admin pages.
      return FutureBuilder<Map<String,dynamic>>(
        future:_support,
        builder:(context,rights)=>rights.data?['canHandle']==true
          ?_entry(context):const SizedBox.shrink());
    },
  );
}

class _AgentEntry extends StatefulWidget {
  const _AgentEntry({required this.api});
  final TotiChatServices api;
  @override State<_AgentEntry> createState()=>_AgentEntryState();
}

class _AgentEntryState extends State<_AgentEntry> {
  late final Future<Map<String,dynamic>> _state=widget.api.rechargeState();
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
    future:_state,builder:(context,snapshot){
      final data=snapshot.data;
      if(data==null)return const SizedBox.shrink();
      final agencies=(data['agencies'] as List? ?? []).whereType<Map>()
        .where((a)=>a['owner_id']==widget.api.userId && a['is_active']==true);
      if(agencies.isEmpty && data['isOwner']!=true && data['canManage']!=true) {
        return const SizedBox.shrink();
      }
      return Card(child:ListTile(
        leading:const Icon(Icons.store_mall_directory_outlined),
        title:const Text('عمليات وكيل الشحن'),
        subtitle:const Text('تشغيل الوكالة داخل التطبيق، دون دخول مركز الإدارة'),
        onTap:()=>Navigator.of(context).push(MaterialPageRoute(
          builder:(_)=>ChargingAgentScreen(api:widget.api)))));
    },
  );
}
