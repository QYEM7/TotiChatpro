import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visual.dart';

/// Display real server-produced gift announcements only. No mock events.
class GlobalGiftAnnouncementStrip extends StatefulWidget {
  const GlobalGiftAnnouncementStrip({super.key});
  @override
  State<GlobalGiftAnnouncementStrip> createState() =>
      _GlobalGiftAnnouncementStripState();
}

class _GlobalGiftAnnouncementStripState
    extends State<GlobalGiftAnnouncementStrip> {
  static const minimumCoins = 7000;
  static const lifetime = Duration(seconds: 12);

  RealtimeChannel? _channel;
  Timer? _hideTimer;
  Map<String, dynamic>? _announcement;

  @override
  void initState() {
    super.initState();
    _loadRecentEvent();
    _channel = Supabase.instance.client
        .channel('gift-global-' + identityHashCode(this).toString())
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'gift_global_announcements',
          callback: (payload) {
            if (!mounted) return;
            _offer(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<void> _loadRecentEvent() async {
    try {
      final cutoff = DateTime.now().toUtc().subtract(lifetime);
      final events = await Supabase.instance.client
          .from('gift_global_announcements')
          .select('id,gift_name,gift_icon,sender_name,recipient_name,total_coins,created_at')
          .gte('created_at', cutoff.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1);
      if (!mounted || events.isEmpty) return;
      _offer(Map<String, dynamic>.from(events.first));
    } catch (_) {
      // An inaccessible or unavailable event yields a clean empty state.
    }
  }

  void _offer(Map<String, dynamic> event) {
    final coins = (event['total_coins'] as num?)?.toInt() ?? 0;
    final created = DateTime.tryParse(event['created_at']?.toString() ?? '');
    if (coins < minimumCoins || created == null) return;
    final elapsed = DateTime.now().toUtc().difference(created.toUtc());
    if (elapsed.isNegative || elapsed >= lifetime) return;
    final previous = _announcement;
    final prevCreated = DateTime.tryParse(
      previous?['created_at']?.toString() ?? '');
    if (prevCreated != null && prevCreated.isAfter(created)) return;

    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _announcement = event);
    _hideTimer = Timer(lifetime - elapsed, () {
      if (mounted) setState(() => _announcement = null);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _announcement;
    if (event == null) return const SizedBox.shrink();
    final giftIcon = event['gift_icon']?.toString() ?? '';
    final giftName = event['gift_name']?.toString() ?? '';
    final sender = event['sender_name']?.toString() ?? '';
    final receiver = event['recipient_name']?.toString() ?? '';
    final coins = (event['total_coins'] as num).toInt();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ApprovedPalette.violet, ApprovedPalette.room]),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ApprovedPalette.gold, width: 1),
      ),
      child: Text(
        '$giftIcon $sender → $receiver | $giftName | $coins',
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: ApprovedPalette.gold,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
