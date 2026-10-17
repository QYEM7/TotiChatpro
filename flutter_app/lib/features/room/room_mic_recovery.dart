/// Best-effort microphone rollback after an interrupted voice operation.
///
/// The local LiveKit session and the authoritative server mute are separate
/// resources. A failed local disconnect must never prevent the server mute
/// attempt; conversely a failed server request cannot be reported as success.
class RoomMicRecoveryResult {
  const RoomMicRecoveryResult({
    this.disconnectError,
    this.serverMuteError,
  });

  final Object? disconnectError;
  final Object? serverMuteError;

  bool get disconnectConfirmed => disconnectError == null;
  bool get serverMuteConfirmed => serverMuteError == null;
  bool get fullyRecovered => disconnectConfirmed && serverMuteConfirmed;
}

class RoomMicRecovery {
  const RoomMicRecovery._();

  static Future<RoomMicRecoveryResult> run({
    required Future<void> Function() disconnectAudio,
    required Future<void> Function() muteOnServer,
  }) async {
    Object? disconnectError;
    Object? serverMuteError;

    try {
      await disconnectAudio();
    } catch (error) {
      disconnectError = error;
    }

    // Never gate this on the outcome of the LiveKit disconnect.
    try {
      await muteOnServer();
    } catch (error) {
      serverMuteError = error;
    }

    return RoomMicRecoveryResult(
      disconnectError: disconnectError,
      serverMuteError: serverMuteError,
    );
  }
}
