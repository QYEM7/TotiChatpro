import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';
import 'package:totichat/models/gift_announcement.dart';

void main() {
  test('fresh and replayed DM receipts match the live Staging contract', () {
    for (final replayed in [false, true]) {
      expect(() => TotiChatServices.verifyDmSendReceipt(
        {'sent': true, 'id': 42, 'replayed': replayed}), returnsNormally);
    }
  });

  test('incomplete DM acknowledgements cannot clear pending messages', () {
    for (final receipt in [
      <String, dynamic>{'sent': true},
      {'sent': true, 'id': 42},
      {'sent': true, 'id': 0, 'replayed': false},
      {'sent': true, 'id': -1, 'replayed': false},
      {'sent': true, 'id': 1.5, 'replayed': false},
      {'sent': true, 'id': '42', 'replayed': false},
      {'sent': true, 'id': 42, 'replayed': 'false'},
      {'sent': false, 'id': 42, 'replayed': false},
      {'sent': true, 'id': 9007199254740992, 'replayed': false},
    ]) {
      expect(() => TotiChatServices.verifyDmSendReceipt(receipt),
        throwsA(isA<StateError>()), reason: '$receipt');
    }
  });

  final now = DateTime.utc(2026, 10, 18, 19);
  Map<String, dynamic> event(Object? amount, Duration age) => {
    'total_coins': amount,
    'created_at': now.subtract(age).toIso8601String(),
  };

  test('global strip uses the exact 7000 threshold and valid integer totals', () {
    expect(GiftAnnouncement.isDisplayable(event(7000, Duration.zero), now), isTrue);
    for (final value in [6999, null, '7000', 7000.5, double.nan,
      double.infinity, -7000, 9007199254740992]) {
      expect(GiftAnnouncement.isDisplayable(event(value, Duration.zero), now),
        isFalse, reason: '$value');
    }
  });

  test('strip rejects stale and far-future events with exact time boundaries', () {
    for (final age in [const Duration(seconds: 30),
      const Duration(seconds: -5), Duration.zero]) {
      expect(GiftAnnouncement.isDisplayable(event(7000, age), now), isTrue);
    }
    for (final age in [const Duration(seconds: 30, microseconds: 1),
      const Duration(seconds: -5, microseconds: -1),
      const Duration(days: -1), const Duration(days: 1)]) {
      expect(GiftAnnouncement.isDisplayable(event(7000, age), now), isFalse);
    }
    for (final timestamp in [null, 123, 'invalid date']) {
      expect(GiftAnnouncement.isDisplayable(
        {'total_coins': 7000, 'created_at': timestamp}, now), isFalse);
    }
  });
}
