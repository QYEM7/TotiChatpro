import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  final ticket = {
    'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'subject': 'Server-generated support ticket',
    'status': 'open',
    'category': 'technical',
  };

  test('authenticated support inbox uses genuine total and server authorization', () {
    final page = {
      'rows': [ticket],
      'total': 51,
      'canHandle': true,
    };
    final verified = TotiChatServices.verifySupportList(
      page, offset: 50, staff: true);
    expect((verified['rows'] as List).length, 1);
    expect(verified['total'], 51);
    for (final invalid in [
      {...page, 'canHandle': false},
      {...page, 'rows': List.filled(51, ticket)},
      {...page, 'rows': [{'id': 'x', 'subject': 'no status'}]},
      {...page, 'total': 50},
      {...page, 'total': -1},
      {...page, 'total': 20.5},
    ]) {
      expect(() => TotiChatServices.verifySupportList(
        invalid, offset: 50, staff: true),
        throwsA(isA<StateError>()));
    }
    expect(TotiChatServices.verifySupportList({
      ...page, 'canHandle': false,
    }, offset: 50, staff: false)['canHandle'], false);
  });

  test('owner staff access list is paginated and permission flags must be boolean', () {
    final record = {
      'user_id': '33333333-3333-4333-8333-333333333333',
      'enabled': true,
      'updated_at': '2026-10-17T12:00:00Z',
    };
    final payload = {
      'rows': [record],
      'total': 51,
    };
    expect((TotiChatServices.verifySupportStaffPage(
      payload, offset: 50)['rows'] as List).length, 1);
    for (final invalid in [
      {...payload, 'rows': List.filled(51, record)},
      {...payload, 'rows': [{'user_id': record['user_id'], 'enabled': 'true'}]},
      {...payload, 'rows': [{'user_id': null, 'enabled': false}]},
      {...payload, 'total': 50},
      {...payload, 'total': -1},
      {...payload, 'total': '51'},
    ]) {
      expect(() => TotiChatServices.verifySupportStaffPage(
        invalid, offset: 50), throwsA(isA<StateError>()));
    }
  });

  test('empty pages after the last row are accepted as empty, not invented', () {
    expect(TotiChatServices.verifySupportList({
      'rows': [],
      'total': 0,
      'canHandle': false,
    }, offset: 50, staff: false)['rows'], isEmpty);
    expect(TotiChatServices.verifySupportStaffPage({
      'rows': [], 'total': 0,
    }, offset: 50)['rows'], isEmpty);
  });
}
