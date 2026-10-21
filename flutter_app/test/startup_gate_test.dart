import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/main.dart';

void main() {
  testWidgets('offline native-render diagnostics use no backend screen',
      (tester) async {
    await tester.pumpWidget(const StartupDiagnosticsApp());

    expect(find.text('TotiChat Device Test'), findsOneWidget);
    expect(find.text('Flutter frame visible'), findsOneWidget);
    expect(find.textContaining('No login, rooms'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('first frame is visible while native initialization is pending',
      (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(StartupGate(
      initialize: () => pending.future,
      ready: const Scaffold(body: Text('Backend initialized')),
    ));

    expect(find.text('TotiChat Beta'), findsOneWidget);
    expect(find.text('Starting TotiChat Beta...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Backend initialized'), findsNothing);

    pending.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Backend initialized'), findsOneWidget);
    expect(find.text('Starting TotiChat Beta...'), findsNothing);
  });

  testWidgets('failed initialization shows visible safe error, not white',
      (tester) async {
    await tester.pumpWidget(StartupGate(
      initialize: () async {
        throw StateError('private-internal-diagnostic');
      },
      ready: const Scaffold(body: Text('Should not appear')),
    ));

    await tester.pump();
    expect(find.textContaining('could not start'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('private-internal-diagnostic'), findsNothing);
    expect(find.text('Should not appear'), findsNothing);
  });

  testWidgets('synchronous plugin failure is rendered, not uncaught',
      (tester) async {
    await tester.pumpWidget(StartupGate(
      initialize: () => throw StateError('boot'),
      ready: const Scaffold(body: Text('Should not appear')),
    ));
    await tester.pump();
    expect(find.textContaining('could not start'), findsOneWidget);
    expect(find.text('Should not appear'), findsNothing);
  });
}
