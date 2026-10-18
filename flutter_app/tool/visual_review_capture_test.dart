import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/data/totichat_repository.dart';
import 'package:totichat/data/totichat_services.dart';
import 'package:totichat/features/auth/login_screen.dart';
import 'package:totichat/features/home/home_screen.dart';
import 'package:totichat/features/economy/gift_sheet.dart';
import 'package:totichat/features/room/room_identity_header.dart';
import 'package:totichat/features/room/room_seat_visual.dart';
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

/// Explicitly empty API response: the preview never depicts invented gifts.
class _NoGiftsApi extends TotiChatServices {
  _NoGiftsApi() : super(_UnboundClient());

  @override
  Future<List<Map<String, dynamic>>> gifts() async => const [];
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
  testWidgets('Flutter gift sheet with no fabricated items or members',
      (tester) async {
    await _configureReviewSurface(tester);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTotiTheme(),
      home: RepaintBoundary(
        key: const ValueKey('visual-gifts-root'),
        child: Scaffold(
          backgroundColor: TotiColors.background,
          body: GiftSheet(
            api: _NoGiftsApi(),
            roomId: '00000000-0000-4000-8000-000000000219',
            members: const [],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('visual-gifts-root')),
      matchesGoldenFile('visual_review/new_gift_sheet_empty_flutter.png'),
    );
  });


  testWidgets('Real Flutter voice-room empty-state design review',
      (tester) async {
    await _configureReviewSurface(tester);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTotiTheme(),
      home: RepaintBoundary(
        key: const ValueKey('visual-room-root'),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: TotiColors.background,
            body: SafeArea(child: Column(children: [
              SizedBox(height: 90, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: Row(children: [
                  const FalconMark(size: 43),
                  const Spacer(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('TotiChat', style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900,
                        color: TotiColors.ink)),
                      Text('VOICE ROOM / REVIEW ONLY',
                        style: TextStyle(fontSize: 9,
                          color: TotiColors.muted)),
                    ],
                  ),
                ]),
              )),
              const Padding(
                padding: EdgeInsets.fromLTRB(17, 3, 17, 10),
                child: RoomIdentityHeader(title: 'Room name'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 11, 10, 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: TotiColors.outline),
                  ),
                  child: Column(children: [
                    const Row(children: [
                      Text('15 seats', style: TextStyle(color: TotiColors.plum,
                        fontSize: 11, fontWeight: FontWeight.w800)),
                      Spacer(),
                      Text('Voice seats', style: TextStyle(color: TotiColors.ink,
                        fontSize: 14, fontWeight: FontWeight.w800)),
                    ]),
                    const Divider(height: 21, color: TotiColors.outline),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, mainAxisSpacing: 11,
                        crossAxisSpacing: 6, childAspectRatio: .75),
                      itemCount: 15,
                      itemBuilder: (context, i) => Column(children: [
                        const Expanded(child: RoomSeatVisual(
                          member: null, isOwner: false)),
                        const SizedBox(height: 3),
                        Text('${i + 1}', style: const TextStyle(
                          fontSize: 10, color: TotiColors.muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: TotiColors.outline)),
                  child: const Row(children: [
                    SizedBox(width: 14),
                    Icon(Icons.mic_off_rounded, color: TotiColors.plum),
                    Spacer(),
                    Text('Audio not connected', style: TextStyle(
                      color: TotiColors.ink, fontWeight: FontWeight.w700)),
                    SizedBox(width: 16),
                  ]),
                ),
              ),
              const SizedBox(height: 9),
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: TotiColors.outline)),
                  child: const Column(children: [
                    Align(alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Room chat', style: TextStyle(
                          fontWeight: FontWeight.w800, color: TotiColors.ink)))),
                    Expanded(child: Center(
                      child: Text('No real messages yet',
                        style: TextStyle(color: TotiColors.muted)))),
                  ]),
                ),
              )),
              const SizedBox(height: 9),
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  const Icon(Icons.card_giftcard_rounded, size: 29,
                    color: TotiColors.plum),
                  const SizedBox(width: 13),
                  Expanded(child: Container(
                    height: 43,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: TotiColors.lavender,
                      borderRadius: BorderRadius.circular(23)),
                    child: const Text('Message unavailable in design review',
                      style: TextStyle(fontSize: 10,
                        color: TotiColors.muted)),
                  )),
                  const SizedBox(width: 12),
                  const Icon(Icons.send_rounded, color: TotiColors.plum),
                ])),
            ])),
          ),
        ),
      ),
    ));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage('assets/totichat_falcon.jpg'),
        tester.element(find.byType(FalconMark)));
    });
    await tester.pumpAndSettle();
    expect(find.byType(RoomSeatVisual), findsNWidgets(15));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('visual-room-root')),
      matchesGoldenFile('visual_review/new_room_empty_flutter.png'),
    );
  });
}
