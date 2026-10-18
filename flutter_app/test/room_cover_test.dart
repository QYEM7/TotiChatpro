import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/room_cover_upload.dart';

void main() {
  test('valid WebP RIFF header is accepted', () {
    final bytes = Uint8List.fromList([
      82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80,
    ]);
    expect(RoomCoverUpload.isWebp(bytes), isTrue);
  });

  test('JPEG and short payloads are rejected', () {
    expect(RoomCoverUpload.isWebp(Uint8List.fromList([255, 216, 255])), isFalse);
    expect(RoomCoverUpload.isWebp(Uint8List.fromList([82, 73, 70, 70])), isFalse);
    expect(RoomCoverUpload.isWebp(Uint8List(12)), isFalse);
  });

  test('room cover upload enforces the staging 2 MiB cap', () {
    expect(RoomCoverUpload.maxBytes, 2097152);
    expect(RoomCoverUpload.bucketName, 'totichat-room-images');
  });
}
