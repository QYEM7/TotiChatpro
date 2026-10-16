import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  test('social search uses only server-confirmed user_id', () {
    final identity = TotiChatServices.verifiedSocialUserId({
      'user_id': '00000000-0000-4000-8000-000000000123',
      'display_name': 'Test user',
    });
    expect(identity, '00000000-0000-4000-8000-000000000123');
    expect(
      () => TotiChatServices.verifiedSocialUserId({
        'id': '00000000-0000-4000-8000-000000000123',
      }),
      throwsA(isA<StateError>()),
    );
    expect(
      () => TotiChatServices.verifiedSocialUserId({'user_id': ''}),
      throwsA(isA<StateError>()),
    );
  });

  test('client pages respect Staging RPC hard limits', () {
    expect(TotiChatServices.socialSearchLimit, 20);
    expect(TotiChatServices.notificationPageLimit, 50);
  });

  test('notification mark-all uses an explicit empty list, never null', () {
    final params = TotiChatServices.markAllNotificationParams();
    expect(params['p_all'], isTrue);
    expect(params['p_ids'], isA<List<int>>());
    expect(params['p_ids'], isEmpty);
    expect(params['p_ids'], isNotNull);
  });

  test('support lists never substitute bad server list envelopes', () {
    final rows = TotiChatServices.rows({
      'rows': [
        {'id': 'verified-server-id', 'status': 'open'}
      ],
      'total': 1,
      'canHandle': false,
    });
    expect(rows.single['id'], 'verified-server-id');
    expect(() => TotiChatServices.rows({'rows': null}),
      throwsA(isA<StateError>()));
    expect(() => TotiChatServices.object({'ticket': 'not a map'}),
      returnsNormally);
  });

  test('mocked finance or customer identities are never substituted', () {
    expect(() => TotiChatServices.object(null),
      throwsA(isA<StateError>()));
    expect(() => TotiChatServices.rows({'items': 'not a list'}),
      throwsA(isA<StateError>()));
  });
}
