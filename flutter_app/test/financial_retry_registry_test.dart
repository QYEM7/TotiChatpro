import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/features/economy/financial_retry_registry.dart';

class _UnboundClient extends Fake implements SupabaseClient {}

void main() {
  test('an ambiguous payment retry reuses the exact original id', () {
    final client = Object();
    final journal = FinancialRetryRegistry.forClient(client);
    var minted = 0;
    String nextId() => 'request-${++minted}';

    final first = journal.reserve(
      scope: 'gift:user-a', signature: 'room|recipient|item|7|100',
      newRequestId: nextId,
    );
    // Simulates dismissing and rebuilding the gift sheet.
    final reopened = FinancialRetryRegistry.forClient(client);
    final retry = reopened.reserve(
      scope: 'gift:user-a', signature: 'room|recipient|item|7|100',
      newRequestId: nextId,
    );

    expect(identical(journal, reopened), isTrue);
    expect(retry.requestId, first.requestId);
    expect(minted, 1, reason: 'Do not mint a new debit on uncertain retry');

    reopened.confirm(scope: 'gift:user-a', requestId: retry.requestId);
    expect(journal.pending('gift:user-a'), isNull);
    final newPurchase = journal.reserve(
      scope: 'gift:user-a', signature: 'room|recipient|item|7|100',
      newRequestId: nextId,
    );
    expect(newPurchase.requestId, isNot(first.requestId));
    expect(minted, 2);
  });

  test('unconfirmed debit prevents a different recipient or price', () {
    final journal = FinancialRetryRegistry.forClient(Object());
    journal.reserve(
      scope: 'gift:user-a', signature: 'room|first|gift|1|100',
      newRequestId: () => 'original-id',
    );

    var secondIdMinted = false;
    expect(() => journal.reserve(
      scope: 'gift:user-a', signature: 'room|second|gift|1|100',
      newRequestId: () {
        secondIdMinted = true;
        return 'duplicate-id';
      },
    ), throwsStateError);
    expect(secondIdMinted, isFalse);
    expect(journal.pending('gift:user-a')?.requestId, 'original-id');
  });

  test('wrong receipt cannot clear the pending purchase', () {
    final journal = FinancialRetryRegistry.forClient(Object());
    journal.reserve(
      scope: 'store:user-a', signature: 'frame|200|gold',
      newRequestId: () => 'request-x',
    );

    expect(() => journal.confirm(
      scope: 'store:user-a', requestId: 'other-request',
    ), throwsStateError);
    expect(journal.pending('store:user-a')?.requestId, 'request-x');
    journal.confirm(scope: 'store:user-a', requestId: 'request-x');
    expect(journal.pending('store:user-a'), isNull);
  });

  test('gift, store, accounts and clients cannot inherit each other IDs', () {
    final client = Object();
    final journal = FinancialRetryRegistry.forClient(client);
    journal.reserve(
      scope: 'gift:user-a', signature: 'rose', newRequestId: () => 'gift-a',
    );
    journal.reserve(
      scope: 'gift:user-b', signature: 'rose', newRequestId: () => 'gift-b',
    );
    journal.reserve(
      scope: 'store:user-a', signature: 'rose', newRequestId: () => 'store-a',
    );
    expect(journal.pending('gift:user-a')?.requestId, 'gift-a');
    expect(journal.pending('gift:user-b')?.requestId, 'gift-b');
    expect(journal.pending('store:user-a')?.requestId, 'store-a');
    expect(FinancialRetryRegistry.forClient(Object()).pending('gift:user-a'),
      isNull);
  });

  test('fake widget clients use a non-authoritative local test scope', () {
    final client = _UnboundClient();
    expect(FinancialRetryRegistry.scopeFor(client, 'gift'),
      'gift:not-signed-in');
    expect(FinancialRetryRegistry.scopeFor(client, 'store'),
      'store:not-signed-in');
    expect(() => FinancialRetryRegistry.scopeFor(client, 'unknown'),
      throwsArgumentError);
  });

  test('real gift and store UI both retain unresolved receipts', () {
    final gift = File('lib/features/economy/gift_sheet.dart').readAsStringSync();
    final store = File('lib/features/economy/economy_screen.dart')
      .readAsStringSync();
    for (final source in [gift, store]) {
      expect(source, contains('FinancialRetryRegistry.forClient('));
      expect(source, contains('_retry.reserve('));
      expect(source, contains('_retry.confirm('));
    }
    expect(gift, contains('requestId:pending.requestId'));
    expect(store, contains('buyItem(item,pending.requestId)'));
  });
}
