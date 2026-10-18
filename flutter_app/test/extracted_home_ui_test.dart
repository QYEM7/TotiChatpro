import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/models/room_models.dart';
import 'package:totichat/ui/extracted_home_widgets.dart';
import 'package:totichat/ui/toti_theme.dart';

void main() {
  test('extracted home layout preserves connected room and banner sources', () {
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    final tile = File('lib/ui/extracted_home_widgets.dart').readAsStringSync();

    expect(home, contains('SliverGrid.builder('));
    expect(home, contains('TotiExtractedHomeHeader('));
    expect(home, contains('TotiExtractedRoomTile('));
    expect(home, contains('widget.repository.publicRooms()'));
    expect(home, contains('widget.repository.activeBanners()'));
    expect(home, contains('widget.repository.createRoomWithCover('));
    expect(home, contains('widget.repository.coverUrl(room)'));
    expect(home, contains('onOpen: () => _enter(room)'));
    expect(home, contains('toti-live-room-search'));
    expect(home, contains('RealGiftTicker('));
    expect(home, contains('TotiBottomBar('));
    expect(tile, isNot(contains('listenersCount ?? 50')));
    expect(tile, isNot(contains('mockRooms')));
  });

  testWidgets('square room cover renders its real title and opens on tap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    const room = RoomInfo(
      id: 'room-test',
      title: 'Real room title',
      ownerId: 'owner-test',
      isPrivate: false,
    );
    var opened = 0;

    await tester.pumpWidget(MaterialApp(
      theme: buildTotiTheme(),
      home: Scaffold(body: Center(child: SizedBox(
        width: 170,
        height: 215,
        child: TotiExtractedRoomTile(
          room: room,
          coverUrl: null,
          onOpen: () => opened++,
        ),
      ))),
    ));

    expect(find.text('Real room title'), findsOneWidget);
    expect(find.text('صوتية'), findsOneWidget);
    expect(find.text('50'), findsNothing);
    await tester.tap(find.byType(TotiExtractedRoomTile));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
