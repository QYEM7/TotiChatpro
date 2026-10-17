import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/features/room/room_mic_recovery.dart';

void main() {
  test('successful microphone rollback disconnects then confirms server mute',
      () async {
    final calls = <String>[];
    final result = await RoomMicRecovery.run(
      disconnectAudio: () async { calls.add('disconnect'); },
      muteOnServer: () async { calls.add('mute'); },
    );
    expect(calls, ['disconnect', 'mute']);
    expect(result.fullyRecovered, isTrue);
  });

  test('local disconnect error never blocks server mute', () async {
    final calls = <String>[];
    final result = await RoomMicRecovery.run(
      disconnectAudio: () async {
        calls.add('disconnect');
        throw StateError('LiveKit teardown failed');
      },
      muteOnServer: () async { calls.add('mute'); },
    );
    expect(calls, ['disconnect', 'mute']);
    expect(result.disconnectConfirmed, isFalse);
    expect(result.serverMuteConfirmed, isTrue);
    expect(result.fullyRecovered, isFalse);
  });

  test('server mute failure is distinguishable from transport success',
      () async {
    final result = await RoomMicRecovery.run(
      disconnectAudio: () async {},
      muteOnServer: () async {
        throw StateError('RPC failed');
      },
    );
    expect(result.disconnectConfirmed, isTrue);
    expect(result.serverMuteConfirmed, isFalse);
    expect(result.fullyRecovered, isFalse);
    expect(result.serverMuteError, isA<StateError>());
  });

  test('two failures still attempt both cleanups once', () async {
    var disconnects = 0;
    var mutes = 0;
    final result = await RoomMicRecovery.run(
      disconnectAudio: () async {
        disconnects++;
        throw StateError('disconnect failed');
      },
      muteOnServer: () async {
        mutes++;
        throw StateError('mute failed');
      },
    );
    expect(disconnects, 1);
    expect(mutes, 1);
    expect(result.disconnectConfirmed, isFalse);
    expect(result.serverMuteConfirmed, isFalse);
  });

  test('room seat and microphone failure paths use the rollback workflow', () {
    final source = File('lib/features/room/room_screen.dart')
        .readAsStringSync();
    final seat = source.substring(
      source.indexOf('Future<void> _seat(int seatNumber) async {'),
      source.indexOf('Future<void> _connectAudio() async {'),
    );
    final mic = source.substring(
      source.indexOf('Future<void> _toggleMic() async {'),
      source.indexOf('Future<void> _send() async {'),
    );
    for (final operation in [seat, mic]) {
      expect(operation, contains('RoomMicRecovery.run('));
      expect(operation, contains('disconnectAudio: _voice.disconnect,'));
      expect(operation, contains(
          'muteOnServer: () => widget.repository.setMicMuted(widget.room.id, true),'));
      expect(operation, contains('!recovery.serverMuteConfirmed'));
    }
  });
}
