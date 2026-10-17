import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totichat/features/room/room_draft_guard.dart';

void main() {
  test('confirmed message clears its unchanged original draft', () {
    final controller = TextEditingController(text: 'Hello room');
    addTearDown(controller.dispose);
    final cleared = RoomDraftGuard.clearSentDraftIfUnchanged(
      controller, 'Hello room',
    );
    expect(cleared, isTrue);
    expect(controller.text, isEmpty);
  });

  test('typing more during pending send keeps the newer draft intact', () {
    final controller = TextEditingController(text: 'Hello room');
    addTearDown(controller.dispose);
    const sent = 'Hello room';
    controller.text = 'Hello room - updated while sending';
    expect(RoomDraftGuard.clearSentDraftIfUnchanged(controller, sent), isFalse);
    expect(controller.text, 'Hello room - updated while sending');
  });

  test('editing to a completely different message also remains intact', () {
    final controller = TextEditingController(text: 'draft one');
    addTearDown(controller.dispose);
    controller.text = 'draft two';
    expect(RoomDraftGuard.clearSentDraftIfUnchanged(
      controller, 'draft one',
    ), isFalse);
    expect(controller.text, 'draft two');
  });

  test('server receives the trimmed message but draft comparison is raw', () {
    final controller = TextEditingController(text: ' hi ');
    addTearDown(controller.dispose);
    expect(' hi '.trim(), 'hi');
    expect(RoomDraftGuard.clearSentDraftIfUnchanged(
      controller, ' hi ',
    ), isTrue);
    expect(controller.text, isEmpty);
  });
}
