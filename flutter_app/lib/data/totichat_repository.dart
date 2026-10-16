import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/room_models.dart';

/// Staging-only typed gateway. All state-changing actions use existing
/// server-authorized RPCs, never a direct client-side financial table update.
class TotiChatRepository {
  const TotiChatRepository(this.client);
  final SupabaseClient client;

  String get currentUserId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('A real signed-in user is required');
    return id;
  }

  Future<List<RoomInfo>> publicRooms() async {
    currentUserId;
    final rows = await client.from('rooms').select(
      'id,title,owner_id,is_private,cover_path,welcome_message',
    ).eq('is_private', false).order('created_at', ascending: false).limit(100);
    return rows.map((row) => RoomInfo.fromJson(row)).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> activeBanners() async {
    final now = DateTime.now().toUtc();
    final rows = await client.from('home_banners').select(
      'id,title,image_url,starts_at,ends_at,status,sort_order',
    ).eq('status', 'published').order('sort_order');
    return rows.where((row) {
      final start = DateTime.tryParse(row['starts_at']?.toString() ?? '');
      final end = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      return (start == null || !start.isAfter(now)) &&
          (end == null || end.isAfter(now)) &&
          (row['image_url']?.toString().startsWith('https://') ?? false);
    }).toList(growable: false);
  }

  Future<RoomInfo> createRoom(String title, {bool isPrivate = false}) async {
    final clean = title.trim();
    if (clean.length < 3 || clean.length > 60) {
      throw ArgumentError('Room title must be 3–60 characters');
    }
    final id = await client.rpc('phase2_room_create', params: {
      'p_title': clean, 'p_is_private': isPrivate,
    });
    if (id is! String || id.isEmpty) throw StateError('Room was not confirmed');
    return roomById(id);
  }

  Future<RoomInfo> roomById(String roomId) async {
    currentUserId;
    final row = await client.from('rooms').select(
      'id,title,owner_id,is_private,cover_path,welcome_message',
    ).eq('id', roomId).single();
    return RoomInfo.fromJson(row);
  }

  Future<void> joinRoom(String roomId) async {
    currentUserId;
    final result = await client.rpc('phase2_room_join', params: {'p_room_id': roomId});
    if (result != true) throw StateError('Server did not confirm room join');
  }

  Future<void> leaveRoom(String roomId) async {
    currentUserId;
    final result = await client.rpc('phase2_room_leave', params: {'p_room_id': roomId});
    if (result != true) throw StateError('Server did not confirm room leave');
  }

  Future<List<RoomMember>> members(String roomId) async {
    currentUserId;
    final result = await client.rpc('phase2_room_members_visual',
      params: {'p_room_id': roomId});
    if (result is! List) throw StateError('Invalid members response');
    return result.map((row) =>
      RoomMember.fromJson(Map<String, dynamic>.from(row as Map))).toList(growable: false);
  }

  Future<int?> setSeat(String roomId, int? seatNo) async {
    currentUserId;
    if (seatNo != null && (seatNo < 1 || seatNo > 15)) {
      throw ArgumentError('Seat must be 1–15');
    }
    final result = await client.rpc('phase2_room_take_seat',
      params: {'p_room_id': roomId, 'p_seat': seatNo});
    if (result == null) return null;
    return (result as num).toInt();
  }

  Future<void> setMicMuted(String roomId, bool muted) async {
    currentUserId;
    final result = await client.rpc('phase2_room_set_muted',
      params: {'p_room_id': roomId, 'p_muted': muted});
    if (result != true) throw StateError('Server did not confirm microphone state');
  }

  Future<List<RoomMessage>> messages(String roomId) async {
    currentUserId;
    final rows = await client.from('room_messages')
      .select('id,sender_id,body')
      .eq('room_id', roomId).order('id', ascending: false).limit(80);
    return rows.reversed.map(RoomMessage.fromJson).toList(growable: false);
  }

  Future<void> sendMessage(String roomId, String body) async {
    currentUserId;
    final text = body.trim();
    if (text.isEmpty || text.length > 500) {
      throw ArgumentError('Message must be 1–500 characters');
    }
    final id = await client.rpc('phase2_room_send_message', params: {
      'p_room_id': roomId, 'p_body': text,
    });
    if (id is! num || id.toInt() <= 0) throw StateError('Message not confirmed');
  }

  Future<VoiceGrant> requestVoiceToken(String roomId) async {
    currentUserId;
    final response = await client.functions.invoke(
      'phase2-voice-token', body: {'roomId': roomId},
    );
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Voice authorization failed: ${response.status}');
    }
    final grant = VoiceGrant.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
    if (grant.roomId != roomId || !grant.url.startsWith('wss://') || grant.token.isEmpty) {
      throw StateError('Unsafe voice token response');
    }
    return grant;
  }

  Future<Map<String, dynamic>?> ownWallet() async {
    final id = currentUserId;
    final rows = await client.from('wallets').select('user_id,coins,diamonds,silver')
      .eq('user_id', id).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> ownProfile() async {
    final id = currentUserId;
    final rows = await client.from('profiles').select('id,display_name,bio,avatar_url')
      .eq('id', id).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> ownAssignedId() async {
    final id = currentUserId;
    final value = await client.rpc('phase5_special_id_status', params: {'p_target': id});
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }
}
