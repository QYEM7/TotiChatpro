import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../../data/totichat_repository.dart';

/// Real LiveKit audio only. Never invent a local peer or a success state.
class VoiceSession {
  VoiceSession(this.repository);
  final TotiChatRepository repository;
  lk.Room? _room;
  bool _publishing = false;
  bool _serverCanPublish = false;

  bool get connected => _room != null;
  bool get publishing => _publishing;

  Future<void> connect(String roomId) async {
    await disconnect();
    final grant = await repository.requestVoiceToken(roomId);
    final room = lk.Room();
    try {
      await room.connect(grant.url, grant.token);
      _room = room;
      _publishing = false;
      _serverCanPublish = grant.canPublish;
    } catch (_) {
      await room.disconnect();
      await room.dispose();
      rethrow;
    }
  }

  Future<void> setMicrophone(bool enabled) async {
    final room = _room;
    if (room == null) throw StateError('Join audio first');
    if (enabled && !_serverCanPublish) throw StateError('Server did not grant microphone publishing');
    if (enabled) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) throw StateError('Microphone permission was denied');
    }
    await room.localParticipant?.setMicrophoneEnabled(enabled);
    _publishing = enabled;
  }

  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    _publishing = false;
    _serverCanPublish = false;
    if (room != null) {
      try { await room.disconnect(); }
      finally { await room.dispose(); }
    }
  }
}
