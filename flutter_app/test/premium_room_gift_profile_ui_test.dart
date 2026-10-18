import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/data/totichat_services.dart';
import 'package:totichat/features/economy/gift_sheet.dart';
import 'package:totichat/ui/toti_theme.dart';

class _UnboundClient extends Fake implements SupabaseClient {}

/// Only the empty server state is faked for rendering; no accounts, gifting,
/// balances or successful financial transactions are fabricated.
class _EmptyGiftCatalog extends TotiChatServices {
  _EmptyGiftCatalog() : super(_UnboundClient());

  @override
  Future<List<Map<String, dynamic>>> gifts() async => const [];
}

void main() {
  test('premium UI contract keeps real room and financial guards intact', () {
    final room = File('lib/features/room/room_screen.dart').readAsStringSync();
    final profile = File('lib/features/profile/profile_screen.dart')
        .readAsStringSync();
    final gifts = File('lib/features/economy/gift_sheet.dart')
        .readAsStringSync();

    expect(room, contains('itemCount: 15'));
    expect(room, contains('NeverScrollableScrollPhysics()'));
    expect(room, contains("const Text('15 مقعد'"));
    expect(room, contains('TotiGlassCard('));
    expect(room, contains('showDragHandle: false'));
    expect(room, contains('backgroundColor: Colors.transparent'));
    expect(room, contains('RoomSeatVisual('));
    expect(profile, contains('TotiGradientPanel('));
    expect(profile, contains('TotiGlassCard('));
    expect(profile, contains('ownWallet()'));
    expect(profile, contains('ownAssignedId()'));
    expect(profile, contains('_AdminEntry('));
    expect(gifts, contains('BackdropFilter('));
    expect(gifts, contains('validatedGiftTotal('));
    expect(gifts, contains('newRequestId:TotiChatServices.requestId'));
    expect(gifts, contains('_retry.confirm('));
    expect(gifts, contains('[1, 7, 17, 77, 777]'));
  });

  testWidgets('narrow gift sheet renders empty catalog without fake balances',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final api = _EmptyGiftCatalog();
    await tester.pumpWidget(MaterialApp(
      theme: buildTotiTheme(),
      home: Scaffold(
        body: GiftSheet(
          api: api,
          roomId: '00000000-0000-4000-8000-000000000219',
          members: const [],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('صندوق الهدايا الحقيقية'), findsOneWidget);
    expect(find.text('ماكو هدايا متاحة حالياً.'), findsOneWidget);
    expect(find.text('لا يوجد مستلم جالس على مقعد.'), findsOneWidget);
    expect(find.text('إرسال بعد موافقة الخادم'), findsOneWidget);
    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'إرسال بعد موافقة الخادم'),
    );
    expect(sendButton.onPressed, isNull,
      reason: 'Never allow a gift debit without real catalog and recipient');
    expect(tester.takeException(), isNull);
  });
}
