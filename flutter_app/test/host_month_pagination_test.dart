import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  test('preflight and snapshot request bounded 100-item pages', () {
    final params = TotiChatServices.hostEvidencePageParams(
      DateTime.utc(2026, 9, 12), offset: 200);
    expect(params, {
      'p_month': '2026-09-01',
      'p_offset': 200,
      'p_limit': 100,
    });
    expect(TotiChatServices.hostEvidencePageParams(
      DateTime.utc(2025, 1), offset: 50000)['p_offset'], 50000);
    for (final offset in [-100, 1, 99, 150, 50100]) {
      expect(() => TotiChatServices.hostEvidencePageParams(
        DateTime.utc(2026, 9), offset: offset), throwsArgumentError);
    }
    expect(() => TotiChatServices.hostEvidencePageParams(
      DateTime.utc(2026, 10)), throwsArgumentError);
    expect(() => TotiChatServices.hostEvidencePageParams(
      DateTime.utc(2024, 12)), throwsArgumentError);
  });

  test('preflight validates total and selected page, never payroll', () {
    final response = {
      'isDraftPreflight': true,
      'paysSalaries': false,
      'canZeroDiamonds': false,
      'hasPayrollRates': false,
      'remainingValuesAreCurrent': true,
      'totalHostEntries': 201,
      'entries': List.generate(100, (i) => {'user_id': 'test-$i'}),
    };
    final result = TotiChatServices.verifyHostPreflight(
      response, offset: 100);
    expect((result['entries'] as List).length, 100);
    expect(result['totalHostEntries'], 201);
    for (final invalid in [
      {...response, 'totalHostEntries': 150},
      {...response, 'totalHostEntries': null},
      {...response, 'totalHostEntries': -1},
      {...response, 'entries': List.filled(101, <String, Object>{})},
      {...response, 'isDraftPreflight': false},
      {...response, 'canZeroDiamonds': true},
      {...response, 'paysSalaries': true},
      {...response, 'hasPayrollRates': true},
      {...response, 'remainingValuesAreCurrent': false},
    ]) {
      expect(() => TotiChatServices.verifyHostPreflight(invalid,
          offset: 100), throwsA(isA<StateError>()));
    }
  });

  test('snapshot paging preserves immutable evidence boundaries', () {
    final captured = {
      'captured': true,
      'isAccrualEvidenceOnly': true,
      'paysSalaries': false,
      'canZeroDiamonds': false,
      'hasPayrollRates': false,
      'entries': 101,
      'offset': 100,
      'limit': 100,
      'items': [{'host_id': 'verified-host'}],
    };
    final result = TotiChatServices.verifyHostSnapshot(
      captured, offset: 100);
    expect((result['items'] as List).length, 1);
    expect(() => TotiChatServices.verifyHostSnapshot(captured,
      offset: 0), throwsA(isA<StateError>()));
    for (final bad in [
      {...captured, 'offset': 0},
      {...captured, 'limit': 50},
      {...captured, 'canZeroDiamonds': true},
      {...captured, 'entries': 100},
      {...captured, 'items': List.filled(101, <String, Object>{})},
    ]) {
      expect(() => TotiChatServices.verifyHostSnapshot(bad,
        offset: 100), throwsA(isA<StateError>()));
    }
  });

  test('missing snapshot is not presented as a captured record', () {
    const missing = {
      'captured': false,
      'entries': 0,
      'items': [],
      'isAccrualEvidenceOnly': true,
      'paysSalaries': false,
      'canZeroDiamonds': false,
      'hasPayrollRates': false,
    };
    expect(TotiChatServices.verifyHostSnapshot(missing, offset: 0)['captured'],
      false);
    expect(() => TotiChatServices.verifyHostSnapshot({
      ...missing, 'items': [{'not_a_real_entry': 1}],
    }, offset: 0), throwsA(isA<StateError>()));
  });
}
