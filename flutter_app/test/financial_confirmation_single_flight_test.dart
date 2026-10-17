import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/data/totichat_services.dart';
import 'package:totichat/features/economy/economy_screen.dart';
import 'package:totichat/features/economy/gift_sheet.dart';
import 'package:totichat/models/room_models.dart';

class _SingleFlightApi extends TotiChatServices {
  _SingleFlightApi()
      : super(SupabaseClient('https://example.supabase.co',
          'release-guard-fixture-public-key'));

  int giftRequests = 0;
  int storeRequests = 0;
  final giftGate = Completer<void>();
  final storeGate = Completer<void>();

  @override
  Future<List<Map<String, dynamic>>> gifts() async => [
    {
      'id': 'rose_red',
      'name': 'Red Rose',
      'price': 100,
      'is_active': true,
      'diamond_source_type': 'STANDARD',
    }
  ];

  @override
  Future<void> sendGift({
    required String roomId,
    required String recipientId,
    required Map<String, dynamic> gift,
    required int quantity,
    required String requestId,
  }) async {
    giftRequests++;
    await giftGate.future;
  }

  @override
  Future<List<Map<String, dynamic>>> store() async => [
    {
      'id': 'avatar_frame_1',
      'name': 'Gold Frame',
      'price': 200,
      'currency': 'gold',
      'is_active': true,
      'is_reward': false,
    }
  ];

  @override
  Future<void> buyItem(Map<String, dynamic> item, String requestId) async {
    storeRequests++;
    await storeGate.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two gift taps open one confirmation and initiate one debit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final api = _SingleFlightApi();
    const recipient = RoomMember(
      userId: '11111111-1111-4111-8111-111111111111',
      displayName: 'Member A',
      seatNo: 2,
      isMuted: true,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: GiftSheet(
        api: api,
        roomId: '22222222-2222-4222-8222-222222222222',
        members: const [recipient],
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Red Rose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختر المستلم من المقاعد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Member A').last);
    await tester.pumpAndSettle();

    final button = find.text('إرسال بعد موافقة الخادم');
    expect(button, findsOneWidget);
    await tester.tap(button);
    // A second pointer may hit the modal barrier instead of the old button.
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.giftRequests, 0);

    await tester.tap(find.text('إرسال').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.giftRequests, 1);
    // The route's reverse animation may remain for a frame; one RPC matters.

    api.giftGate.complete();
    await tester.pumpAndSettle();
    expect(api.giftRequests, 1);
  });

  testWidgets('two store taps cannot open duplicate purchase confirmations',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final api = _SingleFlightApi();
    await tester.pumpWidget(MaterialApp(home: EconomyScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Gold Frame'), findsOneWidget);
    final button = find.text('شراء');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.storeRequests, 0);

    await tester.tap(find.text('تأكيد').last);
    await tester.pump();
    expect(api.storeRequests, 1);
    api.storeGate.complete();
    await tester.pumpAndSettle();
    // Dismiss the successful purchase snackbar's finite timer before teardown.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(api.storeRequests, 1);
  });
}
