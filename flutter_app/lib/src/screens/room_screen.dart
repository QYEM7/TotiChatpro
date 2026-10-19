import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../data/room_repository.dart';

/// The first vertical slice: real room membership and real seat visibility.
/// Seats and text chat use real authenticated server data; audio remains separate.
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.room,
    required this.repository,
  });

  final RoomSummary room;
  final RoomRepository repository;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late Future<List<RoomSeatMember>> _members;
  late Stream<List<RoomTextMessage>> _messagesStream;
  final TextEditingController _composer = TextEditingController();
  Timer? _refreshTimer;
  bool _savingSeat = false;
  bool _sending = false;
  bool _leaving = false;
  bool _canPop = false;

  bool get _isOwner =>
      widget.room.ownerId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _members = widget.repository.members(widget.room.id);
    _messagesStream = widget.repository.watchMessages(widget.room.id);
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_leaving && !_canPop) _reload();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _chooseSeat(int number, RoomSeatMember? occupant) async {
    if (_savingSeat || _leaving) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (occupant != null && occupant.userId != userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('seat_busy'))),
      );
      return;
    }
    setState(() => _savingSeat = true);
    try {
      if (occupant?.userId == userId) {
        await widget.repository.releaseSeat(widget.room.id);
      } else {
        await widget.repository.takeSeat(widget.room.id, number);
      }
      if (mounted) _reload();
    } catch (_) {
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('seat_error'))),
      );
    } finally {
      if (mounted) setState(() => _savingSeat = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_sending || _leaving) return;
    final message = _composer.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendMessage(widget.room.id, message);
      if (mounted) _composer.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('chat_send_failed'))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reload() {
    setState(() {
      _members = widget.repository.members(widget.room.id);
    });
  }

  Future<void> _leave() async {
    if (_leaving || _canPop) return;
    final prompt = _isOwner
        ? UiText.get('room_leave_owner_question')
        : UiText.get('room_leave_question');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(prompt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(UiText.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(UiText.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    try {
      await widget.repository.leave(widget.room.id);
      if (!mounted) return;
      setState(() => _canPop = true);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UiText.get('room_exit_failed'))),
      );
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0426),
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                'https://raw.githubusercontent.com/mrbalmain11-star/-/main/public/galaxy-room-bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFF0D0426),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xCC0A031E),
                      Color(0x660A031E),
                      Color(0xEE0A031E),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          widget.room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _reload,
                        tooltip: UiText.get('refresh'),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: _leaving ? null : _leave,
                        tooltip: UiText.get('room_leave'),
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                    ]),
                  ),
                  if (widget.room.welcomeMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        widget.room.welcomeMessage,
                        style: const TextStyle(color: Color(0xFFE9D5FF)),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<List<RoomSeatMember>>(
                      future: _members,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              UiText.get('room_members_failed'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }
                        final members = snapshot.requireData;
                        final seatMap = {
                          for (final member in members)
                            if (member.seatNumber != null)
                              member.seatNumber!: member
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              Text(
                                '${UiText.get('joined_members')}: ${members.length}',
                                style:
                                    const TextStyle(color: Color(0xFFFDE68A)),
                              ),
                              const SizedBox(height: 22),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 15,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 5,
                                  childAspectRatio: 0.70,
                                ),
                                itemBuilder: (context, index) {
                                  final number = index + 1;
                                  return _seat(number, seatMap[number]);
                                },
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: StreamBuilder<List<RoomTextMessage>>(
                                  stream: _messagesStream,
                                  builder: (context, messageSnapshot) {
                                    if (messageSnapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          UiText.get('chat_load_failed'),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      );
                                    }
                                    if (!messageSnapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    final messages = messageSnapshot.requireData;
                                    if (messages.isEmpty) {
                                      return Center(
                                        child: Text(
                                          UiText.get('chat_empty'),
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      );
                                    }
                                    final names = {
                                      for (final member in members)
                                        member.userId: member.displayName,
                                    };
                                    final me = Supabase.instance.client.auth.currentUser?.id;
                                    return ListView.builder(
                                      reverse: true,
                                      itemCount: messages.length,
                                      itemBuilder: (context, index) {
                                        final msg = messages[messages.length - 1 - index];
                                        final sender = msg.senderId == me
                                            ? UiText.get('chat_me')
                                            : (names[msg.senderId] ?? msg.senderId.substring(0, 8));
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            '${sender}: ${msg.body}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                                child: Row(children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _composer,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      maxLines: 1,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: UiText.get('chat_hint'),
                                        hintStyle: const TextStyle(color: Colors.white54),
                                        filled: true,
                                        fillColor: const Color(0xBB100724),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _sending ? null : _sendMessage,
                                    icon: const Icon(Icons.send, color: Color(0xFFFBBF24)),
                                    tooltip: UiText.get('chat_send'),
                                  ),
                                ]),
                              ),
                              Container(
                                margin: const EdgeInsets.all(14),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xBB100724),
                                  border: Border.all(
                                      color: const Color(0x887C3AED)),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  UiText.get('audio_pending'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seat(int index, RoomSeatMember? member) {
    final occupied = member != null;
    final avatar = member?.avatarUrl;
    return InkWell(
      key: Key('room-seat-$index'),
      onTap: _savingSeat ? null : () => _chooseSeat(index, member),
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xAA1B0D3A),
              shape: BoxShape.circle,
              border: Border.all(
                color: occupied
                    ? const Color(0xFFFBBF24)
                    : const Color(0x667C3AED),
              ),
            ),
            child: ClipOval(
              child: avatar != null
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.white70,
                      ),
                    )
                  : Icon(
                      occupied ? Icons.person : Icons.mic_none,
                      color: Colors.white70,
                      size: 22,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          occupied ? member.displayName : UiText.get('room_seat_empty'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
        Text(
          index.toString().padLeft(2, '0'),
          style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 9),
        ),
        ],
      ),
    );
  }
}
