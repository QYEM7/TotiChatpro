import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/data/totichat_repository.dart';
import 'package:totichat/features/room/room_screen.dart';
import 'package:totichat/models/room_models.dart';

/// This widget test must never start a real Supabase or LiveKit connection.
class _UnboundClient extends Fake implements SupabaseClient {}

class _DeferredJoinRepository extends TotiChatRepository {
  _DeferredJoinRepository() : super(_UnboundClient());

  final joinGate = Completer<void>();
  int joinCalls = 0;
  int leaveCalls = 0;

  @override
  String get currentUserId => 'signed-in-test-member';

  @override
  Future<void> joinRoom(String roomId) {
    joinCalls++;
    return joinGate.future;
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    leaveCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rejected pending join completes the already requested exit',
      (tester) async {
    final repository = _DeferredJoinRepository();
    var exits = 0;
    const room = RoomInfo(
      id: '00000000-0000-4000-8000-000000000123',
      title: 'Staging room',
      ownerId: 'different-owner',
      isPrivate: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: RoomScreen(
        repository: repository,
        room: room,
        onExit: () => exits++,
        onMinimize: () {},
      ),
    ));
    expect(repository.joinCalls, 1);
    expect(exits, 0);

    // The room controls are available even while the join RPC is pending.
    await tester.tap(find.byTooltip('Room controls'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Leave room'));
    await tester.pump();
    expect(exits, 0);

    // A rejected join must not strand the user on a closed loading screen.
    repository.joinGate.completeError(StateError('join rejected'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(exits, 1);
    // The server never confirmed membership, so no leave RPC is fabricated.
    expect(repository.leaveCalls, 0);
  });
}
