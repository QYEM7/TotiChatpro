import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/data/room_repository.dart';
import 'package:totichat/src/core/staging_config.dart';

void main() {
  group('RoomSummary', () {
    test('reads real schema keys without adding fake counts or ranks', () {
      final room = RoomSummary.fromJson({
        'id': 'room-uuid',
        'title': 'Contract fixture',
        'owner_id': 'owner-uuid',
        'is_private': false,
        'cover_path': null,
        'image_revision': null,
        'welcome_message': '',
      });
      expect(room.title, 'Contract fixture');
      expect(room.coverPath, isNull);
      expect(room.isPrivate, false);
      expect(room.welcomeMessage, isEmpty);
    });
  });

  group('RoomSeatMember', () {
    test('honors server-assigned seat and mute state', () {
      final member = RoomSeatMember.fromJson({
        'user_id': 'user-uuid',
        'display_name': 'Test fixture',
        'avatar_url': null,
        'seat_no': 15,
        'is_muted': true,
      });
      expect(member.seatNumber, 15);
      expect(member.isMuted, isTrue);
      expect(member.avatarUrl, isNull);
    });

    test('handles a real joined listener without a reserved seat', () {
      final member = RoomSeatMember.fromJson({
        'user_id': 'user-uuid',
        'display_name': 'Test fixture',
        'avatar_url': null,
        'seat_no': null,
        'is_muted': true,
      });
      expect(member.seatNumber, isNull);
    });
  });

  group('RoomTextMessage', () {
    test('maps actual server rows without fabricating message state', () {
      final message = RoomTextMessage.fromJson({
        'id': 42,
        'sender_id': 'sender-uuid',
        'body': 'Test fixture',
        'created_at': '2026-10-19T00:00:00Z',
      });
      expect(message.id, 42);
      expect(message.senderId, 'sender-uuid');
      expect(message.body, 'Test fixture');
      expect(message.createdAt.isUtc, isTrue);
    });
  });

  group('StagingConfig', () {
    test('has a fixed Staging URL and a nonempty publishable key', () {
      expect(
        StagingConfig.url,
        'https://rziaedugbdwefbefcxjt.supabase.co',
      );
      expect(StagingConfig.valid, isTrue);
      expect(
        StagingConfig.publishableKey.startsWith('sb_publishable_'),
        isTrue,
      );
    });
  });

  group('HomeBanner', () {
    test('only displays data supplied by the server', () {
      final banner = HomeBanner.fromJson({
        'id': 'banner-uuid',
        'title': 'Server supplied',
        'image_url': 'https://example.invalid/banner.webp',
      });
      expect(banner.title, 'Server supplied');
    });
  });
}
