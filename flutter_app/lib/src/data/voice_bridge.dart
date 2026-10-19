import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uses only the existing authenticated Staging voice-token endpoint.
/// Does not mint tokens, modify LiveKit configuration, or claim device QA.
class VoiceBridge {
  VoiceBridge(this.client);

  final SupabaseClient client;
  livekit.Room? _connection;
  bool _microphoneOn = false;
  bool _connected = false;

  bool get connected => _connected;
  bool get microphoneOn => _microphoneOn;

  Future<void> connect(String roomId) async {
    if (_connected) return;
    final response = await client.functions.invoke(
      'phase2-voice-token',
      body: {'roomId': roomId},
    );
    final body = response.data;
    if (response.status != 200 || body is! Map) {
      throw StateError('Voice token endpoint unavailable');
    }
    final data = Map<String, dynamic>.from(body);
    final url = data['url'];
    final token = data['token'];
    final approvedRoom = data['roomId'];
    if (url is! String ||
        !url.startsWith('wss://') ||
        token is! String ||
        token.isEmpty ||
        approvedRoom != roomId) {
      throw StateError('Invalid voice permission response');
    }
    final room = livekit.Room();
    try {
      await room.connect(url, token);
      _connection = room;
      _connected = true;
      _microphoneOn = false;
    } catch (_) {
      await room.dispose();
      rethrow;
    }
  }

  /// A new server token is required after becoming eligible to publish.
  /// An earlier listener token must never be used to publish microphone audio.
  Future<void> enableMicrophone(String roomId) async {
    if (_microphoneOn) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw StateError('Microphone permission denied by device');
    }
    final confirmed = await client.rpc('phase2_room_set_muted', params: {
      'p_room_id': roomId,
      'p_muted': false,
    });
    if (confirmed != false) {
      throw StateError('Server denied unmuting microphone');
    }

    try {
      await _releaseConnection();
      final response = await client.functions.invoke(
        'phase2-voice-token',
        body: {'roomId': roomId},
      );
      final body = response.data;
      if (response.status != 200 || body is! Map) {
        throw StateError('Cannot obtain microphone publishing permission');
      }
      final data = Map<String, dynamic>.from(body);
      final url = data['url'];
      final token = data['token'];
      if (data['roomId'] != roomId ||
          data['canPublish'] != true ||
          url is! String ||
          !url.startsWith('wss://') ||
          token is! String ||
          token.isEmpty) {
        throw StateError('Microphone publish grant not approved by server');
      }
      final room = livekit.Room();
      try {
        await room.connect(url, token);
        final participant = room.localParticipant;
        if (participant == null) {
          throw StateError('Local voice participant is not available');
        }
        await participant.setMicrophoneEnabled(true);
        _connection = room;
        _connected = true;
        _microphoneOn = true;
      } catch (_) {
        await room.dispose();
        rethrow;
      }
    } catch (_) {
      await _releaseConnection();
      try {
        await client.rpc('phase2_room_set_muted', params: {
          'p_room_id': roomId,
          'p_muted': true,
        });
      } catch (_) {
        // Server remains authoritative; never claim the mic is live.
      }
      rethrow;
    }
  }

  Future<void> disableMicrophone(String roomId) async {
    final room = _connection;
    if (room != null) {
      await room.localParticipant?.setMicrophoneEnabled(false);
    }
    _microphoneOn = false;
    try {
      await client.rpc('phase2_room_set_muted', params: {
        'p_room_id': roomId,
        'p_muted': true,
      });
    } finally {
      // Discard the old publish-capable token, then reconnect only as listener.
      await _releaseConnection();
    }
    await connect(roomId);
  }

  Future<void> disconnect(String roomId) async {
    try {
      final room = _connection;
      if (room != null && _microphoneOn) {
        await room.localParticipant?.setMicrophoneEnabled(false);
        await client.rpc('phase2_room_set_muted', params: {
          'p_room_id': roomId,
          'p_muted': true,
        });
      }
    } finally {
      await _releaseConnection();
    }
  }

  Future<void> _releaseConnection() async {
    final room = _connection;
    _connection = null;
    _microphoneOn = false;
    _connected = false;
    if (room != null) {
      try {
        await room.disconnect();
      } finally {
        await room.dispose();
      }
    }
  }
}
