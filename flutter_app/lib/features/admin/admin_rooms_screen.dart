import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Owner-only room discovery. Access is also verified by the database RPC.
class AdminRoomsScreen extends StatefulWidget {
  const AdminRoomsScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _rooms;
  String _currentQuery = '';
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() { _rooms = widget.api.adminRoomDirectory(
    search: _currentQuery, offset: _offset); });

  void _submitSearch() {
    final query = _search.text.trim();
    if (query.length > 60) {
      showApiError(context, 'Search cannot exceed 60 characters.');
      return;
    }
    setState(() {
      _currentQuery = query;
      _offset = 0;
      _rooms = widget.api.adminRoomDirectory(
        search: _currentQuery, offset: _offset);
    });
  }

  void _page(int delta) {
    final next = _offset + delta * 30;
    if (next < 0 || next > 99990) return;
    setState(() {
      _offset = next;
      _rooms = widget.api.adminRoomDirectory(
        search: _currentQuery, offset: next);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('Admin room directory'),
        actions: [IconButton(onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded))]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _search,
              maxLength: 60,
              onSubmitted: (_) => _submitSearch(),
              decoration: const InputDecoration(
                labelText: 'Room name',
                counterText: '',
                prefixIcon: Icon(Icons.search_rounded)))),
            IconButton.filled(
              tooltip: 'Find rooms',
              onPressed: _submitSearch,
              icon: const Icon(Icons.search_rounded)),
          ])),
        Expanded(child: ServerPanel<Map<String, dynamic>>(
          future: _rooms,
          retry: _reload,
          builder: (context, page) {
            final rows = TotiChatServices.rows(page);
            final total = (page['total'] as num).toInt();
            return ListView(padding: const EdgeInsets.all(12), children: [
              Text('Verified rooms: $total  ·  Page ${_offset ~/ 30 + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const NoRecords('No rooms found on the server.'),
              for (final room in rows)
                recordCard(context,
                  title: room['title'].toString(),
                  description: [
                    'Room ID: ${room['id']}',
                    'Members: ${room['member_records'] ?? 'Unknown'}',
                    'Private: ${room['is_private'] == true ? 'Yes' : 'No'}',
                  ].join('\n'),
                  icon: Icons.meeting_room_outlined,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AdminRoomDetailScreen(
                        api: widget.api,
                        roomId: room['id'] as String,
                        title: room['title'] as String,
                      ),
                    ));
                    if (mounted) _reload();
                  }),
              if (_offset > 0 || _offset + rows.length < total)
                Row(children: [
                  OutlinedButton(
                    onPressed: _offset == 0 ? null : () => _page(-1),
                    child: const Text('Previous')),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: _offset >= 99990 ||
                        _offset + rows.length >= total
                      ? null : () => _page(1),
                    child: const Text('Next 30')),
                ]),
              if (total > 100020)
                const Text('The API provides the first 100,020 records; '
                  'narrow the room-name search to find older rooms.'),
            ]);
          },
        )),
      ]),
    ),
  );
}

/// The RPC only bans actual members and protects the room owner.
/// No action is sent until confirmed, with a reason and stable request ID.
class AdminRoomDetailScreen extends StatefulWidget {
  const AdminRoomDetailScreen({
    super.key,
    required this.api,
    required this.roomId,
    required this.title,
  });
  final TotiChatServices api;
  final String roomId;
  final String title;

  @override
  State<AdminRoomDetailScreen> createState() =>
    _AdminRoomDetailScreenState();
}

class _AdminRoomDetailScreenState extends State<AdminRoomDetailScreen> {
  final _reason = TextEditingController();
  late Future<Map<String, dynamic>> _state;
  bool _busy = false;
  String? _pendingId;
  String? _pendingTarget;
  String? _pendingAction;
  String? _pendingReason;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() { _state = widget.api.adminRoomState(widget.roomId); });

  Future<void> _confirm(String target, String action) async {
    if (_busy) return;
    if (_pendingId != null) {
      showApiError(context, 'Verify or retry the previous room action '
        'with its original request ID before starting another.');
      return;
    }
    final reason = _reason.text.trim();
    if (reason.length < 10 || reason.length > 300) {
      showApiError(context, 'Enter a documented reason (10–300 characters).');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'ban'
          ? 'Ban participant from this room?' : 'Remove room ban?'),
        content: Text('Room: ${widget.title}\n'
          'Target: $target\n'
          'Reason: $reason\n'
          'This is a real room-only server operation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    _pendingId = TotiChatServices.requestId();
    _pendingTarget = target;
    _pendingAction = action;
    _pendingReason = reason;
    await _retryPending();
  }

  Future<void> _retryPending() async {
    if (_busy || _pendingId == null) return;
    final requestId = _pendingId!;
    final target = _pendingTarget!;
    final action = _pendingAction!;
    final reason = _pendingReason!;
    setState(() => _busy = true);
    try {
      await widget.api.adminRoomAction(
        roomId: widget.roomId,
        targetId: target,
        action: action,
        reason: reason,
        requestId: requestId);
      _pendingId = null;
      _pendingTarget = null;
      _pendingAction = null;
      _pendingReason = null;
      _reason.clear();
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content:
            Text('Server confirmed this room-only moderation action.')));
      }
    } catch (error) {
      // An unknown outcome must retain the original ID for a safe retry.
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text('Room: ${widget.title}'),
        actions: [IconButton(
          onPressed: _busy ? null : _reload,
          icon: const Icon(Icons.refresh_rounded))]),
      body: ServerPanel<Map<String, dynamic>>(
        future: _state,
        retry: _reload,
        builder: (context, state) {
          final owner = state['roomOwnerId'] as String;
          final members = (state['members'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map)).toList();
          final bans = (state['banned'] as List)
              .map((x) => Map<String, dynamic>.from(x as Map)).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Authenticated room moderation',
              style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Room owner (protected): $owner'),
            const SizedBox(height: 7),
            const Text('Room-only actions. No global account ban, '
              'wallet change or room deletion is available here.'),
            const SizedBox(height: 15),
            TextField(
              controller: _reason,
              maxLength: 300,
              minLines: 2,
              maxLines: 3,
              readOnly: _busy || _pendingId != null,
              decoration: const InputDecoration(
                labelText: 'Documented moderation reason',
                hintText: 'Enter a specific reason (10–300 characters)')),
            if (_pendingId != null)
              Card(child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('An earlier operation has an uncertain '
                      'result. Reuse the same request ID.',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Text('${_pendingAction!.toUpperCase()} · '
                      '${_pendingTarget!}'),
                    const SizedBox(height: 9),
                    FilledButton.icon(
                      onPressed: _busy ? null : _retryPending,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Retry original operation')),
                  ],
                ),
              )),
            const SizedBox(height: 18),
            Text('Current participants (${members.length})',
              style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800)),
            if (members.isEmpty)
              const NoRecords('No verified members in this room.'),
            for (final member in members)
              recordCard(context,
                title: member['user_id'].toString(),
                description:
                  'Seat: ${member['seat_no'] ?? 'None'} · '
                  'Muted: ${member['is_muted'] == true ? 'Yes' : 'No'}',
                icon: Icons.person_outline_rounded,
                trailing: member['user_id'] == owner ||
                    member['user_id'] == widget.api.userId
                  ? const Text('Protected')
                  : TextButton(
                      onPressed: _busy || _pendingId != null ? null
                        : () => _confirm(member['user_id'] as String, 'ban'),
                      child: const Text('Room ban'))),
            const SizedBox(height: 18),
            Text('Active room bans (${bans.length})',
              style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800)),
            if (bans.isEmpty)
              const NoRecords('No active bans recorded in this room.'),
            for (final ban in bans)
              recordCard(context,
                title: ban['user_id'].toString(),
                description: 'Reason: ${ban['reason'] ?? 'Unavailable'}',
                icon: Icons.block_outlined,
                trailing: TextButton(
                  onPressed: _busy || _pendingId != null ? null
                    : () => _confirm(ban['user_id'] as String, 'unban'),
                  child: const Text('Unban'))),
            if (members.length >= 200 || bans.length >= 200)
              const Text('The server returns up to 200 members and '
                '200 ban records; this is not a complete export.'),
          ]);
        },
      ),
    ),
  );
}
