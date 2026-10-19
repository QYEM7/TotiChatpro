import '../data/room_repository.dart';

/// Client-side safety check for microphone eligibility.
/// Server/LiveKit permissions remain authoritative.
abstract final class RoomMicrophonePolicy {
  static bool mayPublish({
    required String? userId,
    required Iterable<RoomSeatMember> members,
  }) {
    if (userId == null || userId.isEmpty) return false;
    return members.any((member) =>
        member.userId == userId &&
        member.seatNumber != null &&
        !member.isMuted);
  }
}
