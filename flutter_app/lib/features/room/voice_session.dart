import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../../data/totichat_repository.dart';

/// Real LiveKit audio only. Never invent a local peer or a success state.
/// An incrementing generation guards against a delayed token or connection
/// accidentally reopening audio after the user leaves the room.
class VoiceSession {
  VoiceSession(this.repository);
  final TotiChatRepository repository;
  lk.Room? _room;
  bool _publishing = false;
  bool _serverCanPublish = false;
  int _generation = 0;

  bool get connected => _room != null;
  bool get publishing => _publishing;

  Future<void> connect(String roomId) async {
    // Capture before awaiting teardown: a second join may begin while the
    // previous session is still disconnecting.
    final generation = _generation + 1;
    await disconnect();
    if (generation != _generation) {
      throw StateError('Room audio connection was superseded');
    }
    final grant = await repository.requestVoiceToken(roomId);
    if (generation != _generation) {
      throw StateError('Room audio request was cancelled');
    }
    final room = lk.Room();
    try {
      await room.connect(grant.url, grant.token);
      if (generation != _generation) {
        throw StateError('Room audio connection was cancelled');
      }
      _room = room;
      _publishing = false;
      _serverCanPublish = grant.canPublish;
    } catch (_) {
      try {
        await room.disconnect();
      } finally {
        await room.dispose();
      }
      rethrow;
    }
  }

  Future<void> setMicrophone(bool enabled) async {
    final room = _room;
    final generation = _generation;
    if (room == null) throw StateError('Join audio first');
    if (enabled && !_serverCanPublish) {
      throw StateError('Server did not grant microphone publishing');
    }
    if (enabled) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw StateError('Microphone permission was denied');
      }
    }
    if (generation != _generation || !identical(room, _room)) {
      throw StateError('Audio session ended before microphone change');
    }
    final participant = room.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit local participant is unavailable');
    }
    await participant.setMicrophoneEnabled(enabled);
    if (generation != _generation || !identical(room, _room)) {
      throw StateError('Audio session ended during microphone change');
    }
    _publishing = enabled;
  }

  Future<void> disconnect() async {
    // Invalidate all in-flight token, connection and mic permission requests,
    // including when the current room is not yet connected.
    _generation++;
    final room = _room;
    _room = null;
    _publishing = false;
    _serverCanPublish = false;
    if (room != null) {
      try {
        await room.disconnect();
      } finally {
        await room.dispose();
      }
    }
  }
}
