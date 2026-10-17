import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('postponed FCM has no public settings entry point', () {
    final settings = File(
      'lib/features/profile/settings_screen.dart').readAsStringSync();
    final scope = File('README.md').readAsStringSync();

    expect(settings, isNot(contains('PushPreferencesScreen(')));
    expect(settings, isNot(contains('push_preferences_screen.dart')));
    expect(scope, contains('deferred Firebase Cloud Messaging (FCM)'));
    expect(scope, contains('in-app notifications'));
  });

  test('host settlement remains manual, with read-only evidence', () {
    final report = File(
      'lib/features/admin/host_month_evidence_screen.dart')
      .readAsStringSync();
    final scope = File('README.md').readAsStringSync();

    expect(report,
      contains('Monthly host settlement is handled manually'));
    expect(report,
      contains('A clear audit is not proof of payment'));
    expect(scope,
      contains('Monthly host/agency settlement is manual'));
    expect(scope,
      contains('No automatic salary payout'));
  });
}
