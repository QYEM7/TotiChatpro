import 'package:flutter/material.dart';
import 'connected_features.dart';
import 'social_pages.dart';

class SupportTicketPage extends StatefulWidget {
  final String ticketId;
  const SupportTicketPage({super.key, required this.ticketId});
  @override
  State<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage> {
  final replyField = TextEditingController();
  late Future<Map<String, dynamic>> thread;
  String? requestId;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    thread = features.supportThread(widget.ticketId);
  }

  @override
  void dispose() {
    replyField.dispose();
    super.dispose();
  }

  void problem(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر تنفيذ طلب الدعم: $error')),
    );
  }

  Future<void> sendReply() async {
    if (busy || replyField.text.trim().length < 2) return;
    setState(() {
      busy = true;
      requestId ??= features.newRequestId();
    });
    try {
      await features.replySupportTicket(
        widget.ticketId, replyField.text, requestId: requestId!);
      replyField.clear();
      requestId = null;
      if (mounted) setState(reload);
    } catch (error) {
      problem(error);
      // Preserve idempotency token across uncertain retries.
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changeStatus(String next) async {
    if (busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير حالة طلب الدعم'),
        content: Text('تأكيد الحالة الجديدة: $next'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await features.updateSupportStatus(
        widget.ticketId, next, requestId: features.newRequestId());
      if (mounted) setState(reload);
    } catch (error) {
      problem(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'تفاصيل طلب الدعم',
    body: FutureBuilder<Map<String, dynamic>>(
      future: thread,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر عرض الطلب'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final ticket = ConnectedFeatures.object(data['ticket']);
        final messages = ConnectedFeatures.collection(data['messages'] ?? []);
        final canHandle = data['canHandle'] == true;
        final isClosed = ticket['status'] == 'closed';

        return Column(children: [
          ListTile(
            title: Text(ticket['subject']?.toString() ?? ''),
            subtitle: Text('الحالة: '),
          ),
          if (canHandle)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final status in const [
                  'open', 'in_progress', 'resolved', 'closed',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: busy ? null : () => changeStatus(status),
                      child: Text(status),
                    ),
                  ),
              ]),
            ),
          const Divider(height: 1),
          Expanded(child: messages.isEmpty
            ? const Center(child: Text('لا توجد رسائل بعد'))
            : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (ctx, i) {
                final message = messages[i];
                final mine = message['author_id'] == features.ownId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 310),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFFD1FAE5) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(message['body']?.toString() ?? ''),
                  ),
                );
              },
            )),
          if (!isClosed)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: replyField,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 2500,
                  onChanged: (_) => requestId = null,
                  decoration: const InputDecoration(
                    hintText: 'الرد على التذكرة',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                )),
                IconButton(
                  onPressed: busy ? null : sendReply,
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
        ]);
      },
    ),
  );
}

class SupportInboxPage extends StatefulWidget {
  const SupportInboxPage({super.key});
  @override
  State<SupportInboxPage> createState() => _SupportInboxPageState();
}
class _SupportInboxPageState extends State<SupportInboxPage> {
  late Future<Map<String, dynamic>> access;
  late Future<Map<String, dynamic>> tickets;
  @override
  void initState() {
    super.initState();
    access = features.adminSupportAccess();
    reload();
  }
  void reload() {
    tickets = features.listAllSupportTickets();
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'معالجة طلبات الدعم',
    body: FutureBuilder<Map<String, dynamic>>(
      future: access,
      builder: (context, authorization) {
        if (authorization.hasError ||
            (authorization.hasData &&
             authorization.data?['canHandle'] != true)) {
          return const Center(child: Text('ليس لديك تصريح لمعالجة الدعم'));
        }
        if (!authorization.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return FutureBuilder<Map<String, dynamic>>(
          future: tickets,
          builder: (context, result) {
            if (result.hasError) {
              return const Center(child: Text('تعذر عرض تذاكر الدعم'));
            }
            if (!result.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = ConnectedFeatures.collection(
              result.data!['rows'] ?? []);
            if (rows.isEmpty) {
              return const Center(child: Text('لا توجد تذاكر حالياً'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(reload);
                try { await tickets; } catch (_) {}
              },
              child: ListView(children: [
                for (final ticket in rows)
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: Text(ticket['subject']?.toString() ?? ''),
                    subtitle: Text(ticket['status']?.toString() ?? ''),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () async {
                      await Navigator.push(context,
                        MaterialPageRoute<void>(
                          builder: (_) => SupportTicketPage(
                            ticketId: ticket['id'] as String)));
                      if (context.mounted) setState(reload);
                    },
                  ),
              ]),
            );
          },
        );
      },
    ),
  );
}
