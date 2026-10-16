import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/models/room_models.dart';

void main() {
  test('seat indicators are sourced from authenticated server member fields', () {
    final person = RoomMember.fromJson(const {
      'user_id': '00000000-0000-4000-8000-000000000456',
      'display_name': 'Verified member',
      'seat_no': 12,
      'avatar_url': null,
      'is_muted': true,
    });
    expect(person.seatNo, 12);
    expect(person.isMuted, isTrue);
    expect(person.displayName, 'Verified member');
    expect(person.userId, isNotEmpty);
  });

  test('missing mute flag defaults to safe muted state', () {
    final person = RoomMember.fromJson(const {
      'user_id': '00000000-0000-4000-8000-000000000789',
      'seat_no': null,
    });
    expect(person.seatNo, isNull);
    expect(person.isMuted, isTrue);
    expect(person.displayName, 'TotiChat Member');
  });

  test('unmuted badge is never inferred from occupation alone', () {
    final person = RoomMember.fromJson(const {
      'user_id': '00000000-0000-4000-8000-000000000789',
      'display_name': 'Live member',
      'seat_no': 5,
      'is_muted': false,
    });
    expect(person.isMuted, isFalse);
  });
}
