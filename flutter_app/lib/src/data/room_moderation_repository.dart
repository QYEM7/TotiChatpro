import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class RoomModerationRepository {
  RoomModerationRepository(this.client);
  final SupabaseClient client;
  final _uuid = const Uuid();

  Future<void> act({
    required String roomId,
    required String targetUserId,
    required String action,
    String? reason,
  }) async {
    if (!const ['mute','allow_mic','release_seat','kick'].contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    final response = await client.rpc('phase2_room_moderate', params: {
      'p_room_id': roomId,
      'p_target': targetUserId,
      'p_action': action,
      'p_request_id': _uuid.v4(),
      'p_reason': reason,
    });
    if (response is! Map || response['success'] != true) {
      throw StateError('Room moderation action was not confirmed');
    }
  }
}
