import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/totichat_repository.dart';
import '../../models/room_models.dart';
import '../../ui/toti_theme.dart';
import 'voice_session.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.repository, required this.room});
  final TotiChatRepository repository;
  final RoomInfo room;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  late final VoiceSession _voice = VoiceSession(widget.repository);
  final TextEditingController _message = TextEditingController();
  List<RoomMember> _members = const [];
  List<RoomMessage> _messages = const [];
  bool _joined = false, _joining = true, _sending = false, _leaving = false;
  bool _workingAudio = false;
  bool _active = true;
  String? _error;
  Timer? _refreshTimer;

  RoomMember? get _mine {
    final uid = widget.repository.client.auth.currentUser?.id;
    for (final member in _members) {
      if (member.userId == uid) return member;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enter();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active && _joined) _refresh();
  }

  Future<void> _enter() async {
    try {
      await widget.repository.joinRoom(widget.room.id);
      if (!mounted) return;
      setState(() { _joined = true; _joining = false; });
      await _refresh();
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_active && _joined && !_leaving) _refresh();
      });
    } catch (error) {
      if (mounted) setState(() {
        _joining = false; _error = 'Server rejected room entry: $error';
      });
    }
  }

  Future<void> _refresh() async {
    if (!_joined || _leaving) return;
    try {
      final result = await Future.wait<dynamic>([
        widget.repository.members(widget.room.id),
        widget.repository.messages(widget.room.id),
      ]);
      if (mounted && !_leaving) setState(() {
        _members = result[0] as List<RoomMember>;
        _messages = result[1] as List<RoomMessage>;
        _error = null;
      });
    } catch (error) {
      if (mounted && !_leaving) setState(
        () => _error = 'Failed to refresh real room state: $error');
    }
  }

  Future<void> _seat(int seatNumber) async {
    final occupied = _members.where((member) => member.seatNo == seatNumber).toList();
    if (occupied.isNotEmpty && occupied.first.userId != widget.repository.currentUserId) {
      return;
    }
    try {
      // Revoking a seat also revokes local microphone publishing immediately.
      if (_voice.connected) await _voice.disconnect();
      await widget.repository.setSeat(
        widget.room.id, _mine?.seatNo == seatNumber ? null : seatNumber);
      await _refresh();
      _show('تم تحديث المقعد من الخادم');
    } catch (error) {
      _show('تعذر تحديث المقعد: $error');
    }
  }

  Future<void> _connectAudio() async {
    if (_workingAudio) return;
    setState(() => _workingAudio = true);
    try {
      await _voice.connect(widget.room.id);
      if (mounted) setState(() {});
      _show('تم الاتصال بالصوت الحقيقي');
    } catch (error) { _show('فشل الاتصال الصوتي: $error'); }
    finally { if (mounted) setState(() => _workingAudio = false); }
  }

  Future<void> _toggleMic() async {
    if (_workingAudio || !_voice.connected) return;
    setState(() => _workingAudio = true);
    final enabled = !_voice.publishing;
    try {
      if (enabled && (_mine?.seatNo == null)) {
        throw StateError('اجلس على مقعد قبل تشغيل المايك');
      }
      if (enabled) {
        // A freshly issued server token must contain publish permission.
        // Server mute state and LiveKit track state must agree.
        await widget.repository.setMicMuted(widget.room.id, false);
        await _voice.connect(widget.room.id);
        await _voice.setMicrophone(true, canPublish: true);
      } else {
        await _voice.setMicrophone(false, canPublish: true);
        await widget.repository.setMicMuted(widget.room.id, true);
      }
      await _refresh();
    } catch (error) {
      // Fail closed: never leave a microphone publishing on server error.
      await _voice.disconnect();
      try { await widget.repository.setMicMuted(widget.room.id, true); } catch (_) {}
      _show('تعذر تشغيل المايك: $error');
    } finally { if (mounted) setState(() => _workingAudio = false); }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendMessage(widget.room.id, text);
      if (!mounted) return;
      _message.clear();
      await _refresh();
    } catch (error) { _show('تعذر إرسال الرسالة: $error'); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _refreshTimer?.cancel();
    try {
      await _voice.disconnect();
      if (_joined) await widget.repository.leaveRoom(widget.room.id);
      _joined = false;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _leaving = false);
        _show('لم يؤكد الخادم مغادرة الغرفة: $error');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    // Leaving normally happens through _leave. Defensive clean-up on teardown.
    unawaited(_voice.disconnect());
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF29233E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF29233E),
            foregroundColor: Colors.white,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.room.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(_joined ? '${_members.length} أعضاء متصلون' : 'جارٍ الاتصال بالخادم',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
            leading: IconButton(onPressed: _leaving ? null : _leave,
              icon: const Icon(Icons.exit_to_app_rounded),
              tooltip: 'مغادرة الغرفة'),
          ),
          body: _joining ? const Center(child: CircularProgressIndicator()) :
            !_joined ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error ?? 'تعذّر دخول الغرفة',
                style: const TextStyle(color: Colors.white)))) :
            Column(children: [
              if (_error != null) Container(
                width: double.infinity, color: Colors.red.shade900,
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: Colors.white))),
              if (widget.room.welcomeMessage?.isNotEmpty == true)
                Padding(padding: const EdgeInsets.all(12),
                  child: Text(widget.room.welcomeMessage!,
                    style: const TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, mainAxisSpacing: 12,
                    crossAxisSpacing: 7, childAspectRatio: .72),
                  itemCount: 15,
                  itemBuilder: (context, i) {
                    final seat = i + 1;
                    RoomMember? occupant;
                    for (final member in _members) {
                      if (member.seatNo == seat) occupant = member;
                    }
                    final active = occupant != null;
                    return InkWell(
                      onTap: () => _seat(seat),
                      borderRadius: BorderRadius.circular(14),
                      child: Column(children: [
                        Expanded(child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF6D5AA6) :
                              const Color(0xFF423A5A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: active ?
                              TotiColors.gold : Colors.white24)),
                          child: Center(child: active &&
                              occupant!.avatarUrl?.startsWith('https://') == true
                            ? ClipRRect(borderRadius: BorderRadius.circular(15),
                                child: Image.network(occupant.avatarUrl!,
                                  fit: BoxFit.cover, errorBuilder: (_, _, _) =>
                                    const Icon(Icons.person, color: Colors.white)))
                            : Icon(active ? Icons.person_rounded :
                                Icons.add_rounded, color: Colors.white70))),
                        ),
                        const SizedBox(height: 5),
                        Text(active ? occupant!.displayName : '$seat',
                          textAlign: TextAlign.center, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: FilledButton.tonalIcon(
                    onPressed: _workingAudio ? null :
                      (_voice.connected ? _toggleMic : _connectAudio),
                    icon: Icon(!_voice.connected ? Icons.headphones_rounded :
                      _voice.publishing ? Icons.mic_rounded : Icons.mic_off_rounded),
                    label: Text(!_voice.connected ? 'الاتصال بالصوت' :
                      _voice.publishing ? 'إيقاف المايك' : 'تشغيل المايك'),
                  )),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _workingAudio || !_voice.connected ? null : () async {
                      await _voice.disconnect();
                      if (mounted) setState(() {});
                    }, icon: const Icon(Icons.call_end_rounded)),
                ]),
              ),
              const Divider(color: Colors.white24),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(alignment: Alignment.centerRight,
                  child: Text('دردشة الغرفة', style: TextStyle(
                    color: TotiColors.gold, fontWeight: FontWeight.w700)))),
              Expanded(child: _messages.isEmpty ?
                const Center(child: Text('لا توجد رسائل حقيقية بعد',
                  style: TextStyle(color: Colors.white60))) :
                ListView.builder(
                  key: const PageStorageKey('realRoomChat'),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final message = _messages[i];
                    final sender = _members.where((m) => m.userId == message.senderId);
                    final name = sender.isNotEmpty ? sender.first.displayName : 'عضو';
                    return ListTile(
                      dense: true,
                      title: Text(name, style: const TextStyle(
                        color: TotiColors.gold, fontWeight: FontWeight.w700)),
                      subtitle: Text(message.body,
                        style: const TextStyle(color: Colors.white)),
                    );
                  },
                )),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.viewInsetsOf(context).bottom + 10),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _message, maxLength: 500,
                    style: const TextStyle(color: TotiColors.ink),
                    decoration: const InputDecoration(
                      counterText: '', hintText: 'اكتب رسالة حقيقية…'),
                    onSubmitted: (_) => _send(),
                  )),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            ]),
        ),
      ),
    );
  }
}
