import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  const giftId = 'rose_red';
  const transactionId = '33333333-3333-4333-8333-333333333333';
  const receipt = {
    'id': transactionId,
    'status': 'completed',
    'gift_id': giftId,
    'quantity': 7,
    'amount': 700,
    'balance': 300,
  };

  final gift = <String, dynamic>{
    'id': giftId,
    'name': 'Real test catalog item',
    'price': 100,
    'is_active': true,
    'diamond_source_type': 'STANDARD',
  };

  test('financial gifts use only exact integer prices and approved counts', () {
    expect(TotiChatServices.giftUnitPrice(100), 100);
    for (final invalid in [null, 0, -1, 0.5, 100.99, '100',
      1000000000001, double.infinity, double.nan]) {
      expect(TotiChatServices.giftUnitPrice(invalid), isNull,
        reason: 'Do not round the gift price $invalid');
    }
    expect(TotiChatServices.validatedGiftTotal(gift, 1), 100);
    expect(TotiChatServices.validatedGiftTotal(gift, 7), 700);
    expect(TotiChatServices.validatedGiftTotal(gift, 17), 1700);
    expect(TotiChatServices.validatedGiftTotal(gift, 77), 7700);
    expect(TotiChatServices.validatedGiftTotal(gift, 777), 77700);
    for (final invalidQuantity in [0, 2, 8, -1, 778, 1000]) {
      expect(() => TotiChatServices.validatedGiftTotal(
        gift, invalidQuantity), throwsArgumentError);
    }
    for (final changed in [
      <String,dynamic>{...gift, 'is_active': false},
      <String,dynamic>{...gift, 'diamond_source_type': 'LUCKY_GIFT'},
      <String,dynamic>{...gift, 'price': 100.1},
      <String,dynamic>{...gift, 'price': -1},
      <String,dynamic>{...gift, 'id': ''},
      <String,dynamic>{...gift, 'price': 1000000000001},
    ]) {
      expect(() => TotiChatServices.validatedGiftTotal(changed, 7),
        throwsArgumentError);
    }
  });

  test('gift confirmation must match amount, identity, count and balance', () {
    expect(() => TotiChatServices.verifyGiftReceipt(
      receipt, giftId: giftId, quantity: 7, expectedAmount: 700),
      returnsNormally);
    for (final invalid in [
      {...receipt, 'id': 'invalid'},
      {...receipt, 'id': null},
      {...receipt, 'status': 'queued'},
      {...receipt, 'gift_id': 'another_gift'},
      {...receipt, 'quantity': 1},
      {...receipt, 'amount': 699},
      {...receipt, 'amount': 700.2},
      {...receipt, 'balance': -1},
      {...receipt, 'balance': null},
      {...receipt, 'balance': 0.5},
      {...receipt, 'balance': TotiChatServices.maxSafeCoinAmount + 1},
    ]) {
      expect(() => TotiChatServices.verifyGiftReceipt(invalid,
        giftId: giftId, quantity: 7, expectedAmount: 700),
        throwsA(isA<StateError>()),
        reason: 'Mismatched financial receipt must not show success');
    }
  });

  final item = <String, dynamic>{
    'id': 'vip_level_01',
    'name': 'VIP level 1',
    'is_active': true,
    'is_reward': false,
    'price': 125,
    'currency': 'gold',
  };

  test('store item price is integer and only server-approved currency', () {
    expect(TotiChatServices.validatedStorePrice(item), 125);
    expect(TotiChatServices.validatedStorePrice({
      ...item, 'currency': 'silver',
    }), 125);
    for (final invalid in [
      {...item, 'is_active': false},
      {...item, 'is_reward': true},
      {...item, 'price': 0},
      {...item, 'price': -10},
      {...item, 'price': 1.5},
      {...item, 'price': '125'},
      {...item, 'price': TotiChatServices.maxSafeCoinAmount + 1},
      {...item, 'currency': 'diamonds'},
      {...item, 'currency': null},
      {...item, 'id': ''},
    ]) {
      expect(() => TotiChatServices.validatedStorePrice(invalid),
        throwsArgumentError);
    }
  });

  test('store receipt must exactly match item, amount and currency', () {
    final storeReceipt = {
      'id': transactionId,
      'status': 'completed',
      'item_id': item['id'],
      'price': 125,
      'currency': 'gold',
      'expires_at': null,
    };
    expect(() => TotiChatServices.verifyStoreReceipt(storeReceipt,
      itemId: 'vip_level_01', expectedPrice: 125,
      expectedCurrency: 'gold'), returnsNormally);
    for (final invalid in [
      {...storeReceipt, 'id': null},
      {...storeReceipt, 'id': 'not-a-uuid'},
      {...storeReceipt, 'status': 'pending'},
      {...storeReceipt, 'item_id': 'other'},
      {...storeReceipt, 'price': 126},
      {...storeReceipt, 'price': 125.5},
      {...storeReceipt, 'currency': 'silver'},
    ]) {
      expect(() => TotiChatServices.verifyStoreReceipt(invalid,
        itemId: 'vip_level_01', expectedPrice: 125,
        expectedCurrency: 'gold'), throwsA(isA<StateError>()));
    }
  });
}
