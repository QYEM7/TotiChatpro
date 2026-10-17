import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_repository.dart';

void main() {
  test('Staging confirms exactly 15 possible seats', () {
    for (var seat = 1; seat <= 15; seat++) {
      expect(TotiChatRepository.verifySeatReceipt(
        seat, requested: seat), seat);
    }
  });

  test('leaving a seat is confirmed by a null server response only', () {
    expect(TotiChatRepository.verifySeatReceipt(
      null, requested: null), isNull);

    for (final invalid in [0, 1, 15, 1.5, false, 'none']) {
      expect(() => TotiChatRepository.verifySeatReceipt(
        invalid, requested: null), throwsA(isA<StateError>()));
    }
  });

  test('a seat request must never accept a different or rounded seat', () {
    const selected = 7;
    for (final invalid in [
      null, 1, 6, 8, 15, 7.0, 7.5, '7', true,
    ]) {
      expect(() => TotiChatRepository.verifySeatReceipt(
        invalid, requested: selected), throwsA(isA<StateError>()),
        reason: 'Unverified seat acknowledgment: $invalid');
    }
  });

  test('invalid seat index fails before accepting any response', () {
    for (final invalid in [-10, 0, 16, 100]) {
      expect(() => TotiChatRepository.verifySeatReceipt(
        invalid, requested: invalid), throwsArgumentError);
    }
  });
}
