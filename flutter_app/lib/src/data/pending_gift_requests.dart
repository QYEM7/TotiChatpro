import 'package:shared_preferences/shared_preferences.dart';

/// Stores *only* request identities. This does not store wallet balances,
/// payment details, access tokens or any authentication material.
abstract class PendingGiftStore {
  Future<String?> get(String key);
  Future<void> put(String key, String requestId);
  Future<void> remove(String key);
}

class DevicePendingGiftStore implements PendingGiftStore {
  DevicePendingGiftStore() : _preferences = SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> get(String key) => _preferences.getString(key);

  @override
  Future<void> put(String key, String requestId) =>
      _preferences.setString(key, requestId);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// A gift's stable identity is preserved *before* contacting the server.
///
/// Retrying after a network timeout, dismissing the sheet, app restart or
/// changing the selection must not create a second debit for the same
/// still-unconfirmed payload. The server is authoritative and enforces
/// actor-scoped idempotency, price, membership, and ledger consistency.
///
/// A confirmed gift clears its pending key, so intentional repeated gifts
/// with identical details can use a new operation identifier.
class PendingGiftRequests {
  PendingGiftRequests({
    required PendingGiftStore storage,
    required String Function() newRequestId,
  })  : _storage = storage,
        _newRequestId = newRequestId;

  final PendingGiftStore _storage;
  final String Function() _newRequestId;

  // Share an in-process lock between reopened GiftSheets and distinct store
  // instances. Without it, two calls can both observe a missing key and
  // create different IDs before either asynchronous write completes.
  // The backend remains authoritative; this is only a local retry guard.
  static final Map<String, Future<String>> _inFlightAcquires =
      <String, Future<String>>{};

  static String payloadKey({
    required String senderId,
    required String roomId,
    required String recipientId,
    required String giftId,
    required int quantity,
  }) {
    if (senderId.isEmpty ||
        roomId.isEmpty ||
        recipientId.isEmpty ||
        giftId.isEmpty ||
        !const [1, 7, 17, 77, 777].contains(quantity)) {
      throw ArgumentError('Invalid pending gift payload');
    }
    return [
      'totichat-staging-pending-gift-v1',
      senderId,
      roomId,
      recipientId,
      giftId,
      '$quantity',
    ].map(Uri.encodeComponent).join(':');
  }

  Future<String> acquire(String key) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key');
    final pending = _inFlightAcquires[key];
    if (pending != null) return pending;

    final current = _readOrPersist(key);
    _inFlightAcquires[key] = current;
    // Both success and failure release the lock; an unsuccessful disk write
    // must never leave a permanently blocked gift payload.
    void release() {
      if (identical(_inFlightAcquires[key], current)) {
        _inFlightAcquires.remove(key);
      }
    }
    current.then((_) => release(), onError: (Object _, StackTrace _) {
      release();
    });
    return current;
  }

  Future<String> _readOrPersist(String key) async {
    final existing = await _storage.get(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _newRequestId();
    if (created.isEmpty) throw StateError('Missing gift operation identity');
    // Fail closed if disk persistence is unavailable. Do not debit using
    // an ID that could be lost between a successful debit and retry.
    await _storage.put(key, created);
    return created;
  }

  Future<void> confirmed(String key) => _storage.remove(key);
}
