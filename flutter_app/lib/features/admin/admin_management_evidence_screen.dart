import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Owner-only read-only reports sourced from the audited Staging RPC.
/// This screen never changes salaries, agencies, access, or ledgers.
class AdminManagementEvidenceScreen extends StatefulWidget {
  const AdminManagementEvidenceScreen({super.key, required this.api});

  final TotiChatServices api;

  @override
  State<AdminManagementEvidenceScreen> createState() =>
      _AdminManagementEvidenceScreenState();
}

class _AdminManagementEvidenceScreenState
    extends State<AdminManagementEvidenceScreen> {
  static const _labels = <String, String>{
    'staff': 'Administrative access',
    'host_agencies': 'Host agencies',
    'recharge_agencies': 'Charging agencies',
    'registrations': 'Agency applications',
    'agency_transfers': 'Agency joining / transfers',
    'audit': 'Security audit',
  };

  String _kind = 'staff';
  int _offset = 0;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.adminManagementPage(_kind);
  }

  void _reload() => setState(() {
    _future = widget.api.adminManagementPage(_kind, offset: _offset);
  });

  void _category(String? kind) {
    if (kind == null || kind == _kind || !_labels.containsKey(kind)) return;
    setState(() {
      _kind = kind;
      _offset = 0;
      _future = widget.api.adminManagementPage(kind);
    });
  }

  void _page(int delta) {
    final next = _offset + delta * 30;
    if (next < 0 || next > 49980) return;
    setState(() {
      _offset = next;
      _future = widget.api.adminManagementPage(_kind, offset: next);
    });
  }

  String _details(Map<String, dynamic> item) {
    String val(String key) => item[key]?.toString() ?? 'Unavailable';
    switch (_kind) {
      case 'staff':
        final permissions = item['permissions'] as List;
        return [
          'Role: ${val('role')}',
          'Permissions: ${permissions.isEmpty ? 'None' : permissions.join(', ')}',
          'Granted by: ${val('assigned_by')}',
          'Updated: ${val('updated_at')}',
        ].join('\n');
      case 'host_agencies':
      case 'recharge_agencies':
        return [
          'Owner: ${val('owner_id')}',
          'Status: ${item['is_active'] == true ? 'Active' : 'Inactive'}',
          'Commission: ${val('commission_percent')}',
          'Members: ${val('member_count')}',
        ].join('\n');
      case 'registrations':
        return [
          'Type: ${val('kind')}',
          'Applicant: ${val('applicant_id')}',
          'Status: ${val('status')}',
          'Created: ${val('created_at')}',
        ].join('\n');
      case 'agency_transfers':
        return [
          'Member: ${val('user_id')}',
          'Agency: ${val('agency_id')}',
          'Previous agency: ${val('old_agency_id')}',
          'Status: ${val('status')}',
          'Reason: ${val('reason')}',
        ].join('\n');
      case 'audit':
        return [
          'Actor: ${val('actor_id')}',
          'Request / operation: ${val('operation_id')}',
          'Recorded: ${val('created_at')}',
        ].join('\n');
      default:
        return 'Server record unavailable';
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Administrative records'),
        actions: [
          IconButton(
            tooltip: 'Reload authenticated server evidence',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded)),
        ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Verified server records · read-only',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'The server limits access to the Owner and designated '
                'main partner. No role, agency or audit record can be '
                'changed from this report.'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _kind,
                decoration: const InputDecoration(
                  labelText: 'Records category',
                  border: OutlineInputBorder()),
                items: [
                  for (final entry in _labels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _category,
              ),
            ],
          ),
        ),
        Expanded(child: ServerPanel<Map<String, dynamic>>(
          future: _future,
          retry: _reload,
          builder: (context, page) {
            final rows = TotiChatServices.rows(page);
            final total = (page['total'] as num).toInt();
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Text('${_labels[_kind]} · $total total · '
                  'page ${_offset ~/ 30 + 1}',
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('Verified at: ${page['asOf']}',
                  style: const TextStyle(
                    color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const NoRecords('No matching records on this page.'),
                for (final item in rows)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_kind == 'staff'
                              ? item['user_id'].toString()
                              : _kind == 'audit'
                                ? '${item['action']} · #${item['id']}'
                                : _kind == 'agency_transfers'
                                  ? 'Transfer #${item['id']}'
                                  : item['name']?.toString() ??
                                    'Record #${item['id']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          SelectableText(_details(item)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  OutlinedButton(
                    onPressed: _offset == 0 ? null : () => _page(-1),
                    child: const Text('Previous')),
                  const SizedBox(width: 10),
                  FilledButton.tonal(
                    onPressed: _offset >= 49980 ||
                      _offset + rows.length >= total
                      ? null : () => _page(1),
                    child: const Text('Next 30')),
                ]),
                if (total > 50010)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'The server permits only the first 50,010 records '
                      'through this report. It is not a complete export '
                      'for larger historical datasets.'),
                  ),
              ],
            );
          },
        )),
      ]),
    ),
  );
}
