import 'package:supabase_flutter/supabase_flutter.dart';

import 'totichat_services.dart';

/// RLS-protected saved track references and owner-managed room queue.
///
/// Entries are references/metadata, NOT playable audio. No client request
/// bypasses the server's ownership, room-member or bookmark RLS policies.
class RoomMusicRepository {
  const RoomMusicRepository(this.client);
  final SupabaseClient client;

  String get userId => client.auth.currentUser?.id ??
    (throw StateError('Google sign-in is required'));

  static Map<String, String?> validateBookmark({
    required String title,
    required String artist,
    String? referenceUrl,
  }) {
    final name = title.trim();
    final performer = artist.trim();
    final reference = referenceUrl?.trim() ?? '';
    if (name.length < 2 || name.length > 100 ||
        performer.length > 80) {
      throw ArgumentError('Title must be 2-100 and artist at most 80 characters');
    }
    if (reference.isNotEmpty) {
      final uri = Uri.tryParse(reference);
      if (reference.length > 500 || RegExp(r'\s').hasMatch(reference) ||
          uri == null || uri.scheme != 'https' || !uri.hasAuthority ||
          uri.host.isEmpty || uri.userInfo.isNotEmpty) {
        throw ArgumentError('Reference must be a valid HTTPS URL under 500 characters');
      }
    }
    return {
      'title': name,
      'artist': performer,
      'reference_url': reference.isEmpty ? null : reference,
    };
  }

  Future<List<Map<String, dynamic>>> savedTracks() async {
    final uid = userId;
    final rows = await client.from('user_music_bookmarks')
      .select('id,owner_id,title,artist,reference_url,created_at')
      .eq('owner_id', uid)
      .order('created_at', ascending: false)
      .limit(100);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> queue(String roomId) async {
    userId;
    if (roomId.isEmpty) throw ArgumentError('Room ID required');
    final rows = await client.from('room_music_queue')
      .select('id,room_id,title,artist,bookmark_id,added_by,created_at')
      .eq('room_id', roomId)
      .order('created_at')
      .limit(100);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Caller retains id and exact input across retries after unknown network
  /// outcome; using a new ID could duplicate an already completed insert.
  Future<String> saveTrack({
    required String title,
    required String artist,
    required String requestId,
    String? referenceUrl,
  }) async {
    final uid = userId;
    if (requestId.isEmpty) throw ArgumentError('Request ID required');
    final track = validateBookmark(title: title, artist: artist,
      referenceUrl: referenceUrl);
    final record = <String, dynamic>{
      'id': requestId, 'owner_id': uid, ...track,
    };
    try {
      final saved = Map<String, dynamic>.from(
        await client.from('user_music_bookmarks')
          .insert(record)
          .select('id,owner_id,title,artist,reference_url')
          .single());
      if (!_matchesBookmark(saved, uid, requestId, track)) {
        throw StateError('Bookmark save not confirmed');
      }
    } catch (error) {
      final existing = await client.from('user_music_bookmarks')
        .select('id,owner_id,title,artist,reference_url')
        .eq('id', requestId)
        .eq('owner_id', uid)
        .maybeSingle();
      if (existing == null || !_matchesBookmark(
        Map<String, dynamic>.from(existing), uid, requestId, track)) {
        Error.throwWithStackTrace(error, StackTrace.current);
      }
    }
    return requestId;
  }

  static bool _matchesBookmark(Map<String, dynamic> actual,
      String userId, String requestId, Map<String, String?> track) =>
    actual['id'] == requestId &&
    actual['owner_id'] == userId &&
    actual['title'] == track['title'] &&
    actual['artist'] == track['artist'] &&
    actual['reference_url'] == track['reference_url'];

  /// Only the room owner can insert, enforced by the database RLS; the
  /// bookmark must belong to that same owner and match the copied metadata.
  Future<String> queueTrack({
    required String roomId,
    required Map<String, dynamic> bookmark,
    required String requestId,
  }) async {
    final uid = userId;
    final savedOwner = bookmark['owner_id'];
    final bookmarkId = bookmark['id'];
    if (roomId.isEmpty || requestId.isEmpty ||
        bookmarkId is! String || bookmarkId.isEmpty ||
        savedOwner != uid) {
      throw ArgumentError('Use an owned server-saved track');
    }
    final details = validateBookmark(
      title: bookmark['title']?.toString() ?? '',
      artist: bookmark['artist']?.toString() ?? '',
      referenceUrl: bookmark['reference_url']?.toString());
    final record = <String, dynamic>{
      'id': requestId,
      'room_id': roomId,
      'bookmark_id': bookmarkId,
      'added_by': uid,
      'title': details['title'],
      'artist': details['artist'],
    };
    try {
      final queued = Map<String, dynamic>.from(
        await client.from('room_music_queue')
          .insert(record)
          .select('id,room_id,bookmark_id,added_by,title,artist')
          .single());
      if (!_matchesQueue(queued, record)) {
        throw StateError('Room queue change not confirmed');
      }
    } catch (error) {
      final existing = await client.from('room_music_queue')
        .select('id,room_id,bookmark_id,added_by,title,artist')
        .eq('id', requestId)
        .eq('room_id', roomId)
        .maybeSingle();
      if (existing == null ||
          !_matchesQueue(Map<String, dynamic>.from(existing), record)) {
        Error.throwWithStackTrace(error, StackTrace.current);
      }
    }
    return requestId;
  }

  static bool _matchesQueue(Map<String, dynamic> actual,
      Map<String, dynamic> expected) =>
    ['id','room_id','bookmark_id','added_by','title','artist']
      .every((key) => actual[key] == expected[key]);

  Future<void> removeQueuedTrack(String roomId, String queueEntryId) async {
    final uid = userId;
    if (roomId.isEmpty || queueEntryId.isEmpty) {
      throw ArgumentError('Room and queue entry required');
    }
    // RLS restricts deletion to the room owner who added the entry.
    final deleted = await client.from('room_music_queue')
      .delete()
      .eq('id', queueEntryId)
      .eq('room_id', roomId)
      .eq('added_by', uid)
      .select('id');
    if (deleted.isNotEmpty &&
        deleted.any((r) => r['id'] != queueEntryId)) {
      throw StateError('Queue removal response invalid');
    }
    if (deleted.isEmpty) {
      // A previous attempt might already have succeeded; do not report
      // success if the record is still visible and failed to delete.
      final remaining = await client.from('room_music_queue')
        .select('id')
        .eq('id', queueEntryId)
        .eq('room_id', roomId)
        .limit(1);
      if (remaining.isNotEmpty) {
        throw StateError('Queue removal not authorized or not confirmed');
      }
    }
  }

  Future<void> deleteSavedTrack(String bookmarkId) async {
    final uid = userId;
    if (bookmarkId.isEmpty) throw ArgumentError('Saved track ID required');
    final deleted = await client.from('user_music_bookmarks')
      .delete()
      .eq('id', bookmarkId)
      .eq('owner_id', uid)
      .select('id');
    if (deleted.isEmpty) {
      final remaining = await client.from('user_music_bookmarks')
        .select('id')
        .eq('id', bookmarkId)
        .eq('owner_id', uid)
        .limit(1);
      if (remaining.isNotEmpty) {
        throw StateError('Saved track deletion not authorized');
      }
    } else if (deleted.any((row) => row['id'] != bookmarkId)) {
      throw StateError('Unexpected saved track deletion response');
    }
  }

  static String newRequestId() => TotiChatServices.requestId();
}
