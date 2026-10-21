import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/reference_visuals.dart';
import '../core/ui_text.dart';
import '../data/gift_repository.dart';

class _WalletView {
  const _WalletView(this.balance, this.entries);
  final WalletBalance balance;
  final List<Map<String, dynamic>> entries;
}

/// Design board #05: real authenticated wallet. No card recharge, fake
/// financial values, or frontend balance changes. Agents fund coins elsewhere.
class ReferenceWalletScreen extends StatefulWidget {
  const ReferenceWalletScreen({super.key});

  @override
  State<ReferenceWalletScreen> createState() => _ReferenceWalletScreenState();
}

class _ReferenceWalletScreenState extends State<ReferenceWalletScreen> {
  late Future<_WalletView> _future = _load();

  Future<_WalletView> _load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Authenticated wallet required');
    final balance = await GiftRepository(client).balance();
    final data = await client.from('wallet_ledger')
      .select('id,currency,amount_change,balance_after,kind,created_at')
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(40);
    return _WalletView(balance,
      (data as List).map((item) =>
        Map<String,dynamic>.from(item as Map)).toList(growable: false));
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try { await next; } catch (_) {
      // The future builder owns the retry/error UI.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('reference-wallet-screen'),
    backgroundColor: ReferencePalette.canvas,
    appBar: AppBar(
      backgroundColor: ReferencePalette.canvas,
      title: Text(UiText.get('wallet_balance'),
        style: const TextStyle(
          color:ReferencePalette.ink,fontWeight:FontWeight.w900)),
      actions: [IconButton(onPressed:_refresh,
        tooltip:UiText.get('refresh'),
        icon:const Icon(Icons.refresh_rounded,color:ReferencePalette.deep))],
    ),
    body:FutureBuilder<_WalletView>(
      future:_future,
      builder:(context,snapshot) {
        if(snapshot.connectionState!=ConnectionState.done) {
          return const Center(child:CircularProgressIndicator(
            color:ReferencePalette.teal));
        }
        if(snapshot.hasError || !snapshot.hasData) {
          return Center(child: Column(
            mainAxisSize:MainAxisSize.min,children:[
              const Icon(Icons.account_balance_wallet_outlined,
                color:ReferencePalette.gold,size:51),
              const SizedBox(height:9),
              Text(UiText.get('reference_wallet_failed')),
              const SizedBox(height:12),
              OutlinedButton(onPressed:_refresh,child:Text(UiText.get('retry'))),
            ],
          ));
        }
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh:_refresh,
          child:ListView(
            padding: const EdgeInsets.fromLTRB(17,8,17,28),
            children:[
              Container(
                padding:const EdgeInsets.fromLTRB(20,22,20,21),
                decoration:BoxDecoration(
                  borderRadius:BorderRadius.circular(22),
                  gradient:const LinearGradient(colors:[
                    Color(0xFF00362E),Color(0xFF126451),Color(0xFF002A24)]),
                  border:Border.all(
                    color:ReferencePalette.gold.withValues(alpha:.66)),
                  boxShadow:const [BoxShadow(
                    blurRadius:18,offset:Offset(0,9),color:Color(0x25004A3C)),
                  ],
                ),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    const Row(children:[
                      Icon(Icons.workspace_premium_outlined,
                        size:23,color:ReferencePalette.paleGold),
                      SizedBox(width:8),
                      Text('TotiChat',
                        style:TextStyle(color:ReferencePalette.paleGold,
                          fontWeight:FontWeight.w900,fontSize:16)),
                    ]),
                    const SizedBox(height:18),
                    Text(UiText.get('reference_wallet_total'),
                      style:const TextStyle(color:Color(0xFFC1E5DA),
                        fontSize:12)),
                    const SizedBox(height:12),
                    Row(children:[
                      _currency(
                        Icons.monetization_on_outlined,
                        UiText.get('wallet_coins'),
                        data.balance.coins.toString(),
                      ),
                      const SizedBox(width:14),
                      _currency(
                        Icons.diamond_outlined,
                        UiText.get('wallet_diamonds'),
                        data.balance.diamonds.toString(),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height:18),
              Container(
                padding:const EdgeInsets.all(15),
                decoration:BoxDecoration(
                  borderRadius:BorderRadius.circular(17),
                  color:ReferencePalette.paleMint,
                  border:Border.all(color:const Color(0xFFCBEBD8)),
                ),
                child:Row(children:[
                  const Icon(Icons.verified_user_outlined,
                    color:ReferencePalette.deep,size:25),
                  const SizedBox(width:13),
                  Expanded(child:Text(UiText.get('reference_wallet_agent_notice'),
                    style:const TextStyle(color:ReferencePalette.ink,
                      fontSize:12,height:1.35))),
                ]),
              ),
              const SizedBox(height:25),
              ReferenceSection(title:UiText.get('reference_wallet_history')),
              const SizedBox(height:12),
              if(data.entries.isEmpty)
                Container(
                  padding:const EdgeInsets.all(22),
                  decoration:BoxDecoration(
                    borderRadius:BorderRadius.circular(18),color:Colors.white),
                  child:Column(children:[
                    const Icon(Icons.receipt_long_outlined,
                      size:34,color:ReferencePalette.teal),
                    const SizedBox(height:9),
                    Text(UiText.get('reference_wallet_no_history'),
                      textAlign:TextAlign.center,
                      style:const TextStyle(color:ReferencePalette.ink)),
                  ]),
                ),
              for(final record in data.entries)
                _entry(record),
            ],
          ),
        );
      },
    ),
  );

  Widget _currency(IconData icon,String label,String amount)=>Expanded(
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Icon(icon,size:17,color:ReferencePalette.paleGold),
        const SizedBox(width:5),
        Flexible(child:Text(label,
          style:const TextStyle(color:Colors.white70,fontSize:11))),
      ]),
      const SizedBox(height:6),
      Text(amount,maxLines:1,overflow:TextOverflow.ellipsis,
        style:const TextStyle(
          color:Colors.white,fontSize:26,fontWeight:FontWeight.w900)),
    ]),
  );

  Widget _entry(Map<String,dynamic> record) {
    final amount = (record['amount_change'] as num?)?.toInt();
    final positive = amount != null && amount >= 0;
    return Container(
      margin:const EdgeInsets.only(bottom:8),
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(
        color:Colors.white,borderRadius:BorderRadius.circular(16),
        border:Border.all(color:const Color(0xFFE0EFE6)),
      ),
      child:Row(children:[
        CircleAvatar(backgroundColor:ReferencePalette.paleMint,
          child:Icon(positive?Icons.south_west_rounded:Icons.north_east_rounded,
            color:ReferencePalette.teal,size:21)),
        const SizedBox(width:11),
        Expanded(child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(record['kind']?.toString() ?? '',
              style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800,
                color:ReferencePalette.ink)),
            const SizedBox(height:5),
            Text(record['created_at']?.toString().split('T').first ?? '',
              style:const TextStyle(fontSize:11,color:Color(0xFF85978B))),
          ],
        )),
        Text('${amount != null && positive ? '+' : ''}${amount ?? '—'} '
          '${record['currency'] ?? ''}',
          style:TextStyle(fontWeight:FontWeight.w900,
            color:positive?ReferencePalette.teal:const Color(0xFFBD5664))),
      ]),
    );
  }
}
