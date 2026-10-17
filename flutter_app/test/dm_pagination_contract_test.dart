import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  const self = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const peer = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const stranger = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

  Map<String,dynamic> message(int id, String sender) => {
    'id': id,
    'sender_id': sender,
    'recipient_id': sender == self ? peer : self,
    'body': 'Authenticated message $id',
    'created_at': '2026-10-17T00:00:00Z',
    'read_at': null,
  };

  test('DM RPC uses server cursor and at most 80 records', () {
    expect(TotiChatServices.dmPageParams(peer), {
      'p_other_user': peer,
      'p_before_id': null,
      'p_limit': 80,
    });
    expect(TotiChatServices.dmPageParams(peer, before: 190)[
      'p_before_id'], 190);
    expect(() => TotiChatServices.dmPageParams(peer, before: 0),
      throwsArgumentError);
    expect(() => TotiChatServices.dmPageParams(''),
      throwsArgumentError);
  });

  test('descending server DM records are shown in chronological order', () {
    final result = TotiChatServices.verifyDmPage([
      message(108, self),
      message(107, peer),
      message(106, peer),
    ], selfId: self, peerId: peer, before: 110);
    expect(result.map((x) => x['id']), [106, 107, 108]);
    expect(TotiChatServices.lastIncomingDmId(result, peer), 107);
    expect(TotiChatServices.lastIncomingDmId(result, self), 108);
  });

  test('read marker never uses an outgoing message', () {
    final messages = [
      message(20, peer),
      message(21, self),
      message(22, self),
    ];
    expect(TotiChatServices.lastIncomingDmId(messages, peer), 20);
    expect(TotiChatServices.lastIncomingDmId(
      [message(22, self)], peer), isNull);
  });

  test('DM page rejects private messages from strangers and invalid cursors', () {
    final invalid = [
      [message(201, self)],
      [message(198, stranger)],
      [
        {...message(198, peer), 'recipient_id': stranger},
      ],
      [message(198, self), message(199, peer)],
      [message(198, self), message(198, peer)],
      [
        {...message(198, self), 'id': 198.4},
      ],
      [
        {...message(198, self), 'body': ''},
      ],
      List.generate(81, (i) => message(199 - i, self)),
    ];
    for (final data in invalid) {
      expect(() => TotiChatServices.verifyDmPage(
        data, selfId: self, peerId: peer, before: 200),
        throwsA(isA<StateError>()));
    }
  });

  test('server-scoped block and unblock requests cannot omit a recipient', () {
    expect(TotiChatServices.dmBlockParams(peer, blocked: true), {
      'p_other_user': peer,
      'p_block': true,
    });
    expect(TotiChatServices.dmBlockParams(peer, blocked: false), {
      'p_other_user': peer,
      'p_block': false,
    });
    expect(() => TotiChatServices.dmBlockParams(' ', blocked: true),
      throwsArgumentError);
  });

  test('empty DM page is legal and has no invented read receipt', () {
    final result = TotiChatServices.verifyDmPage(
      <Object>[], selfId: self, peerId: peer, before: 100);
    expect(result, isEmpty);
    expect(TotiChatServices.lastIncomingDmId(result, peer), isNull);
  });
}
