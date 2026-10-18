import 'package:supabase_flutter/supabase_flutter.dart';

import 'domain.dart';

/// Uses only the existing approved Staging project and server-side RLS/RPC.
class StagingRepository {
  final SupabaseClient client;
  StagingRepository(this.client);

  String? get currentUserId => client.auth.currentUser?.id;

  Future<List<VoiceRoom>> publicRooms() async {
    final rows = await client.from('rooms')
        .select('id,title,owner_id,is_private,cover_path,welcome_message')
        .eq('is_private', false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => VoiceRoom.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<BannerItem>> publishedBanners() async {
    // RLS enforces published status and publication time windows.
    final rows = await client.from('home_banners')
        .select('title,image_url')
        .eq('status', 'published')
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((row) => BannerItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<String> createRoom(String title, {bool isPrivate = false}) async {
    final result = await client.rpc('phase2_room_create', params: {
      'p_title': title.trim(),
      'p_is_private': isPrivate,
    });
    return result as String;
  }

  Future<String> createPrivateInvitation(String roomId) async {
    final result = await client.rpc('phase2_room_invite_create',
      params: {'p_room_id': roomId});
    return result as String;
  }

  Future<VoiceRoom> joinPrivateInvitation(String invite) async {
    final parts = invite.trim().split(':');
    final roomIdValid = parts.length == 2 &&
        parts[0].length == 36 &&
        RegExp(r'^[0-9a-fA-F-]{36}').hasMatch(parts[0]);
    final tokenValid = parts.length == 2 &&
        parts[1].length == 48 &&
        RegExp(r'^[0-9a-fA-F]{48}').hasMatch(parts[1]);
    if (!roomIdValid || !tokenValid) {
      throw ArgumentError('Invalid private room invitation');
    }
    await client.rpc('phase2_room_invite_join', params: {
      'p_room_id': parts[0],
      'p_token': parts[1],
    });
    final row = await client.from('rooms')
      .select('id,title,owner_id,is_private,cover_path,welcome_message')
      .eq('id', parts[0]).single();
    return VoiceRoom.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> customizeRoomWelcome(String roomId, String welcome) async {
    if (welcome.length > 500) {
      throw ArgumentError('Welcome message too long');
    }
    await client.rpc('phase2_room_customize', params: {
      'p_room_id': roomId,
      'p_welcome_message': welcome,
      'p_cover_path': null,
      'p_background_path': null,
    });
  }

  Future<void> joinRoom(String roomId) async {
    await client.rpc('phase2_room_join', params: {'p_room_id': roomId});
  }

  Future<void> leaveRoom(String roomId) async {
    await client.rpc('phase2_room_leave', params: {'p_room_id': roomId});
  }

  Future<void> setMuted(String roomId, bool muted) async {
    await client.rpc('phase2_room_set_muted', params: {
      'p_room_id': roomId,
      'p_muted': muted,
    });
  }

  Future<void> takeSeat(String roomId, int? seat) async {
    if (seat != null && (seat < 1 || seat > 15)) {
      throw ArgumentError.value(seat, 'seat', 'Allowed seats: 1..15');
    }
    await client.rpc('phase2_room_take_seat', params: {
      'p_room_id': roomId,
      'p_seat': seat,
    });
  }

  Future<List<RoomMember>> roomMembers(String roomId) async {
    final rows = await client.rpc(
      'phase2_room_members', params: {'p_room_id': roomId});
    return (rows as List)
        .map((row) => RoomMember.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<RoomMessage>> roomMessages(String roomId) async {
    final rows = await client.from('room_messages')
        .select('sender_id,body,created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(40);
    return (rows as List)
        .map((row) => RoomMessage.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList().reversed.toList();
  }

  Future<void> sendMessage(String roomId, String body) async {
    final clean = body.trim();
    if (clean.isEmpty || clean.length > 500) {
      throw ArgumentError.value(body, 'body', 'Message length: 1..500');
    }
    await client.rpc('phase2_room_send_message',
        params: {'p_room_id': roomId, 'p_body': clean});
  }

  Future<List<GiftItem>> activeGifts() async {
    final rows = await client.from('gift_catalog')
        .select('id,name,icon,price,preview_url')
        .eq('is_active', true)
        .isFilter('relationship_type_id', null)
        .order('price', ascending: true);
    return (rows as List)
        .map((row) => GiftItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<int> coinsBalance() async {
    final id = currentUserId;
    if (id == null) throw StateError('Authentication required');
    final row = await client.from('wallets')
        .select('coins')
        .eq('user_id', id)
        .single();
    return (row['coins'] as num).toInt();
  }

  Future<void> sendGift({
    required String roomId,
    required String recipientId,
    required String giftId,
    required int quantity,
    required int expectedPrice,
    required String requestId,
  }) async {
    if (!const [1, 7, 17, 77, 777].contains(quantity)) {
      throw ArgumentError.value(quantity, 'quantity', 'Invalid quantity');
    }
    final self = currentUserId;
    if (self == null || self == recipientId) {
      throw StateError('A different authenticated recipient is required');
    }
    if (expectedPrice <= 0) throw ArgumentError.value(expectedPrice, 'expectedPrice');
    // The backend checks price and atomically commits the operation.
    await client.rpc('phase3_send_gift', params: {
      'p_room_id': roomId,
      'p_recipient_id': recipientId,
      'p_gift_id': giftId,
      'p_quantity': quantity,
      'p_request_id': requestId,
      'p_expected_price': expectedPrice,
    });
  }

  Future<Map<String, dynamic>> myProfile() async {
    final id = currentUserId;
    if (id == null) throw StateError('Authentication required');
    final row = await client.from('profiles')
        .select('display_name,bio,avatar_url')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }
}
).hasMatch(parts[0]) ||
        !RegExp(r'^[0-9a-fA-F]{48}
    if (welcome.length > 500) throw ArgumentError('Welcome message too long');
    await client.rpc('phase2_room_customize', params: {
      'p_room_id': roomId,
      'p_welcome_message': welcome,
      'p_cover_path': null,
      'p_background_path': null,
    });
  }

  Future<void> joinRoom(String roomId) async {
    await client.rpc('phase2_room_join', params: {'p_room_id': roomId});
  }

  Future<void> leaveRoom(String roomId) async {
    await client.rpc('phase2_room_leave', params: {'p_room_id': roomId});
  }

  Future<void> setMuted(String roomId, bool muted) async {
    await client.rpc('phase2_room_set_muted', params: {
      'p_room_id': roomId,
      'p_muted': muted,
    });
  }

  Future<void> takeSeat(String roomId, int? seat) async {
    if (seat != null && (seat < 1 || seat > 15)) {
      throw ArgumentError.value(seat, 'seat', 'Allowed seats: 1..15');
    }
    await client.rpc('phase2_room_take_seat', params: {
      'p_room_id': roomId,
      'p_seat': seat,
    });
  }

  Future<List<RoomMember>> roomMembers(String roomId) async {
    final rows = await client.rpc(
      'phase2_room_members', params: {'p_room_id': roomId});
    return (rows as List)
        .map((row) => RoomMember.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<RoomMessage>> roomMessages(String roomId) async {
    final rows = await client.from('room_messages')
        .select('sender_id,body,created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(40);
    return (rows as List)
        .map((row) => RoomMessage.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList().reversed.toList();
  }

  Future<void> sendMessage(String roomId, String body) async {
    final clean = body.trim();
    if (clean.isEmpty || clean.length > 500) {
      throw ArgumentError.value(body, 'body', 'Message length: 1..500');
    }
    await client.rpc('phase2_room_send_message',
        params: {'p_room_id': roomId, 'p_body': clean});
  }

  Future<List<GiftItem>> activeGifts() async {
    final rows = await client.from('gift_catalog')
        .select('id,name,icon,price,preview_url')
        .eq('is_active', true)
        .isFilter('relationship_type_id', null)
        .order('price', ascending: true);
    return (rows as List)
        .map((row) => GiftItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<int> coinsBalance() async {
    final id = currentUserId;
    if (id == null) throw StateError('Authentication required');
    final row = await client.from('wallets')
        .select('coins')
        .eq('user_id', id)
        .single();
    return (row['coins'] as num).toInt();
  }

  Future<void> sendGift({
    required String roomId,
    required String recipientId,
    required String giftId,
    required int quantity,
    required int expectedPrice,
    required String requestId,
  }) async {
    if (!const [1, 7, 17, 77, 777].contains(quantity)) {
      throw ArgumentError.value(quantity, 'quantity', 'Invalid quantity');
    }
    final self = currentUserId;
    if (self == null || self == recipientId) {
      throw StateError('A different authenticated recipient is required');
    }
    if (expectedPrice <= 0) throw ArgumentError.value(expectedPrice, 'expectedPrice');
    // The backend checks price and atomically commits the operation.
    await client.rpc('phase3_send_gift', params: {
      'p_room_id': roomId,
      'p_recipient_id': recipientId,
      'p_gift_id': giftId,
      'p_quantity': quantity,
      'p_request_id': requestId,
      'p_expected_price': expectedPrice,
    });
  }

  Future<Map<String, dynamic>> myProfile() async {
    final id = currentUserId;
    if (id == null) throw StateError('Authentication required');
    final row = await client.from('profiles')
        .select('display_name,bio,avatar_url')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }
}
).hasMatch(parts[1])) {
      throw ArgumentError('Invalid room invitation');
    }
    await client.rpc('phase2_room_invite_join', params: {
      'p_room_id': parts[0],
      'p_token': parts[1],
    });
    final row = await client.from('rooms')
      .select('id,title,owner_id,is_private,cover_path,welcome_message')
      .eq('id', parts[0]).single();
    return VoiceRoom.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> customizeRoomWelcome(String roomId, String welcome) async {
    if (welcome.length > 500) throw ArgumentError('Welcome message too long');
    await client.rpc('phase2_room_customize', params: {
      'p_room_id': roomId,
      'p_welcome_message': welcome,
      'p_cover_path': null,
      'p_background_path': null,
    });
  }

  Future<void> joinRoom(String roomId) async {
    await client.rpc('phase2_room_join', params: {'p_room_id': roomId});
  }

  Future<void> leaveRoom(String roomId) async {
    await client.rpc('phase2_room_leave', params: {'p_room_id': roomId});
  }

  Future<void> setMuted(String roomId, bool muted) async {
    await client.rpc('phase2_room_set_muted', params: {
      'p_room_id': roomId,
      'p_muted': muted,
    });
  }

  Future<void> takeSeat(String roomId, int? seat) async {
    if (seat != null && (seat < 1 || seat > 15)) {
      throw ArgumentError.value(seat, 'seat', 'Allowed seats: 1..15');
    }
    await client.rpc('phase2_room_take_seat', params: {
      'p_room_id': roomId,
      'p_seat': seat,
    });
  }

  Future<List<RoomMember>> roomMembers(String roomId) async {
    final rows = await client.rpc(
      'phase2_room_members', params: {'p_room_id': roomId});
    return (rows as List)
        .map((row) => RoomMember.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<RoomMessage>> roomMessages(String roomId) async {
    final rows = await client.from('room_messages')
        .select('sender_id,body,created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(40);
    return (rows as List)
        .map((row) => RoomMessage.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList().reversed.toList();
  }

  Future<void> sendMessage(String roomId, String body) async {
    final clean = body.trim();
    if (clean.isEmpty || clean.length > 500) {
      throw ArgumentError.value(body, 'body', 'Message length: 1..500');
    }
    await client.rpc('phase2_room_send_message',
        params: {'p_room_id': roomId, 'p_body': clean});
  }

  Future<List<GiftItem>> activeGifts() async {
    final rows = await client.from('gift_catalog')
        .select('id,name,icon,price,preview_url')
        .eq('is_active', true)
        .isFilter('relationship_type_id', null)
        .order('price', ascending: true);
    return (rows as List)
        .map((row) => GiftItem.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<int> coinsBalance() async {
    final id = currentUserId;
    if (id == null) throw StateError('Authentication required');
    final row = await client.from('wallets')
        .select('coins')
        .eq('user_id', id)
        .single();
    return (row['coins'] as num).toInt();
  }

  Future<void> sendGift({
    required String roomId,
    required String recipientId,
    required String giftId,
    required int quantity,
    required int expectedPrice,
    required String requestId,
  }) async {
    if (!const [1, 7, 17, 77, 777].contains(quantity)) {
      throw ArgumentError.value(quantity, 'quantity', 'Invalid quantity');
    }
    final self = currentUserId;
    if (self == null || self == recipientId) {
      throw StateError('A different authenticated recipient is required');
    }
    if (expectedPrice <= 0) throw ArgumentError.value(expectedPrice, 'expectedPrice');
    // The backend checks price and atomically commits the operation.
    await client.rpc('phase3_send_gift', params: {
      'p_room_id': roomId,
      'p_recipient_id': recipientId,
      'p_gift_id': giftId,
      'p_quantity': quantity,
      'p_request_id': requestId,
      'p_expected_price': expectedPrice,
    });
  }

  Future<Map<String, dynamic>> myProfile() async {
    final id = currentUserId;
    if (id == null) throw StateError('Authentication required');
    final row = await client.from('profiles')
        .select('display_name,bio,avatar_url')
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(row);
  }
}
