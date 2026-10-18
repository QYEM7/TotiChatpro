import 'package:flutter/material.dart';

import 'connected_features.dart';
import 'social_pages.dart';
import 'visual.dart';

class AgenciesPage extends StatefulWidget {
  const AgenciesPage({super.key});
  @override
  State<AgenciesPage> createState() => _AgenciesPageState();
}
class _AgenciesPageState extends State<AgenciesPage> {
  late Future<Map<String, dynamic>> state;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { state = features.agencyState(); }

  Future<void> register() async {
    final name = TextEditingController();
    final contact = TextEditingController();
    final reason = TextEditingController();
    String kind = 'host';
    try {
      final ok = await showDialog<bool>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) =>
        AlertDialog(
          title: const Text('طلب فتح وكالة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButton<String>(value: kind, isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'host', child: Text('وكالة مضيفين')),
                  DropdownMenuItem(value: 'recharge', child: Text('وكالة شحن')),
                ],
                onChanged: (k) => update(() => kind = k ?? 'host')),
              TextField(controller: name,
                decoration: const InputDecoration(labelText: 'اسم الوكالة')),
              TextField(controller: contact,
                decoration: const InputDecoration(labelText: 'وسيلة التواصل')),
              TextField(controller: reason, maxLines: 2,
                decoration: const InputDecoration(labelText: 'سبب الطلب')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تقديم الطلب')),
          ],
        )));
      if (ok != true || !mounted) return;
      await features.registerAgency(kind: kind, name: name.text,
        contact: contact.text, reason: reason.text,
        requestId: features.newRequestId());
      if (mounted) setState(reload);
    } catch (error) { if (mounted) _agencyError(context, error); }
    finally { name.dispose(); contact.dispose(); reason.dispose(); }
  }

  Future<void> join(String agencyId) async {
    final field = TextEditingController();
    try {
      final accepted = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('طلب الانضمام للوكالة'),
          content: TextField(controller: field,
            decoration: const InputDecoration(labelText: 'سبب الانضمام')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال الطلب')),
          ],
        ));
      if (accepted != true || !mounted) return;
      await features.joinAgency(agencyId, field.text,
        requestId: features.newRequestId());
      if (mounted) setState(reload);
    } catch (error) { if (mounted) _agencyError(context, error); }
    finally { field.dispose(); }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'الوكالات',
    body: FutureBuilder<Map<String, dynamic>>(
      future: state,
      builder: (context, snap) {
        if (snap.hasError) return _stateError('تعذر جلب الوكالات');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final s = snap.data!;
        final agencies = ConnectedFeatures.collection(s['agencies'] ?? []);
        final requests = ConnectedFeatures.collection(s['registrations'] ?? []);
        return ListView(children: [
          Padding(padding: const EdgeInsets.all(14),
            child: FilledButton.icon(
              onPressed: register, icon: const Icon(Icons.add_business),
              label: const Text('فتح وكالة جديدة')),
          ),
          if (requests.isNotEmpty) const ListTile(title: Text('طلباتك المسجلة')),
          for (final req in requests)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(req['name']?.toString() ?? ''),
              subtitle: Text(req['status']?.toString() ?? ''),
            ),
          const ListTile(title: Text('الوكالات الموجودة')),
          if (agencies.isEmpty) _stateError('لا توجد وكالات متاحة'),
          for (final agency in agencies)
            Card(child: ListTile(
              leading: const Icon(Icons.groups_2),
              title: Text(agency['name']?.toString() ?? ''),
              subtitle: Text(agency['kind'] == 'host'
                ? 'وكالة مضيفين' : 'وكالة شحن'),
              trailing: agency['kind'] == 'host'
                ? TextButton(onPressed: () => join(agency['id'] as String),
                  child: const Text('انضمام')) : null,
            )),
        ]);
      },
    ),
  );
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}
class _ShopPageState extends State<ShopPage> {
  late Future<List<Map<String, dynamic>>> items;
  late Future<List<Map<String, dynamic>>> ownership;
  final Map<String, String> pending = {};
  @override
  void initState() { super.initState(); reload(); }
  void reload() {
    items = features.catalog();
    ownership = features.ownedItems();
  }
  Future<void> buy(Map<String, dynamic> item) async {
    final price = item['price']?.toString() ?? '?';
    final currency = item['currency']?.toString() ?? '';
    final confirmed = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الشراء'),
        content: Text('شراء ' + (item['name']?.toString() ?? '') +
          ' مقابل ' + price + ' ' + currency + '؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد')),
        ],
      ));
    if (confirmed != true || !mounted) return;
    final id = item['id'] as String;
    pending[id] ??= features.newRequestId();
    try {
      await features.purchase(item, requestId: pending[id]!);
      pending.remove(id);
      if (mounted) setState(reload);
    } catch (error) { if (mounted) _agencyError(context, error); }
  }
  Future<void> equip(Map<String, dynamic> item, bool equipped) async {
    try {
      await features.equip(item['id'] as String, enabled: !equipped);
      if (mounted) setState(reload);
    } catch (error) { if (mounted) _agencyError(context, error); }
  }
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'المتجر والمخزن',
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: items,
      builder: (context, catalog) {
        if (catalog.hasError) return _stateError('تعذر تحميل المتجر');
        if (!catalog.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: ownership,
          builder: (context, ownedSnapshot) {
            if (ownedSnapshot.hasError) return _stateError('تعذر معرفة الممتلكات');
            if (!ownedSnapshot.hasData) return const Center(child: CircularProgressIndicator());
            final owned = {
              for (final item in ownedSnapshot.data!)
                item['item_id'] as String: item,
            };
            final catalogItems = catalog.data!;
            if (catalogItems.isEmpty) return _stateError('لا توجد عناصر حقيقية');
            return ListView(children: [
              const ListTile(
                title: Text('عناصر المتجر'),
                subtitle: Text('الأسعار والأرصدة يحددها الخادم الحقيقي'),
              ),
              for (final item in catalogItems)
                Card(child: ListTile(
                  leading: Text(item['icon']?.toString() ?? '🎁',
                    style: const TextStyle(fontSize: 28)),
                  title: Text(item['name']?.toString() ?? ''),
                  subtitle: Text((item['category']?.toString() ?? '') +
                    ' • ' + (item['price']?.toString() ?? '') +
                    ' ' + (item['currency']?.toString() ?? '')),
                  trailing: owned.containsKey(item['id'])
                    ? TextButton(
                        onPressed: () => equip(item,
                          owned[item['id']]?['equipped'] == true),
                        child: Text(owned[item['id']]?['equipped'] == true
                          ? 'إزالة' : 'استخدام'),
                      )
                    : item['relationship_type_id'] != null
                      ? const Text('CP')
                      : TextButton(onPressed: () => buy(item),
                        child: const Text('شراء')),
                )),
            ]);
          },
        );
      },
    ),
  );
}

class VipPage extends StatelessWidget {
  const VipPage({super.key});
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'VIP',
    body: FutureBuilder<Map<String, dynamic>>(
      future: features.vipStatus(features.ownId),
      builder: (context, snap) {
        if (snap.hasError) return _stateError('تعذر جلب VIP');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final vip = snap.data!;
        return ListView(children: [
          Container(
            margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ApprovedPalette.room, ApprovedPalette.violet]),
              border: Border.all(color: ApprovedPalette.gold, width: 2),
              borderRadius: BorderRadius.circular(22)),
            child: Column(children: [
              const Icon(Icons.workspace_premium,
                color: ApprovedPalette.gold, size: 55),
              Text('VIP ' + (vip['tier']?.toString() ?? '0'),
                style: const TextStyle(color: ApprovedPalette.gold,
                  fontSize: 34, fontWeight: FontWeight.w900)),
              Text(vip['active'] == true ? 'الاشتراك فعّال'
                : 'لا يوجد اشتراك فعّال',
                style: const TextStyle(color: Colors.white)),
              if (vip['expiresAt'] != null)
                Text(vip['expiresAt'].toString(),
                  style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          const Padding(padding: EdgeInsets.all(18),
            child: Text('إدارة VIP من الخادم؛ لا يمكن تفعيل مستوى وهمي أو خصم عملات دون تسعيرة معتمدة.')),
        ]);
      },
    ),
  );
}

class UserNotificationsAndSupportPage extends StatefulWidget {
  const UserNotificationsAndSupportPage({super.key});
  @override
  State<UserNotificationsAndSupportPage> createState() => _UserSupportState();
}
class _UserSupportState extends State<UserNotificationsAndSupportPage> {
  late Future<Map<String, dynamic>> tickets;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { tickets = features.myTickets(); }

  Future<void> createTicket() async {
    final subject = TextEditingController();
    final body = TextEditingController();
    String category = 'technical';
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, change) => AlertDialog(
          title: const Text('إنشاء طلب دعم'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: category,
                items: const [
                  DropdownMenuItem(value: 'technical', child: Text('مشكلة تقنية')),
                  DropdownMenuItem(value: 'account', child: Text('الحساب')),
                  DropdownMenuItem(value: 'recharge', child: Text('الشحن')),
                  DropdownMenuItem(value: 'host_agency', child: Text('وكالة مضيفين')),
                  DropdownMenuItem(value: 'host_transfer', child: Text('نقل مضيف')),
                  DropdownMenuItem(value: 'general', child: Text('عام')),
                ],
                onChanged: (v) => change(() => category = v ?? category)),
              TextField(controller: subject, maxLength: 120,
                decoration: const InputDecoration(labelText: 'الموضوع')),
              TextField(controller: body, maxLines: 4, maxLength: 2500,
                decoration: const InputDecoration(labelText: 'التفاصيل')),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال')),
          ],
        )),
      );
      if (confirmed != true || !mounted) return;
      await features.createSupportTicket(
        category: category, subject: subject.text, message: body.text,
        requestId: features.newRequestId());
      if (mounted) setState(reload);
    } catch (error) { if (mounted) _agencyError(context, error); }
    finally { subject.dispose(); body.dispose(); }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'الدعم الفني',
    body: FutureBuilder<Map<String, dynamic>>(
      future: tickets,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _stateError('تعذر عرض طلبات الدعم');
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final items = ConnectedFeatures.collection(snapshot.data!['rows'] ?? []);
        return ListView(children: [
          Padding(padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: createTicket, icon: const Icon(Icons.support_agent),
              label: const Text('إنشاء طلب دعم جديد'))),
          if (items.isEmpty) _stateError('لا توجد طلبات دعم مسجلة'),
          for (final item in items)
            Card(child: ListTile(
              title: Text(item['subject']?.toString() ?? ''),
              subtitle: Text(item['status']?.toString() ?? ''),
            )),
        ]);
      },
    ),
  );
}

class AdminCenterPage extends StatelessWidget {
  const AdminCenterPage({super.key});
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'مركز الإدارة',
    body: FutureBuilder<Map<String, dynamic>>(
      future: features.adminSession(),
      builder: (context, snap) {
        if (snap.hasError) return _stateError('تعذر التحقق من صلاحية الإدارة');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final admin = snap.data!;
        final isAuthorized = admin['isOwner'] == true ||
          admin['isMainPartner'] == true ||
          (admin['role']?.toString() ?? 'user') != 'user';
        if (!isAuthorized) return _stateError('ليست لديك صلاحية الإدارة');
        final role = admin['role']?.toString() ?? '';
        return ListView(children: [
          const ListTile(
            leading: Icon(Icons.verified_user),
            title: Text('المركز الإداري الموحّد'),
            subtitle: Text('الصلاحيات تعتمد على رد الخادم، مو واجهة المستخدم'),
          ),
          ListTile(title: const Text('الرتبة'),
            trailing: Text(role)),
          if (admin['canManageCatalogs'] == true)
            const ListTile(leading: Icon(Icons.inventory),
              title: Text('صلاحية إدارة الكتالوج'),
              subtitle: Text('متاحة في الخادم؛ أدوات التحرير تحتاج اعتماد واجهاتها')),
          if (admin['canManageHostAgencies'] == true)
            ListTile(leading: const Icon(Icons.groups),
              title: const Text('إدارة وكالات المضيفين'),
              onTap: () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const AgenciesPage()))),
          if (admin['canManageRechargeAgencies'] == true)
            const ListTile(leading: Icon(Icons.account_balance),
              title: Text('صلاحية وكالات الشحن'),
              subtitle: Text('لا تتوفر عمليات خزينة مباشرة من الواجهة')),
          const Padding(padding: EdgeInsets.all(18),
            child: Text('جميع إجراءات الإدارة الحساسة محمية بدوال خادمية؛ أدوات التقارير والعقوبات لم تكتمل بصرياً بعد.')),
        ]);
      },
    ),
  );
}

class WalletInfoPage extends StatelessWidget {
  const WalletInfoPage({super.key});
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'المحفظة والتسوية',
    body: FutureBuilder<Map<String, dynamic>>(
      future: features.diamondState(),
      builder: (context, snap) {
        if (snap.hasError) return _stateError('تعذر جلب بيانات الماس');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final state = snap.data!;
        return ListView(children: [
          const ListTile(title: Text('بيانات التسوية الفعلية'),
            leading: Icon(Icons.diamond, color: ApprovedPalette.emerald)),
          for (final entry in state.entries)
            if (entry.value is num || entry.value is String || entry.value is bool)
              ListTile(title: Text(entry.key),
                trailing: Text(entry.value.toString())),
          const Padding(padding: EdgeInsets.all(12),
            child: Text('التسوية المالية خادمية. لم يتم تفعيل تحويل غير معتمد.')),
        ]);
      },
    ),
  );
}

Widget _stateError(String title) => Center(
  child: Padding(padding: const EdgeInsets.all(20),
    child: Text(title, textAlign: TextAlign.center)),
);
void _agencyError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('تعذر إكمال العملية: ' + error.toString())));
}
