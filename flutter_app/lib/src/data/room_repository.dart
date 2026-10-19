import 'package:supabase_flutter/supabase_flutter.dart';

class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.isPrivate,
    this.coverPath,
    this.imageRevision,
    this.welcomeMessage = '',
  });

  final String id;
  final String title;
  final String ownerId;
  final bool isPrivate;
  final String? coverPath;
  final String? imageRevision;
  final String welcomeMessage;

  factory RoomSummary.fromJson(Map<String, dynamic> data) => RoomSummary(
        id: data['id'] as String,
        title: data['title'] as String,
        ownerId: data['owner_id'] as String,
        isPrivate: data['is_private'] as bool,
        coverPath: data['cover_path'] as String?,
        imageRevision: data['image_revision'] as String?,
        welcomeMessage: (data['welcome_message'] as String?) ?? '',
      );
}

class RoomSeatMember {
  const RoomSeatMember({
    required this.userId,
    required this.displayName,
    required this.seatNumber,
    required this.isMuted,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final int? seatNumber;
  final bool isMuted;
  final String? avatarUrl;

  factory RoomSeatMember.fromJson(Map<String, dynamic> data) => RoomSeatMember(
        userId: data['user_id'] as String,
        displayName: data['display_name'] as String,
        avatarUrl: data['avatar_url'] as String?,
        seatNumber: data['seat_no'] as int?,
        isMuted: data['is_muted'] as bool,
      );
}

class HomeBanner {
  const HomeBanner({required this.id, required this.title, required this.url});
  final String id;
  final String title;
  final String url;

  factory HomeBanner.fromJson(Map<String, dynamic> data) => HomeBanner(
        id: data['id'] as String,
        title: data['title'] as String,
        url: data['image_url'] as String,
      );
}

class RoomTextMessage {
  const RoomTextMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory RoomTextMessage.fromJson(Map<String, dynamic> data) =>
      RoomTextMessage(
        id: data['id'] as int,
        senderId: data['sender_id'] as String,
        body: data['body'] as String,
        createdAt: DateTime.parse(data['created_at'] as String),
      );
}

class RoomRepository {
  RoomRepository(this.client);
  final SupabaseClient client;

  Future<List<RoomSummary>> publicRooms() async {
    final rows = await client
        .from('rooms')
        .select(
          'id,title,owner_id,is_private,cover_path,image_revision,welcome_message',
        )
        .eq('is_private', false)
        .order('created_at', ascending: false)
        .limit(60);
    return (rows as List)
        .map((row) => RoomSummary.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<HomeBanner>> activeBanners() async {
    // RLS additionally filters scheduled, archived and unpublished banners.
    final rows = await client
        .from('home_banners')
        .select('id,title,image_url')
        .eq('status', 'published')
        .order('sort_order', ascending: true)
        .limit(12);
    return (rows as List)
        .map((row) => HomeBanner.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> join(String roomId) async {
    final ok = await client.rpc('phase2_room_join',
        params: {'p_room_id': roomId});
    if (ok != true) {
      throw StateError('Room join was not confirmed by the server');
    }
  }

  Future<void> leave(String roomId) async {
    // A false result may mean the member was already removed; this is safe.
    await client.rpc('phase2_room_leave',
        params: {'p_room_id': roomId});
  }

  Future<List<RoomSeatMember>> members(String roomId) async {
    final rows = await client.rpc('phase2_room_members_visual',
        params: {'p_room_id': roomId});
    return (rows as List)
        .map((row) => RoomSeatMember.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }


  Future<void> takeSeat(String roomId, int number) async {
    if (number < 1 || number > 15) {
      throw RangeError.range(number, 1, 15, 'number');
    }
    final result = await client.rpc('phase2_room_take_seat', params: {
      'p_room_id': roomId,
      'p_seat': number,
    });
    if (result != number) {
      throw StateError('The selected seat was not confirmed by the server');
    }
  }

  Future<void> releaseSeat(String roomId) async {
    await client.rpc('phase2_room_take_seat', params: {
      'p_room_id': roomId,
      'p_seat': null,
    });
  }

  Stream<List<RoomTextMessage>> watchMessages(String roomId) {
    return client
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('id', ascending: false)
        .limit(50)
        .map(
          (rows) => rows
              .map((data) => RoomTextMessage.fromJson(data))
              .toList(growable: false),
        );
  }

  Future<void> sendMessage(String roomId, String message) async {
    final text = message.trim();
    if (text.isEmpty || text.length > 500) {
      throw ArgumentError.value(text, 'message', 'Invalid message length');
    }
    final createdId = await client.rpc('phase2_room_send_message', params: {
      'p_room_id': roomId,
      'p_body': text,
    });
    if (createdId is! int) {
      throw StateError('The message was not confirmed by the server');
    }
  }

  String? coverUrl(RoomSummary room) {
    final path = room.coverPath;
    if (path == null || path != '${room.id}/cover.webp') return null;
    final url = client.storage.from('totichat-room-images').getPublicUrl(path);
    final revision = room.imageRevision;
    if (revision == null || revision.isEmpty) return url;
    return '$url?v=${Uri.encodeQueryComponent(revision)}';
  }
}
