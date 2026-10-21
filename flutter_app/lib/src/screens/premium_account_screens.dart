import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/green_theme.dart';
import '../core/premium_ui.dart';
import '../core/ui_text.dart';
import '../data/gift_repository.dart';

/// Read-only authorized balances and ledger. Charging takes place via
/// approved agents; this screen deliberately has NO direct card payments.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<WalletBalance> _balance = _repo.balance();
  final GiftRepository _repo = GiftRepository(Supabase.instance.client);
  late Future<List<Map<String, dynamic>>> _ledger = _loadLedger();

  Future<List<Map<String, dynamic>>> _loadLedger() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw StateError('Authorized account required');
    final rows = await Supabase.instance.client
      .from('wallet_ledger')
      .select('currency,amount_change,balance_after,kind,created_at')
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(30);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _balance = _repo.balance();
      _ledger = _loadLedger();
    });
  }

  @override
  Widget build(BuildContext context) => PremiumPage(
    title: UiText.get('wallet_title'),
    actions: [
      IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: UiText.get('refresh')),
    ],
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        const PremiumGoldLabel(title: 'TotiChat'),
        const SizedBox(height: 16),
        FutureBuilder<WalletBalance>(
          future: _balance,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return PremiumEmptyState(icon: Icons.error_outline, title: UiText.get('wallet_no_balance'),
                action: TextButton(onPressed: _refresh, child: Text(UiText.get('retry'))));
            }
            final b = snapshot.requireData;
            return Row(children: [
              Expanded(child: PremiumSurface(child: Column(children: [
                const Icon(Icons.monetization_on_outlined, color: GreenTheme.gold, size: 32),
                const SizedBox(height: 8),
                Text('${b.coins}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: GreenTheme.primaryDark)),
                Text(UiText.get('wallet_coins'), style: const TextStyle(fontSize: 12)),
              ]))),
              const SizedBox(width: 10),
              Expanded(child: PremiumSurface(child: Column(children: [
                const Icon(Icons.diamond_outlined, color: GreenTheme.primary, size: 32),
                const SizedBox(height: 8),
                Text('${b.diamonds}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: GreenTheme.primaryDark)),
                Text(UiText.get('wallet_diamonds'), style: const TextStyle(fontSize: 12)),
              ]))),
            ]);
          },
        ),
        const SizedBox(height: 18),
        PremiumSurface(child: Row(children: [
          const Icon(Icons.verified_user_outlined, color: GreenTheme.primaryDark),
          const SizedBox(width: 12),
          Expanded(child: Text(UiText.get('wallet_agents_only'),
              style: const TextStyle(fontSize: 13, color: GreenTheme.ink))),
        ])),
        const SizedBox(height: 24),
        PremiumHeader(title: UiText.get('wallet_transactions')),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _ledger,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(24), child: CircularProgressIndicator(),
              ));
            }
            if (snapshot.hasError) {
              return PremiumEmptyState(
              icon: Icons.error_outline,
              title: UiText.get('wallet_history_error'),
            );
            }
            final rows = snapshot.requireData;
            if (rows.isEmpty) {
              return PremiumEmptyState(
              icon: Icons.receipt_long_outlined,
              title: UiText.get('wallet_history_empty'),
            );
            }
            return Column(children: rows.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumRow(
                icon: Icons.receipt_outlined,
                title: entry['kind']?.toString() ?? '',
                subtitle: entry['created_at']?.toString().split('T').first,
                trailing: Text('${entry['amount_change'] ?? ''}  ${entry['currency'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )).toList());
          },
        ),
      ]),
    ),
  );
}

/// Catalog is loaded from Staging. Buying isn't simulated and won't debit a
/// user's wallet until the approved server-side purchase flow is integrated.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String _category = 'all';
  late Future<List<Map<String, dynamic>>> _items = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('store_catalog')
      .select('id,name,category,price,currency,icon')
      .eq('is_active', true)
      .eq('is_reward', false)
      .order('price', ascending: true)
      .limit(120);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<void> _refresh() async { setState(() => _items = _load()); }

  @override
  Widget build(BuildContext context) {
    const categories = ['all','frames','cars','bubbles','entrances','vip','cards'];
    return PremiumPage(
      title: UiText.get('store_title'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: PremiumSurface(child: Row(children: [
            const Icon(Icons.workspace_premium_outlined, color: GreenTheme.gold, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(UiText.get('store_vip_title'), style: const TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17, color: GreenTheme.primaryDark)),
              Text(UiText.get('store_preview_notice'),
                  style: const TextStyle(fontSize: 12, color: GreenTheme.ink)),
            ])),
          ])),
        ),
        SizedBox(
          height: 49,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: categories.map((c) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                selected: _category == c,
                label: Text(UiText.get('store_category_$c')),
                onSelected: (_) => setState(() => _category = c),
              ),
            )).toList(),
          ),
        ),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return PremiumEmptyState(
              icon: Icons.wifi_off_outlined,
              title: UiText.get('store_load_failed'),
              action: TextButton(onPressed: _refresh, child: Text(UiText.get('retry'))),
            );
            }
            final all = snapshot.requireData;
            final items = all.where((item) =>
              _category == 'all' || item['category'] == _category).toList();
            if (items.isEmpty) {
              return PremiumEmptyState(
              icon: Icons.shopping_bag_outlined, title: UiText.get('store_empty'));
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12,
                  childAspectRatio: .88,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return PremiumSurface(child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(item['icon']?.toString() ?? '🎁',
                          style: const TextStyle(fontSize: 43)),
                      Text(item['name']?.toString() ?? '',
                          textAlign: TextAlign.center, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: GreenTheme.ink)),
                      PremiumGoldLabel(title: '${item['price'] ?? ''} ${item['currency'] ?? ''}'),
                    ],
                  ));
                },
              ),
            );
          },
        )),
      ]),
    );
  }
}

/// Private, server-generated notification records only; no fake demo events.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;
  late Future<List<Map<String, dynamic>>> _items = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw StateError('Authorized account required');
    final rows = await Supabase.instance.client.from('user_notifications')
      .select('id,event_type,created_at,read_at')
      .eq('recipient_id', uid)
      .order('created_at', ascending: false)
      .limit(60);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<void> _refresh() async { setState(() => _items = _load()); }

  @override
  Widget build(BuildContext context) => PremiumPage(
    title: UiText.get('notifications_title'),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        ChoiceChip(
          label: Text(UiText.get('notifications_all')),
          selected: !_unreadOnly,
          onSelected: (_) => setState(() => _unreadOnly = false),
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: Text(UiText.get('notifications_unread')),
          selected: _unreadOnly,
          onSelected: (_) => setState(() => _unreadOnly = true),
        ),
      ])),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
              return PremiumEmptyState(
            icon: Icons.error_outline,
            title: UiText.get('notifications_load_failed'),
            action: TextButton(onPressed: _refresh, child: Text(UiText.get('retry'))),
          );
            }
          final rows = snapshot.requireData.where(
            (x) => !_unreadOnly || x['read_at'] == null,
          ).toList();
          if (rows.isEmpty) {
              return PremiumEmptyState(
            icon: Icons.notifications_none_rounded,
            title: UiText.get('notifications_empty'),
          );
            }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final row = rows[i];
                return PremiumRow(
                  icon: Icons.notifications_outlined,
                  title: row['event_type']?.toString() ?? '',
                  subtitle: row['created_at']?.toString().split('T').first,
                  trailing: row['read_at'] == null
                    ? const Icon(Icons.circle, color: GreenTheme.mint, size: 10)
                    : const Icon(Icons.check, size: 16, color: GreenTheme.primary),
                );
              },
            ),
          );
        },
      )),
    ]),
  );
}
