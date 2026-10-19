import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../data/direct_message_repository.dart';
import 'direct_chat_sheet.dart';

class DirectInboxView extends StatefulWidget {
  const DirectInboxView({super.key});

  @override
  State<DirectInboxView> createState() => _DirectInboxViewState();
}

class _DirectInboxViewState extends State<DirectInboxView> {
  late final DirectMessageRepository _repo =
      DirectMessageRepository(Supabase.instance.client);
  late Future<List<DirectInboxItem>> _inbox = _repo.inbox();

  Future<void> _refresh() async {
    final next = _repo.inbox();
    setState(() => _inbox = next);
    try {
      await next;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  Future<void> _open(DirectInboxItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DirectChatSheet(
        otherUserId: item.otherUserId,
        otherDisplayName: item.displayName,
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DirectInboxItem>>(
        future: _inbox,
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: items.isEmpty
                ? ListView(children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .45,
                      child: Center(child: Text(UiText.get('dm_inbox_empty'))),
                    ),
                  ])
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(item.displayName),
                        subtitle: Text(item.lastBody,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: item.unreadCount > 0
                            ? CircleAvatar(
                                radius: 13,
                                child: Text(
                                  '${item.unreadCount}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              )
                            : null,
                        onTap: () => _open(item),
                      );
                    },
                  ),
          );
        },
      );
}
