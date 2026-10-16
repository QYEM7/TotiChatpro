import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/core/app_config.dart';
import 'package:totichat/models/room_models.dart';
import 'package:totichat/main.dart';

void main() {
  test('development client is pinned to Staging, never production', () {
    expect(AppConfig.isStaging, isTrue);
    expect(AppConfig.supabaseUrl, contains('rziaedugbdwefbefcxjt'));
    expect(AppConfig.oauthRedirect, startsWith('com.totichat.next://'));
  });

  test('server-backed room model preserves real identifiers', () {
    final room = RoomInfo.fromJson(const {
      'id': '00000000-0000-4000-8000-000000000001',
      'title': 'test fixture',
      'owner_id': '00000000-0000-4000-8000-000000000002',
      'is_private': false,
    });
    expect(room.isPrivate, false);
    expect(room.ownerId, isNotEmpty);
  });

  testWidgets('unconfigured app never fakes a logged-in user', (tester) async {
    await tester.pumpWidget(const TotiChatApp(configured: false));
    expect(find.textContaining('Staging setup required'), findsOneWidget);
    expect(find.textContaining('No demonstration users'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
