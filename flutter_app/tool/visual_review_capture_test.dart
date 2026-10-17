import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/data/totichat_repository.dart';
import 'package:totichat/features/auth/login_screen.dart';
import 'package:totichat/features/home/home_screen.dart';
import 'package:totichat/models/room_models.dart';
import 'package:totichat/ui/toti_bottom_bar.dart';
import 'package:totichat/ui/toti_theme.dart';

/// Genuine Flutter-rendered screenshots for OWNER VISUAL REVIEW only.
/// No financial data, users, rooms, banners or server success is invented.
class _UnboundClient extends Fake implements SupabaseClient {}

class _NoActivityRepository extends TotiChatRepository {
  _NoActivityRepository() : super(_UnboundClient());

  @override
  Future<List<RoomInfo>> publicRooms() async => const [];

  @override
  Future<List<Map<String, dynamic>>> activeBanners() async => const [];
}

Future<void> _loadPreviewFont() async {
  final file = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  if (!file.existsSync()) {
    throw StateError('UI review font not installed on screenshot runner');
  }
  final font = await file.readAsBytes();
  await (FontLoader('Roboto')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(
          Uint8List.fromList(font)))))
      .load();

  // The default Flutter test font substitutes Material icons with squares.
  // Load the real bundled SDK icon font so the screenshots represent the app.
  final dartExecutable = File(Platform.resolvedExecutable);
  final sdk = Platform.environment['FLUTTER_ROOT'] ??
      dartExecutable.parent.parent.parent.parent.parent.path;
  final materialIcons = File(
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!materialIcons.existsSync()) {
    throw StateError('MaterialIcons font not found in Flutter SDK: $sdk');
  }
  final icons = await materialIcons.readAsBytes();
  await (FontLoader('MaterialIcons')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(
          Uint8List.fromList(icons)))))
      .load();
}

Future<void> _configureReviewSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  tester.view.devicePixelRatio = 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadPreviewFont);

  testWidgets('Flutter Google login screen', (tester) async {
    await _configureReviewSurface(tester);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTotiTheme(),
      home: const RepaintBoundary(
        key: ValueKey('visual-login-root'),
        child: LoginScreen(),
      ),
    ));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/totichat_falcon.jpg'),
        tester.element(find.byType(LoginScreen)));
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('visual-login-root')),
      matchesGoldenFile('visual_review/new_login_flutter.png'),
    );
  });

  testWidgets('Flutter empty Home with real-data-only UI', (tester) async {
    await _configureReviewSurface(tester);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    final repository = _NoActivityRepository();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTotiTheme(),
      home: RepaintBoundary(
        key: const ValueKey('visual-home-root'),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SafeArea(child: RoomsDirectory(
              repository: repository,
              explore: false,
              activeRoomId: null,
              onOpenRoom: (_) {},
            )),
            bottomNavigationBar: TotiBottomBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              onCreateRoom: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('visual-home-root')),
      matchesGoldenFile('visual_review/new_home_empty_flutter.png'),
    );
  });
}
