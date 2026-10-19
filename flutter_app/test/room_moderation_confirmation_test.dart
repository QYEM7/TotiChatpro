import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/data/room_moderation_repository.dart';

void main() {
  const roomId = '11111111-1111-4111-8111-111111111111';
  const targetId = '22222222-2222-4222-8222-222222222222';
  const action = 'mute';
  final confirmed = <String, dynamic>{
    'success': true,
    'databaseCommitted': true,
    'sfuDisconnected': true,
    'roomId': roomId,
    'targetId': targetId,
    'action': action,
  };

  group('Voice-impacting moderation must be SFU-confirmed', () {
    test('accepts exact successful relay acknowledgement', () {
      expect(
        RoomModerationConfirmation.voiceStopped(
          status: 200,
          body: confirmed,
          roomId: roomId,
          targetUserId: targetId,
          action: action,
        ),
        isTrue,
      );
    });

    test('rejects a database-only success', () {
      expect(
        RoomModerationConfirmation.voiceStopped(
          status: 200,
          body: {'success': true, 'roomId': roomId, 'targetId': targetId},
          roomId: roomId,
          targetUserId: targetId,
          action: action,
        ),
        isFalse,
      );
    });

    test('rejects a 503 after committed DB with failed SFU', () {
      expect(
        RoomModerationConfirmation.voiceStopped(
          status: 503,
          body: {
            'databaseCommitted': true,
            'sfuDisconnected': false,
            'retryWithSameRequestId': true,
          },
          roomId: roomId,
          targetUserId: targetId,
          action: action,
        ),
        isFalse,
      );
    });

    test('rejects mismatched target, room, and action', () {
      for (final mismatch in [
        {...confirmed, 'roomId': 'other-room'},
        {...confirmed, 'targetId': 'other-user'},
        {...confirmed, 'action': 'kick'},
      ]) {
        expect(
          RoomModerationConfirmation.voiceStopped(
            status: 200,
            body: mismatch,
            roomId: roomId,
            targetUserId: targetId,
            action: action,
          ),
          isFalse,
        );
      }
    });

    test('rejects non-200 status and malformed data', () {
      for (final body in <Object?>[null, 'OK', <String>[], 5]) {
        expect(
          RoomModerationConfirmation.voiceStopped(
            status: 200,
            body: body,
            roomId: roomId,
            targetUserId: targetId,
            action: action,
          ),
          isFalse,
        );
      }
      expect(
        RoomModerationConfirmation.voiceStopped(
          status: 401,
          body: confirmed,
          roomId: roomId,
          targetUserId: targetId,
          action: action,
        ),
        isFalse,
      );
    });
  });

  group('Allow microphone remains user opt-in', () {
    test('validates DB-only unmute authorization result', () {
      expect(
        RoomModerationConfirmation.permissionUpdated(
          body: {
            'success': true,
            'roomId': roomId,
            'targetId': targetId,
            'action': 'allow_mic',
          },
          roomId: roomId,
          targetUserId: targetId,
          action: 'allow_mic',
        ),
        isTrue,
      );
    });
    test('denies missing or mismatched result', () {
      expect(
        RoomModerationConfirmation.permissionUpdated(
          body: {'success': true},
          roomId: roomId,
          targetUserId: targetId,
          action: 'allow_mic',
        ),
        isFalse,
      );
    });
  });
}
