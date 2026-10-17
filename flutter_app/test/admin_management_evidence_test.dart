import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  const staffId = '11111111-1111-4111-8111-111111111111';
  const ownerId = '22222222-2222-4222-8222-222222222222';
  const agencyId = '33333333-3333-4333-8333-333333333333';
  const timestamp = '2026-10-17T09:30:00+00:00';

  Map<String, dynamic> envelope(String kind, List<Object> records,
      {int offset = 0, int? total}) => {
    'kind': kind,
    'rows': records,
    'total': total ?? records.length,
    'offset': offset,
    'limit': 30,
    'readOnly': true,
    'asOf': timestamp,
  };

  test('Owner evidence requests only approved categories and bounded offsets', () {
    for (final kind in TotiChatServices.adminManagementKinds) {
      expect(TotiChatServices.adminManagementParams(kind, offset: 60), {
        'p_kind': kind,
        'p_offset': 60,
        'p_limit': 30,
      });
    }
    for (final invalid in ['users', 'wallets', 'ledger', 'owner', '']) {
      expect(() => TotiChatServices.adminManagementParams(invalid),
        throwsArgumentError);
    }
    for (final offset in [-30, 1, 31, 50010]) {
      expect(() => TotiChatServices.adminManagementParams(
        'staff', offset: offset), throwsArgumentError);
    }
    expect(TotiChatServices.adminManagementParams(
      'audit', offset: 49980)['p_offset'], 49980);
  });

  test('administrative staff records use real PostgreSQL text[] permissions', () {
    final row = {
      'user_id': staffId,
      'role': 'admin',
      'permissions': <String>['read_reports'],
      'assigned_by': ownerId,
      'updated_at': timestamp,
    };
    final valid = TotiChatServices.verifyAdminManagementPage(
      envelope('staff', [row]), kind: 'staff', offset: 0);
    expect((valid['rows'] as List).length, 1);
    expect(() => TotiChatServices.verifyAdminManagementPage(
      envelope('staff', [{...row, 'permissions': {'a': true}}]),
      kind: 'staff', offset: 0), throwsA(isA<StateError>()));
    expect(() => TotiChatServices.verifyAdminManagementPage(
      envelope('staff', [{...row, 'role': null}]),
      kind: 'staff', offset: 0), throwsA(isA<StateError>()));
  });

  test('real host and charging agencies stay separated by server category', () {
    final row = {
      'id': agencyId,
      'name': 'Verified agency',
      'owner_id': ownerId,
      'kind': 'host',
      'commission_percent': '0',
      'is_active': true,
      'member_count': 0,
    };
    expect(TotiChatServices.verifyAdminManagementPage(
      envelope('host_agencies', [row]),
      kind: 'host_agencies', offset: 0)['kind'], 'host_agencies');
    expect(() => TotiChatServices.verifyAdminManagementPage(
      envelope('recharge_agencies', [row]),
      kind: 'recharge_agencies', offset: 0),
      throwsA(isA<StateError>()));
    expect(TotiChatServices.verifyAdminManagementPage(
      envelope('recharge_agencies', [{...row, 'kind': 'recharge'}]),
      kind: 'recharge_agencies', offset: 0)['kind'], 'recharge_agencies');
  });

  test('applications, transfers and security audit remain read-only', () {
    final kinds = <String, Map<String, dynamic>>{
      'registrations': {
        'id': agencyId,
        'name': 'Agency application',
        'applicant_id': ownerId,
        'status': 'pending',
      },
      'agency_transfers': {
        'id': agencyId,
        'user_id': staffId,
        'agency_id': ownerId,
        'status': 'pending',
      },
      'audit': {
        'id': 44,
        'actor_id': ownerId,
        'action': 'staff_role_changed',
        'created_at': timestamp,
      },
    };
    for (final entry in kinds.entries) {
      final valid = TotiChatServices.verifyAdminManagementPage(
        envelope(entry.key, [entry.value]),
        kind: entry.key, offset: 0);
      expect(valid['readOnly'], true);
      expect((valid['rows'] as List).length, 1);
    }
  });

  test('reject altered totals, wrong category, duplicated rows, writes and bad pages', () {
    final row = {
      'id': agencyId,
      'name': 'Verified agency',
      'owner_id': ownerId,
      'kind': 'host',
      'is_active': true,
    };
    final valid = envelope('host_agencies', [row], offset: 30, total: 31);
    expect(TotiChatServices.verifyAdminManagementPage(valid,
      kind: 'host_agencies', offset: 30)['offset'], 30);

    for (final invalid in [
      {...valid, 'kind': 'staff'},
      {...valid, 'readOnly': false},
      {...valid, 'limit': 50},
      {...valid, 'offset': 0},
      {...valid, 'total': 30},
      {...valid, 'total': 30.5},
      {...valid, 'total': -1},
      {...valid, 'rows': [row, row]},
      {...valid, 'rows': List.filled(31, row)},
      {...valid, 'asOf': 'invalid'},
    ]) {
      expect(() => TotiChatServices.verifyAdminManagementPage(invalid,
        kind: 'host_agencies', offset: 30),
        throwsA(isA<StateError>()));
    }
  });

  test('empty server evidence is valid without inserting mock records', () {
    final result = TotiChatServices.verifyAdminManagementPage(
      envelope('audit', <Object>[], offset: 30),
      kind: 'audit', offset: 30);
    expect(result['total'], 0);
    expect(result['rows'], isEmpty);
  });
}
