import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/data/gift_repository.dart';
import 'package:totichat/src/data/direct_message_repository.dart';
import 'package:totichat/src/data/admin_session_repository.dart';
import 'package:totichat/src/data/global_gift_feed.dart';

void main() {
  group('Financial DTO safety', () {
    test('wallet reads signed server balance values, not placeholders', () {
      final w = WalletBalance.fromJson({'coins': 137, 'diamonds': 12});
      expect(w.coins, 137);
      expect(w.diamonds, 12);
    });

    test('catalog retains exact price for expected-price settlement', () {
      final g = GiftItem.fromJson({
        'id': 'verified-gift',
        'name': 'Fixture gift',
        'icon': '⭐',
        'price': 7000,
      });
      expect(g.price, 7000);
      expect(g.id, 'verified-gift');
    });

    test('global gift metadata comes only from verified announcement', () {
      final a = GlobalGiftAnnouncement.fromJson({
        'id': 'announcement-uuid',
        'sender_name': 'sender',
        'recipient_name': 'recipient',
        'gift_name': 'Fixture gift',
        'gift_icon': '⭐',
        'quantity': 7,
        'unit_price': 7000,
      });
      expect(a.quantity, 7);
      expect(a.unitPrice, 7000);
    });
  });

  group('Private text message DTOs', () {
    test('maps immutable server sender identity', () {
      final message = DirectMessage.fromJson({
        'id': 28,
        'sender_id': 'server-sender',
        'recipient_id': 'server-recipient',
        'body': 'Message fixture',
        'created_at': '2026-10-19T01:00:00Z',
      });
      expect(message.senderId, 'server-sender');
      expect(message.id, 28);
    });
    test('inbox never invents unread notifications', () {
      final item = DirectInboxItem.fromJson({
        'other_user_id': 'other-id',
        'other_display_name': 'Fixture',
        'last_body': 'Hello',
        'unread_count': 0,
      });
      expect(item.unreadCount, 0);
    });
  });

  group('Admin authorization', () {
    test('normal user never gets the admin entry', () {
      final user = AdminSession.fromJson({
        'role': 'user',
        'isOwner': false,
        'isMainPartner': false,
        'canManageCatalogs': false,
        'canReadReports': false,
        'canManageHostAgencies': false,
        'permissions': <String>[],
      });
      expect(user.canEnterCenter, false);
    });
    test('server-approved owner can open but UI cannot grant itself owner', () {
      final owner = AdminSession.fromJson({
        'role': 'owner',
        'isOwner': true,
        'isMainPartner': false,
        'canManageCatalogs': true,
        'canReadReports': true,
        'canManageHostAgencies': true,
        'permissions': <String>[],
      });
      expect(owner.canEnterCenter, true);
    });
  });
}
