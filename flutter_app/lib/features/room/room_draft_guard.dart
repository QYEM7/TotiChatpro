import 'package:flutter/widgets.dart';

/// Clear a sent chat draft only if the user has not edited it while the
/// network request was in flight. A late server reply must never discard
/// newly typed text.
class RoomDraftGuard {
  const RoomDraftGuard._();

  static bool clearSentDraftIfUnchanged(
    TextEditingController controller,
    String sentDraft,
  ) {
    if (controller.text != sentDraft) return false;
    controller.clear();
    return true;
  }
}
