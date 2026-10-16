import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/room_music_repository.dart';

void main() {
  test('music bookmark form stores only trimmed metadata', () {
    final values = RoomMusicRepository.validateBookmark(
      title: '  A real track  ',
      artist: '  Real artist  ',
      referenceUrl: ' https://example.org/artist/track ',
    );
    expect(values, {
      'title': 'A real track',
      'artist': 'Real artist',
      'reference_url': 'https://example.org/artist/track',
    });
    final noUrl = RoomMusicRepository.validateBookmark(
      title: 'Track title', artist: '');
    expect(noUrl['reference_url'], isNull);
    expect(noUrl['artist'], '');
  });

  test('rejects invalid metadata before reaching financial or audio services', () {
    for (final title in ['', 'x', List.filled(101,'x').join()]) {
      expect(() => RoomMusicRepository.validateBookmark(
        title: title, artist: 'valid'), throwsArgumentError);
    }
    expect(() => RoomMusicRepository.validateBookmark(
      title: 'Two chars', artist: List.filled(81,'a').join()), throwsArgumentError);
    for (final url in [
      'http://example.com/file',
      'javascript:alert(1)',
      'file:///private/file',
      'https://',
      'https://host.test/has spaces',
      'https://user:password@host.test/music',
      'https://host.test/${List.filled(501,'a').join()}',
    ]) {
      expect(() => RoomMusicRepository.validateBookmark(
        title: 'Valid song title', artist: '', referenceUrl: url),
        throwsArgumentError,
        reason: 'Rejected reference: $url');
    }
  });

  test('playlist mutation has a valid generated retry-safe UUID', () {
    final first = RoomMusicRepository.newRequestId();
    final second = RoomMusicRepository.newRequestId();
    final uuidPattern = RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$');
    expect(uuidPattern.hasMatch(first), isTrue);
    expect(uuidPattern.hasMatch(second), isTrue);
    expect(first, isNot(second));
  });
}
