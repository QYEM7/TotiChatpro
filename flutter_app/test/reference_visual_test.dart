import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/reference_visuals.dart';
import 'package:totichat/src/core/ui_text.dart';

/// Captures real Flutter-rendered components against approved board #02.
/// Zero data deliberately: no fake rooms or balances are published to users.
void main() {
  testWidgets('approved illustrated home components render and export evidence', (tester) async {
    await UiText.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: ReferencePalette.canvas,
              body: SafeArea(
                child: Column(children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(17, 8, 17, 12),
                    child: Row(children: [
                      ReferenceBrand(),
                      Spacer(),
                      Icon(Icons.search_rounded, size: 27, color: ReferencePalette.deep),
                      SizedBox(width: 20),
                      Icon(Icons.notifications_none_rounded,
                        size: 27, color: ReferencePalette.deep),
                    ]),
                  ),
                  Expanded(child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    children: [
                      ReferenceWelcomeHero(
                        title: UiText.get('reference_welcome_title'),
                        subtitle: UiText.get('reference_welcome_subtitle'),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        _category(Icons.local_fire_department_rounded, UiText.get('reference_trending'), const Color(0xFFDA6835)),
                        _category(Icons.diamond_outlined, 'VIP', ReferencePalette.teal),
                        _category(Icons.groups_rounded, UiText.get('reference_new_rooms'), ReferencePalette.teal),
                        _category(Icons.star_rounded, UiText.get('reference_featured'), ReferencePalette.gold),
                      ]),
                      const SizedBox(height: 16),
                      ReferenceSection(title: UiText.get('reference_featured_rooms')),
                      const SizedBox(height: 7),
                      ReferenceEmptyRooms(
                        title: UiText.get('rooms_empty'),
                        subtitle: UiText.get('reference_no_rooms_explanation'),
                        actionLabel: UiText.get('room_create'),
                        onAction: () {},
                      ),
                      const SizedBox(height: 20),
                    ],
                  )),
                ]),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 0,
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'الرئيسية'),
                  NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'الرسائل'),
                  NavigationDestination(icon: Icon(Icons.person_outline), label: 'أنا'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReferenceWelcomeHero), findsOneWidget);
    expect(find.byType(ReferenceEmptyRooms), findsOneWidget);
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    // Screenshot rasterization is a real async GPU operation. Avoid awaiting it
    // in TestWidgetsFlutterBinding's fake async zone, which may deadlock CI.
    await tester.runAsync(() async {
      final shot = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull);
        final output = File('build/design_previews/reference-home-empty.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        expect(output.lengthSync(), greaterThan(2000));
      } finally {
        shot.dispose();
      }
    });
  });
}

Widget _category(IconData icon,String label,Color color) =>
  Expanded(child: ReferenceCategory(
    icon: icon,
    label: label,
    color: color,
    background: ReferencePalette.mint,
    onTap: () {},
  ));
