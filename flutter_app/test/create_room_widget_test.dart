import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/ui_text.dart';
import 'package:totichat/src/screens/create_room_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await UiText.load();
  });

  testWidgets('Room creation includes image, title and welcome fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: CreateRoomScreen(),
      ),
    ));

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byKey(const Key('reference-room-cover-picker')), findsOneWidget);
    expect(find.text(UiText.get('room_welcome_label')), findsOneWidget);
    expect(find.byKey(const Key('reference-room-name')), findsOneWidget);
    expect(find.byKey(const Key('reference-room-welcome')), findsOneWidget);
    expect(find.text(UiText.get('room_name_label')), findsOneWidget);
  });

  testWidgets('Empty room form cannot create a server room', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: CreateRoomScreen(),
      ),
    ));
    await tester.tap(find.byKey(const Key('reference-submit-room')));
    await tester.pump();
    expect(find.text(UiText.get('room_name_required')), findsOneWidget);
    expect(find.text(UiText.get('room_welcome_required')), findsOneWidget);
  });
}
