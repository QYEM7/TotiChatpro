import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:totichat/src/core/reference_visuals.dart';
import 'package:totichat/src/core/ui_text.dart';

/// Captures real Flutter-rendered components against approved board #02.
/// Zero data deliberately: no fake rooms or balances are published to users.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await UiText.load();
    if (Platform.environment['TOTICHAT_CAPTURE_GOLDEN'] != '1') {
      return; // Normal unit tests and Android CI require no OS font assets.
    }
    // flutter_test defaults to Ahem squares. Load actual Arabic and icon
    // fonts for a credible raster comparison with the reference boards.
    final arabic = Platform.environment['TOTICHAT_PREVIEW_FONT'];
    if (arabic == null || !File(arabic).existsSync()) {
      throw StateError('Reference screenshot requires a real Arabic font path');
    }
    final arabicLoader = FontLoader('ReferenceArabic')
      ..addFont(File(arabic).readAsBytes().then(ByteData.sublistView));
    await arabicLoader.load();
    final icons = Platform.environment['TOTICHAT_ICONS_FONT'];
    if (icons != null && File(icons).existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(File(icons).readAsBytes().then(ByteData.sublistView));
      await iconLoader.load();
    }
  });
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
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'ReferenceArabic',
            scaffoldBackgroundColor: ReferencePalette.canvas,
            colorScheme: ColorScheme.fromSeed(
              seedColor: ReferencePalette.teal,
            ).copyWith(
              primary: ReferencePalette.teal,
              surface: Colors.white,
            ),
            navigationBarTheme: const NavigationBarThemeData(
              backgroundColor: Colors.white,
              indicatorColor: ReferencePalette.mint,
            ),
          ),
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
    // Decode the two real approved-design WebP assets before golden capture.
    // Without pre-caching, flutter_test can snapshot a placeholder frame
    // before ImageStreamCodec has produced the first image.
    final previewContext = tester.element(find.byType(ReferenceWelcomeHero));
    await tester.runAsync(() async {
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/reference_approved_falcon.webp'),
          previewContext,
        ),
        precacheImage(
          const AssetImage('assets/images/reference_approved_welcome.webp'),
          previewContext,
        ),
      ]);
    });
    await tester.pumpAndSettle();
    expect(find.byType(ReferenceWelcomeHero), findsOneWidget);
    expect(find.byType(ReferenceEmptyRooms), findsOneWidget);
    if (Platform.environment['TOTICHAT_CAPTURE_GOLDEN'] == '1') {
      // Flutter's built-in golden pipeline owns rasterization and timing.
      // CI runs this separately with --update-goldens and uploads its PNG.
      await expectLater(
        find.byKey(key),
        matchesGoldenFile('goldens/reference-home-empty.png'),
      );
    }
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
