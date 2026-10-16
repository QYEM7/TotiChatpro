import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Only authenticated server-defined Lucky Gift policy and awards appear here.
/// Purchasing stays disabled until both the probabilities and a compliant
/// transaction flow are approved. Never imitate a random draw on the client.
class LuckyGiftPanel extends StatefulWidget {
  const LuckyGiftPanel({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<LuckyGiftPanel> createState() => _LuckyGiftPanelState();
}

class _LuckyGiftPanelState extends State<LuckyGiftPanel> {
  late Future<List<Object?>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = Future.wait<Object?>([
    widget.api.luckyReadiness(),
    widget.api.luckyHistory(),
  ]));

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 242,
    child: ServerPanel<List<Object?>>(
      future: _future,
      retry: _reload,
      builder: (context, results) {
        final policy = results[0] as Map<String, dynamic>;
        final history = results[1] as List<Map<String, dynamic>>;
        final tiers = (policy['tiers'] as List).whereType<Map>().toList();
        final canBuy = policy['enabled'] == true &&
            policy['purchasesAllowed'] == true &&
            policy['approvedOddsPublished'] == true &&
            policy['oddsAreProvisionalStaging'] == false;

        // The server has not approved odds. No client-side purchase is exposed
        // even if configuration is later toggled without a reviewed payment
        // implementation.
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Text(
              canBuy
                ? 'Lucky Gift purchase is awaiting client payment review'
                : 'Lucky Gift purchases are currently unavailable',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Official prize odds are not yet published. '
              'The server awards only non-redeemable Lucky points; '
              'these are not salary, cash, or withdrawable diamonds.',
            ),
            const SizedBox(height: 9),
            if (tiers.isNotEmpty) ...[
              const Text('Server reward tiers (not official draw odds)',
                style: TextStyle(fontWeight: FontWeight.w700)),
              ...tiers.map((tier) => ListTile(
                dense: true,
                title: Text(tier['label']?.toString() ??
                  tier['rewardTier']?.toString() ?? 'Tier'),
                subtitle: Text(
                  'Multiplier: ${tier['multiplier'] ?? 'Unavailable'}'
                  ' · provisional rule'),
              )),
            ],
            const Divider(),
            const Text('My real Lucky awards',
              style: TextStyle(fontWeight: FontWeight.w700)),
            if (history.isEmpty)
              const NoRecords('No Lucky awards have been recorded.'),
            ...history.map((award) => ListTile(
              dense: true,
              title: Text(award['rewardTier']?.toString() ??
                'Lucky award'),
              subtitle: Text(
                'Multiplier: ${award['multiplier'] ?? 'Unavailable'}'
                ' · bonus: ${award['bonusPoints'] ?? 'Unavailable'}'
                ' noncash points'),
              trailing: Text(award['createdAt']?.toString() ?? ''),
            )),
          ],
        );
      },
    ),
  );
}
