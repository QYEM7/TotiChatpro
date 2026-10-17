/// Coordinates independent room cleanups without letting a failed local
/// transport teardown suppress the server-authoritative membership leave.
///
/// This intentionally has no Supabase or LiveKit dependency so failure
/// ordering can be verified in regular Dart/Flutter unit tests.
class RoomExitResult {
  const RoomExitResult({
    required this.realtimeCleanupFailed,
    required this.audioCleanupFailed,
  });

  final bool realtimeCleanupFailed;
  final bool audioCleanupFailed;
  bool get hadCleanupErrors => realtimeCleanupFailed || audioCleanupFailed;
}

class RoomExitWorkflow {
  const RoomExitWorkflow._();

  static Future<RoomExitResult> run({
    required Future<void> Function() closeRealtime,
    required Future<void> Function() disconnectAudio,
    required Future<void> Function() leaveOnServer,
  }) async {
    var realtimeCleanupFailed = false;
    var audioCleanupFailed = false;

    // Even a failed Realtime socket should never block local mic cleanup.
    try {
      await closeRealtime();
    } catch (_) {
      realtimeCleanupFailed = true;
    }

    // Never skip the server leave when local transport cleanup fails.
    try {
      await disconnectAudio();
    } catch (_) {
      audioCleanupFailed = true;
    }

    // The server remains authoritative. An error here must propagate:
    // the UI cannot claim the user has left without server confirmation.
    await leaveOnServer();

    return RoomExitResult(
      realtimeCleanupFailed: realtimeCleanupFailed,
      audioCleanupFailed: audioCleanupFailed,
    );
  }
}
