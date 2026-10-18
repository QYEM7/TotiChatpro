import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Strictly server-authoritative feature access. Staging backend is responsible
/// for role checks, RLS, idempotency and all debit/credit operations.
class ConnectedFeatures {
  final SupabaseClient client;
  ConnectedFeatures(this.client);

  String get ownId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign-in required');
    return id;
  }

  static Map<String, dynamic> object(dynamic source) =>
      Map<String, dynamic>.from(source as Map);

  static List<Map<String, dynamic>> collection(dynamic source) =>
      (source as List).map((x) => object(x)).toList();

  Future<List<Map<String, dynamic>>> inbox() async => collection(
        await client.rpc('phase2_dm_inbox', params: {'p_limit': 40}));

  Future<List<Map<String, dynamic>>> thread(String otherId) async =>
      collection(await client.rpc('phase2_dm_thread', params: {
        'p_other_user': otherId,
        'p_before_id': null,
        'p_limit': 60,
      }));

  Future<void> sendDm(String recipient, String body,
      {required String requestId}) async {
    final message = body.trim();
    if (message.isEmpty || message.length > 2000) {
      throw ArgumentError('Invalid text length');
    }
    await client.rpc('phase2_dm_send', params: {
      'p_recipient_id': recipient,
      'p_body': message,
      'p_request_id': requestId,
    });
  }

  Future<void> markDmRead(String otherId) async {
    await client.rpc('phase2_dm_mark_read', params: {
      'p_other_user': otherId,
      'p_through_id': null,
    });
  }

  Future<List<Map<String, dynamic>>> searchPeople(String prefix) async {
    final value = prefix.trim();
    if (value.length < 2 || value.length > 40) {
      return const [];
    }
    final response = object(await client.rpc('phase5_social_search',
        params: {'p_prefix': value, 'p_limit': 20}));
    return collection(response['items'] ?? []);
  }

  Future<Map<String, dynamic>> cpState() async =>
      object(await client.rpc('phase4_cp_state'));

  Future<void> cpAction(String partnerId, String typeId, String action,
      {required String requestId}) async {
    if (!const ['request', 'accept', 'reject', 'end'].contains(action)) {
      throw ArgumentError('Invalid CP action');
    }
    await client.rpc('phase4_cp_action', params: {
      'p_partner_id': partnerId,
      'p_type_id': typeId,
      'p_action': action,
      'p_request_id': requestId,
    });
  }

  Future<Map<String, dynamic>> agencyState() async =>
      object(await client.rpc('phase4_agency_state'));

  Future<void> registerAgency({
    required String kind,
    required String name,
    required String contact,
    required String reason,
    required String requestId,
  }) async {
    if (!const ['host', 'recharge'].contains(kind)) {
      throw ArgumentError('Invalid agency kind');
    }
    await client.rpc('phase4_agency_action', params: {
      'p_action': 'register',
      'p_data': {
        'kind': kind,
        'name': name.trim(),
        'contact': contact.trim(),
        'reason': reason.trim(),
      },
      'p_request_id': requestId,
    });
  }

  Future<void> joinAgency(String id, String reason,
      {required String requestId}) async {
    await client.rpc('phase4_agency_action', params: {
      'p_action': 'join',
      'p_data': {'agency_id': id, 'reason': reason.trim()},
      'p_request_id': requestId,
    });
  }

  Future<Map<String, dynamic>> notifications() async =>
      object(await client.rpc('phase5_notification_feed',
          params: {'p_limit': 40, 'p_before': null}));

  Future<void> markAllNotifications() async {
    await client.rpc('phase5_notification_mark',
        params: {'p_ids': <int>[], 'p_all': true});
  }

  Future<Map<String, dynamic>> vipStatus(String userId) async =>
      object(await client.rpc('phase5_vip_status',
          params: {'p_target': userId}));

  Future<Map<String, dynamic>> adminSession() async =>
      object(await client.rpc('phase3_admin_session'));

  Future<Map<String, dynamic>> adminSupportAccess() async =>
      object(await client.rpc('phase6_admin_support_access'));

  Future<Map<String, dynamic>> myTickets() async =>
      object(await client.rpc('phase5_support_list', params: {
        'p_scope': 'mine',
        'p_offset': 0,
        'p_limit': 30,
      }));

  Future<Map<String, dynamic>> rechargeState() async =>
      object(await client.rpc('phase4_recharge_state'));

  Future<Map<String, dynamic>> diamondState() async =>
      object(await client.rpc('phase4_diamond_state'));

  Future<List<Map<String, dynamic>>> catalog() async => collection(
      await client.from('store_catalog')
          .select('id,name,category,price,currency,icon,description,preview_url,is_reward,relationship_type_id')
          .eq('is_active', true)
          .eq('is_reward', false)
          .order('price', ascending: true));

  Future<List<Map<String, dynamic>>> ownedItems() async => collection(
      await client.from('store_ownership')
          .select('item_id,equipped,expires_at')
          .eq('user_id', ownId));

  Future<void> purchase(Map<String, dynamic> item,
      {required String requestId}) async {
    // Backend checks the server catalog price matches what was displayed.
    await client.rpc('phase3_purchase_store', params: {
      'p_item_id': item['id'],
      'p_request_id': requestId,
      'p_expected_price': item['price'],
      'p_expected_currency': item['currency'],
    });
  }

  Future<void> equip(String itemId, {required bool enabled}) async {
    await client.rpc('phase3_equip_store', params: {
      'p_item_id': itemId,
      'p_equipped': enabled,
    });
  }

  Future<void> follow(String userId, {required bool enabled,
    required String requestId}) async {
    await client.rpc('phase5_social_follow', params: {
      'p_target': userId,
      'p_follow': enabled,
      'p_request_id': requestId,
    });
  }

  String newRequestId() => const Uuid().v4();
}
