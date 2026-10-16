import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Staff access is decided by phase3.support_handler() on the server.
class SupportTicketListScreen extends StatefulWidget {
  const SupportTicketListScreen({
    super.key,
    required this.api,
    this.staff = false,
  });
  final TotiChatServices api;
  final bool staff;

  @override
  State<SupportTicketListScreen> createState() =>
      _SupportTicketListScreenState();
}

class _SupportTicketListScreenState extends State<SupportTicketListScreen> {
  late Future<Map<String, dynamic>> _future;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _future =
      widget.api.supportTicketPage(staff: widget.staff, offset: _offset));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.staff ? 'Official support inbox' : 'My tickets'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ServerPanel<Map<String, dynamic>>(
        future: _future,
        retry: _load,
        builder: (context, data) {
          if (widget.staff && data['canHandle'] != true) {
            return const NoRecords('Support staff permission is required.');
          }
          final tickets = TotiChatServices.rows(data);
          final total = (data['total'] as num?)?.toInt();
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              if (tickets.isEmpty)
                const NoRecords('No authenticated support tickets found.'),
              for (final ticket in tickets)
                recordCard(context,
                  title: ticket['subject']?.toString() ?? 'Support ticket',
                  description: [
                    'Status: ${ticket['status'] ?? 'Unknown'}',
                    'Category: ${ticket['category'] ?? 'Unknown'}',
                    'Updated: ${ticket['updated_at'] ?? 'Unknown'}',
                  ].join('\n'),
                  icon: Icons.support_agent_outlined,
                  onTap: () async {
                    final ticketId = ticket['id']?.toString() ?? '';
                    if (ticketId.isEmpty) return;
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SupportTicketThreadScreen(
                        api: widget.api,
                        ticketId: ticketId,
                        title: ticket['subject']?.toString() ??
                          'Support ticket',
                      ),
                    ));
                    if (mounted) _load();
                  },
                ),
              if (_offset > 0 || (total != null
                  ? _offset + tickets.length < total
                  : tickets.length == 50))
                Row(children: [
                  OutlinedButton(
                    onPressed: _offset <= 0 ? null : () {
                      _offset -= 50;
                      _load();
                    },
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: (total != null
                      ? _offset + tickets.length >= total
                      : tickets.length < 50) ||
                        _offset + 50 > 50000 ? null : () {
                      _offset += 50;
                      _load();
                    },
                    child: const Text('Next 50'),
                  ),
                ]),
            ],
          );
        },
      ),
    ),
  );
}

/// A real support conversation, with server-authorized staff decisions.
class SupportTicketThreadScreen extends StatefulWidget {
  const SupportTicketThreadScreen({
    super.key,
    required this.api,
    required this.ticketId,
    required this.title,
  });
  final TotiChatServices api;
  final String ticketId;
  final String title;

  @override
  State<SupportTicketThreadScreen> createState() =>
      _SupportTicketThreadScreenState();
}

class _SupportTicketThreadScreenState
    extends State<SupportTicketThreadScreen> {
  late Future<Map<String, dynamic>> _thread;
  final _reply = TextEditingController();
  String? _pendingKey, _pendingId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() =>
    _thread = widget.api.supportThread(widget.ticketId));

  Future<void> _perform({
    required String key,
    required Future<void> Function(String requestId) action,
  }) async {
    if (_busy) return;
    if (_pendingKey != null && _pendingKey != key) {
      showApiError(context,
        'Verify the previous support action before changing its details. '
        'Retry the same operation to reuse its original idempotency key.');
      return;
    }
    _pendingKey = key;
    _pendingId ??= TotiChatServices.requestId();
    setState(() => _busy = true);
    try {
      await action(_pendingId!);
      _pendingKey = null;
      _pendingId = null;
      _reply.clear();
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The server confirmed the support action.')));
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final message = _reply.text.trim();
    if (message.length < 2 || message.length > 2500) {
      showApiError(context, 'Reply must be between 2 and 2500 characters.');
      return;
    }
    await _perform(
      key: 'reply|${widget.ticketId}|$message',
      action: (id) => widget.api.supportReply(
        ticketId: widget.ticketId, message: message, requestId: id));
  }

  Future<void> _changeStatus(String value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm support status'),
        content: Text('Change this real ticket to $value?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(
      key: 'status|${widget.ticketId}|$value',
      action: (id) => widget.api.supportChangeStatus(
        ticketId: widget.ticketId, status: value, requestId: id));
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ServerPanel<Map<String, dynamic>>(
        future: _thread,
        retry: _reload,
        builder: (context, data) {
          final ticket = Map<String, dynamic>.from(data['ticket'] as Map);
          final messages = (data['messages'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList()
              .reversed
              .toList();
          final status = ticket['status']?.toString() ?? '';
          final canHandle = data['canHandle'] == true;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                Text('Status: $status',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                if (canHandle)
                  Wrap(spacing: 5, children: [
                    for (final option in [
                      'open', 'in_progress', 'resolved', 'closed'
                    ])
                      ActionChip(
                        label: Text(option),
                        onPressed: _busy || status == option ? null :
                          () => _changeStatus(option)),
                  ]),
                if ((data['total'] as num?)?.toInt() != null &&
                    (data['total'] as num).toInt() > 50)
                  const Text('Showing the latest 50 messages only.'),
              ]),
            ),
            Expanded(child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (messages.isEmpty)
                  const NoRecords('No messages in this ticket.'),
                ...messages.map((m) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['author_id']?.toString() ==
                            widget.api.userId ? 'Me' : 'Support conversation',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(m['body']?.toString() ?? ''),
                        const SizedBox(height: 5),
                        Text(m['created_at']?.toString() ?? '',
                          style: const TextStyle(fontSize: 11)),
                      ]),
                  ),
                )),
              ]),
            )),
            if (status != 'closed')
              SafeArea(top: false, child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _reply,
                    maxLength: 2500,
                    minLines: 1,
                    maxLines: 3,
                    readOnly: _busy || _pendingId != null,
                    decoration: const InputDecoration(
                      labelText: 'Reply to this ticket',
                      counterText: ''),
                  )),
                  const SizedBox(width: 7),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_rounded)),
                ]),
              )),
          ]);
        },
      ),
    ),
  );
}
