import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/features/auth/login_screen.dart';
import 'package:totichat/ui/toti_bottom_bar.dart';
import 'package:totichat/ui/toti_theme.dart';

void main() {
  test('rebuilt screens do not revert to rejected generic layouts', () {
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    final room = File('lib/features/room/room_screen.dart').readAsStringSync();
    final login = File('lib/features/auth/login_screen.dart').readAsStringSync();

    expect(home, contains('TotiBottomBar('));
    expect(home, contains('toti-live-room-search'));
    expect(home, contains('onCreateRoom:'));
    expect(home, isNot(contains('NavigationBar(')));
    expect(room, contains('itemCount: 15'));
    expect(room, contains('NeverScrollableScrollPhysics()'));
    expect(room, contains('TotiAtmosphere('));
    expect(room, contains('RoomSeatVisual('));
    expect(room, contains('ImageFilter.blur('));
    expect(room, isNot(contains('Color(0xFF29233E)')));
    expect(login, contains('TotiGradientPanel('));
    expect(login, contains('Continue with Google'));
    expect(login, contains('OAuthProvider.google'));
  });

  testWidgets('new Google login fits a narrow Android-sized screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(380, 760));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildTotiTheme(),
      home: const LoginScreen(),
    ));

    expect(find.text('TotiChat'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(FalconMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium bottom bar uses a functioning central create action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(380, 760));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    var create = 0;
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTotiTheme(),
      home: Scaffold(bottomNavigationBar: TotiBottomBar(
        selectedIndex: 0,
        onCreateRoom: () => create++,
        onDestinationSelected: (index) => selected = index,
      )),
    ));
    await tester.tap(find.byKey(const ValueKey('toti-create-room-action')));
    expect(create, 1);
    await tester.tap(find.text('اكتشف'));
    expect(selected, 1);
    expect(tester.takeException(), isNull);
  });
}
