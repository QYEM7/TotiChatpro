import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class WalletBalance {
  const WalletBalance({required this.coins, required this.diamonds});
  final int coins;
  final int diamonds;
  factory WalletBalance.fromJson(Map<String, dynamic> row) =>
      WalletBalance(
        coins: (row['coins'] as num).toInt(),
        diamonds: (row['diamonds'] as num).toInt(),
      );
}

class GiftItem {
  const GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.price,
  });
  final String id;
  final String name;
  final String icon;
  final int price;

  factory GiftItem.fromJson(Map<String, dynamic> row) => GiftItem(
        id: row['id'] as String,
        name: row['name'] as String,
        icon: (row['icon'] as String?) ?? '',
        price: (row['price'] as num).toInt(),
      );
}

class GiftReceipt {
  const GiftReceipt({required this.id, required this.amount});
  final String id;
  final int amount;
}

/// No client-side balance mutation. The only sender-authoritative operation is
/// phase3_send_gift with an expected server price and a stable request UUID.
class GiftRepository {
  GiftRepository(this.client);
  final SupabaseClient client;
  final _uuid = const Uuid();

  String newRequestId() => _uuid.v4();

  Future<WalletBalance> balance() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authenticated wallet required');
    final row = await client.from('wallets')
        .select('coins,diamonds').eq('user_id', userId).single();
    return WalletBalance.fromJson(row);
  }

  Future<List<GiftItem>> gifts() async {
    // Lucky gifts are deliberately deferred until admin policy is approved.
    final rows = await client.from('gift_catalog')
        .select('id,name,icon,price')
        .eq('is_active', true)
        .eq('category_id', 'gift')
        .order('price', ascending: true);
    return (rows as List)
        .map((row) => GiftItem.fromJson(row as Map<String, dynamic>))
        .where((gift) => gift.price > 0)
        .toList(growable: false);
  }

  Future<GiftReceipt> send({
    required String roomId,
    required String recipientId,
    required GiftItem gift,
    required int quantity,
    required String requestId,
  }) async {
    if (!const [1, 7, 17, 77, 777].contains(quantity)) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    if (recipientId == client.auth.currentUser?.id) {
      throw ArgumentError('Self gifting is not allowed');
    }
    final response = await client.rpc('phase3_send_gift', params: {
      'p_room_id': roomId,
      'p_recipient_id': recipientId,
      'p_gift_id': gift.id,
      'p_quantity': quantity,
      'p_request_id': requestId,
      'p_expected_price': gift.price,
    });
    if (response is! Map) throw StateError('Gift not confirmed');
    final row = Map<String, dynamic>.from(response);
    if (row['status'] != 'completed' || row['id'] is! String ||
        row['amount'] is! num) {
      throw StateError('Gift was not settled');
    }
    return GiftReceipt(
      id: row['id'] as String,
      amount: (row['amount'] as num).toInt(),
    );
  }
}
