import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Read-only historical accrual evidence. This is not a salary payout or
/// month-reset workflow; those actions do not have approved server semantics.
class HostMonthEvidenceScreen extends StatefulWidget {
  const HostMonthEvidenceScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<HostMonthEvidenceScreen> createState() =>
      _HostMonthEvidenceScreenState();
}

class _HostMonthEvidenceScreenState extends State<HostMonthEvidenceScreen> {
  late DateTime _month;
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _month = DateTime.utc(now.year, now.month - 1);
    _reload();
  }

  Future<Map<String, dynamic>> _readEvidence() async {
    final results = await Future.wait([
      widget.api.hostMonthPreflight(_month),
      widget.api.hostMonthSnapshot(_month),
    ]);
    return {'preflight': results[0], 'snapshot': results[1]};
  }

  void _reload() => setState(() => _future = _readEvidence());

  void _changeMonth(int delta) {
    final target = DateTime.utc(_month.year, _month.month + delta);
    final now = DateTime.now().toUtc();
    final current = DateTime.utc(now.year, now.month);
    if (target.isBefore(DateTime.utc(2025)) || !target.isBefore(current)) {
      return;
    }
    setState(() {
      _month = target;
      _future = _readEvidence();
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Host monthly evidence'),
        actions: [
          IconButton(onPressed: _reload,
            icon: const Icon(Icons.refresh)),
        ]),
      body: ServerPanel<Map<String, dynamic>>(
        future: _future,
        retry: _reload,
        builder: (context, data) {
          final preflight = Map<String, dynamic>.from(
            data['preflight'] as Map);
          final snapshot = Map<String, dynamic>.from(
            data['snapshot'] as Map);
          final entries = (preflight['entries'] as List? ?? [])
              .whereType<Map>().toList();
          final capturedItems = (snapshot['items'] as List? ?? [])
              .whereType<Map>().toList();
          final isCaptured = snapshot['captured'] == true;
          final label = '${_month.year}-' +
            _month.month.toString().padLeft(2, '0');
          final now = DateTime.now().toUtc();
          final next = DateTime.utc(_month.year, _month.month + 1);
          final current = DateTime.utc(now.year, now.month);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_right)),
                Expanded(child: Text(
                  'Closed UTC month: $label',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800))),
                IconButton(
                  onPressed: next.isBefore(current)
                    ? () => _changeMonth(1) : null,
                  icon: const Icon(Icons.chevron_left)),
              ]),
              const SizedBox(height: 12),
              const Card(child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Evidence only: no salaries are paid, no diamonds '
                  'are zeroed, and rates are not computed here. '
                  'The source currently covers at most 100 host entries '
                  'per page; totals are server-supplied.',
                ),
              )),
              recordCard(context,
                title: 'Host entries: ' +
                  (preflight['totalHostEntries']?.toString() ?? 'Unavailable'),
                description: 'Draft preflight, current remaining balances '
                  'may differ from the closed-month historical balances.',
                icon: Icons.analytics_outlined),
              recordCard(context,
                title: isCaptured
                  ? 'Snapshot evidence captured'
                  : 'No saved monthly snapshot',
                description: isCaptured
                  ? 'Total diamonds: ' +
                      (snapshot['totalDiamonds']?.toString() ?? 'Unavailable')
                  : 'No immutable capture exists for this month.',
                icon: Icons.verified_outlined),
              const SizedBox(height: 18),
              const Text('Observed host earnings',
                style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800)),
              if (entries.isEmpty)
                const NoRecords('No verified host accrual entries.'),
              ...entries.map((x) => recordCard(context,
                title: 'Host: ' + (x['user_id']?.toString() ?? 'Unavailable'),
                description: [
                  'Agency: ' +
                    (x['agency_id']?.toString() ?? 'Unavailable'),
                  'Earned diamonds: ' +
                    (x['earned_diamonds']?.toString() ?? 'Unavailable'),
                  'Remaining (as of query): ' +
                    (x['remaining_diamonds']?.toString() ?? 'Unavailable'),
                ].join('\n'),
                icon: Icons.diamond_outlined)),
              if (capturedItems.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text('Saved immutable evidence',
                  style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800)),
                ...capturedItems.map((x) => recordCard(context,
                  title: 'Host: ' +
                    (x['host_id']?.toString() ?? 'Unavailable'),
                  description: [
                    'Agency: ' +
                      (x['agency_id']?.toString() ?? 'Unavailable'),
                    'Gift count: ' +
                      (x['gift_count']?.toString() ?? 'Unavailable'),
                    'Earned diamonds: ' +
                      (x['earned_diamonds']?.toString() ?? 'Unavailable'),
                  ].join('\n'))),
              ],
            ],
          );
        },
      ),
    ),
  );
}
