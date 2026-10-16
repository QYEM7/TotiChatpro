import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/features/room/room_seat_visual.dart';
import 'package:totichat/models/room_models.dart';
import 'package:totichat/models/room_seat_decoration.dart';

void main() {
  const ownerId = '00000000-0000-4000-8000-000000000123';

  test('real server decoration contract includes gift, VIP and equipped frame', () {
    final rows = RoomSeatDecoration.indexFromResponse([
      {
        'userId': ownerId,
        'vipTier': 10,
        'receivedGifts': 128,
        'frame': {'name': 'Night Falcon', 'icon': '✨'},
      },
    ]);
    expect(rows.length, 1);
    expect(rows[ownerId]?.vipTier, 10);
    expect(rows[ownerId]?.receivedGifts, 128);
    expect(rows[ownerId]?.frameName, 'Night Falcon');
    expect(rows[ownerId]?.frameIcon, '✨');
  });

  test('zero real rewards and no equipped frame are accepted', () {
    final data = RoomSeatDecoration.indexFromResponse([
      {'userId': ownerId, 'vipTier': 0,
        'receivedGifts': 0, 'frame': null},
    ]);
    expect(data[ownerId]?.receivedGifts, 0);
    expect(data[ownerId]?.frameName, isNull);
  });

  test('missing, duplicate or fabricated seat decorations are rejected', () {
    const valid = {
      'userId': ownerId,
      'vipTier': 1,
      'receivedGifts': 0,
      'frame': null,
    };
    final invalidRows = [
      {'userId': ownerId, 'vipTier': 11, 'receivedGifts': 1},
      {'userId': ownerId, 'vipTier': -1, 'receivedGifts': 1},
      {'userId': ownerId, 'vipTier': 1, 'receivedGifts': -1},
      {'userId': ownerId, 'vipTier': 1.5, 'receivedGifts': 2},
      {'userId': ownerId, 'vipTier': 1, 'receivedGifts': null},
      {'userId': '', 'vipTier': 1, 'receivedGifts': 3},
      {'userId': ownerId, 'vipTier': 1, 'receivedGifts': 1,
        'frame': 'not a frame'},
    ];
    for (final invalid in invalidRows) {
      expect(() => RoomSeatDecoration.fromJson(invalid),
        throwsA(isA<FormatException>()));
    }
    expect(() => RoomSeatDecoration.indexFromResponse([valid, valid]),
      throwsA(isA<FormatException>()));
    expect(() => RoomSeatDecoration.indexFromResponse(List.filled(16, valid)),
      throwsA(isA<FormatException>()));
    expect(() => RoomSeatDecoration.indexFromResponse(null),
      throwsA(isA<FormatException>()));
  });

  testWidgets('room visual shows only verified metadata', (tester) async {
    const member = RoomMember(
      userId: ownerId, displayName: 'Owner', seatNo: 1,
      isMuted: true,
    );
    const decoration = RoomSeatDecoration(
      userId: ownerId, vipTier: 5, receivedGifts: 17,
      frameName: 'Silver Falcon', frameIcon: '✨',
    );
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(width: 120, height: 120,
        child: RoomSeatVisual(
          member: member, isOwner: true, decoration: decoration)),
    )));
    expect(find.text('VIP 5'), findsOneWidget);
    expect(find.text('🎁 17'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
  });

  testWidgets('empty seat never receives fake VIP or gift count',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: SizedBox(width: 120, height: 120,
        child: RoomSeatVisual(member: null, isOwner: false)),
    )));
    expect(find.textContaining('VIP'), findsNothing);
    expect(find.textContaining('🎁'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
  });
}
