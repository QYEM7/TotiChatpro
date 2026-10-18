import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/models/room_models.dart';
import 'package:totichat/ui/extracted_premium_panels.dart';
import 'package:totichat/ui/toti_theme.dart';
import 'package:totichat/ui/toti_vip_tiers.dart';

void main() {
  test('exactly 10 distinct VIP tiers and a safe fallback', () {
    final tiers = List.generate(10, (i) => TotiVipTierStyle.colorFor(i + 1));
    expect(tiers.toSet().length, 10);
    expect(TotiVipTierStyle.colorFor(0), TotiColors.plum);
    expect(TotiVipTierStyle.colorFor(11), TotiColors.plum);
    for (var level = 1; level <= 10; level++) {
      expect(TotiVipTierStyle.gradientFor(level).colors.length, 3);
    }
  });

  test('room and gift flows keep real-only, safe operations', () {
    final room = File('lib/features/room/room_screen.dart').readAsStringSync();
    final gifts = File('lib/features/economy/gift_sheet.dart').readAsStringSync();
    final profile = File('lib/features/profile/profile_screen.dart').readAsStringSync();
    final agency = File('lib/features/agency/host_membership_screen.dart').readAsStringSync();
    final admin = File('lib/features/admin/admin_screen.dart').readAsStringSync();

    expect(room, contains('itemCount: 15'));
    expect(room, contains('NeverScrollableScrollPhysics()'));
    expect(room, contains('RealGiftTicker('));
    expect(room, contains('RoomSeatVisual('));
    expect(room, contains('_toggleMic'));
    expect(gifts, contains('[1, 7, 17, 77, 777]'));
    expect(gifts, contains('validatedGiftTotal('));
    expect(gifts, contains('_retry.confirm('));
    expect(profile, contains("ownWallet()"));
    expect(profile, contains("ownAssignedId()"));
    expect(profile, contains("TotiVipTierStyle.colorFor(level)"));
    expect(agency, contains('widget.api.agencyState()'));
    expect(admin, contains('canOpenAdmin(a)'));
    expect(admin, contains("a['isOwner']==true"));
    expect(admin, contains("a['isMainPartner']==true"));
  });

  testWidgets('premium header is accessible with narrow device width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildTotiTheme(),
      home: const Scaffold(body: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: TotiRoyalTopBanner(
            title: 'TotiChat',
            subtitle: 'Server-verified membership and controls',
          ),
        ),
      )),
    ));
    expect(find.text('TotiChat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
