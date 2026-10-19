import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
  });
  final int id;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;

  factory DirectMessage.fromJson(Map<String, dynamic> row) => DirectMessage(
        id: (row['id'] as num).toInt(),
        senderId: row['sender_id'] as String,
        recipientId: row['recipient_id'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}

class DirectInboxItem {
  const DirectInboxItem({
    required this.otherUserId,
    required this.displayName,
    required this.lastBody,
    required this.unreadCount,
  });
  final String otherUserId;
  final String displayName;
  final String lastBody;
  final int unreadCount;

  factory DirectInboxItem.fromJson(Map<String, dynamic> row) => DirectInboxItem(
        otherUserId: row['other_user_id'] as String,
        displayName: (row['other_display_name'] as String?) ?? '',
        lastBody: (row['last_body'] as String?) ?? '',
        unreadCount: (row['unread_count'] as num?)?.toInt() ?? 0,
      );
}

class DirectMessageRepository {
  DirectMessageRepository(this.client);
  final SupabaseClient client;
  final _uuid = const Uuid();
  String newRequestId() => _uuid.v4();

  Future<List<DirectMessage>> thread(String otherId) async {
    final rows = await client.rpc('phase2_dm_thread', params: {
      'p_other_user': otherId, 'p_before_id': null, 'p_limit': 50,
    });
    return (rows as List)
        .map((e) => DirectMessage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<DirectInboxItem>> inbox() async {
    final rows = await client.rpc('phase2_dm_inbox', params: {'p_limit': 30});
    return (rows as List)
        .map((e) => DirectInboxItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<int> send(String recipientId, String body, String requestId) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 2000) {
      throw ArgumentError('Invalid DM');
    }
    final result = await client.rpc('phase2_dm_send', params: {
      'p_recipient_id': recipientId,
      'p_body': text,
      'p_request_id': requestId,
    });
    if (result is! Map || result['sent'] != true || result['id'] is! num) {
      throw StateError('DM send was not confirmed');
    }
    return (result['id'] as num).toInt();
  }

  Future<void> markRead(String otherId) async {
    await client.rpc('phase2_dm_mark_read', params: {
      'p_other_user': otherId,
      'p_through_id': null,
    });
  }
}
