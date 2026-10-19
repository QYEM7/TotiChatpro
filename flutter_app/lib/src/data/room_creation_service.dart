import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'room_repository.dart';

/// A room is server-created before its image can be uploaded: Storage RLS
/// allows only a server-created room ID followed by /cover.webp.
/// This client rolls back unfinished creates when possible.
class RoomCreationService {
  RoomCreationService(this.client);

  final SupabaseClient client;
  static const _bucket = 'totichat-room-images';
  static const _maxBytes = 2097152;
  static const _maxInputBytes = 15 * 1024 * 1024;

  Future<XFile?> chooseCover() =>
      ImagePicker().pickImage(source: ImageSource.gallery);

  Future<Uint8List> prepareWebp(XFile source) async {
    final size = await source.length();
    if (size <= 0 || size > _maxInputBytes) {
      throw StateError('Cover image size is not supported');
    }
    final original = await source.readAsBytes();
    for (final quality in [84, 66, 48, 30]) {
      final encoded = await FlutterImageCompress.compressWithList(
        original,
        minWidth: 1024,
        minHeight: 1024,
        quality: quality,
        format: CompressFormat.webp,
      );
      if (encoded.length <= _maxBytes && _isWebp(encoded)) {
        return encoded;
      }
    }
    throw StateError('Could not create a valid WebP cover under 2 MiB');
  }

  bool _isWebp(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
  }

  Future<RoomSummary> create({
    required String title,
    required String welcomeMessage,
    required Uint8List cover,
  }) async {
    final cleanedTitle = title.trim();
    final cleanedWelcome = welcomeMessage.trim();
    if (cleanedTitle.length < 2 || cleanedTitle.length > 60 ||
        cleanedWelcome.isEmpty || cleanedWelcome.length > 500 ||
        cover.isEmpty || cover.length > _maxBytes || !_isWebp(cover)) {
      throw ArgumentError('Invalid room title, welcome message, or WebP cover');
    }
    final created = await client.rpc('phase2_room_create', params: {
      'p_title': cleanedTitle,
      'p_is_private': false,
    });
    if (created is! String || created.isEmpty) {
      throw StateError('Room create was not confirmed');
    }
    final roomId = created;
    final path = '$roomId/cover.webp';
    var coverUploaded = false;
    try {
      await client.storage.from(_bucket).uploadBinary(
        path,
        cover,
        fileOptions: const FileOptions(
          contentType: 'image/webp',
          upsert: false,
        ),
      );
      coverUploaded = true;
      final saved = await client.rpc('phase2_room_customize', params: {
        'p_room_id': roomId,
        'p_welcome_message': cleanedWelcome,
        'p_cover_path': path,
        'p_background_path': null,
      });
      if (saved != true) throw StateError('Room customization failed');
      final row = await client.from('rooms')
          .select('id,title,owner_id,is_private,cover_path,image_revision,welcome_message')
          .eq('id', roomId).single();
      return RoomSummary.fromJson(row);
    } catch (_) {
      if (coverUploaded) {
        try {
          await client.storage.from(_bucket).remove([path]);
        } catch (_) {
          // The failed cleanup is never presented as a successful creation.
        }
      }
      try {
        // Owner leaving their own room removes it and its memberships.
        await client.rpc('phase2_room_leave', params: {'p_room_id': roomId});
      } catch (_) {
        // Report original failure; an orphan may require administrative QA.
      }
      rethrow;
    }
  }
}
