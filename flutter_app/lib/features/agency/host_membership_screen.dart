import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Host agency membership and transfer requests are always committed by RPC.
class HostAgencyMembershipScreen extends StatefulWidget {
  const HostAgencyMembershipScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<HostAgencyMembershipScreen> createState() =>
      _HostAgencyMembershipScreenState();
}

class _HostAgencyMembershipScreenState
    extends State<HostAgencyMembershipScreen> {
  late Future<Map<String, dynamic>> _state;
  bool _busy = false;
  String? _pendingKey, _pendingId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _state = widget.api.agencyState(); });

  Future<void> _join(Map agency) async {
    if (_busy) return;
    final id = agency['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final reason = TextEditingController();
    final request = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Join ' + (agency['name']?.toString() ?? 'host agency')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'A transfer must be approved by the previous agency first. '
            'Only the server can complete membership changes.'),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for joining (required)'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, reason.text.trim()),
            child: const Text('Submit request')),
        ],
      ),
    );
    reason.dispose();
    if (request == null || !mounted) return;
    if (request.length < 3 || request.length > 500) {
      showApiError(context, 'Enter a reason between 3 and 500 characters.');
      return;
    }
    final key = 'join|$id|$request';
    await _run(key, () => widget.api.joinHostAgency(
      agencyId: id, reason: request, requestId: _pendingId!));
  }

  Future<void> _decision(String id, String action) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm host agency decision'),
        content: Text('Submit $action for this pending request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm')),
        ]),
    );
    if (confirmed != true || !mounted) return;
    await _run('decision|$id|$action', () => widget.api.reviewHostJoin(
      joinId: id, action: action, requestId: _pendingId!));
  }

  Future<void> _run(String signature, Future<Object?> Function() call) async {
    // An unknown network outcome must only be retried with its original key
    // and identical payload; never double-create financial/social requests.
    if (_pendingKey != null && _pendingKey != signature) {
      showApiError(context,
        'An earlier request needs verification. Retry the same action '
        'with identical details or refresh its status.');
      return;
    }
    _pendingKey = signature;
    _pendingId ??= TotiChatServices.requestId();
    setState(() => _busy = true);
    try {
      await call();
      _pendingId = null;
      _pendingKey = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Server confirmed your agency action.')));
        _refresh();
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Host agencies'),
        actions: [
          IconButton(onPressed: _refresh,
            icon: const Icon(Icons.refresh)),
        ]),
      body: ServerPanel<Map<String, dynamic>>(
        future: _state,
        retry: _refresh,
        builder: (context, state) {
          final uid = widget.api.userId;
          final agencies = (state['agencies'] as List? ?? [])
              .whereType<Map>()
              .where((a) => a['kind'] == 'host').toList();
          final owned = agencies
              .where((a) => a['owner_id']?.toString() == uid)
              .map((a) => a['id']?.toString())
              .whereType<String>().toSet();
          final available = agencies
              .where((a) => a['is_active'] == true).toList();
          final requests = (state['requests'] as List? ?? [])
              .whereType<Map>().toList();
          final member = (state['members'] as List? ?? [])
              .whereType<Map>()
              .where((m) => m['user_id']?.toString() == uid)
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _state;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text('My membership',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)),
                if (member.isEmpty)
                  const NoRecords('Not enrolled in a host agency.'),
                ...member.map((m) => recordCard(context,
                  title: 'Active membership',
                  description: 'Agency ID: ' +
                    (m['agency_id']?.toString() ?? 'Unavailable'),
                  icon: Icons.verified_user_outlined)),
                const SizedBox(height: 20),
                const Text('Available host agencies',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)),
                if (available.isEmpty)
                  const NoRecords('No active host agencies yet.'),
                ...available.map((a) => recordCard(context,
                  title: a['name']?.toString() ?? 'Host agency',
                  icon: Icons.groups_rounded,
                  trailing: FilledButton.tonal(
                    onPressed: _busy ? null : () => _join(a),
                    child: const Text('Request to join')))),
                const SizedBox(height: 20),
                const Text('Membership requests',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)),
                if (requests.isEmpty)
                  const NoRecords('No real requests have been registered.'),
                ...requests.map((r) {
                  final id = r['id']?.toString() ?? '';
                  final status = r['status']?.toString() ?? '';
                  final ownOld = owned.contains(
                    r['old_agency_id']?.toString());
                  final ownNew = owned.contains(
                    r['agency_id']?.toString());
                  final action = status == 'pending_old' && ownOld
                      ? 'approve_old'
                      : status == 'pending_new' && ownNew
                          ? 'accept_join'
                          : null;
                  final canReject = (ownOld && status == 'pending_old') ||
                      (ownNew && status == 'pending_new');
                  return recordCard(context,
                    title: r['user_id']?.toString() == uid
                        ? 'My request'
                        : 'Agency membership request',
                    description: 'Status: $status\nRequest: $id',
                    icon: Icons.assignment_outlined,
                    trailing: action == null && !canReject ? null
                        : Wrap(spacing: 6, children: [
                          if (action != null)
                            FilledButton.tonal(
                              onPressed: _busy ? null :
                                () => _decision(id, action),
                              child: Text(action == 'approve_old'
                                ? 'Release host' : 'Accept')),
                          if (canReject)
                            TextButton(
                              onPressed: _busy ? null :
                                () => _decision(id, 'reject_join'),
                              child: const Text('Reject')),
                        ]),
                  );
                }),
              ],
            ),
          );
        },
      ),
    ),
  );
}
