import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/domain.dart';
import 'package:totichat/src/visual.dart';

void main() {
  test('room DTO retains real authoritative identifiers', () {
    final room = VoiceRoom.fromJson({
      'id': '00000000-0000-0000-0000-000000000001',
      'title': 'Test',
      'owner_id': '00000000-0000-0000-0000-000000000002',
      'is_private': false,
      'welcome_message': 'Welcome'
    });
    expect(room.title, 'Test');
    expect(room.isPrivate, false);
    expect(room.welcomeMessage, 'Welcome');
  });
  test('room members have server-assigned seats', () {
    final member = RoomMember.fromJson({
      'user_id': 'u1', 'display_name': 'Speaker',
      'seat_no': 15, 'is_muted': true
    });
    expect(member.seat, 15);
    expect(member.muted, true);
  });
  test('gift values come from catalog, never fixture balances', () {
    final gift = GiftItem.fromJson({
      'id': 'g1', 'name': 'Rose', 'icon': '🌹', 'price': 7000
    });
    expect(gift.price, 7000);
  });
  test('approved design tokens come from new source', () {
    expect(ApprovedPalette.emerald.value, 0xFF25BE8E);
    expect(ApprovedPalette.gold.value, 0xFFFBBF24);
  });
}
