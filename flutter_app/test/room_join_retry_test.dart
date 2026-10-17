import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:totichat/data/totichat_repository.dart';
import 'package:totichat/features/room/room_screen.dart';
import 'package:totichat/models/room_models.dart';

class _UnboundClient extends Fake implements SupabaseClient {}

class _JoinRetryRepository extends TotiChatRepository {
  _JoinRetryRepository() : super(_UnboundClient());

  final requests = <Completer<void>>[];
  int leaves = 0;

  @override
  String get currentUserId => 'test-member';

  @override
  Future<void> joinRoom(String roomId) {
    final request = Completer<void>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    leaves++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rejected join offers a retry without duplicate in-flight RPCs',
      (tester) async {
    final repository = _JoinRetryRepository();
    var exits = 0;
    const room = RoomInfo(
      id: '00000000-0000-4000-8000-000000000324',
      title: 'Test room',
      ownerId: 'another-member',
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
    expect(repository.requests.length, 1);

    repository.requests.first.completeError(StateError('network unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('إعادة محاولة الدخول'), findsOneWidget);
    expect(find.textContaining('network unavailable'), findsOneWidget);

    await tester.tap(find.text('إعادة محاولة الدخول'));
    await tester.pump();
    expect(repository.requests.length, 2);
    expect(find.text('إعادة محاولة الدخول'), findsNothing);
    expect(exits, 0);

    repository.requests.last.completeError(StateError('network unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('إعادة محاولة الدخول'), findsOneWidget);
    expect(repository.requests.length, 2);

    await tester.tap(find.byTooltip('Room controls'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Leave room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(exits, 1);
    // Neither rejected join established a real server-side membership.
    expect(repository.leaves, 0);
  });
}
