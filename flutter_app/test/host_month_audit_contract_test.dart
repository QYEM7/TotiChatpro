import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/data/totichat_services.dart';

void main() {
  test('host reconciliation requests a closed UTC month only', () {
    expect(TotiChatServices.hostConservationParams(
      DateTime.utc(2026, 9, 18)), {
        'p_month': '2026-09-01',
        'p_offset': 0,
        'p_limit': 30,
      });
    expect(TotiChatServices.hostConservationParams(
      DateTime.utc(2026, 9, 1), offset: 60)['p_offset'], 60);
    expect(() => TotiChatServices.hostConservationParams(
      DateTime.utc(2024, 12)), throwsArgumentError);
    expect(() => TotiChatServices.hostConservationParams(
      DateTime.utc(2026, 12)), throwsArgumentError);
    for (final offset in [-30, 1, 29, 100020]) {
      expect(() => TotiChatServices.hostConservationParams(
        DateTime.utc(2026, 9), offset: offset), throwsArgumentError);
    }
  });

  test('integrity report never authorizes salary actions', () {
    final clean = {
      'isReadOnly': true,
      'hasEvidenceProblems': false,
      'snapshotCaptured': false,
      'hasVerifiedHistory': false,
      'canApprovePayroll': false,
      'canPaySalaries': false,
      'canZeroDiamonds': false,
    };
    final verified = TotiChatServices.verifyHostMonthIntegrity(clean);
    expect(verified['snapshotCaptured'], false);
    expect(verified['canPaySalaries'], false);
    for (final field in [
      'isReadOnly',
      'canApprovePayroll',
      'canPaySalaries',
      'canZeroDiamonds',
    ]) {
      final unsafe = {...clean, field: field == 'isReadOnly' ? false : true};
      expect(() => TotiChatServices.verifyHostMonthIntegrity(unsafe),
        throwsA(isA<StateError>()));
    }
    expect(() => TotiChatServices.verifyHostMonthIntegrity({
      ...clean, 'hasVerifiedHistory': null,
    }), throwsA(isA<StateError>()));
  });

  test('diamond conservation is always evidence-only and paged', () {
    final report = {
      'isReadOnly': true,
      'canApprovePayroll': false,
      'canPaySalaries': false,
      'canZeroDiamonds': false,
      'hasPayrollRates': false,
      'isReadyForFinalClose': false,
      'hasDiscrepancies': false,
      'hosts': <Object>[],
      'pageOffset': 30,
      'pageLimit': 30,
    };
    final valid = TotiChatServices.verifyHostConservation(report, offset: 30);
    expect(valid['hosts'], isEmpty);
    expect(valid['canZeroDiamonds'], false);
    expect(() => TotiChatServices.verifyHostConservation(report, offset: 0),
      throwsA(isA<StateError>()));
    expect(() => TotiChatServices.verifyHostConservation({
      ...report, 'isReadyForFinalClose': true,
    }, offset: 30), throwsA(isA<StateError>()));
    expect(() => TotiChatServices.verifyHostConservation({
      ...report, 'hasPayrollRates': true,
    }, offset: 30), throwsA(isA<StateError>()));
    expect(() => TotiChatServices.verifyHostConservation({
      ...report, 'canPaySalaries': true,
    }, offset: 30), throwsA(isA<StateError>()));
    expect(() => TotiChatServices.verifyHostConservation({
      ...report, 'hosts': List.filled(31, 'not confirmed'),
    }, offset: 30), throwsA(isA<StateError>()));
  });
}
