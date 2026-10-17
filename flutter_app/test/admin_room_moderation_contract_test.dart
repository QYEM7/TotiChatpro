import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  const roomId = '11111111-1111-4111-8111-111111111111';
  const ownerId = '22222222-2222-4222-8222-222222222222';
  const memberId = '33333333-3333-4333-8333-333333333333';
  const requestId = '44444444-4444-4444-8444-444444444444';

  test('Owner room directory page uses only server-supported bounds', () {
    expect(TotiChatServices.adminRoomDirectoryParams(
      search: ' Fun Room ', offset: 60), {
      'p_kind': 'rooms',
      'p_query': 'Fun Room',
      'p_offset': 60,
      'p_limit': 30,
    });
    for (final offset in [-30, 1, 31, 100020]) {
      expect(() => TotiChatServices.adminRoomDirectoryParams(
        offset: offset), throwsArgumentError);
    }
    expect(() => TotiChatServices.adminRoomDirectoryParams(
      search: List.filled(61, 'a').join()), throwsArgumentError);
  });

  test('Room directory rejects wrong kind, missing UUID or fabricated rows', () {
    final room = {
      'id': roomId,
      'owner_id': ownerId,
      'title': 'Real room',
      'member_records': 2,
    };
    final response = {
      'kind': 'rooms',
      'readOnly': true,
      'offset': 30,
      'limit': 30,
      'total': 31,
      'rows': [room],
    };
    expect((TotiChatServices.verifyAdminRoomDirectory(
      response, offset: 30)['rows'] as List).length, 1);
    for (final invalid in [
      {...response, 'kind': 'users'},
      {...response, 'readOnly': false},
      {...response, 'limit': 50},
      {...response, 'offset': 0},
      {...response, 'total': -1},
      {...response, 'total': 30},
      {...response, 'rows': [{...room, 'id': 'bad'}]},
      {...response, 'rows': [{...room, 'owner_id': null}]},
      {...response, 'rows': List.filled(31, room)},
    ]) {
      expect(() => TotiChatServices.verifyAdminRoomDirectory(
        invalid, offset: 30), throwsA(isA<StateError>()));
    }
  });

  test('Room state enforces exact room, protected owner and valid IDs', () {
    final room = {
      'roomId': roomId,
      'roomOwnerId': ownerId,
      'readOnly': true,
      'members': [
        {'user_id': memberId, 'seat_no': 1, 'is_muted': true},
      ],
      'banned': <Object>[],
    };
    final verified = TotiChatServices.verifyAdminRoomState(
      room, roomId: roomId);
    expect((verified['members'] as List).length, 1);
    for (final invalid in [
      {...room, 'roomId': ownerId},
      {...room, 'roomOwnerId': null},
      {...room, 'readOnly': false},
      {...room, 'members': [{'user_id': null}]},
      {...room, 'members': List.filled(2,
        {'user_id': memberId, 'is_muted': true})},
      {...room, 'banned': [{'user_id': 'not-uuid'}]},
      {...room, 'banned': List.filled(201,
        {'user_id': memberId})},
    ]) {
      expect(() => TotiChatServices.verifyAdminRoomState(
        invalid, roomId: roomId), throwsA(isA<StateError>()));
    }
  });

  test('Moderation requires a documented room-only ban or unban', () {
    const reason = 'Repeated intentional disruption in the voice room';
    expect(TotiChatServices.adminRoomActionParams(
      roomId: roomId,
      targetId: memberId,
      action: 'ban',
      reason: ' $reason ',
      requestId: requestId,
    ), {
      'p_room_id': roomId,
      'p_target': memberId,
      'p_action': 'ban',
      'p_reason': reason,
      'p_request_id': requestId,
    });
    for (final invalid in [
      {'roomId': 'invalid', 'targetId': memberId,
        'action': 'ban', 'reason': reason, 'requestId': requestId},
      {'roomId': roomId, 'targetId': 'invalid',
        'action': 'ban', 'reason': reason, 'requestId': requestId},
      {'roomId': roomId, 'targetId': memberId,
        'action': 'kick', 'reason': reason, 'requestId': requestId},
      {'roomId': roomId, 'targetId': memberId,
        'action': 'ban', 'reason': 'too short', 'requestId': requestId},
      {'roomId': roomId, 'targetId': memberId,
        'action': 'ban', 'reason': reason, 'requestId': 'invalid'},
    ]) {
      expect(() => TotiChatServices.adminRoomActionParams(
        roomId: invalid['roomId']!,
        targetId: invalid['targetId']!,
        action: invalid['action']!,
        reason: invalid['reason']!,
        requestId: invalid['requestId']!,
      ), throwsArgumentError);
    }
  });

  test('Room action is successful only with exact idempotent receipt', () {
    final receipt = {
      'roomId': roomId,
      'targetId': memberId,
      'action': 'unban',
      'requestId': requestId,
      'scope': 'room_only',
      'success': true,
    };
    expect(() => TotiChatServices.verifyAdminRoomAction(
      receipt, roomId: roomId, targetId: memberId,
      action: 'unban', requestId: requestId), returnsNormally);
    for (final invalid in [
      {...receipt, 'roomId': ownerId},
      {...receipt, 'targetId': ownerId},
      {...receipt, 'action': 'ban'},
      {...receipt, 'requestId': ownerId},
      {...receipt, 'scope': 'global_account'},
      {...receipt, 'success': false},
    ]) {
      expect(() => TotiChatServices.verifyAdminRoomAction(
        invalid, roomId: roomId, targetId: memberId,
        action: 'unban', requestId: requestId),
        throwsA(isA<StateError>()));
    }
  });
}
