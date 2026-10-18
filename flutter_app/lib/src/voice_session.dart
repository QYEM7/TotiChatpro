import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'staging_repository.dart';

/// Retains a real voice connection after minimizing a room.
class VoiceSession {
  VoiceSession._();
  static final VoiceSession instance = VoiceSession._();

  Room? _room;
  String? _roomId;
  bool _publishing = false;
  bool _connecting = false;

  String? get roomId => _roomId;
  bool get connected => _room != null;
  bool get publishing => _publishing;

  Future<Map<String, dynamic>> _token(String roomId) async {
    final response = await Supabase.instance.client.functions.invoke(
      'phase2-voice-token',
      body: {'roomId': roomId},
    );
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Voice token request failed');
    }
    final result = Map<String, dynamic>.from(response.data as Map);
    if (result['roomId'] != roomId ||
        result['token'] is! String || result['url'] is! String) {
      throw StateError('Invalid voice room authorization');
    }
    return result;
  }

  Future<void> connect(String roomId) async {
    if (_connecting) return;
    if (_roomId == roomId && _room != null) return;
    _connecting = true;
    try {
      await disconnect();
      final access = await _token(roomId);
      final room = Room();
      try {
        await room.connect(access['url'] as String, access['token'] as String);
        _room = room;
        _roomId = roomId;
        _publishing = false;
      } catch (_) {
        await room.disconnect();
        room.dispose();
        rethrow;
      }
    } finally {
      _connecting = false;
    }
  }

  Future<void> setMicrophone({
    required String roomId,
    required bool enabled,
    required StagingRepository repository,
  }) async {
    if (!enabled) {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      _publishing = false;
      await repository.setMuted(roomId, true);
      return;
    }
    await repository.setMuted(roomId, false);
    try {
      final access = await _token(roomId);
      if (access['canPublish'] != true) {
        throw StateError('Microphone publishing denied');
      }
      await disconnect();
      final room = Room();
      try {
        await room.connect(access['url'] as String, access['token'] as String);
        await room.localParticipant?.setMicrophoneEnabled(true);
        _room = room;
        _roomId = roomId;
        _publishing = true;
      } catch (_) {
        await room.disconnect();
        room.dispose();
        rethrow;
      }
    } catch (_) {
      await repository.setMuted(roomId, true);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final old = _room;
    _room = null;
    _roomId = null;
    _publishing = false;
    if (old != null) {
      await old.disconnect();
      old.dispose();
    }
  }
}
