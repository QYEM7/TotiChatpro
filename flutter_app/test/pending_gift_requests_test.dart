import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/data/pending_gift_requests.dart';

class MemoryGiftStore implements PendingGiftStore {
  final Map<String, String> values = {};
  bool rejectWrites = false;
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> put(String key, String requestId) async {
    if (rejectWrites) throw StateError('Disk unavailable');
    values[key] = requestId;
  }
  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class BlockingGiftStore implements PendingGiftStore {
  final Map<String, String> values = {};
  final Completer<void> unlockReads = Completer<void>();
  int reads = 0;
  int writes = 0;
  bool failWrites = false;

  @override
  Future<String?> get(String key) async {
    reads++;
    await unlockReads.future;
    return values[key];
  }

  @override
  Future<void> put(String key, String requestId) async {
    writes++;
    if (failWrites) throw StateError('Disk unavailable');
    values[key] = requestId;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  const alice = 'alice-uuid';
  const room = 'room-uuid';
  const bob = 'bob-uuid';
  const gift = 'gift-id';
  String key({
    String sender = alice,
    String recipient = bob,
    String giftId = gift,
    int quantity = 1,
  }) =>
      PendingGiftRequests.payloadKey(
        senderId: sender,
        roomId: room,
        recipientId: recipient,
        giftId: giftId,
        quantity: quantity,
      );

  test('same operation is replayed safely across sheet/registry restart', () async {
    final disk = MemoryGiftStore();
    var count = 0;
    String nextId() => 'id-${++count}';
    final first = PendingGiftRequests(storage: disk, newRequestId: nextId);
    final one = await first.acquire(key());
    final anotherSheet = PendingGiftRequests(storage: disk, newRequestId: nextId);
    expect(await anotherSheet.acquire(key()), one);
    expect(count, 1);
    expect(disk.values.length, 1);
  });

  test('confirmed operation is cleared and next intentional send gets a new id', () async {
    final disk = MemoryGiftStore();
    var count = 0;
    final requests = PendingGiftRequests(
      storage: disk,
      newRequestId: () => 'id-${++count}',
    );
    final payload = key();
    expect(await requests.acquire(payload), 'id-1');
    await requests.confirmed(payload);
    expect(await requests.acquire(payload), 'id-2');
  });

  test('different recipients, accounts, gifts or quantities never share a key', () {
    final unique = {
      key(),
      key(sender: 'another-actor'),
      key(recipient: 'another-recipient'),
      key(giftId: 'another-gift'),
      key(quantity: 7),
    };
    expect(unique.length, 5);
  });

  test('no financial send can be allowed if request id cannot persist', () async {
    final disk = MemoryGiftStore()..rejectWrites = true;
    final requests = PendingGiftRequests(
      storage: disk,
      newRequestId: () => 'new-operation',
    );
    await expectLater(requests.acquire(key()), throwsStateError);
    expect(disk.values, isEmpty);
  });

  test('invalid quantities cannot create pending financial operations', () {
    expect(() => key(quantity: 2), throwsArgumentError);
    expect(() => key(sender: ''), throwsArgumentError);
  });
  test('concurrent sheets persist only one id for the identical gift', () async {
    final disk = BlockingGiftStore();
    var generated = 0;
    String newId() => 'operation-${++generated}';
    final sheetA = PendingGiftRequests(storage: disk, newRequestId: newId);
    final sheetB = PendingGiftRequests(storage: disk, newRequestId: newId);
    final original = sheetA.acquire(key());
    final concurrent = sheetB.acquire(key());

    // A second sheet must wait on the exact pending read/identity, rather
    // than race a separate storage read and overwrite the durable request.
    expect(disk.reads, 1);
    disk.unlockReads.complete();
    final ids = await Future.wait([original, concurrent]);
    expect(ids, ['operation-1', 'operation-1']);
    expect(disk.writes, 1);
    expect(generated, 1);
    expect(disk.values[key()], 'operation-1');
  });

  test('failed concurrent persistence releases lock and prevents sending', () async {
    final disk = BlockingGiftStore()..failWrites = true;
    var generated = 0;
    final sheetA = PendingGiftRequests(
      storage: disk,
      newRequestId: () => 'operation-${++generated}',
    );
    final sheetB = PendingGiftRequests(
      storage: disk,
      newRequestId: () => 'operation-${++generated}',
    );
    final first = sheetA.acquire(key());
    final second = sheetB.acquire(key());
    disk.unlockReads.complete();
    await expectLater(first, throwsStateError);
    await expectLater(second, throwsStateError);
    expect(disk.values, isEmpty);
    expect(disk.writes, 1);

    disk.failWrites = false;
    expect(await sheetA.acquire(key()), 'operation-2');
    expect(disk.values[key()], 'operation-2');
  });

}
