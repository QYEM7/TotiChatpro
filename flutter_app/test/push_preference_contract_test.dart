import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/push_preference_models.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';
  const otherId = '22222222-2222-4222-8222-222222222222';
  const deviceId = '33333333-3333-4333-8333-333333333333';

  final registeredDevice = <String, dynamic>{
    'device_id': deviceId,
    'platform': 'android',
    'provider': 'fcm',
    'registered_at': '2026-10-14T10:00:00+00:00',
    'refreshed_at': '2026-10-17T10:00:00+00:00',
  };

  test('verified push status reports consent separately from FCM delivery', () {
    final status = PushPreferenceState.fromJson({
      'userId': userId,
      'pushEnabled': true,
      'deliveryConfigured': false,
      'devices': [registeredDevice],
    }, expectedUserId: userId);
    expect(status.userId, userId);
    expect(status.enabled, isTrue);
    expect(status.deliveryConfigured, isFalse);
    expect(status.devices.length, 1);
    expect(status.devices.single.platform, 'android');
    expect(status.devices.single.provider, 'fcm');
    expect(status.devices.single.deviceId, deviceId);
  });

  test('opted-out status returns no devices without fabricated permissions', () {
    final status = PushPreferenceState.fromJson({
      'userId': userId,
      'pushEnabled': false,
      'deliveryConfigured': false,
      'devices': <Object>[],
    }, expectedUserId: userId);
    expect(status.enabled, isFalse);
    expect(status.devices, isEmpty);
  });

  test('device notifications reject cross-account and malformed status', () {
    final valid = {
      'userId': userId,
      'pushEnabled': true,
      'deliveryConfigured': false,
      'devices': [registeredDevice],
    };
    for (final invalid in [
      {...valid, 'userId': otherId},
      {...valid, 'pushEnabled': null},
      {...valid, 'pushEnabled': 'true'},
      {...valid, 'deliveryConfigured': null},
      {...valid, 'devices': null},
      {...valid, 'devices': [registeredDevice, registeredDevice]},
      {...valid, 'devices': List.filled(6, registeredDevice)},
      {...valid, 'devices': [{'device_id': deviceId}]},
      {...valid, 'devices': [{...registeredDevice, 'device_id': 'bad-id'}]},
      {...valid, 'devices': [{...registeredDevice, 'registered_at': 'invalid'}]},
    ]) {
      expect(() => PushPreferenceState.fromJson(
        invalid, expectedUserId: userId),
        throwsA(isA<FormatException>()));
    }
  });

  test('explicit push-consent receipt must match same account and action', () {
    final receipt = {
      'userId': userId,
      'pushEnabled': true,
      'deliveryConfigured': false,
      'message': 'FCM delivery is not deployed',
    };
    expect(() => TotiChatServices.verifyPushConsentReceipt(
      receipt, userId: userId, enabled: true), returnsNormally);
    for (final bad in [
      {...receipt, 'userId': otherId},
      {...receipt, 'pushEnabled': false},
      {...receipt, 'deliveryConfigured': null},
    ]) {
      expect(() => TotiChatServices.verifyPushConsentReceipt(
        bad, userId: userId, enabled: true),
        throwsA(isA<StateError>()));
    }
  });

  test('device revocation receipt is verified before showing success', () {
    final receipt = {
      'userId': userId,
      'deviceId': deviceId,
      'registered': false,
    };
    expect(() => TotiChatServices.verifyPushDeviceRemoval(
      receipt, userId: userId, deviceId: deviceId), returnsNormally);
    for (final bad in [
      {...receipt, 'userId': otherId},
      {...receipt, 'deviceId': otherId},
      {...receipt, 'registered': true},
      {...receipt, 'registered': null},
    ]) {
      expect(() => TotiChatServices.verifyPushDeviceRemoval(
        bad, userId: userId, deviceId: deviceId),
        throwsA(isA<StateError>()));
    }
  });
}
