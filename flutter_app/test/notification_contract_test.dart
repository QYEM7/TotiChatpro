import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/notification_models.dart';
import 'package:totichat/data/totichat_services.dart';

Map<String, dynamic> event(
  int id, {
  String? readAt,
  String type = 'support_reply',
}) => {
  'id': id,
  'event_type': type,
  'context': <String, dynamic>{
    'title': 'Server recorded reply',
    'message': 'Your ticket received a response',
  },
  'created_at': '2026-10-17T07:00:00Z',
  'read_at': readAt,
};

void main() {
  test('server-provided notification records render without placeholders', () {
    final data = NotificationPage.fromJson({
      'items': [
        event(201),
        event(199, readAt: '2026-10-17T08:00:00Z'),
      ],
      'unreadCount': 13,
    });
    expect(data.items.length, 2);
    expect(data.unreadCount, 13);
    expect(data.nextBefore, 199);
    expect(data.items.first.id, 201);
    expect(data.items.first.unread, isTrue);
    expect(data.items.last.unread, isFalse);
    expect(data.items.first.displayTitle, 'Server recorded reply');
    expect(data.items.first.displayMessage,
      'Your ticket received a response');
  });

  test('unknown events display their real event type', () {
    final record = NotificationEntry.fromJson({
      'id': 999,
      'event_type': 'host_agency_transfer',
      'created_at': '2026-10-17T10:25:00+03:00',
      'context': <String, dynamic>{},
      'read_at': null,
    });
    expect(record.displayTitle, 'host agency transfer');
    expect(record.displayMessage, isNull);
    expect(record.unread, isTrue);
  });

  test('notification envelope rejects invalid server values', () {
    final badPayloads = <Object?>[
      null,
      {'items': null, 'unreadCount': 1},
      {'items': <Object>[], 'unreadCount': -2},
      {'items': <Object>[], 'unreadCount': 1.4},
      {'items': [event(3), event(3)], 'unreadCount': 2},
      {'items': [
        {'id': 0, 'event_type': 'bad',
         'created_at': '2026-10-17T07:00:00Z'},
      ], 'unreadCount': 1},
      {'items': [
        {'id': 12, 'event_type': 'bad',
         'created_at': 'invalid-date'},
      ], 'unreadCount': 1},
    ];
    for (final invalid in badPayloads) {
      expect(() => NotificationPage.fromJson(invalid),
        throwsA(isA<FormatException>()));
    }
  });

  test('pagination cursor cannot be null or nonpositive at call boundary', () {
    expect(TotiChatServices.notificationFeedParams(),
      {'p_limit': 50, 'p_before': null});
    expect(TotiChatServices.notificationFeedParams(limit: 30, before: 102),
      {'p_limit': 30, 'p_before': 102});
    for (final bad in [0, -1, 51]) {
      expect(() => TotiChatServices.notificationFeedParams(limit: bad),
        throwsArgumentError);
    }
    expect(() => TotiChatServices.notificationFeedParams(before: 0),
      throwsArgumentError);
  });

  test('mark-selected notifications acknowledges at most 100 real IDs', () {
    expect(TotiChatServices.notificationMarkSelectedParams([9, 9, 6]), {
      'p_ids': [9, 6],
      'p_all': false,
    });
    expect(() => TotiChatServices.notificationMarkSelectedParams([]),
      throwsArgumentError);
    expect(() => TotiChatServices.notificationMarkSelectedParams([0]),
      throwsArgumentError);
    expect(() => TotiChatServices.notificationMarkSelectedParams(
      List.generate(101, (i) => i + 1)), throwsArgumentError);
    expect(TotiChatServices.markAllNotificationParams(), {
      'p_ids': <int>[],
      'p_all': true,
    });
  });
}
