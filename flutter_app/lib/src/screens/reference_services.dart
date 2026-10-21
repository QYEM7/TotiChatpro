import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/reference_visuals.dart';
import '../core/ui_text.dart';

/// Approved secondary Store design. Read-only real catalog.
class ReferenceStoreScreen extends StatefulWidget {
  const ReferenceStoreScreen({super.key});
  @override
  State<ReferenceStoreScreen> createState() => _ReferenceStoreScreenState();
}

class _ReferenceStoreScreenState extends State<ReferenceStoreScreen> {
  String _category = 'all';
  late Future<List<Map<String,dynamic>>> _future = _read();

  Future<List<Map<String,dynamic>>> _read() async {
    final data = await Supabase.instance.client
      .from('store_catalog')
      .select('id,name,category,price,currency,icon,preview_url')
      .eq('is_active',true)
      .eq('is_reward',false)
      .order('price')
      .limit(120);
    return (data as List).map((r)=>
      Map<String,dynamic>.from(r as Map)).toList(growable:false);
  }

  Future<void> _refresh() async {
    final next=_read();
    setState(()=>_future=next);
    try { await next; } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key:const Key('reference-store-screen'),
    backgroundColor:ReferencePalette.canvas,
    appBar:AppBar(
      backgroundColor:ReferencePalette.canvas,
      title:Text(UiText.get('reference_store_title'),
        style:const TextStyle(color:ReferencePalette.ink,
          fontWeight:FontWeight.w900)),
    ),
    body:Column(children:[
      Padding(
        padding:const EdgeInsets.fromLTRB(14,8,14,14),
        child:ReferenceVipStrip(
          title:'TotiChat VIP',
          description:UiText.get('reference_store_intro'),
        ),
      ),
      SizedBox(height:47,child:ListView(
        scrollDirection:Axis.horizontal,
        padding:const EdgeInsets.symmetric(horizontal:13),
        children:[
          for(final entry in <(String,String)>[
            ('all','reference_store_all'),
            ('frames','reference_store_frames'),
            ('cars','reference_store_cars'),
            ('bubbles','reference_store_bubbles'),
            ('entrances','reference_store_entry'),
            ('vip','reference_store_vip'),
            ('cards','reference_store_cards'),
          ])
            Padding(
              padding:const EdgeInsetsDirectional.only(end:7),
              child:ChoiceChip(
                label:Text(UiText.get(entry.$2)),
                selected:_category==entry.$1,
                onSelected:(_)=>setState(()=>_category=entry.$1),
                selectedColor:ReferencePalette.teal,
                labelStyle:TextStyle(color:_category==entry.$1
                  ?Colors.white:ReferencePalette.deep,
                  fontSize:12,fontWeight:FontWeight.w700),
                side:const BorderSide(color:Color(0xFFDAEBDD)),
                backgroundColor:Colors.white,
              ),
            ),
        ],
      )),
      const SizedBox(height:6),
      Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(
        future:_future,
        builder:(context,snapshot) {
          if(snapshot.connectionState!=ConnectionState.done) {
            return const Center(child:CircularProgressIndicator(
              color:ReferencePalette.teal));
          }
          if(snapshot.hasError) return _notice(UiText.get('reference_store_failed'),_refresh);
          final products=snapshot.requireData.where((product)=>
            _category=='all'||product['category']==_category).toList(growable:false);
          if(products.isEmpty) return _notice(UiText.get('reference_store_empty'),_refresh);
          return RefreshIndicator(
            onRefresh:_refresh,
            child:GridView.builder(
              padding:const EdgeInsets.fromLTRB(14,10,14,24),
              itemCount:products.length,
              gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:230,mainAxisSpacing:12,crossAxisSpacing:12,
                childAspectRatio:.8,
              ),
              itemBuilder:(context,index) {
                final p=products[index];
                final preview=p['preview_url']?.toString();
                return Container(
                  padding:const EdgeInsets.all(9),
                  decoration:BoxDecoration(
                    color:Colors.white,
                    borderRadius:BorderRadius.circular(19),
                    border:Border.all(color:const Color(0xFFE2EFE6)),
                  ),
                  child:Column(children:[
                    Expanded(child:ClipRRect(
                      borderRadius:BorderRadius.circular(13),
                      child:Container(
                        width:double.infinity,
                        color:ReferencePalette.paleMint,
                        child:preview==null||preview.isEmpty
                          ?Center(child:Text(p['icon']?.toString()??'',
                            style:const TextStyle(fontSize:43)))
                          :Image.network(preview,fit:BoxFit.cover,
                            errorBuilder:(_,_,_)=>const Icon(
                              Icons.card_giftcard,color:ReferencePalette.teal,size:44)),
                      ),
                    )),
                    const SizedBox(height:9),
                    Text(p['name']?.toString()??'',
                      maxLines:2,overflow:TextOverflow.ellipsis,
                      textAlign:TextAlign.center,
                      style:const TextStyle(
                        fontSize:13,color:ReferencePalette.ink,
                        fontWeight:FontWeight.w900)),
                    const SizedBox(height:7),
                    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      const Icon(Icons.monetization_on_outlined,
                        size:16,color:ReferencePalette.gold),
                      const SizedBox(width:4),
                      Flexible(child:Text(
                        '${p['price']??''} ${p['currency']??''}',
                        maxLines:1,overflow:TextOverflow.ellipsis,
                        style:const TextStyle(color:ReferencePalette.deep,
                          fontWeight:FontWeight.w900,fontSize:12))),
                    ]),
                    const SizedBox(height:7),
                    Text(UiText.get('reference_store_preview_only'),
                      textAlign:TextAlign.center,
                      style:const TextStyle(
                        fontSize:10,color:Color(0xFF83968A))),
                  ]),
                );
              },
            ),
          );
        },
      )),
    ]),
  );

  Widget _notice(String label,Future<void> Function() retry)=>
    Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.storefront_outlined,color:ReferencePalette.gold,size:52),
      const SizedBox(height:12),
      Text(label,textAlign:TextAlign.center),
      const SizedBox(height:9),
      OutlinedButton(onPressed:retry,child:Text(UiText.get('retry'))),
    ]));
}

/// Server-accepted relationships only; no fabricated partners or CP levels.
class ReferenceCpScreen extends StatefulWidget {
  const ReferenceCpScreen({super.key});
  @override
  State<ReferenceCpScreen> createState() => _ReferenceCpScreenState();
}

class _ReferenceCpScreenState extends State<ReferenceCpScreen> {
  late final Future<List<Map<String,dynamic>>> _relationships = _load();

  Future<List<Map<String,dynamic>>> _load() async {
    final uid=Supabase.instance.client.auth.currentUser?.id;
    if(uid==null)throw StateError('Authenticated user required');
    final rows=await Supabase.instance.client.from('cp_relationships')
      .select('id,type_id,accepted_at,ended_at')
      .or('user_a.eq.$uid,user_b.eq.$uid')
      .not('accepted_at','is',null)
      .isFilter('ended_at',null)
      .order('accepted_at',ascending:false);
    return (rows as List).map((x)=>
      Map<String,dynamic>.from(x as Map)).toList(growable:false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key:const Key('reference-cp-screen'),
    backgroundColor:ReferencePalette.canvas,
    appBar:AppBar(title:Text(UiText.get('reference_cp_title'),
      style:const TextStyle(color:ReferencePalette.ink,
        fontWeight:FontWeight.w900))),
    body:ListView(padding:const EdgeInsets.all(17),children:[
      Container(
        padding:const EdgeInsets.all(21),
        decoration:BoxDecoration(
          gradient:const LinearGradient(colors:[
            Color(0xFF17372F),Color(0xFF096B51),Color(0xFF233B31)]),
          borderRadius:BorderRadius.circular(23),
          border:Border.all(color:ReferencePalette.gold),
        ),
        child:Column(children:[
          const Icon(Icons.favorite_outline,
            color:ReferencePalette.paleGold,size:46),
          const SizedBox(height:10),
          Text(UiText.get('reference_cp_banner'),
            style:const TextStyle(color:Colors.white,
              fontSize:20,fontWeight:FontWeight.w900)),
          const SizedBox(height:7),
          Text(UiText.get('reference_cp_intro'),
            textAlign:TextAlign.center,
            style:const TextStyle(color:Color(0xFFE5F6E9),
              fontSize:12)),
        ]),
      ),
      const SizedBox(height:22),
      ReferenceSection(title:UiText.get('reference_cp_active')),
      const SizedBox(height:9),
      FutureBuilder<List<Map<String,dynamic>>>(
        future:_relationships,
        builder:(context,snapshot) {
          if(snapshot.connectionState!=ConnectionState.done) {
            return const Center(child:LinearProgressIndicator(
              color:ReferencePalette.teal));
          }
          if(snapshot.hasError) {
            return Text(UiText.get('reference_cp_failed'));
          }
          final rows=snapshot.requireData;
          if(rows.isEmpty) return Container(
            padding:const EdgeInsets.all(18),
            decoration:BoxDecoration(
              color:Colors.white,borderRadius:BorderRadius.circular(17)),
            child:Text(UiText.get('reference_cp_empty'),
              textAlign:TextAlign.center));
          return Column(children:[
            for(final row in rows)
              ReferenceInfoTile(
                title:row['type_id']?.toString()??'',
                icon:Icons.favorite_outline,
                subtitle:row['accepted_at']?.toString().split('T').first,
              ),
          ]);
        },
      ),
    ]),
  );
}

/// Agency browser; business membership mutations require server workflow.
class ReferenceAgenciesScreen extends StatefulWidget {
  const ReferenceAgenciesScreen({super.key});
  @override
  State<ReferenceAgenciesScreen> createState()=>_ReferenceAgenciesState();
}

class _ReferenceAgenciesState extends State<ReferenceAgenciesScreen> {
  late final Future<List<Map<String,dynamic>>> _agencies=_load();

  Future<List<Map<String,dynamic>>> _load() async {
    final rows=await Supabase.instance.client.from('agencies')
      .select('id,name,kind')
      .eq('is_active',true).order('name').limit(50);
    return (rows as List).map((r)=>
      Map<String,dynamic>.from(r as Map)).toList(growable:false);
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    key:const Key('reference-agencies-screen'),
    backgroundColor:ReferencePalette.canvas,
    appBar:AppBar(title:Text(UiText.get('reference_agencies_title'),
      style:const TextStyle(
        color:ReferencePalette.ink,fontWeight:FontWeight.w900))),
    body:FutureBuilder<List<Map<String,dynamic>>>(
      future:_agencies,
      builder:(context,snapshot) {
        if(snapshot.connectionState!=ConnectionState.done) {
          return const Center(child:CircularProgressIndicator(
            color:ReferencePalette.teal));
        }
        if(snapshot.hasError) {
          return Center(child:Text(UiText.get('reference_agencies_failed')));
        }
        final rows=snapshot.requireData;
        return ListView(padding:const EdgeInsets.all(17),children:[
          Container(
            padding:const EdgeInsets.all(21),
            decoration:BoxDecoration(
              color:ReferencePalette.deep,
              borderRadius:BorderRadius.circular(22),
              border:Border.all(color:ReferencePalette.gold),
            ),
            child:Row(children:[
              const Icon(Icons.apartment_rounded,
                color:ReferencePalette.paleGold,size:45),
              const SizedBox(width:14),
              Expanded(child:Text(UiText.get('reference_agencies_intro'),
                style:const TextStyle(color:Colors.white,
                  fontSize:15,fontWeight:FontWeight.w800))),
            ]),
          ),
          const SizedBox(height:22),
          ReferenceSection(title:UiText.get('reference_agencies_available')),
          const SizedBox(height:12),
          if(rows.isEmpty) Padding(
            padding:const EdgeInsets.all(22),
            child:Text(UiText.get('reference_agencies_empty'),
              textAlign:TextAlign.center),
          ),
          for(final row in rows)
            ReferenceInfoTile(
              title:row['name']?.toString()??'',
              subtitle:row['kind']?.toString(),
              icon:Icons.groups_2_outlined,
            ),
        ]);
      },
    ),
  );
}
