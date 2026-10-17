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
  int _conservationOffset = 0;
  int _preflightOffset = 0;
  int _snapshotOffset = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _month = DateTime.utc(now.year, now.month - 1);
    _reload();
  }

  Future<Map<String, dynamic>> _readEvidence() async {
    final results = await Future.wait([
      widget.api.hostMonthPreflight(_month, offset: _preflightOffset),
      widget.api.hostMonthSnapshot(_month, offset: _snapshotOffset),
      widget.api.hostMonthIntegrity(_month),
      widget.api.hostMonthConservation(
        _month, offset: _conservationOffset),
    ]);
    return {
      'preflight': results[0],
      'snapshot': results[1],
      'integrity': results[2],
      'conservation': results[3],
    };
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
      _conservationOffset = 0;
      _preflightOffset = 0;
      _snapshotOffset = 0;
      _future = _readEvidence();
    });
  }

  void _changeEvidencePage(int delta, {required bool snapshot}) {
    final old = snapshot ? _snapshotOffset : _preflightOffset;
    final target = old + delta * 100;
    if (target < 0 || target > 50000) return;
    setState(() {
      if (snapshot) {
        _snapshotOffset = target;
      } else {
        _preflightOffset = target;
      }
      _future = _readEvidence();
    });
  }

  void _changeConservationPage(int delta) {
    final target = _conservationOffset + delta * 30;
    if (target < 0 || target > 99990) return;
    setState(() {
      _conservationOffset = target;
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
          final integrity = Map<String, dynamic>.from(
            data['integrity'] as Map);
          final conservation = Map<String, dynamic>.from(
            data['conservation'] as Map);
          final conservationHosts = (conservation['hosts'] as List)
              .whereType<Map>().toList();
          final auditHasProblems = integrity['hasEvidenceProblems'] == true ||
            conservation['hasDiscrepancies'] == true;
          final entries = (preflight['entries'] as List? ?? [])
              .whereType<Map>().toList();
          final capturedItems = (snapshot['items'] as List? ?? [])
              .whereType<Map>().toList();
          final isCaptured = snapshot['captured'] == true;
          final preflightTotal = (preflight['totalHostEntries'] as num).toInt();
          final snapshotTotal = (snapshot['entries'] as num).toInt();
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
                  'Each preflight and saved-snapshot page contains at most '
                  '100 host entries. Conservation pages contain at most 30. '
                  'All page totals come from the server.',
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
              const Text('Historical gift and diamond audit',
                style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(auditHasProblems
                        ? 'Audit: discrepancies detected — review required'
                        : 'Audit: no discrepancies detected in current evidence',
                      style: TextStyle(fontWeight: FontWeight.w800,
                        color: auditHasProblems
                          ? Colors.red.shade800 : Colors.black87)),
                    const SizedBox(height: 8),
                    Text('Historical host gifts: ' +
                      (integrity['hostGiftEvents']?.toString() ?? 'Unknown')),
                    Text('Missing or mismatched diamond lots: ' +
                      (integrity['hostGiftsMissingOrMismatchedLots']
                        ?.toString() ?? 'Unknown')),
                    Text('Unassigned gift events for review: ' +
                      (integrity['unassignedGiftEventsForReview']
                        ?.toString() ?? 'Unknown')),
                    Text('Snapshot: ' + (integrity['snapshotCaptured'] == true
                      ? integrity['snapshotConsistent'] == true
                        ? 'Captured and consistent'
                        : 'Captured — consistency not established'
                      : 'Not captured')),
                    const SizedBox(height: 10),
                    Text('Lot discrepancies: ' +
                      (conservation['hostLotDiscrepancies']?.toString() ?? 'Unknown')),
                    Text('Redemption allocation owner issues: ' +
                      (conservation['foreignOwnerRedemptionAllocations']
                        ?.toString() ?? 'Unknown')),
                    Text('Redemption conservation issues: ' +
                      (conservation['redemptionConservationDiscrepancies']
                        ?.toString() ?? 'Unknown')),
                    Text('Host wallet balance issues: ' +
                      (conservation['hostWalletBalanceDiscrepancies']
                        ?.toString() ?? 'Unknown')),
                    const Divider(),
                    const Text('Payroll approval, salary transfers, '
                      'conversion rates and diamond reset are not enabled. '
                      'A clean audit is NOT payroll authorization.'),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text(
                  'Host conservation evidence (page ' +
                    (_conservationOffset ~/ 30 + 1).toString() + ')',
                  style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800))),
                OutlinedButton(
                  onPressed: _conservationOffset == 0 ? null
                    : () => _changeConservationPage(-1),
                  child: const Text('Previous')),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: conservationHosts.length < 30 ||
                      _conservationOffset >= 99990 ? null
                    : () => _changeConservationPage(1),
                  child: const Text('Next')),
              ]),
              if (conservationHosts.isEmpty)
                const NoRecords('No historical host conservation rows.'),
              ...conservationHosts.map((entry) => recordCard(context,
                icon: Icons.fact_check_outlined,
                title: 'Host: ' +
                  (entry['hostId']?.toString() ?? 'Unknown'),
                description: [
                  'Agency: ' + (entry['agencyId']?.toString() ?? 'Unknown'),
                  'Completed gifts: ' +
                    (entry['giftCount']?.toString() ?? 'Unknown'),
                  'Historical earned diamonds: ' +
                    (entry['earnedDiamonds']?.toString() ?? 'Unknown'),
                  'Redeemed up to now: ' +
                    (entry['redeemedDiamondsToDate']?.toString() ?? 'Unknown'),
                  'Remaining now (not historical): ' +
                    (entry['unredeemedDiamondsNow']?.toString() ?? 'Unknown'),
                ].join('\n'))),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Text(
                  'Observed host earnings · page ' +
                    (_preflightOffset ~/ 100 + 1).toString() +
                    ' · total $preflightTotal',
                  style: const TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800))),
                OutlinedButton(
                  onPressed: _preflightOffset == 0 ? null
                    : () => _changeEvidencePage(-1, snapshot: false),
                  child: const Text('Previous')),
                const SizedBox(width: 6),
                OutlinedButton(
                  onPressed: _preflightOffset + 100 >= preflightTotal
                    ? null : () => _changeEvidencePage(1, snapshot: false),
                  child: const Text('Next')),
              ]),
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
              if (isCaptured) ...[
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: Text(
                    'Saved immutable evidence · page ' +
                      (_snapshotOffset ~/ 100 + 1).toString() +
                      ' · total $snapshotTotal',
                    style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800))),
                  OutlinedButton(
                    onPressed: _snapshotOffset == 0 ? null
                      : () => _changeEvidencePage(-1, snapshot: true),
                    child: const Text('Previous')),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: _snapshotOffset + 100 >= snapshotTotal
                      ? null : () => _changeEvidencePage(1, snapshot: true),
                    child: const Text('Next')),
                ]),
                if (capturedItems.isEmpty)
                  const NoRecords('No saved records on this page.'),
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
