import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../core/reference_visuals.dart';
import '../data/room_creation_service.dart';
import '../data/room_repository.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _welcome = TextEditingController();
  late final RoomCreationService _service =
      RoomCreationService(Supabase.instance.client);
  Uint8List? _cover;
  bool _busy = false;
  bool _isPrivate = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _welcome.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_busy) return;
    try {
      final selected = await _service.chooseCover();
      if (selected == null) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final webp = await _service.prepareWebp(selected);
      if (!mounted) return;
      setState(() => _cover = webp);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = UiText.get('room_image_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final cover = _cover;
    if (cover == null) {
      setState(() => _error = UiText.get('room_image_required'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await _service.create(
        title: _title.text,
        welcomeMessage: _welcome.text,
        cover: cover,
        isPrivate: _isPrivate,
      );
      if (!mounted) return;
      Navigator.of(context).pop<RoomSummary>(room);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = UiText.get('room_create_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _fieldHeading(String title,{bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(title,style: const TextStyle(
        fontSize: 13,fontWeight: FontWeight.w800,color: ReferencePalette.ink,
      )),
      if(required) const Text(' *',style: TextStyle(
        color: Color(0xFFBD4F57),fontSize: 15,fontWeight: FontWeight.w900)),
    ]),
  );

  InputDecoration _fieldDecoration(String hint,{IconData? icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12,color: Color(0xFF899C91)),
        prefixIcon: icon==null ? null : Icon(icon,size:21,color:ReferencePalette.teal),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15,vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color:Color(0xFFDAEAE2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color:Color(0xFFDAEAE2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color:ReferencePalette.teal,width:1.5),
        ),
      );

  Widget _coverInput() => InkWell(
    key: const Key('reference-room-cover-picker'),
    borderRadius: BorderRadius.circular(20),
    onTap: _busy ? null : _pickCover,
    child: Container(
      height: 174,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:ReferencePalette.deep,
        borderRadius: BorderRadius.circular(20),
        border:Border.all(color:ReferencePalette.gold.withValues(alpha:.7)),
      ),
      child: Stack(fit: StackFit.expand, children: [
        if(_cover != null) Image.memory(_cover!,fit:BoxFit.cover)
        else const CustomPaint(painter: WelcomeIllumination()),
        if(_cover==null) const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,end: Alignment.bottomRight,
            colors:[Color(0x88002820),Color(0x55005848),Color(0x99001B16)],
          ),
        )),
        Center(child: Container(
          padding:const EdgeInsets.symmetric(horizontal:16,vertical:13),
          decoration:BoxDecoration(
            color:const Color(0xDD082E29),
            borderRadius:BorderRadius.circular(17),
            border:Border.all(color:const Color(0x88DBB576)),
          ),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Icon(_cover==null ? Icons.add_a_photo_outlined : Icons.edit_outlined,
              color:ReferencePalette.paleGold,size:29),
            const SizedBox(height:5),
            Text(UiText.get('room_pick_cover'),
              style:const TextStyle(color:Colors.white,fontSize:12,
                fontWeight:FontWeight.w800)),
          ]),
        )),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('reference-create-room'),
    backgroundColor:ReferencePalette.canvas,
    appBar:AppBar(
      backgroundColor: ReferencePalette.canvas,
      centerTitle:true,
      elevation:0,
      title:Text(UiText.get('room_create'),
        style:const TextStyle(color:ReferencePalette.ink,
          fontSize:19,fontWeight:FontWeight.w900)),
    ),
    bottomNavigationBar:SafeArea(top:false,child:Container(
      padding:const EdgeInsets.fromLTRB(16,10,16,15),
      color:ReferencePalette.canvas,
      child:FilledButton.icon(
        key:const Key('reference-submit-room'),
        onPressed:_busy?null:_create,
        style:FilledButton.styleFrom(
          backgroundColor:ReferencePalette.teal,
          foregroundColor:Colors.white,
          minimumSize:const Size.fromHeight(53),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        ),
        icon:const Icon(Icons.add_circle_outline_rounded),
        label:Text(UiText.get('room_create'),style:const TextStyle(
          fontSize:15,fontWeight:FontWeight.w900)),
      ),
    )),
    body:SafeArea(child:Form(
      key:_formKey,
      child:ListView(
        padding:const EdgeInsets.fromLTRB(18,11,18,22),
        children:[
          _fieldHeading(UiText.get('reference_create_cover_label'),required:true),
          _coverInput(),
          const SizedBox(height:19),
          _fieldHeading(UiText.get('room_name_label'),required:true),
          TextFormField(
            key:const Key('reference-room-name'),
            controller:_title,
            maxLength:60,
            decoration:_fieldDecoration(UiText.get('reference_room_name_hint')),
            validator:(value) {
              final n=value?.trim().length??0;
              return n<2||n>60?UiText.get('room_name_required'):null;
            },
          ),
          const SizedBox(height:11),
          _fieldHeading(UiText.get('room_welcome_label'),required:true),
          TextFormField(
            key:const Key('reference-room-welcome'),
            controller:_welcome,
            maxLength:500,
            minLines:3,maxLines:5,
            decoration:_fieldDecoration(UiText.get('reference_room_welcome_hint')),
            validator:(value)=>(value?.trim().isEmpty??true)
              ?UiText.get('room_welcome_required'):null,
          ),
          const SizedBox(height:11),
          _fieldHeading(UiText.get('reference_room_category')),
          Container(
            padding:const EdgeInsets.symmetric(horizontal:13,vertical:13),
            decoration:BoxDecoration(
              color:Colors.white,
              borderRadius:BorderRadius.circular(13),
              border:Border.all(color:const Color(0xFFDAEAE2)),
            ),
            child:Row(children:[
              const Icon(Icons.headset_mic_outlined,
                color:ReferencePalette.teal,size:22),
              const SizedBox(width:9),
              Text(UiText.get('reference_voice_category'),
                style:const TextStyle(fontSize:13,color:ReferencePalette.ink,
                  fontWeight:FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.verified_outlined,
                size:18,color:ReferencePalette.teal),
            ]),
          ),
          const SizedBox(height:19),
          _fieldHeading(UiText.get('reference_room_privacy')),
          Row(children:[
            Expanded(child:_privacyChoice(
              value:false,
              icon:Icons.public,
              title:UiText.get('reference_room_public'),
            )),
            const SizedBox(width:9),
            Expanded(child:_privacyChoice(
              value:true,
              icon:Icons.lock_outline_rounded,
              title:UiText.get('reference_room_private'),
            )),
          ]),
          const SizedBox(height:8),
          Text(UiText.get('reference_room_privacy_helper'),
            style:const TextStyle(fontSize:11,color:Color(0xFF748E7F))),
          if(_error!=null) Padding(
            padding:const EdgeInsets.symmetric(vertical:14),
            child:Text(_error!,textAlign:TextAlign.center,
              style:const TextStyle(color:Color(0xFFA92F38))),
          ),
          if(_busy) const Padding(
            padding:EdgeInsets.all(12),
            child:LinearProgressIndicator(color:ReferencePalette.teal)),
        ],
      ),
    )),
  );

  Widget _privacyChoice({
    required bool value,
    required IconData icon,
    required String title,
  }) {
    final selected=_isPrivate==value;
    return Material(
      color:selected?ReferencePalette.teal:Colors.white,
      borderRadius:BorderRadius.circular(14),
      child:InkWell(
        onTap:_busy?null:()=>setState(()=>_isPrivate=value),
        borderRadius:BorderRadius.circular(14),
        child:Container(
          padding:const EdgeInsets.symmetric(vertical:13,horizontal:10),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(14),
            border:Border.all(
              color:selected?ReferencePalette.teal:const Color(0xFFD8E9E0)),
          ),
          child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(selected?Icons.check_circle_rounded:icon,
              size:18,color:selected?Colors.white:ReferencePalette.deep),
            const SizedBox(width:7),
            Flexible(child:Text(title,
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:TextStyle(color:selected?Colors.white:ReferencePalette.ink,
                fontSize:13,fontWeight:FontWeight.w800))),
          ]),
        ),
      ),
    );
  }
}
