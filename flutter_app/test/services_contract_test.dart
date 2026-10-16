import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  test('financial idempotency keys are unique UUIDs', () {
    final first = TotiChatServices.requestId();
    final second = TotiChatServices.requestId();
    expect(first, isNot(second));
    expect(first, matches(RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
    )));
  });

  test('server list parsing accepts actual RPC rows envelopes', () {
    final rows = TotiChatServices.rows({
      'rows': [
        {'id': 10, 'body': 'hello from test data'},
      ],
    });
    expect(rows, hasLength(1));
    expect(rows.single['id'], 10);
  });

  test('unexpected server response fails instead of displaying fake data', () {
    expect(() => TotiChatServices.rows('offline'),
      throwsA(isA<StateError>()));
    expect(() => TotiChatServices.object([1, 2]),
      throwsA(isA<StateError>()));
  });
}
