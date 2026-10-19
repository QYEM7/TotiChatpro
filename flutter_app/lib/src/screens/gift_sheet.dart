import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../data/gift_repository.dart';
import '../data/room_repository.dart';

class GiftSheet extends StatefulWidget {
  const GiftSheet({super.key, required this.roomId, required this.members});
  final String roomId;
  final List<RoomSeatMember> members;

  @override
  State<GiftSheet> createState() => _GiftSheetState();
}

class _GiftData {
  const _GiftData(this.items, this.balance);
  final List<GiftItem> items;
  final WalletBalance balance;
}

class _GiftSheetState extends State<GiftSheet> {
  late final GiftRepository _repo =
      GiftRepository(Supabase.instance.client);
  late Future<_GiftData> _data = _load();
  GiftItem? _selected;
  String? _recipient;
  String? _requestId;
  int _quantity = 1;
  bool _sending = false;
  String? _error;

  Future<_GiftData> _load() async {
    final balance = await _repo.balance();
    final items = await _repo.gifts();
    return _GiftData(items, balance);
  }

  void _changeSelection({GiftItem? gift, String? recipient, int? quantity}) {
    setState(() {
      if (gift != null) _selected = gift;
      if (recipient != null) _recipient = recipient;
      if (quantity != null) _quantity = quantity;
      _requestId = null; // New payload => new idempotency identity.
      _error = null;
    });
  }

  Future<void> _send() async {
    final gift = _selected;
    final recipient = _recipient;
    if (_sending || gift == null || recipient == null) {
      setState(() => _error = UiText.get('gift_select_recipient'));
      return;
    }
    final requestId = _requestId ??= _repo.newRequestId();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final receipt = await _repo.send(
        roomId: widget.roomId,
        recipientId: recipient,
        gift: gift,
        quantity: _quantity,
        requestId: requestId,
      );
      if (!mounted) return;
      Navigator.of(context).pop<GiftReceipt>(receipt);
    } catch (_) {
      if (!mounted) return;
      // Retain the same key on retry to avoid a second debit when a response
      // was lost after a successful first financial settlement.
      setState(() => _error = UiText.get('gift_failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final recipients = widget.members
        .where((m) => m.userId != userId)
        .toList(growable: false);
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.69,
      decoration: const BoxDecoration(
        color: Color(0xF2180F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: FutureBuilder<_GiftData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(UiText.get('wallet_no_balance'),
                      style: const TextStyle(color: Colors.white)),
                  TextButton(
                    onPressed: () => setState(() => _data = _load()),
                    child: Text(UiText.get('retry')),
                  ),
                ],
              ));
            }
            final model = snapshot.requireData;
            return Column(children: [
              const SizedBox(height: 12),
              Text(UiText.get('gift'),
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 20, fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 10),
              Text(
                '${UiText.get('wallet_coins')}: ${model.balance.coins}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _recipient,
                  dropdownColor: const Color(0xFF24143C),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    label: Text(UiText.get('gift_select_recipient'),
                        style: const TextStyle(color: Colors.white)),
                    border: const OutlineInputBorder(),
                  ),
                  items: recipients.map((member) =>
                    DropdownMenuItem(
                      value: member.userId,
                      child: Text(member.displayName),
                    )).toList(growable: false),
                  onChanged: _sending
                      ? null
                      : (value) {
                          if (value != null) _changeSelection(recipient: value);
                        },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: model.items.isEmpty
                    ? Center(child: Text(UiText.get('gift_no_catalog'),
                        style: const TextStyle(color: Colors.white)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: model.items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.91,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final gift = model.items[index];
                          final selected = gift.id == _selected?.id;
                          return InkWell(
                            onTap: _sending ? null :
                                () => _changeSelection(gift: gift),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFF2F1A4C),
                                border: Border.all(
                                  color: selected
                                    ? const Color(0xFFFBBF24)
                                    : Colors.white24,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(gift.icon,
                                      style: const TextStyle(fontSize: 25)),
                                  Text(gift.name, maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white, fontSize: 11,
                                      )),
                                  Text('${gift.price}',
                                      style: const TextStyle(
                                        color: Color(0xFFFBBF24),
                                      )),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [1, 7, 17, 77, 777].map((count) =>
                    ChoiceChip(
                      label: Text('$count'),
                      selected: count == _quantity,
                      onSelected: _sending ? null :
                          (_) => _changeSelection(quantity: count),
                    )).toList(growable: false),
              ),
              if (_error != null)
                Text(_error!,
                    style: const TextStyle(color: Color(0xFFFFB4AB))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sending ||
                        recipients.isEmpty ||
                        _selected == null ||
                        _recipient == null
                            ? null : _send,
                    child: Text(_sending
                        ? UiText.get('please_wait')
                        : UiText.get('gift_send')),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
