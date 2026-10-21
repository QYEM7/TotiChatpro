import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/reference_visuals.dart';

/// Captures real Flutter-rendered components against approved board #02.
/// Zero data deliberately: no fake rooms or balances are published to users.
void main() {
  testWidgets('approved illustrated home components render and export evidence', (tester) async {
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
                      const ReferenceWelcomeHero(
                        title: 'Welcome to TotiChat',
                        subtitle: 'Where voices meet friends',
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        _category(Icons.local_fire_department_rounded, 'Popular', const Color(0xFFDA6835)),
                        _category(Icons.diamond_outlined, 'VIP', ReferencePalette.teal),
                        _category(Icons.groups_rounded, 'New rooms', ReferencePalette.teal),
                        _category(Icons.star_rounded, 'Featured', ReferencePalette.gold),
                      ]),
                      const SizedBox(height: 16),
                      const ReferenceSection(title: 'Featured rooms'),
                      const SizedBox(height: 7),
                      ReferenceEmptyRooms(
                        title: 'No public rooms',
                        subtitle: 'Live rooms will appear here when available.',
                        actionLabel: 'Create room',
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
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
                  NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
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
    final shot = await boundary.toImage(pixelRatio: 2);
    final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final output = File('build/design_previews/reference-home-empty.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    shot.dispose();
    expect(output.lengthSync(), greaterThan(2000));
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
