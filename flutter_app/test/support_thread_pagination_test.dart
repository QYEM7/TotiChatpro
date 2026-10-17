import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  const ticketId = '55555555-5555-4555-8555-555555555555';

  test('support message pagination respects the 50-row server limit', () {
    expect(TotiChatServices.supportThreadParams(ticketId), {
      'p_ticket_id': ticketId, 'p_offset': 0, 'p_limit': 50,
    });
    expect(TotiChatServices.supportThreadParams(ticketId, offset: 50000), {
      'p_ticket_id': ticketId, 'p_offset': 50000, 'p_limit': 50,
    });
    for (final offset in [-50, 1, 49, 51, 50050]) {
      expect(() => TotiChatServices.supportThreadParams(
        ticketId, offset: offset), throwsArgumentError);
    }
    expect(() => TotiChatServices.supportThreadParams(''),
      throwsArgumentError);
  });

  test('support thread verification rejects forged ticket and bad pages', () {
    final message = {
      'id': 42,
      'author_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'body': 'Genuine support reply',
      'created_at': '2026-10-17T12:00:00Z',
    };
    final envelope = {
      'ticket': {'id': ticketId, 'status': 'open'},
      'canHandle': false,
      'total': 58,
      'messages': [message],
    };
    expect(TotiChatServices.verifySupportThread(
      envelope, ticketId: ticketId, offset: 50)['total'], 58);
    for (final bad in [
      {...envelope, 'ticket': {'id': 'other-ticket'}},
      {...envelope, 'messages': List.filled(51, message)},
      {...envelope, 'messages': [{'id': 1, 'body': 'Missing author'}]},
      {...envelope, 'total': 50},
      {...envelope, 'total': -1},
      {...envelope, 'total': 1.5},
      {...envelope, 'canHandle': null},
    ]) {
      expect(() => TotiChatServices.verifySupportThread(
        bad, ticketId: ticketId, offset: 50), throwsA(isA<StateError>()));
    }
  });

  test('empty thread and exact last page are supported', () {
    const blank = {
      'ticket': {'id': ticketId, 'status': 'open'},
      'canHandle': true,
      'total': 0,
      'messages': <Object>[],
    };
    expect((TotiChatServices.verifySupportThread(blank,
      ticketId: ticketId, offset: 0)['messages'] as List).isEmpty, true);
    expect(() => TotiChatServices.verifySupportThread(blank,
      ticketId: ticketId, offset: 50), returnsNormally);
  });
}
