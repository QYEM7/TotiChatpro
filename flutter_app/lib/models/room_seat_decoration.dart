/// Read-only visual metadata confirmed by phase6_room_mic_decorations.
/// These values do not grant microphone or seat permissions.
class RoomSeatDecoration {
  const RoomSeatDecoration({
    required this.userId,
    required this.vipTier,
    required this.receivedGifts,
    this.frameName,
    this.frameIcon,
  });

  final String userId;
  final int vipTier;
  final int receivedGifts;
  final String? frameName;
  final String? frameIcon;

  static int _integer(Object? value, String field, int minimum, int? maximum) {
    if (value is! num || !value.isFinite || value != value.toInt() ||
        value < minimum || (maximum != null && value > maximum)) {
      throw FormatException('Invalid room seat $field');
    }
    return value.toInt();
  }

  factory RoomSeatDecoration.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid seat decoration row');
    final data = Map<String, dynamic>.from(raw);
    final userId = data['userId'];
    if (userId is! String || userId.trim().isEmpty) {
      throw const FormatException('Seat decoration user ID is missing');
    }
    final frame = data['frame'];
    if (frame != null && frame is! Map) {
      throw const FormatException('Invalid equipped frame');
    }
    final details = frame == null
        ? null : Map<String, dynamic>.from(frame);
    final name = details?['name'];
    final icon = details?['icon'];
    if ((name != null && (name is! String || name.length > 100)) ||
        (icon != null && (icon is! String || icon.length > 200))) {
      throw const FormatException('Malformed equipped frame metadata');
    }
    return RoomSeatDecoration(
      userId: userId,
      vipTier: _integer(data['vipTier'], 'VIP tier', 0, 10),
      receivedGifts: _integer(data['receivedGifts'], 'gift count', 0, null),
      frameName: name as String?,
      frameIcon: icon as String?,
    );
  }

  /// Reject missing or duplicated member IDs rather than showing invented
  /// VIP levels or gift counts on a seat.
  static Map<String, RoomSeatDecoration> indexFromResponse(Object? result) {
    if (result is! List || result.length > 15) {
      throw const FormatException('Invalid room seat decorations response');
    }
    final byUser = <String, RoomSeatDecoration>{};
    for (final raw in result) {
      final entry = RoomSeatDecoration.fromJson(raw);
      if (byUser.containsKey(entry.userId)) {
        throw const FormatException('Duplicate seat decoration user');
      }
      byUser[entry.userId] = entry;
    }
    return Map.unmodifiable(byUser);
  }
}
