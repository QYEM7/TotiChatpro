import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../core/reference_visuals.dart';
import '../data/direct_message_repository.dart';
import 'direct_chat_sheet.dart';

/// Design board #06: rich emerald inbox with authenticated messages only.
/// No sample users, unseen notification badges or fabricated conversations.
class DirectInboxView extends StatefulWidget {
  const DirectInboxView({super.key});

  @override
  State<DirectInboxView> createState() => _DirectInboxViewState();
}

class _DirectInboxViewState extends State<DirectInboxView> {
  late final DirectMessageRepository _repo =
      DirectMessageRepository(Supabase.instance.client);
  late Future<List<DirectInboxItem>> _inbox = _repo.inbox();
  final _search = TextEditingController();
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_queryUpdated);
  }

  void _queryUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.removeListener(_queryUpdated);
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = _repo.inbox();
    setState(() => _inbox = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder renders an actionable error.
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

  Widget _filter(String label, bool unread) => Expanded(child: ChoiceChip(
    key: Key('reference-dm-tab-${unread ? 'unread' : 'all'}'),
    selected: unread == _unreadOnly,
    onSelected: (_) => setState(() => _unreadOnly = unread),
    selectedColor: ReferencePalette.teal,
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFD7EDE2)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    label: SizedBox(width: double.infinity,child: Center(child:Text(
      label,
      style: TextStyle(
        color: _unreadOnly == unread ? Colors.white : ReferencePalette.deep,
        fontWeight: FontWeight.w800,
      ),
    ))),
  ));

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(17, 6, 17, 5),
      child: Row(children: [
        Text(UiText.get('messages'), style: const TextStyle(
          color: ReferencePalette.ink,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        )),
        const Spacer(),
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, color: ReferencePalette.deep),
          tooltip: UiText.get('refresh'),
        ),
      ]),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 7),
      child: TextField(
        key: const Key('reference-dm-search'),
        controller: _search,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          hintText: UiText.get('reference_dm_search'),
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
            color: ReferencePalette.teal),
          suffixIcon: _search.text.isEmpty ? null : IconButton(
            onPressed: _search.clear,
            icon: const Icon(Icons.close),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE3EEE7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE3EEE7)),
          ),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(15, 3, 15, 10),
      child: Row(children: [
        _filter(UiText.get('reference_dm_all'), false),
        const SizedBox(width: 9),
        _filter(UiText.get('reference_dm_unread'), true),
      ]),
    ),
    Expanded(child: FutureBuilder<List<DirectInboxItem>>(
      future: _inbox,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: ReferencePalette.teal));
        }
        if (snapshot.hasError) {
          return Center(child:Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(UiText.get('reference_dm_failed')),
              OutlinedButton(onPressed: _refresh,
                child: Text(UiText.get('retry'))),
            ],
          ));
        }
        final q = _search.text.trim().toLowerCase();
        final items = snapshot.requireData.where((item) {
          if (_unreadOnly && item.unreadCount == 0) return false;
          if (q.isNotEmpty && !item.displayName.toLowerCase().contains(q)) {
            return false;
          }
          return true;
        }).toList(growable: false);
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * .35,
                child: Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: Column(mainAxisSize:MainAxisSize.min,children:[
                    Container(width: 78,height:78,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,color: ReferencePalette.mint),
                      child: const Icon(Icons.mark_chat_read_outlined,
                        size: 40,color: ReferencePalette.teal)),
                    const SizedBox(height: 14),
                    Text(UiText.get('dm_inbox_empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800,color: ReferencePalette.deep)),
                    const SizedBox(height: 7),
                    Text(UiText.get('reference_dm_empty_details'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12,
                        color: Color(0xFF6E8A7F))),
                  ]),
                )),
              ),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 30),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context,index) {
              final item = items[index];
              return Material(
                borderRadius: BorderRadius.circular(17),
                color: Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => _open(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,vertical: 14),
                    child: Row(children: [
                      Container(
                        height: 51,width: 51,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ReferencePalette.mint,
                          border: Border.all(
                            color: ReferencePalette.gold.withValues(alpha:.65),
                            width: 1.5),
                        ),
                        child: const Icon(Icons.person_outline_rounded,
                          color: ReferencePalette.deep,size: 28),
                      ),
                      const SizedBox(width: 11),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.displayName,maxLines:1,
                            overflow:TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ReferencePalette.ink,
                              fontSize: 15,fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(item.lastBody,maxLines:1,
                            overflow:TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF76877F),fontSize: 12)),
                        ],
                      )),
                      if(item.unreadCount > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 21),
                          padding:const EdgeInsets.symmetric(
                            vertical:4,horizontal:6),
                          decoration:const BoxDecoration(
                            shape: BoxShape.circle,color: Color(0xFFE74451)),
                          child: Text('${item.unreadCount}',
                            textAlign:TextAlign.center,
                            style:const TextStyle(fontSize:11,color:Colors.white,
                              fontWeight:FontWeight.w800)),
                        )
                      else
                        const Icon(Icons.chevron_left_rounded,
                          color: ReferencePalette.teal),
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      },
    )),
  ]);
}
