import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
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
        height: MediaQuery.sizeOf(context).height * 0.76,
        decoration: const BoxDecoration(
          color: Color(0xFFF4FBF7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(children: [
            const SizedBox(height: 14),
            Text(widget.otherDisplayName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
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
                                ? const Color(0xFFD5F5E5)
                                : const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(item.body),
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
                12, 6, 12, MediaQuery.viewInsetsOf(context).bottom + 12),
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
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  tooltip: UiText.get('chat_send'),
                ),
              ]),
            ),
          ]),
        ),
      );
}
