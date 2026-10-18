class VoiceRoom {
  final String id;
  final String title;
  final bool isPrivate;
  final String ownerId;
  final String? coverPath;
  final String? welcomeMessage;

  const VoiceRoom({
    required this.id,
    required this.title,
    required this.isPrivate,
    required this.ownerId,
    this.coverPath,
    this.welcomeMessage,
  });

  factory VoiceRoom.fromJson(Map<String, dynamic> json) => VoiceRoom(
        id: json['id'] as String,
        title: json['title'] as String,
        isPrivate: json['is_private'] == true,
        ownerId: json['owner_id'] as String,
        coverPath: json['cover_path'] as String?,
        welcomeMessage: json['welcome_message'] as String?,
      );
}

class RoomMember {
  final String userId;
  final String name;
  final int? seat;
  final bool muted;
  const RoomMember(this.userId, this.name, this.seat, this.muted);
  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
        json['user_id'] as String,
        json['display_name'] as String? ?? '',
        (json['seat_no'] as num?)?.toInt(),
        json['is_muted'] == true,
      );
}

class RoomMessage {
  final String senderId;
  final String body;
  const RoomMessage(this.senderId, this.body);
  factory RoomMessage.fromJson(Map<String, dynamic> json) =>
      RoomMessage(json['sender_id'] as String, json['body'] as String);
}

class GiftItem {
  final String id;
  final String name;
  final String icon;
  final int price;
  final String? previewUrl;

  const GiftItem(this.id, this.name, this.icon, this.price, this.previewUrl);
  factory GiftItem.fromJson(Map<String, dynamic> json) => GiftItem(
        json['id'] as String,
        json['name'] as String,
        json['icon'] as String? ?? '🎁',
        (json['price'] as num).toInt(),
        json['preview_url'] as String?,
      );
}

class BannerItem {
  final String title;
  final String url;
  const BannerItem(this.title, this.url);
  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        json['title'] as String,
        json['image_url'] as String,
      );
}
