import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../data/totichat_services.dart';
import 'financial_retry_registry.dart';
import '../../models/room_models.dart';
import '../../ui/server_panel.dart';
import '../../ui/toti_theme.dart';
import '../../ui/toti_visual_language.dart';
import 'lucky_gift_panel.dart';

class GiftSheet extends StatefulWidget {
  const GiftSheet({
    super.key,required this.api,required this.roomId,required this.members,
  });
  final TotiChatServices api;
  final String roomId;
  final List<RoomMember> members;
  @override State<GiftSheet> createState()=>_GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet>{
  late Future<List<Map<String,dynamic>>> _catalog;
  Map<String,dynamic>? _selected;
  String? _recipient;
  late final FinancialRetryRegistry _retry;
  String get _retryScope => FinancialRetryRegistry.scopeFor(widget.api.client, 'gift');
  bool _showLucky=false;
  int _quantity=1;
  bool _busy=false, _confirming=false;
  @override void initState(){
    super.initState();
    _retry=FinancialRetryRegistry.forClient(widget.api.client);
    _catalog=widget.api.gifts();
  }

  Future<void> _send() async{
    final item=_selected,recipient=_recipient;
    if(_busy||_confirming||item==null||recipient==null)return;
    late final int total;
    try {
      total = TotiChatServices.validatedGiftTotal(item, _quantity);
    } catch (error) {
      if (mounted) showApiError(context, error);
      return;
    }
    final price = TotiChatServices.giftUnitPrice(item['price'])!;
    setState(()=>_confirming=true);
    bool? confirmed;
    try {
      confirmed=await showDialog<bool>(context:context,builder:(ctx)=>
        AlertDialog(title:const Text('تأكيد الهدية'),
          content:Text('إرسال ${item['name']} × $_quantity بقيمة $total كوين؟'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إرسال')),
          ]));
    } finally {
      if(mounted)setState(()=>_confirming=false);
    }
    if(confirmed!=true||!mounted)return;
    final signature = [
      widget.roomId, recipient, item['id'], _quantity, price,
    ].join('|');
    // Reuse the same idempotency key even after this sheet is closed and
    // reopened in the same session. Only a verified receipt releases it.
    late final FinancialPendingIntent pending;
    try {
      pending=_retry.reserve(
        scope:_retryScope,
        signature:signature,
        newRequestId:TotiChatServices.requestId,
      );
    } catch(error) {
      if(mounted)showApiError(context,error);
      return;
    }
    setState(()=>_busy=true);
    try {
      await widget.api.sendGift(roomId:widget.roomId,recipientId:recipient,
        gift:item,quantity:_quantity,requestId:pending.requestId);
      _retry.confirm(scope:_retryScope,requestId:pending.requestId);
      if(mounted)Navigator.pop(context,true);
    } catch(error) {
      if(mounted)showApiError(context,error);
    } finally {
      if(mounted)setState(()=>_busy=false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final participants = widget.members.where((m) => m.seatNo != null).toList();
    final pending = _retry.pending(_retryScope);
    final maxHeight = MediaQuery.sizeOf(context).height * .82;
    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 17, sigmaY: 17),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30)),
              border: const Border(
                top: BorderSide(color: TotiColors.outline),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  17, 12, 17,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Container(
                      width: 46, height: 5,
                      decoration: BoxDecoration(
                        color: TotiColors.outline,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )),
                    const SizedBox(height: 17),
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: TotiColors.heroGradient,
                          borderRadius: BorderRadius.circular(17)),
                        child: const Icon(Icons.card_giftcard_rounded,
                          size: 27, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('صندوق الهدايا الحقيقية',
                            style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900,
                              color: TotiColors.ink)),
                          Text('اختر هدية حقيقية ومستلم من مقاعد الغرفة',
                            style: TextStyle(
                              fontSize: 11, color: TotiColors.muted)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 18),
                    Wrap(spacing: 9, runSpacing: 8, children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.auto_awesome_rounded,
                          size: 16),
                        label: const Text('Regular gifts'),
                        selected: !_showLucky,
                        selectedColor: TotiColors.lavender,
                        onSelected: _busy ? null :
                          (_) => setState(() => _showLucky = false),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.casino_outlined, size: 16),
                        label: const Text('Lucky Gifts'),
                        selected: _showLucky,
                        selectedColor: TotiColors.lavender,
                        onSelected: _busy ? null :
                          (_) => setState(() => _showLucky = true),
                      ),
                    ]),
                    const SizedBox(height: 13),
                    if (_showLucky)
                      LuckyGiftPanel(api: widget.api)
                    else ...[
                      const Text('الهدايا المتاحة',
                        style: TextStyle(color: TotiColors.ink,
                          fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 138,
                        child: ServerPanel<List<Map<String, dynamic>>>(
                          future: _catalog,
                          retry: () => setState(() {
                            _catalog = widget.api.gifts();
                          }),
                          builder: (context, items) {
                            final available = items.where((g) =>
                                g['is_active'] == true &&
                                g['diamond_source_type'] != 'LUCKY_GIFT')
                                .toList();
                            if (available.isEmpty) {
                              return const NoRecords(
                                'ماكو هدايا متاحة حالياً.');
                            }
                            return ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: available.length,
                              separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final gift = available[index];
                                final selected =
                                  _selected?['id'] == gift['id'];
                                return SizedBox(width: 118,
                                  child: ChoiceChip(
                                    selected: selected,
                                    selectedColor: TotiColors.lavender,
                                    onSelected: _busy ? null :
                                      (_) => setState(() => _selected = gift),
                                    padding: const EdgeInsets.all(8),
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.card_giftcard_rounded,
                                          size: 32,
                                          color: selected
                                            ? TotiColors.plum
                                            : TotiColors.pink),
                                        const SizedBox(height: 8),
                                        Text(gift['name']?.toString() ??
                                          'هدية',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text('${gift['price']} كوين',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: TotiColors.muted)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('المستلم',
                        style: TextStyle(color: TotiColors.ink,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (participants.isEmpty)
                        const NoRecords('لا يوجد مستلم جالس على مقعد.')
                      else
                        DropdownButtonFormField<String>(
                          initialValue: participants.any(
                              (m) => m.userId == _recipient)
                            ? _recipient : null,
                          hint: const Text('اختر المستلم من المقاعد'),
                          isExpanded: true,
                          items: participants.map((m) => DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: _busy ? null :
                            (value) => setState(() => _recipient = value),
                        ),
                      const SizedBox(height: 16),
                      const Text('العدد',
                        style: TextStyle(color: TotiColors.ink,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 7, runSpacing: 8, children:
                        [1, 7, 17, 77, 777].map((n) =>
                          ChoiceChip(
                            selected: _quantity == n,
                            selectedColor: TotiColors.lavender,
                            label: Text('$n'),
                            onSelected: _busy ? null :
                              (_) => setState(() => _quantity = n),
                          )).toList()),
                      const SizedBox(height: 16),
                      if (pending != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TotiGlassCard(
                            padding: const EdgeInsets.all(11),
                            child: const Text(
                              'طلب هدية سابق غير محسوم. أعد نفس المستلم والهدية والعدد للتحقق، ولا تبدأ عملية مختلفة.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: TotiColors.ink)),
                          ),
                        ),
                      SizedBox(
                        height: 53,
                        child: FilledButton.icon(
                          onPressed: _busy || _confirming ||
                            _selected == null || _recipient == null
                              ? null : _send,
                          icon: _busy
                            ? const SizedBox(width: 17, height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded),
                          label: const Text('إرسال بعد موافقة الخادم'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
