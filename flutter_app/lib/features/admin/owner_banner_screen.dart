import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Official admin banner source. Staging RPC and Storage policies independently
/// require Owner or designated partner. No fake, client-only banner is inserted.
class OwnerBannerScreen extends StatefulWidget {
  const OwnerBannerScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<OwnerBannerScreen> createState() => _OwnerBannerScreenState();
}

class _OwnerBannerScreenState extends State<OwnerBannerScreen> {
  late Future<List<Map<String, dynamic>>> _banners;
  bool _busy = false;
  String? _pendingSignature, _pendingId, _pendingImagePath;
  bool _imageUploaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() =>
    _banners = widget.api.adminBanners());

  static String? _imagePath(Object? uri) {
    final raw = uri?.toString() ?? '';
    const segment = '/totichat-admin-banners/';
    final start = raw.indexOf(segment);
    if (start < 0) return null;
    final path = raw.substring(start + segment.length).split('?').first;
    return RegExp(r'^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$')
      .hasMatch(path) ? path : null;
  }

  Future<void> _save({
    required String action,
    required Map<String, dynamic> data,
    required String signature,
    String? bannerId,
    XFile? upload,
  }) async {
    if (_busy) return;
    if (_pendingSignature != null && _pendingSignature != signature) {
      showApiError(context,
        'A prior banner action has an uncertain result. '
        'Retry the same action or verify its audit record first.');
      return;
    }
    _pendingSignature = signature;
    _pendingId ??= TotiChatServices.requestId();
    setState(() => _busy = true);
    try {
      if (upload != null && !_imageUploaded) {
        _pendingImagePath ??=
          '${widget.api.userId}/${TotiChatServices.requestId()}.webp';
        final bytes = await upload.readAsBytes();
        if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
          throw ArgumentError('Image must be under 10 MB');
        }
        final webp = await FlutterImageCompress.compressWithList(
          bytes,
          format: CompressFormat.webp,
          quality: 82,
          minWidth: 720,
          minHeight: 240,
        );
        if (webp.isEmpty || webp.length > 2 * 1024 * 1024) {
          throw StateError('WebP image exceeds 2 MB after compression');
        }
        await widget.api.client.storage.from('totichat-admin-banners')
          .uploadBinary(_pendingImagePath!, webp,
            fileOptions: const FileOptions(
              contentType: 'image/webp', upsert: false));
        _imageUploaded = true;
      }
      if (upload != null) data['image_path'] = _pendingImagePath;
      await widget.api.saveOwnerBanner(
        action: action, bannerId: bannerId,
        data: data, requestId: _pendingId!);
      _pendingSignature = null;
      _pendingId = null;
      _pendingImagePath = null;
      _imageUploaded = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Banner change confirmed by the server.')));
        _refresh();
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    final title = TextEditingController();
    final sort = TextEditingController(text: '0');
    XFile? selected;
    final draft = await showDialog<({
      String title, int sort, XFile image,
    })>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Create an audited banner draft'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'The upload is a pending draft, not a public promotion.'),
              TextField(controller: title, maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Banner title')),
              TextField(controller: sort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Order (0-10000)')),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1800, maxHeight: 900,
                      imageQuality: 88);
                    if (picked != null && ctx.mounted) {
                      update(() => selected = picked);
                    }
                  } catch (error) {
                    if (ctx.mounted) showApiError(ctx, error);
                  }
                },
                icon: const Icon(Icons.image_outlined),
                label: Text(selected?.name ?? 'Select actual banner image'),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final order = int.tryParse(sort.text.trim());
                if (selected == null || title.text.trim().isEmpty ||
                    title.text.trim().length > 120 ||
                    order == null || order < 0 || order > 10000) {
                  showApiError(ctx, 'Title, image and valid order required.');
                  return;
                }
                Navigator.pop(ctx, (
                  title: title.text.trim(),
                  sort: order,
                  image: selected!,
                ));
              },
              child: const Text('Save server draft')),
          ],
        ),
      ),
    );
    title.dispose();
    sort.dispose();
    if (draft == null || !mounted) return;
    final signature =
      'create|${draft.title}|${draft.sort}|${draft.image.path}';
    await _save(
      action: 'create',
      signature: signature,
      upload: draft.image,
      data: {
        'title': draft.title,
        'link_kind': 'none',
        'link_target': null,
        'status': 'draft',
        'sort_order': draft.sort,
        'starts_at': null,
        'ends_at': null,
      },
    );
  }

  Future<void> _status(Map<String, dynamic> banner,
      String status) async {
    if (_busy) return;
    final id = banner['id']?.toString();
    final path = _imagePath(banner['image_url']);
    if (id == null || path == null) {
      showApiError(context, 'Invalid server banner image reference.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change banner to $status?'),
        content: const Text(
          'Publishing makes a real banner visible to all users when '
          'its schedule is active.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final data = {
      'title': banner['title'],
      'image_path': path,
      'link_kind': banner['link_kind'] ?? 'none',
      'link_target': banner['link_target'],
      'status': status,
      'sort_order': banner['sort_order'] ?? 0,
      'starts_at': banner['starts_at'],
      'ends_at': banner['ends_at'],
    };
    final signature = 'update|$id|$status|${data.toString()}';
    await _save(
      action: 'update', bannerId: id,
      signature: signature, data: data,
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Official home banners'),
        actions: [
          IconButton(onPressed: _refresh,
            icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 8),
          child: FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add draft banner')),
        ),
        Expanded(child: ServerPanel<List<Map<String, dynamic>>>(
          future: _banners,
          retry: _refresh,
          builder: (context, banners) => ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const Text(
                'Banners become public only when explicitly published '
                'and their schedule permits. This UI has no dummy banners.'),
              const SizedBox(height: 12),
              if (banners.isEmpty)
                const NoRecords('No banners have been saved yet.'),
              for (final row in banners) Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (row['image_url'] is String)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(row['image_url'] as String,
                            height: 110, fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) =>
                              const Icon(Icons.broken_image_outlined,
                                size: 45))),
                      const SizedBox(height: 8),
                      Text(row['title']?.toString() ?? 'Untitled banner',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800)),
                      Text('Server status: ${row['status'] ?? 'unknown'}'),
                      const SizedBox(height: 9),
                      Wrap(spacing: 8, children: [
                        if (row['status'] == 'draft' ||
                            row['status'] == 'archived')
                          FilledButton.tonal(
                            onPressed: _busy ? null :
                              () => _status(row, 'published'),
                            child: const Text('Publish')),
                        if (row['status'] == 'published')
                          OutlinedButton(
                            onPressed: _busy ? null :
                              () => _status(row, 'archived'),
                            child: const Text('Archive')),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )),
      ]),
    ),
  );
}
