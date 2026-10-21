import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/green_theme.dart';
import '../core/premium_ui.dart';
import '../core/ui_text.dart';
import '../data/room_repository.dart';

/// Display verified CP relationships and currently enabled types only.
class RelationshipScreen extends StatefulWidget {
  const RelationshipScreen({super.key});

  @override
  State<RelationshipScreen> createState() => _RelationshipScreenState();
}

class _RelationshipScreenState extends State<RelationshipScreen> {
  late final Future<List<Map<String, dynamic>>> _relationships = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) throw StateError('Authorized account required');
    final rows = await Supabase.instance.client.from('cp_relationships')
      .select('id,type_id,accepted_at,ended_at')
      .or('user_a.eq.$id,user_b.eq.$id')
      .order('created_at', ascending: false)
      .limit(30);
    return (rows as List).map((x) => Map<String, dynamic>.from(x as Map)).where(
      (x) => x['accepted_at'] != null && x['ended_at'] == null,
    ).toList();
  }

  @override
  Widget build(BuildContext context) => PremiumPage(
    title: UiText.get('cp_title'),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _relationships,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
              return PremiumEmptyState(
          icon: Icons.error_outline, title: UiText.get('cp_load_failed'));
            }
        final relationships = snapshot.requireData;
        return ListView(padding: const EdgeInsets.all(16), children: [
          PremiumSurface(child: Row(children: [
            const Icon(Icons.favorite_outline, color: GreenTheme.gold, size: 36),
            const SizedBox(width: 14),
            Expanded(child: Text(UiText.get('cp_description'),
                style: const TextStyle(color: GreenTheme.ink))),
          ])),
          const SizedBox(height: 20),
          PremiumHeader(title: UiText.get('cp_active')),
          const SizedBox(height: 12),
          if (relationships.isEmpty)
            PremiumEmptyState(icon: Icons.favorite_border, title: UiText.get('cp_empty'))
          else
            ...relationships.map((item) {
              final accepted = DateTime.tryParse(item['accepted_at']?.toString() ?? '');
              final days = accepted == null ? null : DateTime.now().difference(accepted).inDays;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumRow(
                  icon: Icons.favorite_outline,
                  title: item['type_id']?.toString() ?? '',
                  subtitle: days == null ? null : '${UiText.get('cp_days')}: $days',
                ),
              );
            }),
          const SizedBox(height: 20),
          PremiumHeader(title: UiText.get('cp_types')),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: Supabase.instance.client.from('cp_types')
              .select('id,label').eq('enabled', true).order('label'),
            builder: (context, typeSnapshot) {
              if (typeSnapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (!typeSnapshot.hasData) {
      return Text(UiText.get('cp_load_failed'));
    }
              final types = typeSnapshot.requireData;
              if (types.isEmpty) {
              return Text(UiText.get('cp_no_active_types'));
            }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: types.map((item) => PremiumGoldLabel(
                  title: (item as Map)['label']?.toString() ?? '',
                  icon: Icons.favorite_outline,
                )).toList(),
              );
            },
          ),
        ]);
      },
    ),
  );
}

/// Browse genuine charging/host agencies without enabling unsanctioned joins.
class AgencyScreen extends StatefulWidget {
  const AgencyScreen({super.key});

  @override
  State<AgencyScreen> createState() => _AgencyScreenState();
}

class _AgencyScreenState extends State<AgencyScreen> {
  late Future<List<Map<String, dynamic>>> _agencies = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('agencies')
      .select('id,name,kind')
      .eq('is_active', true)
      .order('name')
      .limit(40);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  @override
  Widget build(BuildContext context) => PremiumPage(
    title: UiText.get('agency_title'),
    body: RefreshIndicator(
      onRefresh: () async { setState(() => _agencies = _load()); },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        PremiumSurface(child: Row(children: [
          const Icon(Icons.apartment_outlined, size: 38, color: GreenTheme.gold),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(UiText.get('agency_heading'), style: const TextStyle(
              color: GreenTheme.primaryDark, fontSize: 19, fontWeight: FontWeight.w900)),
            Text(UiText.get('agency_intro')),
          ])),
        ])),
        const SizedBox(height: 20),
        PremiumHeader(title: UiText.get('agency_available')),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _agencies,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return PremiumEmptyState(
              icon: Icons.error_outline, title: UiText.get('agency_load_failed'));
            }
            final rows = snapshot.requireData;
            if (rows.isEmpty) {
              return PremiumEmptyState(
              icon: Icons.apartment_outlined,
              title: UiText.get('agency_empty'),
              subtitle: UiText.get('agency_notice'),
            );
            }
            return Column(children: rows.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumRow(
                icon: Icons.apartment_outlined,
                title: a['name']?.toString() ?? '',
                subtitle: a['kind']?.toString(),
              ),
            )).toList());
          },
        ),
      ]),
    ),
  );
}

/// Shared-room queue metadata only. No pretend playback or cross-device sync.
class MusicQueueScreen extends StatefulWidget {
  const MusicQueueScreen({super.key, required this.roomId});
  final String roomId;

  @override
  State<MusicQueueScreen> createState() => _MusicQueueScreenState();
}

class _MusicQueueScreenState extends State<MusicQueueScreen> {
  late final Future<List<Map<String, dynamic>>> _queue = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client.from('room_music_queue')
      .select('title,artist,created_at')
      .eq('room_id', widget.roomId)
      .order('created_at')
      .limit(60);
    return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  @override
  Widget build(BuildContext context) => PremiumPage(
    title: UiText.get('music_title'),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      PremiumSurface(child: Row(children: [
        const Icon(Icons.music_note_rounded, color: GreenTheme.gold, size: 40),
        const SizedBox(width: 14),
        Expanded(child: Text(UiText.get('music_metadata_only'),
            style: const TextStyle(color: GreenTheme.ink))),
      ])),
      const SizedBox(height: 20),
      PremiumHeader(title: UiText.get('music_queue')),
      const SizedBox(height: 12),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _queue,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
              return PremiumEmptyState(
            icon: Icons.error_outline, title: UiText.get('music_load_failed'));
            }
          final rows = snapshot.requireData;
          if (rows.isEmpty) {
              return PremiumEmptyState(
            icon: Icons.queue_music_rounded, title: UiText.get('music_empty'));
            }
          return Column(children: rows.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumRow(
              icon: Icons.music_note,
              title: entry['title']?.toString() ?? '',
              subtitle: entry['artist']?.toString(),
            ),
          )).toList());
        },
      ),
    ]),
  );
}

/// Only update the two profile attributes supported by current Staging schema.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _bio = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) return;
    try {
      final record = await Supabase.instance.client.from('profiles')
        .select('display_name,bio').eq('id', id).single();
      if (!mounted) return;
      setState(() {
        _name.text = record['display_name']?.toString() ?? '';
        _bio.text = record['bio']?.toString() ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = UiText.get('profile_load_failed');
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) return;
    setState(() { _saving = true; _error = null; });
    try {
      final saved = await Supabase.instance.client.from('profiles')
        .update({'display_name': _name.text.trim(), 'bio': _bio.text.trim()})
        .eq('id', id).select('id');
      if (saved.isEmpty) throw StateError('Profile update not confirmed');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = UiText.get('profile_save_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PremiumPage(
    title: UiText.get('profile_edit'),
    body: _loading ? const Center(child: CircularProgressIndicator()) :
    (_error != null && _name.text.isEmpty)
      ? PremiumEmptyState(icon: Icons.error_outline, title: _error!)
      : Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Center(child: CircleAvatar(
              radius: 45,
              backgroundColor: GreenTheme.highlight,
              child: Icon(Icons.person, color: GreenTheme.primaryDark, size: 45),
            )),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: UiText.get('profile_name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty || v.trim().length > 40)
                  ? UiText.get('profile_name_invalid') : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bio,
              maxLength: 160,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: UiText.get('profile_bio'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Text(UiText.get('profile_edit_limitations')),
            if (_error != null) Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
              label: Text(UiText.get('save_changes')),
            ),
          ]),
        ),
  );
}

/// Real public room preview; no invented member counts or moderation ranks.
class RoomDetailsScreen extends StatelessWidget {
  const RoomDetailsScreen({super.key,
    required this.room,
    required this.repository,
    required this.onJoin,
  });

  final RoomSummary room;
  final RoomRepository repository;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final cover = repository.coverUrl(room);
    return PremiumPage(
      title: UiText.get('room_details_title'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 190,
            child: cover == null ? const ColoredBox(
              color: GreenTheme.highlight,
              child: Icon(Icons.headphones_rounded, size: 72, color: GreenTheme.primaryDark),
            ) : Image.network(cover, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: GreenTheme.highlight,
                child: Icon(Icons.headphones_rounded, size: 70))),
          ),
        ),
        const SizedBox(height: 18),
        PremiumHeader(title: room.title),
        const SizedBox(height: 16),
        PremiumRow(
          icon: room.isPrivate ? Icons.lock_outline : Icons.public,
          title: room.isPrivate
              ? UiText.get('room_private') : UiText.get('discover_public_room'),
        ),
        const SizedBox(height: 12),
        PremiumSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PremiumHeader(title: UiText.get('room_welcome_label')),
          const SizedBox(height: 8),
          Text(room.welcomeMessage.isEmpty ? UiText.get('room_welcome_empty') : room.welcomeMessage),
        ])),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: onJoin,
          icon: const Icon(Icons.headset_outlined),
          label: Text(UiText.get('room_join'))),
      ]),
    );
  }
}
