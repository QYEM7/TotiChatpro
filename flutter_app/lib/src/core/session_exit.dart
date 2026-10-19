/// Consistent account exit: a live room must be closed on the server before
/// revoking the authenticated session that is needed to call the leave RPC.
abstract final class SessionExit {
  static Future<void> run({
    required bool hasRoom,
    required Future<bool> Function() closeRoom,
    required Future<void> Function() signOut,
  }) async {
    if (hasRoom) {
      final closed = await closeRoom();
      if (!closed) {
        throw StateError('Active room membership was not closed');
      }
    }
    await signOut();
  }
}
