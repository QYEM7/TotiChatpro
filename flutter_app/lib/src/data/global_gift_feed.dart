import 'package:supabase_flutter/supabase_flutter.dart';

class GlobalGiftAnnouncement {
  const GlobalGiftAnnouncement({
    required this.id,
    required this.senderName,
    required this.recipientName,
    required this.giftName,
    required this.giftIcon,
    required this.quantity,
    required this.unitPrice,
  });

  final String id;
  final String senderName;
  final String recipientName;
  final String giftName;
  final String giftIcon;
  final int quantity;
  final int unitPrice;

  factory GlobalGiftAnnouncement.fromJson(Map<String, dynamic> row) =>
      GlobalGiftAnnouncement(
        id: row['id'] as String,
        senderName: row['sender_name'] as String,
        recipientName: row['recipient_name'] as String,
        giftName: row['gift_name'] as String,
        giftIcon: row['gift_icon'] as String,
        quantity: (row['quantity'] as num).toInt(),
        unitPrice: (row['unit_price'] as num).toInt(),
      );
}

class GlobalGiftFeed {
  GlobalGiftFeed(this.client);
  final SupabaseClient client;

  Stream<List<GlobalGiftAnnouncement>> watch() {
    // A database deferred trigger publishes only financially settled gifts.
    // Client additionally enforces approved minimum UNIT price of 7000.
    return client.from('gift_global_announcements')
        .stream(primaryKey: ['id'])
        // Filter in Postgres BEFORE the top-ten limit, so cheaper recent
        // gifts never hide qualifying settled announcements.
        .gte('unit_price', 7000)
        .order('created_at', ascending: false)
        .limit(10)
        .map((rows) => rows
            .where((row) => (row['unit_price'] as num).toInt() >= 7000)
            .map(GlobalGiftAnnouncement.fromJson)
            .toList(growable: false));
  }
}
