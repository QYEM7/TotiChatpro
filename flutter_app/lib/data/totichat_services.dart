import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Real authenticated Staging APIs. Server remains the authority for all money,
/// permissions, CP, gifts and moderation. No client-side ledger writes.
class TotiChatServices {
  const TotiChatServices(this.client);
  final SupabaseClient client;
  static const uuid = Uuid();
  static const socialSearchLimit = 20;
  static const notificationPageLimit = 50;
  static const maxSafeCoinAmount = 9007199254740991;

  /// Parse exact positive integers; reject decimals and scientific notation.
  static int? parseTreasuryAmount(String raw) {
    final text = raw.trim();
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(text)) return null;
    final value = int.tryParse(text);
    if (value == null || value > maxSafeCoinAmount) return null;
    return value;
  }

  /// Social search returns user_id, not id. Never guess a recipient identity.
  static String verifiedSocialUserId(Map<String, dynamic> person) {
    final id = person['user_id'];
    if (id is! String || id.isEmpty) {
      throw StateError('Missing real social user ID');
    }
    return id;
  }

  String get userId => client.auth.currentUser?.id ??
      (throw StateError('Sign in is required'));

  static List<Map<String, dynamic>> rows(Object? payload) {
    Object? data = payload;
    if (data is Map) {
      data = data['rows'] ?? data['items'] ?? data['tickets'] ?? data['results'];
    }
    if (data is! List) throw StateError('Invalid server list response');
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Map<String, dynamic> object(Object? data) {
    if (data is! Map) throw StateError('Invalid server object response');
    return Map<String, dynamic>.from(data);
  }

  /// The id is created by the caller and retained across retries. Inserting
  /// finance/messaging with a new ID after a timeout could double-charge.
  static String requestId() => uuid.v4();

  Future<List<Map<String, dynamic>>> inbox() async {
    userId;
    return rows(await client.rpc('phase2_dm_inbox', params: {'p_limit': 50}));
  }

  Future<List<Map<String, dynamic>>> thread(String peer) async {
    userId;
    final result = await client.rpc('phase2_dm_thread',
      params: {'p_other_user': peer, 'p_before_id': null, 'p_limit': 80});
    return rows(result).reversed.toList();
  }

  Future<void> sendDm(String peer, String body, String id) async {
    userId;
    final text = body.trim();
    if (text.isEmpty || text.length > 2000 || peer == userId) {
      throw ArgumentError('Invalid message');
    }
    final result = object(await client.rpc('phase2_dm_send', params: {
      'p_recipient_id': peer, 'p_body': text, 'p_request_id': id,
    }));
    if (result['sent'] != true) throw StateError('Message not confirmed');
  }

  Future<void> markDmRead(String peer, int lastId) async {
    userId;
    await client.rpc('phase2_dm_mark_read',
      params: {'p_other_user': peer, 'p_through_id': lastId});
  }

  Future<List<Map<String, dynamic>>> socialSearch(String text) async {
    userId;
    final prefix = text.trim();
    if (prefix.length < 2 || prefix.length > 40) {
      throw ArgumentError('Search requires 2-40 characters');
    }
    final found = rows(await client.rpc('phase5_social_search',
      params: {'p_prefix': prefix, 'p_limit': socialSearchLimit}));
    for (final person in found) {
      verifiedSocialUserId(person);
    }
    return found;
  }

  Future<void> follow(String peer, {required bool enabled, required String requestId}) async {
    userId;
    if (peer == userId) throw ArgumentError('Cannot follow yourself');
    final result = object(await client.rpc('phase5_social_follow', params: {
      'p_target': peer, 'p_follow': enabled, 'p_request_id': requestId,
    }));
    if (result['followed'] != enabled ||
        result['targetId']?.toString() != peer) {
      throw StateError('Follow operation not confirmed by server');
    }
  }

  /// Draws are read-only until official probability disclosures are approved.
  Future<Map<String, dynamic>> luckyReadiness() async {
    userId;
    final result = object(await client.rpc('phase5_lucky_gift_readiness'));
    if (result['approvedOddsPublished'] is! bool ||
        result['purchasesAllowed'] is! bool ||
        result['bonusCurrency'] != 'LUCKY_POINTS_NON_REDEEMABLE' ||
        result['tiers'] is! List) {
      throw StateError('Lucky Gift policy response is incomplete');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> luckyHistory() async {
    userId;
    return rows(await client.rpc('phase6_lucky_gift_history',
      params: {'p_limit': 30}));
  }

  Future<List<Map<String, dynamic>>> gifts() async {
    userId;
    final result = await client.from('gift_catalog').select(
      'id,name,price,is_active,diamond_source_type,category_id,icon,preview_url',
    ).eq('is_active', true).order('price');
    return result.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> sendGift({
    required String roomId, required String recipientId,
    required Map<String, dynamic> gift, required int quantity,
    required String requestId,
  }) async {
    userId;
    if (![1,7,17,77,777].contains(quantity) ||
        gift['is_active'] != true ||
        gift['diamond_source_type'] == 'LUCKY_GIFT') {
      throw ArgumentError('Unavailable gift or quantity');
    }
    final price = (gift['price'] as num?)?.toInt();
    if (price == null || price < 1 || price > 1000000000000) {
      throw ArgumentError('Invalid catalog price');
    }
    final result = object(await client.rpc('phase3_send_gift', params: {
      'p_room_id': roomId, 'p_recipient_id': recipientId,
      'p_gift_id': gift['id'], 'p_quantity': quantity,
      'p_expected_price': price, 'p_request_id': requestId,
    }));
    if (result['status'] != 'completed') throw StateError('Gift not confirmed');
  }

  Future<List<Map<String, dynamic>>> store() async {
    userId;
    final rows = await client.from('store_catalog').select(
      'id,name,category,price,currency,icon,description,duration_days,'
      'vip_level,is_active,is_reward,preview_url',
    ).eq('is_active', true).order('price');
    return rows.map((x) => Map<String, dynamic>.from(x)).toList();
  }

  Future<List<Map<String, dynamic>>> inventory() async {
    final uid = userId;
    final rows = await client.from('store_ownership')
      .select('id,item_id,equipped,expires_at,created_at')
      .eq('user_id', uid).order('created_at', ascending: false);
    return rows.map((x) => Map<String, dynamic>.from(x)).toList();
  }

  Future<void> buyItem(Map<String, dynamic> item, String requestId) async {
    userId;
    if (item['is_active'] != true || item['is_reward'] == true) {
      throw ArgumentError('Item not purchasable');
    }
    final price = (item['price'] as num?)?.toInt();
    if (price == null || price <= 0) throw ArgumentError('Invalid price');
    final result = object(await client.rpc('phase3_purchase_store', params: {
      'p_item_id': item['id'], 'p_request_id': requestId,
      'p_expected_price': price, 'p_expected_currency': item['currency'],
    }));
    if (result['status'] != 'completed') throw StateError('Purchase not confirmed');
  }

  Future<List<Map<String, dynamic>>> giftHistory() async {
    userId;
    return rows(await client.rpc('phase5_gift_history',params:{
      'p_direction':'received','p_limit':40,
      'p_before_at':null,'p_before_id':null,
    }));
  }

  Future<Map<String, dynamic>> vip() async {
    final uid=userId;
    return object(await client.rpc('phase5_vip_status',
      params: {'p_target':uid}));
  }

  Future<Map<String, dynamic>> cpState() async {
    userId;
    return object(await client.rpc('phase4_cp_state'));
  }

  Future<void> cpAction({
    required String peer,required String type, required String action,
    required String requestId,
  }) async {
    userId;
    if (peer == userId || !['request','accept','reject','cancel','end'].contains(action)) {
      throw ArgumentError('Invalid CP action');
    }
    final result=object(await client.rpc('phase4_cp_action',params:{
      'p_partner_id':peer,'p_type_id':type,
      'p_action':action,'p_request_id':requestId,
    }));
    if (result['id']==null && result['status']==null) {
      throw StateError('CP action not confirmed');
    }
  }

  Future<void> reviewHostRegistration({
    required String registrationId,
    required bool approve,
    required String note,
    required String requestId,
    double? commissionPercent,
  }) async {
    userId;
    final clean = note.trim();
    if (registrationId.isEmpty || clean.length < 3 || clean.length > 500 ||
        (approve && (commissionPercent == null ||
          !commissionPercent.isFinite ||
          commissionPercent < 0 || commissionPercent > 100))) {
      throw ArgumentError('Invalid host agency review');
    }
    final expectedStatus = approve ? 'approved' : 'rejected';
    final result = object(await client.rpc('phase4_agency_action', params: {
      'p_action': approve ? 'approve_registration' : 'reject_registration',
      'p_data': {
        'id': registrationId,
        'note': clean,
        if (approve) 'commission_percent': commissionPercent,
      },
      'p_request_id': requestId,
    }));
    if (result['id']?.toString() != registrationId ||
        result['status'] != expectedStatus) {
      throw StateError('Agency decision not confirmed by server');
    }
  }

  /// Submit a real host agency join or transfer request.
  Future<String> joinHostAgency({
    required String agencyId,
    required String reason,
    required String requestId,
  }) async {
    userId;
    final clean = reason.trim();
    if (agencyId.isEmpty || clean.length < 3 || clean.length > 500) {
      throw ArgumentError('Host join reason and agency are required');
    }
    final result = object(await client.rpc('phase4_agency_action', params: {
      'p_action': 'join',
      'p_data': {'agency_id': agencyId, 'reason': clean},
      'p_request_id': requestId,
    }));
    if (result['id'] is! String ||
        !['pending_new', 'pending_old'].contains(result['status'])) {
      throw StateError('Server did not confirm host join request');
    }
    return result['id'] as String;
  }

  /// The server decides whether the actor is old or new agency owner.
  Future<String> reviewHostJoin({
    required String joinId,
    required String action,
    required String requestId,
  }) async {
    userId;
    if (joinId.isEmpty ||
        !['approve_old', 'accept_join', 'reject_join'].contains(action)) {
      throw ArgumentError('Invalid host join decision');
    }
    final result = object(await client.rpc('phase4_agency_action', params: {
      'p_action': action,
      'p_data': {'id': joinId},
      'p_request_id': requestId,
    }));
    final expectedStatus = action == 'approve_old'
        ? 'pending_new'
        : action == 'accept_join' ? 'completed' : 'rejected';
    if (result['id']?.toString() != joinId ||
        result['status'] != expectedStatus) {
      throw StateError('Host join decision not confirmed');
    }
    return expectedStatus;
  }

  Future<Map<String,dynamic>> hostMonthPreflight(DateTime month) async {
    userId;
    final utc = DateTime.utc(month.year, month.month);
    final data = object(await client.rpc('phase5_host_month_preflight', params: {
      'p_month': utc.toIso8601String().substring(0, 10),
      'p_offset': 0,
      'p_limit': 100,
    }));
    if (data['isDraftPreflight'] != true || data['paysSalaries'] != false) {
      throw StateError('Unexpected host evidence response');
    }
    return data;
  }

  Future<Map<String,dynamic>> hostMonthSnapshot(DateTime month) async {
    userId;
    final utc = DateTime.utc(month.year, month.month);
    final data = object(await client.rpc('phase5_host_month_snapshot_state',
      params: {
        'p_month': utc.toIso8601String().substring(0, 10),
        'p_offset': 0,
        'p_limit': 100,
      }));
    if (data['isAccrualEvidenceOnly'] != true ||
        data['paysSalaries'] != false) {
      throw StateError('Unexpected monthly accrual evidence');
    }
    return data;
  }

  Future<Map<String,dynamic>> agencyState() async {
    userId;
    return object(await client.rpc('phase4_agency_state'));
  }

  Future<void> applyAgency({
    required String kind,required String name,
    required String contact,required String reason,required String requestId,
  }) async {
    userId;
    if (!['host','recharge'].contains(kind) || name.trim().length<2 ||
        contact.trim().length<3 || reason.trim().length<3) {
      throw ArgumentError('Agency form incomplete');
    }
    final result=object(await client.rpc('phase4_agency_action',params:{
      'p_action':'register',
      'p_data':{'kind':kind,'name':name.trim(),'contact':contact.trim(),'reason':reason.trim()},
      'p_request_id':requestId,
    }));
    if (result['id']==null) throw StateError('Agency request not confirmed');
  }

  Future<List<Map<String,dynamic>>> notifications() async {
    userId;
    return rows(await client.rpc('phase5_notification_feed',
      params:{'p_limit':notificationPageLimit,'p_before':null}));
  }

  Future<void> readNotifications() async {
    userId;
    await client.rpc('phase5_notification_mark',params:{'p_ids':null,'p_all':true});
  }

  Future<List<Map<String,dynamic>>> supportTickets() async {
    userId;
    return rows(await client.rpc('phase5_support_list',
      params:{'p_scope':'mine','p_offset':0,'p_limit':40}));
  }

  Future<String> supportRequest({
    required String category,required String subject,
    required String message,required String requestId,
  }) async {
    userId;
    if (subject.trim().length<5 || subject.length>120 ||
        message.trim().length<2 || message.length>2500) {
      throw ArgumentError('Support form incomplete');
    }
    final result=object(await client.rpc('phase5_support_action',params:{
      'p_action':'create',
      'p_data':{'category':category,'subject':subject.trim(),'message':message.trim()},
      'p_request_id':requestId,
    }));
    if (result['id'] is! String) throw StateError('Support ticket not confirmed');
    return result['id'] as String;
  }

  Future<Map<String,dynamic>> authority() async {
    userId;
    return object(await client.rpc('phase3_admin_session'));
  }

  Future<Map<String,dynamic>> report() async {
    userId;
    final role=await authority();
    if (role['isOwner']!=true && role['isMainPartner']!=true &&
        role['canReadReports']!=true) {
      throw StateError('Access denied by role');
    }
    final now=DateTime.now().toUtc();
    return object(await client.rpc('phase4_admin_report',params:{
      'p_from':now.subtract(const Duration(days:30)).toIso8601String(),
      'p_to':now.toIso8601String(),'p_status':null,
      'p_offset':0,'p_limit':30,
    }));
  }

  Future<Map<String,dynamic>> gameState(String roomId) async {
    userId;
    return object(await client.rpc('phase5_room_game_state',
      params:{'p_room_id':roomId}));
  }

  Future<Map<String,dynamic>> gameAction(String roomId,String action,
      int? cell,String requestId) async {
    userId;
    return object(await client.rpc('phase5_room_game_action',params:{
      'p_room_id':roomId,'p_action':action,'p_cell':cell,'p_request_id':requestId,
    }));
  }

  Future<Map<String,dynamic>> rechargeState() async {
    userId;
    return object(await client.rpc('phase4_recharge_state'));
  }

  /// Owner-only issuance/allocation. The backend holds all authority,
  /// treasury ledgers, idempotency and debit checks.
  Future<void> ownerTreasuryAction({
    required String action,
    required int coins,
    required String note,
    required String requestId,
    String? cashReference,
    String? agencyId,
  }) async {
    userId;
    final cleanNote = note.trim();
    if (!['issue', 'allocate'].contains(action) ||
        coins < 1 || coins > maxSafeCoinAmount ||
        cleanNote.length < 10 || cleanNote.length > 500 ||
        (action == 'issue' &&
          (cashReference == null || cashReference.trim().length < 3 ||
           cashReference.trim().length > 120)) ||
        (action == 'allocate' && (agencyId == null || agencyId.isEmpty))) {
      throw ArgumentError('Owner treasury evidence is incomplete');
    }
    final data = <String, dynamic>{
      'coins': coins,
      'note': cleanNote,
      if (action == 'issue') 'cash_reference': cashReference!.trim(),
      if (action == 'allocate') 'agency_id': agencyId!,
    };
    final result = object(await client.rpc('phase4_recharge_action', params: {
      'p_action': action,
      'p_data': data,
      'p_request_id': requestId,
    }));
    if (result['id'] is! String ||
        result['status'] != 'completed' ||
        (result['coins'] as num?)?.toInt() != coins) {
      throw StateError('Treasury change not confirmed');
    }
  }

  Future<void> decideAgentRequest({
    required String operationId, required String action,
    required String note, required String requestId,
    String? cashReference,
  }) async {
    userId;
    if(!['approve','reject'].contains(action)||
      note.trim().length<3||note.length>500||
      (action=='approve'&&(cashReference==null||
         cashReference.trim().length<3||cashReference.length>120))){
      throw ArgumentError('Documented recharge decision required');
    }
    final result=object(await client.rpc('phase4_recharge_action',
      params:{
        'p_action':action,
        'p_data':{
          'id':operationId,
          'note':note.trim(),
          if(action=='approve')'cash_reference':cashReference!.trim(),
        },
        'p_request_id':requestId,
      }));
    final expected = action == 'approve' ? 'completed' : 'failed';
    if (result['id'] is! String ||
        result['request_id']?.toString() != operationId ||
        result['status'] != expected) {
      throw StateError('Recharge operation not confirmed');
    }
  }

  Future<Map<String,dynamic>> roomModerationState(String roomId) async {
    userId;
    return object(await client.rpc('phase2_room_moderation_state',
      params:{'p_room_id':roomId}));
  }

  Future<void> moderateRoom({
    required String roomId, required String targetId,
    required String action, required String requestId,
    String? reason,
  }) async {
    userId;
    if(!['grant_moderator','revoke_moderator','kick','ban','unban',
      'mute','allow_mic','release_seat'].contains(action) ||
      targetId==userId || (action=='ban' &&
        (reason==null || reason.trim().length<5 || reason.length>300))) {
      throw ArgumentError('Invalid room moderation action');
    }
    final result=object(await client.rpc('phase2_room_moderate',params:{
      'p_room_id':roomId,'p_target':targetId,'p_action':action,
      'p_request_id':requestId,'p_reason':reason,
    }));
    if(result['success']!=true)throw StateError('Moderation not confirmed');
  }

  Future<List<Map<String,dynamic>>> musicQueue(String roomId) async {
    userId;
    final rows=await client.from('room_music_queue')
      .select('id,title,artist,bookmark_id,added_by,created_at')
      .eq('room_id',roomId).order('created_at');
    return rows.map((x)=>Map<String,dynamic>.from(x)).toList();
  }
}
