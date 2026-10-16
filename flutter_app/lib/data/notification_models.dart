/// Server-owned notification domain objects. No placeholder events.
class NotificationEntry {
  const NotificationEntry({
    required this.id,
    required this.eventType,
    required this.context,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String eventType;
  final Map<String, dynamic> context;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  static NotificationEntry fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Notification row must be an object');
    }
    final map = Map<String, dynamic>.from(raw);
    final rawId = map['id'];
    if (rawId is! num || !rawId.isFinite ||
        rawId < 1 || rawId.toInt() != rawId) {
      throw const FormatException('Invalid notification ID');
    }
    final type = map['event_type'];
    final timestamp = map['created_at'];
    final created = timestamp is String
      ? DateTime.tryParse(timestamp) : null;
    if (type is! String || type.trim().isEmpty || created == null) {
      throw const FormatException('Incomplete notification record');
    }
    final details = map['context'];
    if (details != null && details is! Map) {
      throw const FormatException('Invalid notification context');
    }
    final read = map['read_at'];
    final whenRead = read == null ? null :
      read is String ? DateTime.tryParse(read) : null;
    if (read != null && whenRead == null) {
      throw const FormatException('Invalid notification read timestamp');
    }
    return NotificationEntry(
      id: rawId.toInt(),
      eventType: type,
      context: Map<String, dynamic>.unmodifiable(
        details == null ? const <String, dynamic>{} :
          Map<String, dynamic>.from(details as Map)),
      createdAt: created,
      readAt: whenRead,
    );
  }

  String get displayTitle {
    final actual = context['title'];
    if (actual is String && actual.trim().isNotEmpty) {
      return actual.trim();
    }
    return eventType.replaceAll('_', ' ');
  }

  String? get displayMessage {
    for (final key in ['message', 'body', 'description']) {
      final raw = context[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }
    return null;
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.unreadCount,
  });

  final List<NotificationEntry> items;
  final int unreadCount;

  static NotificationPage fromJson(Object? payload) {
    if (payload is! Map) {
      throw const FormatException('Invalid notification response');
    }
    final data = Map<String, dynamic>.from(payload);
    final raw = data['items'];
    final unread = data['unreadCount'];
    if (raw is! List || unread is! num || !unread.isFinite ||
        unread < 0 || unread.toInt() != unread) {
      throw const FormatException('Notification envelope is incomplete');
    }
    final rows = raw.map(NotificationEntry.fromJson).toList();
    final ids = <int>{};
    for (final row in rows) {
      if (!ids.add(row.id)) {
        throw const FormatException('Duplicate notification ID');
      }
    }
    return NotificationPage(
      items: List.unmodifiable(rows),
      unreadCount: unread.toInt(),
    );
  }

  int? get nextBefore => items.isEmpty ? null : items.last.id;
}
