import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Owner operations are backed by the Staging treasury and immutable ledgers.
/// No coins are minted by client state or by any test fixture.
class OwnerTreasuryScreen extends StatefulWidget {
  const OwnerTreasuryScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<OwnerTreasuryScreen> createState() => _OwnerTreasuryScreenState();
}

class _OwnerTreasuryScreenState extends State<OwnerTreasuryScreen> {
  late Future<Map<String, dynamic>> _state;
  bool _busy = false;
  String? _pendingSignature, _pendingId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _state = widget.api.rechargeState(); });

  Future<void> _perform(String action, List<Map> agencies) async {
    if (_busy) return;
    final amountField = TextEditingController();
    final noteField = TextEditingController();
    final referenceField = TextEditingController();
    String? target = agencies.isNotEmpty
        ? agencies.first['id']?.toString() : null;

    final proposal = await showDialog<({
      String amount, String note, String reference, String? target
    })>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(action == 'issue'
            ? 'Record verified coin issuance'
            : 'Allocate treasury to recharge agency'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'Financial operations are server-audited. '
                'Never enter a fictitious receipt or amount.'),
              const SizedBox(height: 12),
              TextField(
                controller: amountField,
                keyboardType: TextInputType.number,
                maxLength: 16,
                decoration: const InputDecoration(
                  labelText: 'Coins (positive integer)'),
              ),
              const SizedBox(height: 8),
              if (action == 'allocate')
                DropdownButtonFormField<String>(
                  initialValue: target,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Active recharge agency'),
                  items: agencies.map((a) => DropdownMenuItem(
                    value: a['id']?.toString(),
                    child: Text(a['name']?.toString() ?? 'Recharge agent',
                      overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => update(() => target = value),
                ),
              TextField(
                controller: noteField,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Evidence and reason (10-500 chars)'),
              ),
              if (action == 'issue')
                TextField(
                  controller: referenceField,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Unique verified cash reference'),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (
                amount: amountField.text.trim(),
                note: noteField.text.trim(),
                reference: referenceField.text.trim(),
                target: target,
              )),
              child: const Text('Review operation')),
          ],
        ),
      ),
    );

    amountField.dispose();
    noteField.dispose();
    referenceField.dispose();
    if (proposal == null || !mounted) return;
    final amount = TotiChatServices.parseTreasuryAmount(proposal.amount);
    if (amount == null ||
        proposal.note.length < 10 || proposal.note.length > 500 ||
        (action == 'issue' &&
          (proposal.reference.length < 3 || proposal.reference.length > 120)) ||
        (action == 'allocate' && proposal.target == null)) {
      showApiError(context, 'Invalid evidence, amount or agency selection.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final financial confirmation'),
        content: Text(
          'This will submit $amount coins as $action to the real '
          'Staging ledger. This operation cannot be undone from this screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm audited operation')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final signature = [
      action, amount, proposal.note,
      proposal.reference, proposal.target ?? '',
    ].join('|');
    if (_pendingSignature != null && _pendingSignature != signature) {
      showApiError(context,
        'An earlier treasury operation has an unknown result. '
        'Verify it in the ledger before submitting different data.');
      return;
    }
    _pendingSignature = signature;
    _pendingId ??= TotiChatServices.requestId();
    setState(() => _busy = true);
    try {
      await widget.api.ownerTreasuryAction(
        action: action,
        coins: amount,
        note: proposal.note,
        cashReference: action == 'issue' ? proposal.reference : null,
        agencyId: action == 'allocate' ? proposal.target : null,
        requestId: _pendingId!,
      );
      _pendingSignature = null;
      _pendingId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Operation confirmed by Staging ledger.')));
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
        title: const Text('Owner treasury'),
        actions: [
          IconButton(onPressed: _refresh,
            icon: const Icon(Icons.refresh)),
        ]),
      body: ServerPanel<Map<String, dynamic>>(
        future: _state,
        retry: _refresh,
        builder: (context, state) {
          if (state['isOwner'] != true) {
            return const NoRecords('Owner authorization is required.');
          }
          final balance = state['treasury']?.toString() ?? 'Unavailable';
          final issued = state['issued']?.toString() ?? 'Unavailable';
          final agencies = (state['agencies'] as List? ?? [])
              .whereType<Map>()
              .where((a) => a['is_active'] == true)
              .toList();
          final ledger = (state['ledger'] as List? ?? [])
              .whereType<Map>().toList();

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _state;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                recordCard(context,
                  title: 'Available owner coins: $balance',
                  description: 'Total issued (server): $issued',
                  icon: Icons.account_balance_rounded),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _perform('issue', agencies),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Record documented issuance')),
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: _busy || agencies.isEmpty
                    ? null : () => _perform('allocate', agencies),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Fund an active recharge agency')),
                const SizedBox(height: 22),
                const Text('Treasury ledger (verified)',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)),
                if (ledger.isEmpty)
                  const NoRecords('No treasury movements recorded.'),
                ...ledger.map((r) => recordCard(context,
                  title: 'Change: ' +
                    (r['amount']?.toString() ?? 'Unavailable'),
                  icon: Icons.history_outlined,
                  description: [
                    'Balance after: ' +
                      (r['balance_after']?.toString() ?? 'Unavailable'),
                    'Date: ' + (r['created_at']?.toString() ?? 'Unavailable'),
                  ].join('\n'))),
              ],
            ),
          );
        },
      ),
    ),
  );
}
