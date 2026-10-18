import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'domain.dart';
import 'social_pages.dart';

class MusicMetadataRepository {
  final SupabaseClient client;
  MusicMetadataRepository(this.client);

  String get userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Authentication required');
    return id;
  }

  Future<List<Map<String, dynamic>>> savedTracks() async {
    final rows = await client.from('user_music_bookmarks')
      .select('id,title,artist,reference_url,created_at')
      .eq('owner_id', userId).order('created_at', ascending: false);
    return (rows as List).map((item) =>
      Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> roomQueue(String roomId) async {
    final rows = await client.from('room_music_queue')
      .select('id,title,artist,bookmark_id,added_by,created_at')
      .eq('room_id', roomId).order('created_at', ascending: true);
    return (rows as List).map((item) =>
      Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> addSavedTrack({
    required String title,
    required String artist,
    String? referenceUrl,
  }) async {
    final cleanedTitle = title.trim();
    final cleanedArtist = artist.trim();
    if (cleanedTitle.length < 2 || cleanedTitle.length > 100 ||
        cleanedArtist.length > 80) {
      throw ArgumentError('Music title or artist length invalid');
    }
    final url = referenceUrl?.trim();
    if (url != null && url.isNotEmpty &&
        (!url.startsWith('https://') || url.length > 500)) {
      throw ArgumentError('Music reference must use HTTPS');
    }
    await client.from('user_music_bookmarks').insert({
      'owner_id': userId,
      'title': cleanedTitle,
      'artist': cleanedArtist,
      'reference_url': url == null || url.isEmpty ? null : url,
    });
  }

  Future<void> removeSavedTrack(String bookmarkId) async {
    await client.from('user_music_bookmarks')
      .delete().eq('id', bookmarkId).eq('owner_id', userId);
  }

  Future<void> addToQueue(String roomId, Map<String, dynamic> track) async {
    await client.from('room_music_queue').insert({
      'room_id': roomId,
      'bookmark_id': track['id'],
      'added_by': userId,
      'title': track['title'],
      'artist': track['artist'],
    });
    // The backend RLS requires the current user to OWN the room and bookmark.
  }

  Future<void> removeFromQueue(String id) async {
    await client.from('room_music_queue').delete()
      .eq('id', id).eq('added_by', userId);
  }
}

class RoomMusicQueuePage extends StatefulWidget {
  final VoiceRoom room;
  const RoomMusicQueuePage({super.key, required this.room});
  @override
  State<RoomMusicQueuePage> createState() => _RoomMusicQueuePageState();
}

class _RoomMusicQueuePageState extends State<RoomMusicQueuePage> {
  MusicMetadataRepository get repository =>
      MusicMetadataRepository(Supabase.instance.client);
  late Future<List<Map<String, dynamic>>> queue;
  late Future<List<Map<String, dynamic>>> saved;
  bool busy = false;

  bool get isOwner => widget.room.ownerId ==
      Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() { super.initState(); reload(); }
  void reload() {
    queue = repository.roomQueue(widget.room.id);
    saved = repository.savedTracks();
  }

  void error(Object value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تعذر تحديث الموسيقى: $value')));
  }

  Future<void> addBookmark() async {
    final title = TextEditingController();
    final artist = TextEditingController();
    final url = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حفظ أغنية في مكتبتي'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, maxLength: 100,
                decoration: const InputDecoration(labelText: 'اسم الأغنية')),
              TextField(controller: artist, maxLength: 80,
                decoration: const InputDecoration(labelText: 'الفنان')),
              TextField(controller: url, maxLength: 500,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'رابط مرجعي HTTPS (اختياري)')),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      setState(() => busy = true);
      await repository.addSavedTrack(
        title: title.text, artist: artist.text, referenceUrl: url.text);
      if (mounted) setState(reload);
    } catch (e) { error(e); }
    finally {
      title.dispose(); artist.dispose(); url.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addToRoom(Map<String, dynamic> bookmark) async {
    if (!isOwner || busy) return;
    setState(() => busy = true);
    try {
      await repository.addToQueue(widget.room.id, bookmark);
      if (mounted) setState(reload);
    } catch (e) { error(e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> deleteTrack(String id, {required bool queueItem}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (queueItem) {
        await repository.removeFromQueue(id);
      } else {
        await repository.removeSavedTrack(id);
      }
      if (mounted) setState(reload);
    } catch (e) { error(e); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'قائمة موسيقى الغرفة',
    body: Column(children: [
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'الأغاني محفوظة كعناوين وروابط مرجعية حقيقية. '
          'التشغيل الصوتي المتزامن غير مفعّل حتى ربط خادم التوقيت والصوت.',
          textAlign: TextAlign.center,
        ),
      ),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: queue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('لا يمكن عرض قائمة الغرفة'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('قائمة الغرفة فارغة'));
          }
          return ListView(children: [
            for (final item in items)
              ListTile(
                leading: const Icon(Icons.music_note),
                title: Text(item['title']?.toString() ?? ''),
                subtitle: Text(item['artist']?.toString() ?? ''),
                trailing: isOwner ? IconButton(
                  onPressed: busy ? null : () => deleteTrack(
                    item['id'] as String, queueItem: true),
                  icon: const Icon(Icons.remove_circle_outline),
                ) : null,
              ),
          ]);
        },
      )),
      const Divider(height: 1),
      Row(children: [
        const Expanded(child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('أغانيّ المحفوظة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        IconButton(
          onPressed: busy ? null : addBookmark,
          tooltip: 'أضف أغنية للمكتبة',
          icon: const Icon(Icons.add_circle_outline),
        ),
      ]),
      SizedBox(height: 195, child: FutureBuilder<List<Map<String, dynamic>>>(
        future: saved,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر عرض مكتبة الموسيقى'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('مكتبتك فارغة'));
          }
          return ListView(children: [
            for (final item in items)
              ListTile(
                title: Text(item['title']?.toString() ?? ''),
                subtitle: Text(item['artist']?.toString() ?? ''),
                trailing: Wrap(children: [
                  if (isOwner)
                    IconButton(
                      onPressed: busy ? null : () => addToRoom(item),
                      tooltip: 'إضافة لقائمة الغرفة',
                      icon: const Icon(Icons.playlist_add),
                    ),
                  IconButton(
                    onPressed: busy ? null : () => deleteTrack(
                      item['id'] as String, queueItem: false),
                    tooltip: 'حذف من مكتبتي',
                    icon: const Icon(Icons.delete_outline),
                  ),
                ]),
              ),
          ]);
        },
      )),
    ]),
  );
}
