import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'domain.dart';
import 'staging_repository.dart';
import 'visual.dart';
import 'social_pages.dart';
import 'voice_session.dart';

class ApprovedRoomView extends StatefulWidget {
  final VoiceRoom room;
  const ApprovedRoomView({super.key, required this.room});
  @override
  State<ApprovedRoomView> createState() => _ApprovedRoomViewState();
}

class _ApprovedRoomViewState extends State<ApprovedRoomView> {
  StagingRepository get repo => StagingRepository(Supabase.instance.client);
  final messageField = TextEditingController();
  List<RoomMember> members = [];
  List<RoomMessage> messages = [];
  bool loading = true;
  bool sendingMessage = false;
  String? issue;
  RealtimeChannel? roomChannel;

  @override
  void initState() {
    super.initState();
    refresh();
    // Realtime changes are still validated by RLS. Refresh canonical state
    // rather than trusting event payloads to mutate seat ownership locally.
    roomChannel = Supabase.instance.client
      .channel('room-live-${widget.room.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: widget.room.id,
        ),
        callback: (_) { if (mounted) unawaited(refresh()); },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: widget.room.id,
        ),
        callback: (_) { if (mounted) unawaited(refresh()); },
      )
      .subscribe();
    VoiceSession.instance.connect(widget.room.id).then((_) {
      if (mounted) setState(() => voiceReady = true);
    }).catchError((Object error) {
      if (mounted) _error(error);
    });
  }
  bool voiceReady = false;
  bool voiceBusy = false;
  @override
  void dispose() {
    final channel = roomChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    messageField.dispose();
    super.dispose();
  }
  Future<void> refresh() async {
    if (!mounted) return;
    setState(() { loading = true; issue = null; });
    try {
      final results = await Future.wait<Object>([
        repo.roomMembers(widget.room.id),
        repo.roomMessages(widget.room.id),
      ]);
      if (!mounted) return;
      setState(() {
        members = results[0] as List<RoomMember>;
        messages = results[1] as List<RoomMessage>;
      });
    } catch (error) {
      if (mounted) setState(() => issue = error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  Future<void> selectSeat(int seatNumber) async {
    try {
      final mine = members.where((m) => m.userId == repo.currentUserId).toList();
      final occupying = members.where((m) => m.seat == seatNumber).toList();
      if (occupying.isNotEmpty && occupying.first.userId != repo.currentUserId) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذا المقعد مشغول')));
        return;
      }
      await repo.takeSeat(widget.room.id,
          mine.isNotEmpty && mine.first.seat == seatNumber ? null : seatNumber);
      await refresh();
    } catch (error) { if (mounted) _error(error); }
  }
  Future<void> postMessage() async {
    if (sendingMessage || messageField.text.trim().isEmpty) return;
    setState(() => sendingMessage = true);
    try {
      await repo.sendMessage(widget.room.id, messageField.text);
      messageField.clear();
      await refresh();
    } catch (error) { if (mounted) _error(error); }
    finally { if (mounted) setState(() => sendingMessage = false); }
  }
  void _error(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إكمال العملية: ' + error.toString())));
  }
  Future<void> toggleMic() async {
    if (voiceBusy) return;
    setState(() => voiceBusy = true);
    try {
      await VoiceSession.instance.setMicrophone(
        roomId: widget.room.id,
        enabled: !VoiceSession.instance.publishing,
        repository: repo,
      );
      if (mounted) {
        setState(() => voiceReady = VoiceSession.instance.connected);
        await refresh();
      }
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => voiceBusy = false);
    }
  }
  Future<void> exitRoom() async {
    try {
      await VoiceSession.instance.disconnect();
      await repo.leaveRoom(widget.room.id);
      if (mounted) Navigator.pop(context, false);
    } catch (error) { if (mounted) _error(error); }
  }
  Future<void> menu() async {
    final result = await showModalBottomSheet<String>(
      context: context, backgroundColor: const Color(0xFF211540),
      builder: (ctx) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('تصغير الغرفة', style: TextStyle(color: Colors.white)),
            leading: const Icon(Icons.picture_in_picture_alt, color: ApprovedPalette.mint),
            onTap: () => Navigator.pop(ctx, 'minimize'),
          ),
          ListTile(
            title: const Text('مغادرة الغرفة', style: TextStyle(color: Colors.white)),
            leading: const Icon(Icons.logout, color: ApprovedPalette.gold),
            onTap: () => Navigator.pop(ctx, 'leave'),
          ),
        ],
      )),
    );
    if (!mounted) return;
    if (result == 'leave') {
      await exitRoom();
    } else if (result == 'minimize') {
      Navigator.pop(context, true);
    }
  }
  void openGifts() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xEE211540),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => GiftBottomSheet(
        roomId: widget.room.id,
        members: members,
      ),
    );
  }
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: ApprovedPalette.room,
      body: SafeArea(child: Stack(children: [
        Positioned.fill(child: ApprovedNetworkImage(
          url: approvedAsset('assets/images/galaxy_room_bg_1792054675831.jpg'))),
        Positioned.fill(child: Container(color: const Color(0xAA120729))),
        Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.room.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 17)),
                  Text('ID: ' + widget.room.id.substring(0, 8),
                    style: const TextStyle(color: ApprovedPalette.mint, fontSize: 11)),
                ],
              )),
              IconButton(onPressed: refresh, tooltip: 'تحديث',
                icon: const Icon(Icons.refresh, color: Colors.white)),
              IconButton(onPressed: menu, tooltip: 'إدارة الخروج',
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white)),
            ]),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (issue != null) Padding(
            padding: const EdgeInsets.all(6),
            child: Text('تعذر تحديث الغرفة', style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(children: [
              for (var row = 0; row < 3; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: Row(children: [
                    for (var col = 0; col < 5; col++)
                      Expanded(child: _seatWidget(row * 5 + col + 1)),
                  ]),
                ),
            ]),
          ),
          const Spacer(),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListView(
              shrinkWrap: true, reverse: true,
              children: [
                for (final message in messages.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(message.body, style: const TextStyle(
                      color: Colors.white, fontSize: 13))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
            decoration: const BoxDecoration(color: Color(0xCC170A2F)),
            child: Row(children: [
              Expanded(child: TextField(
                controller: messageField, maxLength: 500, minLines: 1, maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...', counterText: '',
                  hintStyle: const TextStyle(color: Colors.white60),
                  filled: true, fillColor: const Color(0xFF33204E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(26)),
                ),
              )),
              IconButton(
                onPressed: sendingMessage ? null : postMessage,
                icon: const Icon(Icons.send, color: ApprovedPalette.mint)),
              IconButton(
                onPressed: openGifts,
                icon: const Icon(Icons.card_giftcard, color: ApprovedPalette.gold)),
              IconButton(
                tooltip: voiceReady ? 'تشغيل أو إيقاف الميكروفون' : 'الاتصال بالصوت',
                onPressed: voiceBusy || !voiceReady ? null : toggleMic,
                icon: Icon(VoiceSession.instance.publishing
                  ? Icons.mic : Icons.mic_off,
                  color: VoiceSession.instance.publishing
                    ? ApprovedPalette.mint : Colors.white70),
              ),
            ]),
          ),
        ]),
      ])),
    ),
  );

  Widget _seatWidget(int seatNumber) {
    final found = members.where((m) => m.seat == seatNumber).toList();
    final seated = found.isEmpty ? null : found.first;
    return InkWell(
      onLongPress: seated != null && seated.userId != repo.currentUserId
        ? () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ConversationPage(
              otherId: seated.userId, otherName: seated.name)))
        : null,
      onTap: () => selectSeat(seatNumber),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          height: 49, width: 49,
          decoration: BoxDecoration(
            color: const Color(0x99201042),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x889457C7), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0x337E4DCF), blurRadius: 9)],
          ),
          child: Icon(seated == null ? Icons.mic : Icons.person,
            color: seated == null ? ApprovedPalette.mint : ApprovedPalette.gold, size: 23),
        ),
        const SizedBox(height: 4),
        Text(seated?.name ?? ('NO ' + seatNumber.toString().padLeft(2, '0')),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10,
            fontWeight: FontWeight.w800)),
        const Text('♡', style: TextStyle(color: ApprovedPalette.mint, fontSize: 12)),
      ]),
    );
  }
}

class GiftBottomSheet extends StatefulWidget {
  final String roomId;
  final List<RoomMember> members;
  const GiftBottomSheet({super.key, required this.roomId, required this.members});
  @override
  State<GiftBottomSheet> createState() => _GiftBottomSheetState();
}
class _GiftBottomSheetState extends State<GiftBottomSheet> {
  StagingRepository get repo => StagingRepository(Supabase.instance.client);
  late Future<List<GiftItem>> gifts;
  GiftItem? selected;
  String? recipient;
  int quantity = 1;
  bool busy = false;
  String? requestId;
  @override
  void initState() {
    super.initState();
    gifts = repo.activeGifts();
    final recipients = widget.members.where(
        (m) => m.userId != repo.currentUserId).toList();
    if (recipients.isNotEmpty) recipient = recipients.first.userId;
  }
  Future<void> send() async {
    if (busy || selected == null || recipient == null) return;
    final item = selected!;
    final selectedRecipient = recipient!;
    final total = item.price * quantity;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد إرسال الهدية'),
        content: Text('سيتم خصم ' + total.toString() +
          ' عملة مقابل ' + quantity.toString() +
          ' من ' + item.name + '.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الخصم')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { busy = true; requestId ??= const Uuid().v4(); });
    try {
      await repo.sendGift(
        roomId: widget.roomId,
        recipientId: selectedRecipient,
        giftId: item.id,
        quantity: quantity,
        expectedPrice: item.price,
        requestId: requestId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد الهدية من الخادم')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لم يتم تأكيد العملية: ' + error.toString())));
      // Preserve same key if network timed out after a server commit.
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final receivers = widget.members.where(
        (m) => m.userId != repo.currentUserId).toList();
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('صندوق الهدايا', style: TextStyle(
          color: ApprovedPalette.gold, fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 10),
        if (receivers.isEmpty)
          const Text('لا يوجد مستلم حقيقي داخل الغرفة',
            style: TextStyle(color: Colors.white70))
        else DropdownButton<String>(
          dropdownColor: ApprovedPalette.violet,
          value: recipient,
          items: [
            for (final m in receivers)
              DropdownMenuItem(value: m.userId,
                child: Text(m.name, style: const TextStyle(color: Colors.white))),
          ],
          onChanged: (id) => setState(() { recipient = id; requestId = null; }),
        ),
        SizedBox(height: 225, child: FutureBuilder<List<GiftItem>>(
          future: gifts,
          builder: (ctx, snap) {
            if (snap.hasError) return const Center(child: Text(
              'تعذر تحميل كتالوج الهدايا', style: TextStyle(color: Colors.white)));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!;
            if (list.isEmpty) return const Center(child: Text(
              'لا توجد هدايا حقيقية متاحة حالياً',
              style: TextStyle(color: Colors.white70)));
            return GridView.builder(
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, childAspectRatio: .72),
              itemBuilder: (context, i) {
                final gift = list[i];
                return InkWell(
                  onTap: () => setState(() { selected = gift; requestId = null; }),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0x88321D56),
                      border: Border.all(color: selected?.id == gift.id
                        ? ApprovedPalette.gold : Colors.transparent),
                      borderRadius: BorderRadius.circular(10)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(gift.icon, style: const TextStyle(fontSize: 27)),
                      Text(gift.name, textAlign: TextAlign.center, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.white)),
                      Text(gift.price.toString(), style: const TextStyle(
                        fontSize: 11, color: ApprovedPalette.gold)),
                    ]),
                  ),
                );
              },
            );
          },
        )),
        FutureBuilder<int>(
          future: repo.coinsBalance(),
          builder: (ctx, snap) => Text(snap.hasData
            ? 'الرصيد الحقيقي: ' + snap.data.toString()
            : 'الرصيد غير متاح',
            style: const TextStyle(color: Colors.white70)),
        ),
        Row(children: [
          const Text('العدد', style: TextStyle(color: Colors.white)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: quantity, dropdownColor: ApprovedPalette.violet,
            items: const [1, 7, 17, 77, 777].map((q) =>
              DropdownMenuItem(value: q,
                child: Text(q.toString(), style: const TextStyle(color: Colors.white)))).toList(),
            // Display selected quantity in a separate text; avoid fake quantities.
            onChanged: (q) => setState(() { quantity = q ?? 1; requestId = null; }),
          ),
          Text(quantity.toString(),
            style: const TextStyle(color: ApprovedPalette.gold)),
          const Spacer(),
          FilledButton(
            onPressed: busy || selected == null || recipient == null ? null : send,
            child: Text(busy ? 'جاري الإرسال...' : 'إرسال'),
          ),
        ]),
      ]),
    ));
  }
}
