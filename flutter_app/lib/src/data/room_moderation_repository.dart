import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// A database mutation is not proof that LiveKit stopped broadcasting.
abstract final class RoomModerationConfirmation {
  static bool voiceStopped({
    required int status,
    required Object? body,
    required String roomId,
    required String targetUserId,
    required String action,
  }) {
    if (status != 200 || body is! Map) return false;
    return body['success'] == true &&
        body['databaseCommitted'] == true &&
        body['sfuDisconnected'] == true &&
        body['roomId'] == roomId &&
        body['targetId'] == targetUserId &&
        body['action'] == action;
  }

  static bool permissionUpdated({
    required Object? body,
    required String roomId,
    required String targetUserId,
    required String action,
  }) {
    if (body is! Map) return false;
    return body['success'] == true &&
        body['roomId'] == roomId &&
        body['targetId'] == targetUserId &&
        body['action'] == action;
  }
}

class RoomModerationRepository {
  RoomModerationRepository(this.client);
  final SupabaseClient client;
  final _uuid = const Uuid();

  // Failed relay calls keep the SAME request ID for a safe retry during
  // this screen lifetime. Durable cross-restart retry still needs testing.
  final Map<String, String> _pendingIds = <String, String>{};

  Future<void> act({
    required String roomId,
    required String targetUserId,
    required String action,
    String? reason,
  }) async {
    if (!const ['mute', 'allow_mic', 'release_seat', 'kick']
        .contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    if (roomId.isEmpty ||
        targetUserId.isEmpty ||
        (reason != null && reason.length > 300)) {
      throw ArgumentError('Invalid moderation request');
    }
    final payloadKey = '$roomId:$targetUserId:$action:${reason ?? ''}';
    final requestId = _pendingIds.putIfAbsent(payloadKey, _uuid.v4);

    if (action == 'allow_mic') {
      // Only lifts a DB restriction; never remotely enables another mic.
      final body = await client.rpc('phase2_room_moderate', params: {
        'p_room_id': roomId,
        'p_target': targetUserId,
        'p_action': action,
        'p_request_id': requestId,
        'p_reason': reason,
      });
      if (!RoomModerationConfirmation.permissionUpdated(
        body: body,
        roomId: roomId,
        targetUserId: targetUserId,
        action: action,
      )) {
        throw StateError('Room moderation permission was not confirmed');
      }
    } else {
      // Must use the voice relay, not a DB-only moderation RPC.
      final response = await client.functions.invoke(
        'phase2-voice-moderate',
        body: {
          'roomId': roomId,
          'targetId': targetUserId,
          'action': action,
          'requestId': requestId,
          'reason': reason,
        },
      );
      if (!RoomModerationConfirmation.voiceStopped(
        status: response.status,
        body: response.data,
        roomId: roomId,
        targetUserId: targetUserId,
        action: action,
      )) {
        // A committed DB action with an unconfirmed SFU kick is NOT success.
        throw StateError('LiveKit moderation disconnection unconfirmed');
      }
    }
    _pendingIds.remove(payloadKey);
  }
}
