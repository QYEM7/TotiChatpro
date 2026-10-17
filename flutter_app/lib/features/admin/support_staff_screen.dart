import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Owner-only support handler delegation. The server verifies verified users,
/// denies self-delegation and writes the permission audit.
class SupportStaffScreen extends StatefulWidget {
  const SupportStaffScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<SupportStaffScreen> createState() => _SupportStaffScreenState();
}

class _SupportStaffScreenState extends State<SupportStaffScreen> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _staff;
  int _staffOffset = 0;
  Future<List<Map<String, dynamic>>>? _found;
  String? _pendingKey, _pendingId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() =>
    _staff = widget.api.supportStaffPage(offset: _staffOffset));

  void _staffPage(int delta) {
    if (_busy) return;
    final target = _staffOffset + delta * 50;
    if (target < 0 || target > 50000) return;
    setState(() {
      _staffOffset = target;
      _staff = widget.api.supportStaffPage(offset: target);
    });
  }

  void _find() {
    final text = _search.text.trim();
    if (text.length < 2 || text.length > 40) {
      showApiError(context, 'Search requires 2-40 characters.');
      return;
    }
    setState(() { _found = widget.api.socialSearch(text); });
  }

  Future<void> _decision(String targetId, bool enable) async {
    if (_busy || targetId.isEmpty || targetId == widget.api.userId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(enable
          ? 'Grant official support access?'
          : 'Revoke official support access?'),
        content: Text(
          'Account: $targetId\n'
          'This is a real server permission change. '
          'It does not provide Owner, treasury or banner rights.'),
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
    final signature = '${enable?'grant':'revoke'}|$targetId';
    if (_pendingKey != null && _pendingKey != signature) {
      showApiError(context,
        'A prior support-role change has an uncertain result. '
        'Verify or retry that identical action first.');
      return;
    }
    _pendingKey = signature;
    _pendingId ??= TotiChatServices.requestId();
    setState(() => _busy = true);
    try {
      await widget.api.manageSupportStaff(
        targetUserId: targetId,
        enable: enable,
        requestId: _pendingId!);
      _pendingKey = null;
      _pendingId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Official support access updated on server.')));
        _staffOffset = 0;
        _refresh();
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      appBar: AppBar(
        title: const Text('Support staff permissions'),
        actions: [
          IconButton(onPressed: _refresh,
            icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            'Only the Owner can grant/revoke support handling. '
            'This permission allows ticket review and status changes, '
            'not direct wallet or host agency access.'),
          const SizedBox(height: 16),
          const Text('Granted or revoked staff',
            style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.w800)),
          ServerPanel<Map<String, dynamic>>(
            future: _staff,
            retry: _refresh,
            builder: (context, page) {
              final rows = TotiChatServices.rows(page);
              final total = (page['total'] as num).toInt();
              return Column(children: [
              Text('Showing page ${_staffOffset ~/ 50 + 1} '
                '· $total historical staff records'),
              if (rows.isEmpty)
                const NoRecords('No support staff records on this page.'),
              ...rows.map((r) {
                final target = r['user_id']?.toString() ?? '';
                final enabled = r['enabled'] == true;
                return recordCard(context,
                  title: target,
                  description: enabled ? 'Authorized' : 'Revoked',
                  icon: Icons.support_agent,
                  trailing: enabled ? OutlinedButton(
                    onPressed: _busy ? null :
                      () => _decision(target, false),
                    child: const Text('Revoke'),
                  ) : null,
                );
              }),
              if (_staffOffset > 0 || _staffOffset + rows.length < total)
                Row(children: [
                  OutlinedButton(
                    onPressed: _busy || _staffOffset == 0 ? null
                      : () => _staffPage(-1),
                    child: const Text('Previous 50')),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _busy || _staffOffset >= 50000 ||
                        _staffOffset + rows.length >= total ? null
                      : () => _staffPage(1),
                    child: const Text('Next 50')),
                ]),
              if (total > 50050)
                const Text('Only the first 50,050 staff records can '
                  'be paged using the current server API.'),
            ]);
            },
          ),
          const SizedBox(height: 22),
          const Text('Select a verified user to authorize',
            style: TextStyle(fontWeight: FontWeight.w800,
              fontSize: 18)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              controller: _search,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'User display name',
                counterText: ''),
            )),
            IconButton.filled(
              onPressed: _busy ? null : _find,
              icon: const Icon(Icons.search)),
          ]),
          if (_found != null)
            ServerPanel<List<Map<String, dynamic>>>(
              future: _found!,
              retry: _find,
              builder: (context, people) => Column(children: [
                if (people.isEmpty)
                  const NoRecords('No confirmed matching users.'),
                ...people.map((user) {
                  final target =
                    TotiChatServices.verifiedSocialUserId(user);
                  return recordCard(context,
                    title: user['display_name']?.toString() ?? 'Member',
                    description: target,
                    trailing: FilledButton.tonal(
                      onPressed: _busy ||
                          target == widget.api.userId ? null :
                          () => _decision(target, true),
                      child: const Text('Grant support'),
                    ),
                  );
                }),
              ]),
            ),
        ],
      ),
    ),
  );
}
