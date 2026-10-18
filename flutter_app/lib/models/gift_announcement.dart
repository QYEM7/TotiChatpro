/// Validate untrusted Realtime payloads before rendering a global gift strip.
/// This does not replace the server's settlement and authorization checks.
class GiftAnnouncement {
  const GiftAnnouncement._();

  static bool isDisplayable(Map<String, dynamic> row, DateTime now) {
    final total = row['total_coins'];
    if (total is! int || total < 7000 || total > 9007199254740991) {
      return false;
    }
    final timestamp = row['created_at'];
    if (timestamp is! String) return false;
    final created = DateTime.tryParse(timestamp);
    if (created == null) return false;
    final age = now.toUtc().difference(created.toUtc());
    // Use exact durations: truncating to seconds accepted events >30s old.
    // Allow five seconds of clock skew, not arbitrarily future-dated events.
    return age >= const Duration(seconds: -5) &&
        age <= const Duration(seconds: 30);
  }
}
