import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/features/room/room_exit_workflow.dart';

void main() {
  test('room exit runs cleanup and server leave in order', () async {
    final calls = <String>[];
    final result = await RoomExitWorkflow.run(
      closeRealtime: () async => calls.add('socket'),
      disconnectAudio: () async => calls.add('audio'),
      leaveOnServer: () async => calls.add('server'),
    );

    expect(calls, ['socket', 'audio', 'server']);
    expect(result.realtimeCleanupFailed, isFalse);
    expect(result.audioCleanupFailed, isFalse);
    expect(result.hadCleanupErrors, isFalse);
  });

  test('failed socket cleanup cannot suppress audio or server leave',
      () async {
    final calls = <String>[];
    final result = await RoomExitWorkflow.run(
      closeRealtime: () async {
        calls.add('socket');
        throw StateError('socket already closed');
      },
      disconnectAudio: () async => calls.add('audio'),
      leaveOnServer: () async => calls.add('server'),
    );

    expect(calls, ['socket', 'audio', 'server']);
    expect(result.realtimeCleanupFailed, isTrue);
    expect(result.audioCleanupFailed, isFalse);
  });

  test('failed audio cleanup never skips authoritative membership leave',
      () async {
    final calls = <String>[];
    final result = await RoomExitWorkflow.run(
      closeRealtime: () async => calls.add('socket'),
      disconnectAudio: () async {
        calls.add('audio');
        throw StateError('audio teardown failed');
      },
      leaveOnServer: () async => calls.add('server'),
    );

    expect(calls, ['socket', 'audio', 'server']);
    expect(result.audioCleanupFailed, isTrue);
    expect(result.hadCleanupErrors, isTrue);
  });

  test('both local failures still try server leave exactly once', () async {
    var leaves = 0;
    final result = await RoomExitWorkflow.run(
      closeRealtime: () async => throw StateError('socket failed'),
      disconnectAudio: () async => throw StateError('audio failed'),
      leaveOnServer: () async { leaves++; },
    );
    expect(leaves, 1);
    expect(result.realtimeCleanupFailed, isTrue);
    expect(result.audioCleanupFailed, isTrue);
  });

  test('server rejection propagates even if both cleanups succeed', () async {
    var called = 0;
    await expectLater(RoomExitWorkflow.run(
      closeRealtime: () async => called++,
      disconnectAudio: () async => called++,
      leaveOnServer: () async {
        called++;
        throw StateError('not confirmed by server');
      },
    ), throwsStateError);
    expect(called, 3);
  });
}
