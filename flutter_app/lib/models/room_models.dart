class RoomInfo {
  const RoomInfo({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.isPrivate,
    this.coverPath,
    this.welcomeMessage,
  });

  final String id;
  final String title;
  final String ownerId;
  final bool isPrivate;
  final String? coverPath;
  final String? welcomeMessage;

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
    id: json['id'] as String,
    title: json['title'] as String,
    ownerId: json['owner_id'] as String,
    isPrivate: json['is_private'] as bool? ?? false,
    coverPath: json['cover_path'] as String?,
    welcomeMessage: json['welcome_message'] as String?,
  );
}

class RoomMember {
  const RoomMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.seatNo,
    required this.isMuted,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int? seatNo;
  final bool isMuted;

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
    userId: json['user_id'] as String,
    displayName: (json['display_name'] as String?) ?? 'TotiChat Member',
    avatarUrl: json['avatar_url'] as String?,
    seatNo: (json['seat_no'] as num?)?.toInt(),
    isMuted: json['is_muted'] as bool? ?? true,
  );
}

class RoomMessage {
  const RoomMessage({required this.id, required this.senderId, required this.body});
  final int id;
  final String senderId;
  final String body;

  factory RoomMessage.fromJson(Map<String, dynamic> json) => RoomMessage(
    id: (json['id'] as num).toInt(),
    senderId: json['sender_id'] as String,
    body: json['body'] as String,
  );
}

class VoiceGrant {
  const VoiceGrant({
    required this.roomId,
    required this.url,
    required this.token,
    required this.canPublish,
  });
  final String roomId;
  final String url;
  final String token;
  final bool canPublish;
  factory VoiceGrant.fromJson(Map<String, dynamic> json) => VoiceGrant(
    roomId: json['roomId'] as String,
    url: json['url'] as String,
    token: json['token'] as String,
    canPublish: json['canPublish'] == true,
  );
}
