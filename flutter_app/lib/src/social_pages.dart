import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_features.dart';
import 'visual.dart';

ConnectedFeatures get features =>
    ConnectedFeatures(Supabase.instance.client);

void _problem(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('تعذر التنفيذ: ' + error.toString())));
}

Widget _blank(String message) => Center(
  child: Padding(padding: const EdgeInsets.all(28),
    child: Text(message, textAlign: TextAlign.center)),
);

class FeatureScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  const FeatureScaffold({super.key, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: ApprovedPalette.cream,
      appBar: AppBar(title: Text(title),
        backgroundColor: ApprovedPalette.emerald,
        foregroundColor: Colors.white),
      body: body,
    ),
  );
}

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});
  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late Future<List<Map<String, dynamic>>> inbox;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { inbox = features.inbox(); }

  Future<void> _findPerson() async {
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => const PeopleSearchPage()));
    if (mounted) setState(_reload);
  }
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'المحادثات',
    body: Column(children: [
      ListTile(
        title: const Text('بدء محادثة حقيقية'),
        leading: const Icon(Icons.person_search),
        trailing: const Icon(Icons.add),
        onTap: _findPerson,
      ),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: inbox,
        builder: (context, result) {
          if (result.hasError) return _blank('تعذر عرض المحادثات');
          if (!result.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = result.data!;
          if (rows.isEmpty) return _blank('لا توجد رسائل خاصة بعد');
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await inbox;
            },
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final r = rows[i];
                final other = r['other_user_id'] as String;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(r['other_display_name']?.toString() ?? 'مستخدم'),
                  subtitle: Text(r['last_body']?.toString() ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: r['unread_count'] == null ||
                      r['unread_count'] == 0
                    ? null
                    : Badge(label: Text(r['unread_count'].toString())),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute<void>(
                      builder: (_) => ConversationPage(
                        otherId: other,
                        otherName: r['other_display_name']?.toString() ?? 'مستخدم')));
                    if (context.mounted) setState(_reload);
                  },
                );
              },
            ),
          );
        },
      )),
    ]),
  );
}

class ConversationPage extends StatefulWidget {
  final String otherId;
  final String otherName;
  const ConversationPage({super.key, required this.otherId, required this.otherName});
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}
class _ConversationPageState extends State<ConversationPage> {
  final field = TextEditingController();
  late Future<List<Map<String, dynamic>>> messages;
  bool sending = false;
  String? requestId;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() {
    messages = features.thread(widget.otherId);
    // Read status is authoritative and scoped to this exact conversation.
    features.markDmRead(widget.otherId).catchError((Object _) {});
  }
  @override
  void dispose() { field.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (sending || field.text.trim().isEmpty) return;
    setState(() { sending = true; requestId ??= features.newRequestId(); });
    try {
      await features.sendDm(widget.otherId, field.text,
        requestId: requestId!);
      field.clear();
      requestId = null;
      if (mounted) setState(_reload);
    } catch (error) { if (mounted) _problem(context, error); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: widget.otherName,
    body: Column(children: [
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: messages,
        builder: (context, result) {
          if (result.hasError) return _blank('تعذر تحميل الرسائل');
          if (!result.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = result.data!;
          if (rows.isEmpty) return _blank('ابدأ محادثة نصية');
          return ListView(
            reverse: true,
            padding: const EdgeInsets.all(12),
            children: [
              for (final message in rows)
                Align(
                  alignment: message['sender_id'] == features.ownId
                    ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 285),
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: message['sender_id'] == features.ownId
                        ? const Color(0xFFD1FAE5) : Colors.white,
                      borderRadius: BorderRadius.circular(15)),
                    child: Text(message['body']?.toString() ?? ''),
                  ),
                ),
            ],
          );
        },
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
        child: Row(children: [
          Expanded(child: TextField(controller: field, maxLength: 2000,
            minLines: 1, maxLines: 3,
            onChanged: (_) { requestId = null; },
            decoration: const InputDecoration(
              hintText: 'رسالة نصية...', counterText: '',
              border: OutlineInputBorder()))),
          IconButton(onPressed: sending ? null : _send,
            icon: const Icon(Icons.send, color: ApprovedPalette.emeraldDeep)),
        ]),
      ),
    ]),
  );
}

class PeopleSearchPage extends StatefulWidget {
  const PeopleSearchPage({super.key});
  @override
  State<PeopleSearchPage> createState() => _PeopleSearchPageState();
}
class _PeopleSearchPageState extends State<PeopleSearchPage> {
  final field = TextEditingController();
  Future<List<Map<String, dynamic>>>? result;
  @override
  void dispose() { field.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'البحث عن المستخدمين',
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12),
        child: TextField(controller: field,
          decoration: InputDecoration(
            labelText: 'بداية اسم المستخدم',
            suffixIcon: IconButton(
              onPressed: () => setState(() => result = features.searchPeople(field.text)),
              icon: const Icon(Icons.search)),
            border: const OutlineInputBorder()),
          onSubmitted: (_) => setState(() => result = features.searchPeople(field.text)),
        ),
      ),
      Expanded(child: result == null ? _blank('اكتب حرفين على الأقل للبحث')
        : FutureBuilder<List<Map<String, dynamic>>>(
          future: result,
          builder: (context, snap) {
            if (snap.hasError) return _blank('فشل البحث');
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) return _blank('لا توجد نتائج حقيقية');
            return ListView(children: [
              for (final person in snap.data!)
                ListTile(
                  title: Text(person['display_name']?.toString() ?? ''),
                  leading: const Icon(Icons.account_circle),
                  trailing: const Icon(Icons.chat),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                    builder: (_) => ConversationPage(
                      otherId: person['user_id'] as String,
                      otherName: person['display_name']?.toString() ?? 'مستخدم'))),
                ),
            ]);
          },
        )),
    ]),
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}
class _NotificationsPageState extends State<NotificationsPage> {
  late Future<Map<String, dynamic>> feed;
  @override
  void initState() { super.initState(); _reload(); }
  void _reload() { feed = features.notifications(); }
  Future<void> _markAll() async {
    try { await features.markAllNotifications(); if (mounted) setState(_reload); }
    catch (e) { if (mounted) _problem(context, e); }
  }
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'الإشعارات',
    body: FutureBuilder<Map<String, dynamic>>(
      future: feed,
      builder: (context, snap) {
        if (snap.hasError) return _blank('تعذر تحميل الإشعارات');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!;
        final items = ConnectedFeatures.collection(data['items'] ?? []);
        return Column(children: [
          if (items.isNotEmpty) Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _markAll,
              child: const Text('تحديد الكل كمقروء')),
          ),
          Expanded(child: items.isEmpty ? _blank('لا توجد إشعارات حقيقية')
            : ListView(children: [
              for (final item in items)
                ListTile(
                  leading: Icon(item['read_at'] == null
                    ? Icons.notifications_active : Icons.notifications_none),
                  title: Text(item['event_type']?.toString() ?? 'إشعار'),
                  subtitle: Text(item['created_at']?.toString() ?? ''),
                ),
            ])),
        ]);
      },
    ),
  );
}

class CpPage extends StatefulWidget {
  const CpPage({super.key});
  @override
  State<CpPage> createState() => _CpPageState();
}
class _CpPageState extends State<CpPage> {
  late Future<Map<String, dynamic>> state;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { state = features.cpState(); }

  Future<void> _request(List<Map<String, dynamic>> types) async {
    final partner = TextEditingController();
    String type = types.first['id'] as String;
    try {
      final confirmed = await showDialog<bool>(context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('طلب علاقة CP'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: partner,
              decoration: const InputDecoration(labelText: 'User UUID')),
            DropdownButton<String>(
              value: type,
              items: [for (final t in types)
                DropdownMenuItem(
                  value: t['id'] as String,
                  child: Text(t['label']?.toString() ?? 'CP'))],
              onChanged: (next) => update(() => type = next ?? type),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال')),
          ],
        )));
      if (confirmed != true || !mounted) return;
      await features.cpAction(partner.text.trim(), type, 'request',
        requestId: features.newRequestId());
      if (mounted) setState(reload);
    } catch (error) { if (mounted) _problem(context, error); }
    finally { partner.dispose(); }
  }

  Future<void> _act(Map<String, dynamic> relation, String action) async {
    try {
      await features.cpAction(
        (relation['partner'] as Map)['id'] as String,
        relation['type_id'] as String, action,
        requestId: features.newRequestId());
      if (mounted) setState(reload);
    } catch (e) { if (mounted) _problem(context, e); }
  }
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'علاقات CP',
    body: FutureBuilder<Map<String, dynamic>>(
      future: state,
      builder: (context, snap) {
        if (snap.hasError) return _blank('تعذر قراءة العلاقات');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final types = ConnectedFeatures.collection(snap.data!['types'] ?? []);
        final relations = ConnectedFeatures.collection(snap.data!['relations'] ?? []);
        return ListView(children: [
          if (types.isNotEmpty) Padding(padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: () => _request(types),
              icon: const Icon(Icons.favorite),
              label: const Text('طلب علاقة جديدة'))),
          if (relations.isEmpty) _blank('ما توجد علاقة CP فعّالة'),
          for (final r in relations) Card(
            child: ListTile(
              title: Text((r['partner'] as Map?)?['display_name']?.toString() ?? ''),
              subtitle: Text((r['type_label']?.toString() ?? '') +
                ' - Lv. ' + (r['level']?.toString() ?? '1')),
              trailing: r['accepted_at'] != null
                ? TextButton(onPressed: () => _act(r, 'end'),
                  child: const Text('إنهاء'))
                : r['requested_by'] == features.ownId
                  ? const Text('بانتظار الموافقة')
                  : Wrap(spacing: 4, children: [
                      TextButton(onPressed: () => _act(r, 'accept'),
                        child: const Text('قبول')),
                      TextButton(onPressed: () => _act(r, 'reject'),
                        child: const Text('رفض')),
                    ]),
            ),
          ),
        ]);
      },
    ),
  );
}
