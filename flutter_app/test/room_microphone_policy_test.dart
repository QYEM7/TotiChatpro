import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/room_microphone_policy.dart';
import 'package:totichat/src/data/room_repository.dart';

RoomSeatMember member(String userId, {int? seat, bool muted = false}) =>
    RoomSeatMember(
      userId: userId,
      displayName: 'Test fixture',
      seatNumber: seat,
      isMuted: muted,
    );

void main() {
  group('RoomMicrophonePolicy', () {
    test('permits the authenticated occupant of an unmuted seat', () {
      expect(
        RoomMicrophonePolicy.mayPublish(
          userId: 'speaker',
          members: [member('speaker', seat: 15)],
        ),
        isTrue,
      );
    });

    test('denies a muted member who still occupies a seat', () {
      expect(
        RoomMicrophonePolicy.mayPublish(
          userId: 'speaker',
          members: [member('speaker', seat: 2, muted: true)],
        ),
        isFalse,
      );
    });

    test('denies a member whose seat was revoked', () {
      expect(
        RoomMicrophonePolicy.mayPublish(
          userId: 'speaker',
          members: [member('speaker')],
        ),
        isFalse,
      );
    });

    test('does not confuse another occupant with the current user', () {
      expect(
        RoomMicrophonePolicy.mayPublish(
          userId: 'speaker',
          members: [member('other', seat: 1)],
        ),
        isFalse,
      );
    });

    test('fails closed after session is lost or actor leaves room', () {
      final members = [member('speaker', seat: 1)];
      expect(
        RoomMicrophonePolicy.mayPublish(
          userId: null,
          members: members,
        ),
        isFalse,
      );
      expect(
        RoomMicrophonePolicy.mayPublish(
          userId: 'speaker',
          members: <RoomSeatMember>[],
        ),
        isFalse,
      );
    });
  });
}
