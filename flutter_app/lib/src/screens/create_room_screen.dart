import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFFDFBF7),
        appBar: AppBar(title: Text(UiText.get('room_create'))),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              InkWell(
                onTap: _busy ? null : _pickCover,
                child: Center(
                  child: Container(
                    height: 168,
                    width: 168,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: _cover == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined, size: 40),
                              Text(UiText.get('room_pick_cover')),
                            ],
                          )
                        : Image.memory(_cover!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: UiText.get('room_name_label'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 2 || length > 60) {
                    return UiText.get('room_name_required');
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _welcome,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: UiText.get('room_welcome_label'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '').isEmpty) {
                    return UiText.get('room_welcome_required');
                  }
                  return null;
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(UiText.get('room_create')),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: LinearProgressIndicator(),
                ),
            ]),
          ),
        ),
      );
}
