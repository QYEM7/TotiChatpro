import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class RoomCoverUpload {
  static const bucketName = 'totichat-room-images';
  static const maxBytes = 2 * 1024 * 1024;

  static bool isWebp(Uint8List data) =>
      data.length >= 12 &&
      String.fromCharCodes(data.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(data.sublist(8, 12)) == 'WEBP';

  static Future<Uint8List?> selectAndEncode() async {
    final chosen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (chosen == null) return null;
    final source = await chosen.readAsBytes();
    if (source.isEmpty || source.length > 16 * 1024 * 1024) {
      throw StateError('The source photo must be under 16 MB');
    }
    final encoded = await FlutterImageCompress.compressWithList(
      source,
      minWidth: 1024,
      minHeight: 1024,
      quality: 76,
      format: CompressFormat.webp,
      keepExif: false,
    );
    if (!isWebp(encoded) || encoded.length > maxBytes) {
      throw StateError('A compatible WebP image below 2 MB is required');
    }
    return encoded;
  }

  static Future<String> upload(SupabaseClient client, String roomId,
      Uint8List webp) async {
    if (!isWebp(webp) || webp.length > maxBytes) {
      throw ArgumentError('Invalid WebP cover');
    }
    final path = '$roomId/cover.webp';
    await client.storage.from(bucketName).uploadBinary(
      path,
      webp,
      fileOptions: const FileOptions(
        contentType: 'image/webp',
        upsert: true,
        cacheControl: '3600',
      ),
    );
    await client.rpc('phase2_room_customize', params: {
      'p_room_id': roomId,
      'p_welcome_message': null,
      'p_cover_path': path,
      'p_background_path': null,
    });
    return path;
  }

  static String imageUrl(SupabaseClient client, String path) =>
      client.storage.from(bucketName).getPublicUrl(path);
}
