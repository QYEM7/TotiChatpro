import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/data/totichat_repository.dart';
import 'package:totichat/features/room/voice_session.dart';
import 'package:totichat/models/room_models.dart';

class _DeferredVoiceRepository extends TotiChatRepository {
  _DeferredVoiceRepository()
      : super(SupabaseClient('https://example.supabase.co',
          'test-public-anon-key-not-for-a-real-account'));

  final requests = <Completer<VoiceGrant>>[];

  @override
  Future<VoiceGrant> requestVoiceToken(String roomId) {
    final completer = Completer<VoiceGrant>();
    requests.add(completer);
    return completer.future;
  }
}

VoiceGrant _fakeGrant(String roomId) => VoiceGrant(
  roomId: roomId,
  url: 'wss://example.invalid',
  token: 'synthetic-token-never-used-for-connection',
  canPublish: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('leaving room cancels a delayed voice token before LiveKit connects',
      () async {
    final repository = _DeferredVoiceRepository();
    final voice = VoiceSession(repository);

    final attempt = voice.connect('room-one');
    final cancelled = expectLater(attempt, throwsA(isA<StateError>()));

    await Future<void>.delayed(Duration.zero);
    expect(repository.requests, hasLength(1));
    expect(voice.connected, false);
    await voice.disconnect();
    repository.requests.single.complete(_fakeGrant('room-one'));

    await cancelled;
    expect(voice.connected, false);
    expect(voice.publishing, false);
  });

  test('a newer audio connect invalidates the earlier token request', () async {
    final repository = _DeferredVoiceRepository();
    final voice = VoiceSession(repository);

    final first = voice.connect('room-one');
    final firstCancelled = expectLater(first, throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);

    final second = voice.connect('room-two');
    final secondCancelled = expectLater(second, throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);
    expect(repository.requests.length, 2);

    // Complete the first token while the second attempt is pending.
    repository.requests[0].complete(_fakeGrant('room-one'));
    await firstCancelled;
    expect(voice.connected, false);

    // Disconnection must also cancel the latest unfinished attempt.
    await voice.disconnect();
    repository.requests[1].complete(_fakeGrant('room-two'));
    await secondCancelled;
    expect(voice.connected, false);
  });

  test('microphone cannot turn on after audio session has ended', () async {
    final voice = VoiceSession(_DeferredVoiceRepository());
    await voice.disconnect();
    await expectLater(voice.setMicrophone(true),
      throwsA(isA<StateError>()));
    expect(voice.publishing, false);
  });
}
