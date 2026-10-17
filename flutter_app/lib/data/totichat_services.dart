import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'notification_models.dart';
import 'push_preference_models.dart';

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

  /// Gift price is an exact Postgres bigint. Never round a decimal or a
  /// floating-point price into an irreversible wallet debit.
  static int? giftUnitPrice(Object? raw) {
    if (raw is! int || raw < 1 || raw > 1000000000000) return null;
    return raw;
  }

  /// Return the *exact* confirmed display amount; guard int overflows and
  /// unsupported quantities before any gift operation reaches the server.
  static int validatedGiftTotal(
      Map<String, dynamic> gift, int quantity) {
    final giftId = gift['id'];
    final price = giftUnitPrice(gift['price']);
    if (giftId is! String || giftId.trim().isEmpty ||
        gift['is_active'] != true ||
        gift['diamond_source_type'] == 'LUCKY_GIFT' ||
        ![1, 7, 17, 77, 777].contains(quantity) ||
        price == null || price > maxSafeCoinAmount ~/ quantity) {
      throw ArgumentError('Gift or total amount is not valid');
    }
    return price * quantity;
  }

  static void verifyGiftReceipt(Object? response, {
    required String giftId,
    required int quantity,
    required int expectedAmount,
  }) {
    final result = object(response);
    if (result['status'] != 'completed' ||
        result['id'] is! String ||
        !isVerifiedUuid(result['id'] as String) ||
        result['gift_id'] != giftId ||
        result['quantity'] != quantity ||
        result['amount'] != expectedAmount ||
        result['balance'] is! int ||
        (result['balance'] as int) < 0 ||
        (result['balance'] as int) > maxSafeCoinAmount) {
      throw StateError('Gift receipt does not match confirmed purchase');
    }
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

  static const int dmPageLimit = 80;

  static Map<String, dynamic> dmPageParams(
      String peer, {int? before}) {
    if (peer.trim().isEmpty || (before != null && before < 1)) {
      throw ArgumentError('Invalid direct message cursor or peer');
    }
    return {
      'p_other_user': peer,
      'p_before_id': before,
      'p_limit': dmPageLimit,
    };
  }

  /// The RPC returns descending message IDs, and every row must belong to
  /// exactly the authenticated pair. Fail closed on malformed/private data.
  static List<Map<String, dynamic>> verifyDmPage(
    Object? response, {
    required String selfId,
    required String peerId,
    int? before,
  }) {
    final page = rows(response);
    if (selfId.isEmpty || peerId.isEmpty || selfId == peerId ||
        page.length > dmPageLimit ||
        (before != null && before < 1)) {
      throw StateError('Invalid direct message page');
    }
    int? previousId;
    for (final message in page) {
      final rawId = message['id'];
      final sender = message['sender_id'];
      final recipient = message['recipient_id'];
      final body = message['body'];
      if (rawId is! num || !rawId.isFinite ||
          rawId != rawId.toInt() || rawId < 1 ||
          (previousId != null && rawId >= previousId) ||
          (before != null && rawId >= before) ||
          !((sender == selfId && recipient == peerId) ||
            (sender == peerId && recipient == selfId)) ||
          body is! String || body.isEmpty || body.length > 2000) {
        throw StateError('Unverified direct message contents');
      }
      previousId = rawId.toInt();
    }
    return page.reversed.toList(growable: false);
  }

  static int? lastIncomingDmId(
      List<Map<String, dynamic>> chronological, String peerId) {
    int? latest;
    for (final message in chronological) {
      if (message['sender_id'] == peerId) {
        final raw = message['id'];
        if (raw is! num || !raw.isFinite || raw != raw.toInt() || raw < 1) {
          throw StateError('Unverified inbound message ID');
        }
        final candidate = raw.toInt();
        if (latest == null || candidate > latest) latest = candidate;
      }
    }
    return latest;
  }

  Future<List<Map<String, dynamic>>> thread(
      String peer, {int? before}) async {
    final selfId = userId;
    if (peer == selfId) throw ArgumentError('Cannot message yourself');
    final response = await client.rpc('phase2_dm_thread',
      params: dmPageParams(peer, before: before));
    return verifyDmPage(response, selfId: selfId,
      peerId: peer, before: before);
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

  static Map<String, dynamic> dmBlockParams(
      String peer, {required bool blocked}) {
    if (peer.trim().isEmpty) {
      throw ArgumentError('A verified recipient ID is required');
    }
    return {'p_other_user': peer, 'p_block': blocked};
  }

  /// The server applies sender-scoped blocks. These RPC actions are
  /// idempotent, and are not bypassed by a locally rendered UI state.
  Future<void> setDmBlocked(String peer, {required bool blocked}) async {
    final selfId = userId;
    if (peer == selfId) throw ArgumentError('Cannot block yourself');
    final response = await client.rpc('phase2_dm_block',
      params: dmBlockParams(peer, blocked: blocked));
    if (response != true) {
      throw StateError('Server did not confirm DM blocking preference');
    }
  }

  Future<int> markDmRead(String peer, int lastId) async {
    final caller = userId;
    if (peer.isEmpty || peer == caller || lastId < 1) {
      throw ArgumentError('Invalid direct message read receipt');
    }
    final result = await client.rpc('phase2_dm_mark_read',
      params: {'p_other_user': peer, 'p_through_id': lastId});
    if (result is! num || !result.isFinite ||
        result != result.toInt() || result < 0) {
      throw StateError('Direct message read receipt not confirmed');
    }
    return result.toInt();
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
    final self = userId;
    final total = validatedGiftTotal(gift, quantity);
    if (!isVerifiedUuid(roomId) || !isVerifiedUuid(recipientId) ||
        !isVerifiedUuid(requestId) || self == recipientId) {
      throw ArgumentError('Invalid room gift recipient or request ID');
    }
    final price = giftUnitPrice(gift['price'])!;
    final giftId = gift['id'] as String;
    final result = await client.rpc('phase3_send_gift', params: {
      'p_room_id': roomId, 'p_recipient_id': recipientId,
      'p_gift_id': giftId, 'p_quantity': quantity,
      'p_expected_price': price, 'p_request_id': requestId,
    });
    verifyGiftReceipt(result, giftId: giftId,
      quantity: quantity, expectedAmount: total);
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

  static int validatedStorePrice(Map<String, dynamic> item) {
    final price = item['price'];
    final id = item['id'];
    final currency = item['currency'];
    if (item['is_active'] != true || item['is_reward'] == true ||
        id is! String || id.trim().isEmpty ||
        price is! int || price < 1 || price > maxSafeCoinAmount ||
        !['gold', 'silver'].contains(currency)) {
      throw ArgumentError('Invalid store item, currency or exact price');
    }
    return price;
  }

  static void verifyStoreReceipt(Object? response, {
    required String itemId,
    required int expectedPrice,
    required String expectedCurrency,
  }) {
    final data = object(response);
    if (data['status'] != 'completed' ||
        data['id'] is! String || !isVerifiedUuid(data['id'] as String) ||
        data['item_id'] != itemId ||
        data['price'] != expectedPrice ||
        data['currency'] != expectedCurrency) {
      throw StateError('Store purchase receipt does not match selection');
    }
  }

  Future<void> buyItem(Map<String, dynamic> item, String requestId) async {
    userId;
    final price = validatedStorePrice(item);
    if (!isVerifiedUuid(requestId)) {
      throw ArgumentError('A valid idempotency request ID is required');
    }
    final itemId = item['id'] as String;
    final currency = item['currency'] as String;
    final result = await client.rpc('phase3_purchase_store', params: {
      'p_item_id': itemId, 'p_request_id': requestId,
      'p_expected_price': price, 'p_expected_currency': currency,
    });
    verifyStoreReceipt(result, itemId: itemId,
      expectedPrice: price, expectedCurrency: currency);
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

  /// The source reports at most 100 records per page, not a whole month.
  /// Limit and offset must match the documented server contract.
  static Map<String, dynamic> hostEvidencePageParams(
      DateTime month, {int offset = 0}) {
    final start = DateTime.utc(month.year, month.month);
    final now = DateTime.now().toUtc();
    final currentMonth = DateTime.utc(now.year, now.month);
    if (start.isBefore(DateTime.utc(2025)) ||
        !start.isBefore(currentMonth) ||
        offset < 0 || offset > 50000 || offset % 100 != 0) {
      throw ArgumentError('Closed UTC host month and 100-entry page required');
    }
    return {
      'p_month': start.toIso8601String().substring(0, 10),
      'p_offset': offset,
      'p_limit': 100,
    };
  }

  static Map<String, dynamic> verifyHostPreflight(
      Object? response, {required int offset}) {
    final data = object(response);
    final entries = data['entries'];
    final total = data['totalHostEntries'];
    if (data['isDraftPreflight'] != true ||
        data['paysSalaries'] != false ||
        data['canZeroDiamonds'] != false ||
        data['hasPayrollRates'] != false ||
        data['remainingValuesAreCurrent'] != true ||
        entries is! List || entries.length > 100 ||
        total is! num || !total.isFinite ||
        total != total.toInt() || total < 0 ||
        offset > total && entries.isNotEmpty ||
        entries.length > total - offset) {
      throw StateError('Unexpected or incomplete monthly host preflight');
    }
    return data;
  }

  static Map<String, dynamic> verifyHostSnapshot(
      Object? response, {required int offset}) {
    final data = object(response);
    final items = data['items'];
    final total = data['entries'];
    final captured = data['captured'];
    if (data['isAccrualEvidenceOnly'] != true ||
        data['paysSalaries'] != false ||
        data['canZeroDiamonds'] != false ||
        data['hasPayrollRates'] != false ||
        captured is! bool || items is! List || items.length > 100 ||
        total is! num || !total.isFinite ||
        total != total.toInt() || total < 0 ||
        (captured && (data['offset'] != offset || data['limit'] != 100)) ||
        (!captured && (items.isNotEmpty || total != 0)) ||
        items.length > total - offset) {
      throw StateError('Unexpected or incomplete monthly snapshot evidence');
    }
    return data;
  }

  Future<Map<String, dynamic>> hostMonthPreflight(
      DateTime month, {int offset = 0}) async {
    userId;
    final params = hostEvidencePageParams(month, offset: offset);
    return verifyHostPreflight(await client.rpc(
      'phase5_host_month_preflight', params: params), offset: offset);
  }

  Future<Map<String, dynamic>> hostMonthSnapshot(
      DateTime month, {int offset = 0}) async {
    userId;
    final params = hostEvidencePageParams(month, offset: offset);
    return verifyHostSnapshot(await client.rpc(
      'phase5_host_month_snapshot_state', params: params), offset: offset);
  }

  /// Financial host evidence is read-only. Server explicitly forbids
  /// payroll approval, salary transfers and diamond zeroing.
  static Map<String, dynamic> hostConservationParams(
      DateTime month, {int offset = 0}) {
    final start = DateTime.utc(month.year, month.month);
    final current = DateTime.now().toUtc();
    final nowMonth = DateTime.utc(current.year, current.month);
    if (start.isBefore(DateTime.utc(2025)) || !start.isBefore(nowMonth) ||
        offset < 0 || offset > 100000 || offset % 30 != 0) {
      throw ArgumentError('A closed UTC host month and valid offset are required');
    }
    return {
      'p_month': start.toIso8601String().substring(0, 10),
      'p_offset': offset,
      'p_limit': 30,
    };
  }

  static void _checkHostAudit(Map<String, dynamic> data) {
    if (data['isReadOnly'] != true ||
        data['canApprovePayroll'] != false ||
        data['canPaySalaries'] != false ||
        data['canZeroDiamonds'] != false) {
      throw StateError('Host audit did not confirm disabled payroll actions');
    }
  }

  static Map<String, dynamic> verifyHostMonthIntegrity(Object? result) {
    final data = object(result);
    _checkHostAudit(data);
    if (data['hasEvidenceProblems'] is! bool ||
        data['snapshotCaptured'] is! bool ||
        data['hasVerifiedHistory'] is! bool) {
      throw StateError('Missing host accrual audit indicators');
    }
    return data;
  }

  Future<Map<String, dynamic>> hostMonthIntegrity(DateTime month) async {
    userId;
    final params = hostConservationParams(month);
    return verifyHostMonthIntegrity(await client.rpc(
      'phase6_host_month_evidence_integrity',
      params: {'p_month': params['p_month']}));
  }

  static Map<String, dynamic> verifyHostConservation(
      Object? result, {required int offset}) {
    final data = object(result);
    _checkHostAudit(data);
    if (data['isReadyForFinalClose'] != false ||
        data['hasPayrollRates'] != false ||
        data['hasDiscrepancies'] is! bool ||
        data['hosts'] is! List ||
        (data['hosts'] as List).length > 30 ||
        data['pageOffset'] != offset ||
        data['pageLimit'] != 30) {
      throw StateError('Invalid or unsafe diamond conservation audit');
    }
    return data;
  }

  Future<Map<String, dynamic>> hostMonthConservation(DateTime month,
      {int offset = 0}) async {
    userId;
    final params = hostConservationParams(month, offset: offset);
    final response = await client.rpc('phase7_host_month_diamond_conservation',
      params: params);
    return verifyHostConservation(response, offset: offset);
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

  /// A push opt-in records consent only. FCM installation and delivery are
  /// separate and are not enabled by this operation.
  Future<PushPreferenceState> pushStatus() async {
    final caller = userId;
    final response = await client.rpc('phase5_push_status');
    return PushPreferenceState.fromJson(response, expectedUserId: caller);
  }

  static void verifyPushConsentReceipt(Object? response, {
    required String userId,
    required bool enabled,
  }) {
    final data = object(response);
    if (data['userId'] != userId ||
        data['pushEnabled'] != enabled ||
        data['deliveryConfigured'] is! bool) {
      throw StateError('Server did not confirm device notification consent');
    }
  }

  Future<PushPreferenceState> setPushConsent(bool enabled) async {
    final caller = userId;
    final receipt = await client.rpc('phase5_push_opt_in',
      params: {'p_enabled': enabled});
    verifyPushConsentReceipt(receipt, userId: caller, enabled: enabled);
    final state = await pushStatus();
    if (state.enabled != enabled) {
      throw StateError('Device notification consent could not be verified');
    }
    return state;
  }

  static void verifyPushDeviceRemoval(Object? response, {
    required String userId,
    required String deviceId,
  }) {
    final data = object(response);
    if (data['userId'] != userId ||
        data['deviceId'] != deviceId ||
        data['registered'] != false) {
      throw StateError('Server did not confirm device revocation');
    }
  }

  Future<PushPreferenceState> unregisterPushDevice(String deviceId) async {
    final caller = userId;
    if (!RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}'
       r'[0-9a-fA-F]{12}$').hasMatch(deviceId)) {
      throw ArgumentError('Valid registered device ID required');
    }
    final receipt = await client.rpc('phase5_push_device_action', params: {
      'p_action': 'unregister',
      'p_device_id': deviceId,
      'p_token': null,
    });
    verifyPushDeviceRemoval(receipt, userId: caller, deviceId: deviceId);
    final state = await pushStatus();
    if (state.devices.any((d) => d.deviceId == deviceId)) {
      throw StateError('Device is still registered on the server');
    }
    return state;
  }

  static Map<String, dynamic> notificationFeedParams({
    int limit = notificationPageLimit,
    int? before,
  }) {
    if (limit < 1 || limit > notificationPageLimit ||
        (before != null && before < 1)) {
      throw ArgumentError('Invalid notification page');
    }
    return {'p_limit': limit, 'p_before': before};
  }

  Future<NotificationPage> notificationPage({
    int limit = notificationPageLimit,
    int? before,
  }) async {
    userId;
    final raw = await client.rpc('phase5_notification_feed',
      params: notificationFeedParams(limit: limit, before: before));
    final page = NotificationPage.fromJson(raw);
    if (page.items.length > limit) {
      throw StateError('Server exceeded notification page size');
    }
    return page;
  }

  static Map<String, dynamic> notificationMarkSelectedParams(
      List<int> rawIds) {
    final ids = rawIds.toSet().toList();
    if (ids.isEmpty || ids.length > 100 || ids.any((x) => x < 1)) {
      throw ArgumentError('Select between 1 and 100 valid notifications');
    }
    return {'p_ids': ids, 'p_all': false};
  }

  Future<int> markSelectedNotificationsRead(List<int> ids) async {
    userId;
    final result = object(await client.rpc('phase5_notification_mark',
      params: notificationMarkSelectedParams(ids)));
    final count = result['updated'];
    if (count is! num || count < 0 || !count.isFinite ||
        count.toInt() != count) {
      throw StateError('Notification read receipt not confirmed');
    }
    return count.toInt();
  }

  Future<List<Map<String,dynamic>>> notifications() async {
    userId;
    return rows(await client.rpc('phase5_notification_feed',
      params:{'p_limit':notificationPageLimit,'p_before':null}));
  }

  /// The Staging RPC rejects null p_ids even when p_all is true.
  static Map<String, dynamic> markAllNotificationParams() => {
    'p_ids': <int>[],
    'p_all': true,
  };

  Future<int> readNotifications() async {
    userId;
    final response = object(await client.rpc('phase5_notification_mark',
      params: markAllNotificationParams()));
    final changed = response['updated'];
    if (changed is! num || changed < 0) {
      throw StateError('Notification acknowledgment was not confirmed');
    }
    return changed.toInt();
  }

  static Map<String, dynamic> verifySupportList(Object? response,
      {required int offset, required bool staff}) {
    final result = object(response);
    final rows = result['rows'];
    final total = result['total'];
    if (offset < 0 || offset > 50000 ||
        rows is! List || rows.length > 50 ||
        rows.any((r) => r is! Map || r['id'] == null ||
          r['subject'] is! String || r['status'] is! String) ||
        total is! num || !total.isFinite ||
        total != total.toInt() || total < 0 ||
        (offset < total && rows.length > total - offset) ||
        (offset >= total && rows.isNotEmpty) ||
        result['canHandle'] is! bool ||
        (staff && result['canHandle'] != true)) {
      throw StateError('Malformed authenticated ticket list');
    }
    return result;
  }

  Future<Map<String, dynamic>> supportTicketPage({
    bool staff = false,
    int offset = 0,
  }) async {
    userId;
    if (offset < 0 || offset > 50000 || offset % 50 != 0) {
      throw ArgumentError('Invalid ticket page offset');
    }
    final response = await client.rpc('phase5_support_list',
      params: {'p_scope': staff ? 'all' : 'mine',
               'p_offset': offset, 'p_limit': 50});
    return verifySupportList(response, offset: offset, staff: staff);
  }

  Future<List<Map<String,dynamic>>> supportTickets() async {
    return rows(await supportTicketPage());
  }

  static Map<String, dynamic> supportThreadParams(
      String ticketId, {int offset = 0}) {
    if (ticketId.isEmpty || offset < 0 || offset > 50000 ||
        offset % 50 != 0) {
      throw ArgumentError('Invalid support thread page');
    }
    return {'p_ticket_id': ticketId, 'p_offset': offset, 'p_limit': 50};
  }

  /// Strictly verify the server envelope before displaying private messages.
  static Map<String, dynamic> verifySupportThread(
      Object? response, {required String ticketId, required int offset}) {
    final result = object(response);
    final ticket = result['ticket'];
    final messages = result['messages'];
    final total = result['total'];
    if (ticket is! Map || ticket['id']?.toString() != ticketId ||
        messages is! List || messages.length > 50 ||
        messages.any((row) => row is! Map || row['id'] is! num ||
          row['body'] is! String || row['author_id'] == null) ||
        total is! num || !total.isFinite ||
        total != total.toInt() || total < 0 ||
        (offset < total && messages.length > total - offset) ||
        (offset >= total && messages.isNotEmpty) ||
        result['canHandle'] is! bool) {
      throw StateError('Malformed authenticated support thread');
    }
    return result;
  }

  Future<Map<String, dynamic>> supportThread(
      String ticketId, {int offset = 0}) async {
    userId;
    final params = supportThreadParams(ticketId, offset: offset);
    final response = await client.rpc(
      'phase5_support_thread_page', params: params);
    return verifySupportThread(response, ticketId: ticketId, offset: offset);
  }

  Future<void> supportReply({
    required String ticketId,
    required String message,
    required String requestId,
  }) async {
    userId;
    final clean = message.trim();
    if (ticketId.isEmpty || clean.length < 2 || clean.length > 2500) {
      throw ArgumentError('Reply must be between 2 and 2500 characters');
    }
    final result = object(await client.rpc('phase5_support_action',
      params: {
        'p_action': 'reply',
        'p_data': {'ticket_id': ticketId, 'message': clean},
        'p_request_id': requestId,
      }));
    if (result['id']?.toString() != ticketId ||
        result['action'] != 'reply' ||
        result['status'] != 'completed') {
      throw StateError('Ticket reply not confirmed by server');
    }
  }

  Future<void> supportChangeStatus({
    required String ticketId,
    required String status,
    required String requestId,
  }) async {
    userId;
    if (ticketId.isEmpty ||
        !['open','in_progress','resolved','closed'].contains(status)) {
      throw ArgumentError('Invalid ticket status change');
    }
    final result = object(await client.rpc('phase5_support_action',
      params: {
        'p_action': 'status',
        'p_data': {'ticket_id': ticketId, 'status': status},
        'p_request_id': requestId,
      }));
    if (result['id']?.toString() != ticketId ||
        result['action'] != 'status' ||
        result['status'] != 'completed') {
      throw StateError('Ticket status change not confirmed by server');
    }
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

  static Map<String, dynamic> verifySupportStaffPage(
      Object? response, {required int offset}) {
    final result = object(response);
    final staff = result['rows'];
    final total = result['total'];
    if (offset < 0 || offset > 50000 ||
        staff is! List || staff.length > 50 ||
        staff.any((r) => r is! Map || r['user_id'] == null ||
          r['enabled'] is! bool) ||
        total is! num || !total.isFinite ||
        total != total.toInt() || total < 0 ||
        (offset < total && staff.length > total - offset) ||
        (offset >= total && staff.isNotEmpty)) {
      throw StateError('Malformed owner-only support staff list');
    }
    return result;
  }

  Future<Map<String, dynamic>> supportStaffPage({int offset = 0}) async {
    userId;
    if (offset < 0 || offset > 50000 || offset % 50 != 0) {
      throw ArgumentError('Invalid support staff page');
    }
    final response=await client.rpc('phase5_support_staff_list',
      params:{'p_offset':offset,'p_limit':50});
    return verifySupportStaffPage(response, offset: offset);
  }

  Future<List<Map<String,dynamic>>> supportStaff() async {
    return rows(await supportStaffPage());
  }

  Future<void> manageSupportStaff({
    required String targetUserId,
    required bool enable,
    required String requestId,
  }) async {
    userId;
    if (targetUserId.isEmpty || targetUserId == userId) {
      throw ArgumentError('A separate confirmed user is required');
    }
    final action=enable?'staff_grant':'staff_revoke';
    final result=object(await client.rpc('phase5_support_action',params:{
      'p_action':action,
      'p_data':{'user_id':targetUserId},
      'p_request_id':requestId,
    }));
    if (result['action']!=action ||
        result['id']?.toString()!=targetUserId ||
        result['status']!='completed') {
      throw StateError('Support staff access change not confirmed');
    }
  }

  Future<List<Map<String, dynamic>>> adminBanners() async {
    userId;
    final result=object(await client.rpc('phase6_admin_banner_list',
      params:{'p_offset':0,'p_limit':60}));
    return rows(result);
  }

  Future<void> saveOwnerBanner({
    required String action,
    required Map<String,dynamic> data,
    required String requestId,
    String? bannerId,
  }) async {
    userId;
    if (!['create','update'].contains(action) ||
        (action == 'create' && bannerId != null) ||
        (action == 'update' && (bannerId == null || bannerId.isEmpty))) {
      throw ArgumentError('Invalid banner action');
    }
    final title=data['title']?.toString().trim() ?? '';
    final path=data['image_path']?.toString() ?? '';
    if (title.isEmpty || title.length > 120 ||
        !RegExp(r'^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$').hasMatch(path) ||
        !['draft','published','archived'].contains(data['status'])) {
      throw ArgumentError('Invalid banner details');
    }
    final result=object(await client.rpc('phase6_admin_banner_action',
      params:{
        'p_action':action,'p_id':bannerId,
        'p_data':data,'p_request_id':requestId,
      }));
    if (result['saved']!=true ||
        result['status']!=data['status'] ||
        result['id'] is! String ||
        (bannerId!=null && result['id']!=bannerId)) {
      throw StateError('Banner change was not confirmed');
    }
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

  static bool isVerifiedUuid(String input) =>
      RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}'
        r'[0-9a-fA-F]{12}$').hasMatch(input);

  /// Owner/authorized main-partner management evidence. The server response
  /// is strictly read-only; never infer authorization from role labels.
  static const adminManagementKinds = <String>[
    'staff', 'host_agencies', 'recharge_agencies',
    'registrations', 'agency_transfers', 'audit',
  ];

  static Map<String, dynamic> adminManagementParams(
      String kind, {int offset = 0}) {
    if (!adminManagementKinds.contains(kind) ||
        offset < 0 || offset > 49980 || offset % 30 != 0) {
      throw ArgumentError('Invalid management evidence page');
    }
    return {
      'p_kind': kind,
      'p_offset': offset,
      'p_limit': 30,
    };
  }

  static Map<String, dynamic> verifyAdminManagementPage(
      Object? response, {
      required String kind,
      required int offset,
  }) {
    final data = object(response);
    final records = data['rows'];
    final count = data['total'];
    final time = data['asOf'];
    if (!adminManagementKinds.contains(kind) ||
        data['kind'] != kind ||
        data['readOnly'] != true ||
        data['offset'] != offset ||
        data['limit'] != 30 ||
        records is! List || records.length > 30 ||
        count is! num || !count.isFinite ||
        count != count.toInt() || count < 0 ||
        (offset < count && records.length > count - offset) ||
        (offset >= count && records.isNotEmpty) ||
        time is! String || DateTime.tryParse(time) == null) {
      throw StateError('Invalid authenticated management evidence');
    }
    final ids = <String>{};
    for (final row in records) {
      if (row is! Map) {
        throw StateError('Unexpected management record');
      }
      final id = kind == 'staff' ? row['user_id'] : row['id'];
      final idString = id?.toString();
      if (idString == null || idString.isEmpty ||
          !ids.add(idString) ||
          (kind == 'staff' && (row['role'] is! String ||
            row['permissions'] is! List)) ||
          ((kind == 'host_agencies' || kind == 'recharge_agencies') &&
            (row['kind'] != (kind == 'host_agencies' ? 'host' : 'recharge') ||
              row['name'] is! String || row['is_active'] is! bool)) ||
          (kind == 'registrations' &&
            (row['name'] is! String || row['status'] is! String)) ||
          (kind == 'agency_transfers' && row['status'] is! String) ||
          (kind == 'audit' && row['action'] is! String)) {
        throw StateError('Unverified management record');
      }
    }
    return data;
  }

  Future<Map<String, dynamic>> adminManagementPage(
      String kind, {int offset = 0}) async {
    userId;
    final params = adminManagementParams(kind, offset: offset);
    final response = await client.rpc('phase6_admin_management_page',
      params: params);
    return verifyAdminManagementPage(response,
      kind: kind, offset: offset);
  }

  static Map<String, dynamic> adminRoomDirectoryParams({
    String search = '',
    int offset = 0,
  }) {
    final query = search.trim();
    if (query.length > 60 || offset < 0 || offset > 99990 ||
        offset % 30 != 0) {
      throw ArgumentError('Invalid admin room directory page');
    }
    return {
      'p_kind': 'rooms',
      'p_query': query,
      'p_offset': offset,
      'p_limit': 30,
    };
  }

  static Map<String, dynamic> verifyAdminRoomDirectory(
      Object? response, {required int offset}) {
    final data = object(response);
    final items = data['rows'];
    final total = data['total'];
    if (data['kind'] != 'rooms' || data['readOnly'] != true ||
        data['offset'] != offset || data['limit'] != 30 ||
        items is! List || items.length > 30 ||
        total is! num || !total.isFinite ||
        total != total.toInt() || total < 0 ||
        (offset < total && items.length > total - offset) ||
        (offset >= total && items.isNotEmpty) ||
        items.any((x) => x is! Map ||
          x['id'] is! String || !isVerifiedUuid(x['id'] as String) ||
          x['owner_id'] is! String ||
          !isVerifiedUuid(x['owner_id'] as String) ||
          x['title'] is! String || x['title'].toString().isEmpty)) {
      throw StateError('Unverified admin room directory');
    }
    return data;
  }

  Future<Map<String, dynamic>> adminRoomDirectory({
    String search = '',
    int offset = 0,
  }) async {
    userId;
    final params = adminRoomDirectoryParams(search: search, offset: offset);
    return verifyAdminRoomDirectory(
      await client.rpc('phase6_admin_directory', params: params),
      offset: offset,
    );
  }

  static Map<String, dynamic> verifyAdminRoomState(
      Object? response, {required String roomId}) {
    final data = object(response);
    final members = data['members'];
    final banned = data['banned'];
    if (!isVerifiedUuid(roomId) || data['roomId'] != roomId ||
        data['readOnly'] != true ||
        data['roomOwnerId'] is! String ||
        !isVerifiedUuid(data['roomOwnerId'] as String) ||
        members is! List || members.length > 200 ||
        banned is! List || banned.length > 200 ||
        members.any((x) => x is! Map ||
          x['user_id'] is! String ||
          !isVerifiedUuid(x['user_id'] as String)) ||
        banned.any((x) => x is! Map ||
          x['user_id'] is! String ||
          !isVerifiedUuid(x['user_id'] as String))) {
      throw StateError('Unverified admin room moderation state');
    }
    final memberIds = <String>{};
    for (final row in members) {
      if (!memberIds.add((row as Map)['user_id'] as String)) {
        throw StateError('Duplicate room member in server response');
      }
    }
    final bannedIds = <String>{};
    for (final row in banned) {
      if (!bannedIds.add((row as Map)['user_id'] as String)) {
        throw StateError('Duplicate room ban in server response');
      }
    }
    return data;
  }

  Future<Map<String, dynamic>> adminRoomState(String roomId) async {
    userId;
    if (!isVerifiedUuid(roomId)) throw ArgumentError('Valid room ID required');
    return verifyAdminRoomState(await client.rpc('phase6_admin_room_state',
      params: {'p_room_id': roomId}), roomId: roomId);
  }

  static Map<String, dynamic> adminRoomActionParams({
    required String roomId,
    required String targetId,
    required String action,
    required String reason,
    required String requestId,
  }) {
    final clean = reason.trim();
    if (!isVerifiedUuid(roomId) || !isVerifiedUuid(targetId) ||
        !isVerifiedUuid(requestId) ||
        !['ban', 'unban'].contains(action) ||
        clean.length < 10 || clean.length > 300 ||
        roomId == targetId) {
      throw ArgumentError('Documented and verified room action required');
    }
    return {
      'p_room_id': roomId,
      'p_target': targetId,
      'p_action': action,
      'p_reason': clean,
      'p_request_id': requestId,
    };
  }

  static void verifyAdminRoomAction(Object? response, {
    required String roomId,
    required String targetId,
    required String action,
    required String requestId,
  }) {
    final data = object(response);
    if (data['roomId'] != roomId ||
        data['targetId'] != targetId ||
        data['action'] != action ||
        data['requestId'] != requestId ||
        data['scope'] != 'room_only' ||
        data['success'] != true) {
      throw StateError('Admin room action not confirmed by server');
    }
  }

  Future<void> adminRoomAction({
    required String roomId,
    required String targetId,
    required String action,
    required String reason,
    required String requestId,
  }) async {
    final actor = userId;
    if (targetId == actor) throw ArgumentError('Self-moderation forbidden');
    final params = adminRoomActionParams(
      roomId: roomId, targetId: targetId, action: action,
      reason: reason, requestId: requestId,
    );
    verifyAdminRoomAction(
      await client.rpc('phase6_admin_room_action', params: params),
      roomId: roomId, targetId: targetId,
      action: action, requestId: requestId,
    );
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
