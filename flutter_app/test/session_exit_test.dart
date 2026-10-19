import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/src/core/session_exit.dart';

void main() {
  group('SessionExit', () {
    test('leaves active room before revoking authenticated session', () async {
      final calls = <String>[];
      await SessionExit.run(
        hasRoom: true,
        closeRoom: () async {
          calls.add('leave');
          return true;
        },
        signOut: () async => calls.add('signout'),
      );
      expect(calls, ['leave', 'signout']);
    });

    test('blocks signout when server room closure is not confirmed', () async {
      final calls = <String>[];
      await expectLater(
        SessionExit.run(
          hasRoom: true,
          closeRoom: () async {
            calls.add('leave_failed');
            return false;
          },
          signOut: () async => calls.add('signout'),
        ),
        throwsStateError,
      );
      expect(calls, ['leave_failed']);
    });

    test('never calls session logout on room close exception', () async {
      var signedOut = false;
      await expectLater(
        SessionExit.run(
          hasRoom: true,
          closeRoom: () async => throw StateError('network unavailable'),
          signOut: () async => signedOut = true,
        ),
        throwsStateError,
      );
      expect(signedOut, isFalse);
    });

    test('logs out normally when no room is active', () async {
      var closed = false;
      var signedOut = false;
      await SessionExit.run(
        hasRoom: false,
        closeRoom: () async {
          closed = true;
          return true;
        },
        signOut: () async => signedOut = true,
      );
      expect(closed, false);
      expect(signedOut, true);
    });
  });
}
