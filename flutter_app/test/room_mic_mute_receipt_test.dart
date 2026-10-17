import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_repository.dart';

void main() {
  test('microphone receipts acknowledge the exact requested state', () {
    expect(TotiChatRepository.verifyMicMuteReceipt(false,
      requestedMuted: false), isFalse);
    expect(TotiChatRepository.verifyMicMuteReceipt(true,
      requestedMuted: true), isTrue);

    // A valid unmute receipt is false; its value is not RPC failure.
    expect(() => TotiChatRepository.verifyMicMuteReceipt(true,
      requestedMuted: false), throwsStateError);
    expect(() => TotiChatRepository.verifyMicMuteReceipt(false,
      requestedMuted: true), throwsStateError);

    for (final malformed in <Object?>[null, 0, 1, 'true', 'false', {}]) {
      expect(() => TotiChatRepository.verifyMicMuteReceipt(malformed,
        requestedMuted: true), throwsStateError);
      expect(() => TotiChatRepository.verifyMicMuteReceipt(malformed,
        requestedMuted: false), throwsStateError);
    }
  });

  test('room audio hangup must confirm server mute after disconnect', () {
    final source = File('lib/features/room/room_screen.dart')
      .readAsStringSync();
    final start = source.indexOf('Future<void> _hangUpAudio() async {');
    final end = source.indexOf('Future<void> _toggleMic() async {');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final hangup = source.substring(start, end);
    expect(hangup, contains('await _voice.disconnect();'));
    expect(hangup,
      contains('await widget.repository.setMicMuted(widget.room.id, true);'));
    expect(hangup.indexOf('await _voice.disconnect();'),
      lessThan(hangup.indexOf(
        'await widget.repository.setMicMuted(widget.room.id, true);')));
    expect(source, contains('!_voice.connected ? null : _hangUpAudio'));
  });
}
