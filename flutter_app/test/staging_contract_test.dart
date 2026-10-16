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

  test('mocked finance or customer identities are never substituted', () {
    expect(() => TotiChatServices.object(null),
      throwsA(isA<StateError>()));
    expect(() => TotiChatServices.rows({'items': 'not a list'}),
      throwsA(isA<StateError>()));
  });
}
