import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../core/reference_visuals.dart';
import '../data/direct_message_repository.dart';

/// Overlay: opening this does NOT disconnect or minimize the LiveKit room.
class DirectChatSheet extends StatefulWidget {
  const DirectChatSheet({
    super.key,
    required this.otherUserId,
    required this.otherDisplayName,
  });
  final String otherUserId;
  final String otherDisplayName;

  @override
  State<DirectChatSheet> createState() => _DirectChatSheetState();
}

class _DirectChatSheetState extends State<DirectChatSheet> {
  late final DirectMessageRepository _repo =
      DirectMessageRepository(Supabase.instance.client);
  late Future<List<DirectMessage>> _messages = _repo.thread(widget.otherUserId);
  final TextEditingController _input = TextEditingController();
  Timer? _refreshTimer;
  bool _sending = false;
  String? _requestId;
  String? _pendingBody;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) _refresh();
    });
    unawaited(_repo.markRead(widget.otherUserId).catchError((Object _) {}));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _messages = _repo.thread(widget.otherUserId));
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (text != _pendingBody) {
      _requestId = _repo.newRequestId();
      _pendingBody = text;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _repo.send(widget.otherUserId, text, _requestId!);
      if (!mounted) return;
      _input.clear();
      _pendingBody = null;
      _requestId = null;
      _refresh();
    } catch (_) {
      if (!mounted) return;
      // Keep the same request ID for a retry with identical content.
      setState(() => _error = UiText.get('dm_send_failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        height: MediaQuery.sizeOf(context).height * 0.82,
        decoration: const BoxDecoration(
          color: ReferencePalette.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(15, 15, 15, 9),
              padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 6),
              child: Row(children: [
                IconButton(
                  tooltip: UiText.get('reference_dm_back'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_right,
                    color: ReferencePalette.ink),
                ),
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: ReferencePalette.mint,
                  child: Icon(Icons.person_outline_rounded,
                    color: ReferencePalette.deep,size:26),
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(
                  widget.otherDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ReferencePalette.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                )),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded,
                    color: ReferencePalette.teal),
                  tooltip: UiText.get('refresh'),
                ),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFD6EAE0)),
            Expanded(
              child: FutureBuilder<List<DirectMessage>>(
                future: _messages,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _refresh,
                        child: Text(UiText.get('retry')),
                      ),
                    );
                  }
                  final items = snapshot.requireData;
                  if (items.isEmpty) {
                    return Center(child: Text(UiText.get('dm_empty')));
                  }
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  return ListView.builder(
                    reverse: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final own = item.senderId == userId;
                      return Align(
                        alignment:
                            own ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 16),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .75,
                          ),
                          decoration: BoxDecoration(
                            color: own
                                ? const Color(0xFF128D73)
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(own ? 16 : 4),
                              bottomRight: Radius.circular(own ? 4 : 16),
                            ),
                            border: own ? null : Border.all(
                              color: const Color(0xFFDFEEE6)),
                            boxShadow: const [BoxShadow(
                              color: Color(0x100B6549), blurRadius: 10,
                              offset: Offset(0, 3))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item.body,style:TextStyle(
                                color: own ? Colors.white : ReferencePalette.ink,
                                fontSize: 13.5, height:1.3,
                              )),
                              const SizedBox(height: 5),
                              Text(
                                TimeOfDay.fromDateTime(item.createdAt.toLocal())
                                    .format(context),
                                style: TextStyle(
                                  color: own ? Colors.white70 :
                                    const Color(0xFF85998F),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12, 10, 12, MediaQuery.viewInsetsOf(context).bottom + 13),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    maxLength: 2000,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: UiText.get('chat_hint'),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded,
                        color: ReferencePalette.teal),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color:Color(0xFFE1EEE6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color:Color(0xFFE1EEE6)),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: ReferencePalette.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.send_rounded),
                  tooltip: UiText.get('chat_send'),
                ),
              ]),
            ),
          ]),
        ),
      );
}
