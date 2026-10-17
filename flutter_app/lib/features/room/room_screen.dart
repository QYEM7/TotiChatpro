import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/totichat_repository.dart';
import '../../data/totichat_services.dart';
import '../community/dm_screen.dart';
import '../economy/gift_sheet.dart';
import '../economy/real_gift_ticker.dart';
import 'room_draft_guard.dart';
import 'room_exit_workflow.dart';
import 'room_game_screen.dart';
import 'room_moderation_screen.dart';
import 'room_mic_recovery.dart';
import 'room_music_queue_screen.dart';
import 'room_seat_visual.dart';
import '../../models/room_models.dart';
import '../../models/room_seat_decoration.dart';
import '../../ui/toti_theme.dart';
import '../../ui/toti_visual_language.dart';
import 'voice_session.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key, required this.repository, required this.room,
    this.minimized = false, this.onExit, this.onMinimize,
  });
  final TotiChatRepository repository;
  final RoomInfo room;
  final bool minimized;
  final VoidCallback? onExit;
  final VoidCallback? onMinimize;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with WidgetsBindingObserver {
  late final VoiceSession _voice = VoiceSession(widget.repository);
  final TextEditingController _message = TextEditingController();
  List<RoomMember> _members = const [];
  List<RoomMessage> _messages = const [];
  Map<String,RoomSeatDecoration> _seatDecorations = const {};
  String? _seatDecorationError;
  bool _refreshing = false, _refreshRequestedAgain = false;
  bool _joined = false, _joining = true, _sending = false, _leaving = false;
  bool _workingAudio = false;
  bool _workingSeat = false;
  bool _leaveRequested = false;
  bool _active = true;
  String? _error;
  Timer? _refreshTimer;
  RealtimeChannel? _liveChannel;

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
      if (!mounted) {
        await widget.repository.leaveRoom(widget.room.id);
        return;
      }
      setState(() { _joined = true; _joining = false; });
      if (_leaveRequested) {
        await _leave();
        return;
      }
      await _refresh();
      if (!mounted || !_joined || _leaving || _leaveRequested) return;
      _subscribeRoomChanges();
      _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_active && _joined && !_leaving) _refresh();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _joining = false; _error = 'Server rejected room entry: $error';
      });
      // A leave requested during an unsuccessful join must still finish.
      // No membership was confirmed, so do not send an unverified leave RPC.
      if (_leaveRequested) {
        await _leave();
      }
    }
  }

  /// A rejected join must have an in-place retry, not require navigating
  /// away and recreating the room while the network is recovering.
  void _retryJoin() {
    if (!mounted || _joining || _joined || _leaving || _leaveRequested) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    _enter();
  }

  void _subscribeRoomChanges() {
    final id=widget.room.id;
    _liveChannel=widget.repository.client.channel('voice-room-live:$id')
      .onPostgresChanges(
        event:PostgresChangeEvent.all,schema:'public',table:'room_messages',
        filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,
          column:'room_id',value:id),
        callback:(_){if(_active&&_joined&&!_leaving)_refresh();},
      )
      .onPostgresChanges(
        event:PostgresChangeEvent.all,schema:'public',table:'room_members',
        filter:PostgresChangeFilter(type:PostgresChangeFilterType.eq,
          column:'room_id',value:id),
        callback:(_){if(_active&&_joined&&!_leaving)_refresh();},
      ).subscribe();
  }

  /// Coalesces simultaneous Realtime/poll calls to prevent stale room updates.
  /// Visual decoration failures must never block seat or chat refresh.
  Future<void> _refresh() async {
    if (!_joined || _leaving || !mounted) return;
    if (_refreshing) {
      _refreshRequestedAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshRequestedAgain = false;
        try {
          final decorations = widget.repository.seatDecorations(widget.room.id)
            .then<Object?>((items) => items)
            .catchError((Object error) => error);
          final result = await Future.wait<dynamic>([
            widget.repository.members(widget.room.id),
            widget.repository.messages(widget.room.id),
            decorations,
          ]);
          if (mounted && _joined && !_leaving) setState(() {
            _members = result[0] as List<RoomMember>;
            _messages = result[1] as List<RoomMessage>;
            final visual = result[2];
            if (visual is Map<String, RoomSeatDecoration>) {
              _seatDecorations = visual;
              _seatDecorationError = null;
            } else {
              _seatDecorations = const {};
              _seatDecorationError =
                'Seat decorations could not be verified with the server.';
            }
            _error = null;
          });
        } catch (error) {
          if (mounted && _joined && !_leaving) setState(
            () => _error = 'Failed to refresh real room state: $error');
        }
      } while (_refreshRequestedAgain && mounted && _joined && !_leaving);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _seat(int seatNumber) async {
    if (!_joined || _joining || _leaving || _leaveRequested ||
        _workingSeat || _workingAudio || !mounted) return;
    if (seatNumber < 1 || seatNumber > 15) return;
    final occupied = _members.where((member) => member.seatNo == seatNumber).toList();
    if (occupied.isNotEmpty &&
        occupied.first.userId != widget.repository.currentUserId) {
      return;
    }
    // Capture before any await: repeated taps must not turn a single
    // selection into an unintended seat release.
    final desiredSeat = _mine?.seatNo == seatNumber ? null : seatNumber;
    setState(() => _workingSeat = true);
    try {
      // Even a still-pending voice token must be cancelled before moving.
      // The Staging seat RPC also restores server mute=true.
      await _voice.disconnect();
      if (!_joined || _leaving || _leaveRequested || !mounted) return;
      // Seat RPC re-mutes on success, but it may fail after LiveKit has
      // disconnected. Mute first so a failed seat change cannot leave a
      // stale unmuted badge or server microphone grant.
      await widget.repository.setMicMuted(widget.room.id, true);
      if (!_joined || _leaving || _leaveRequested || !mounted) return;
      await widget.repository.setSeat(widget.room.id, desiredSeat);
      await _refresh();
      _show('تم تحديث المقعد من الخادم');
    } catch (error) {
      // If the local disconnect itself failed, we must still attempt to mute
      // on the server. A rejected seat RPC must not leave stale mic state.
      if (_joined && !_leaving && mounted) {
        final recovery = await RoomMicRecovery.run(
          disconnectAudio: _voice.disconnect,
          muteOnServer: () => widget.repository.setMicMuted(widget.room.id, true),
        );
        if (!recovery.serverMuteConfirmed) {
          _show('تعذر تغيير المقعد ولم يؤكد الخادم كتم المايك: $error');
        } else if (!recovery.disconnectConfirmed) {
          _show('تعذر تغيير المقعد وتعذر تأكيد فصل الصوت: $error');
        } else {
          _show('تعذر تحديث المقعد: $error');
        }
      } else {
        _show('تعذر تحديث المقعد: $error');
      }
    } finally {
      if (mounted) setState(() => _workingSeat = false);
    }
  }

  Future<void> _connectAudio() async {
    if (_workingAudio || _workingSeat || !_joined ||
        _leaving || _leaveRequested) return;
    setState(() => _workingAudio = true);
    try {
      await _voice.connect(widget.room.id);
      if (mounted) setState(() {});
      _show('تم الاتصال بالصوت الحقيقي');
    } catch (error) { _show('فشل الاتصال الصوتي: $error'); }
    finally { if (mounted) setState(() => _workingAudio = false); }
  }

  /// Disconnecting LiveKit alone leaves the server's mic badge stale.
  /// Always request a server mute, even if local disconnect throws. Do not
  /// show a successful hangup until the authoritative mute is acknowledged.
  Future<void> _hangUpAudio() async {
    if (_workingAudio || _workingSeat || _leaving || _leaveRequested ||
        !_joined || !_voice.connected) return;
    setState(() => _workingAudio = true);
    Object? disconnectError;
    try {
      try {
        await _voice.disconnect();
      } catch (error) {
        disconnectError = error;
      }
      try {
        await widget.repository.setMicMuted(widget.room.id, true);
      } catch (error) {
        _show('قطع الصوت محلياً، لكن الخادم لم يؤكد كتم المايك: $error');
        return;
      }
      await _refresh();
      if (disconnectError != null) {
        _show('تم تأكيد كتم المايك، لكن فصل الصوت تعثّر: $disconnectError');
      } else {
        _show('تم قطع الصوت وتأكيد كتم المايك');
      }
    } finally {
      if (mounted) setState(() => _workingAudio = false);
    }
  }

  Future<void> _toggleMic() async {
    if (_workingAudio || _workingSeat || !_joined ||
        _leaving || _leaveRequested || !_voice.connected) return;
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
        await _voice.setMicrophone(true);
      } else {
        await _voice.setMicrophone(false);
        await widget.repository.setMicMuted(widget.room.id, true);
      }
      await _refresh();
    } catch (error) {
      // A failed LiveKit disconnect must not skip the server mute request.
      // Never report the microphone as safely muted if either cleanup failed.
      final recovery = await RoomMicRecovery.run(
        disconnectAudio: _voice.disconnect,
        muteOnServer: () => widget.repository.setMicMuted(widget.room.id, true),
      );
      if (!recovery.serverMuteConfirmed) {
        _show('فشلت عملية المايك، والخادم لم يؤكد كتمه: $error');
      } else if (!recovery.disconnectConfirmed) {
        _show('الخادم أكد الكتم لكن فصل الصوت تعثر: $error');
      } else {
        _show('تعذر تشغيل المايك: $error');
      }
    } finally { if (mounted) setState(() => _workingAudio = false); }
  }

  Future<void> _send() async {
    final draft = _message.text;
    final text = draft.trim();
    if (text.isEmpty || text.length > 500 || _sending || _joining ||
        !_joined || _leaving || _leaveRequested || !mounted) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendMessage(widget.room.id, text);
      if (!mounted) return;
      // A member can continue typing while an RPC is pending. Never clear
      // their newer draft in response to the earlier message succeeding.
      RoomDraftGuard.clearSentDraftIfUnchanged(_message, draft);
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
    if (_joining) {
      _leaveRequested = true;
      return;
    }
    setState(() => _leaving = true);
    _refreshTimer?.cancel();
    _refreshTimer = null;
    final live = _liveChannel;
    _liveChannel = null;
    try {
      // Local socket/audio cleanup is best effort, but an acknowledged server
      // leave is mandatory. Never skip it if LiveKit teardown throws.
      final result = await RoomExitWorkflow.run(
        closeRealtime: () async {
          if (live != null) {
            await widget.repository.client.removeChannel(live);
          }
        },
        disconnectAudio: _voice.disconnect,
        leaveOnServer: () async {
          if (_joined) await widget.repository.leaveRoom(widget.room.id);
        },
      );
      _joined = false;
      if (mounted) {
        if (result.hadCleanupErrors) {
          _show('Server confirmed room exit, but local cleanup reported an error.');
        }
        if (widget.onExit != null) {
          widget.onExit!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (error) {
      if (!mounted) return;
      // A failed server leave means membership may still exist. Restore
      // updates and controls so the user can retry instead of getting stuck.
      setState(() {
        _leaving = false;
        _leaveRequested = false;
      });
      if (_joined) {
        try {
          _subscribeRoomChanges();
        } catch (_) {
          // The polling fallback still works if Realtime is disconnected.
        }
        _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
          if (_active && _joined && !_leaving) _refresh();
        });
        _refresh();
      }
      _show('Server did not confirm leaving this room: $error');
    }
  }

  Future<void> _openMusicQueue() async {
    if (!_joined || _leaving) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RoomMusicQueueScreen(
        api: TotiChatServices(widget.repository.client),
        roomId: widget.room.id,
        roomOwnerId: widget.room.ownerId,
      )));
  }

  Future<void> _openGame() async {
    if(!_joined)return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder:(_)=>RoomGameScreen(
        api:TotiChatServices(widget.repository.client),roomId:widget.room.id)));
  }

  Future<void> _openModeration() async {
    if(!_joined||widget.room.ownerId!=widget.repository.currentUserId)return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder:(_)=>RoomModerationScreen(
        api:TotiChatServices(widget.repository.client),
        roomId:widget.room.id,members:_members)));
    if(mounted)await _refresh();
  }

  Future<void> _roomControls() async {
    if (_leaving || !mounted) return;
    if (widget.onMinimize == null) {
      await _leave();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(27)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: Colors.white.withValues(alpha: .88),
            child: SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.minimize_rounded,
              color: TotiColors.plum),
            title: const Text('Minimize room',
              style: TextStyle(color: TotiColors.ink)),
            onTap: _joined ? () {
              Navigator.pop(sheetContext);
              widget.onMinimize?.call();
            } : null,
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app_rounded,
              color: TotiColors.plum),
            title: const Text('Leave room',
              style: TextStyle(color: TotiColors.ink)),
            onTap: () {
              Navigator.pop(sheetContext);
              _leave();
            },
          ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showInvite() async {
    if (!_joined || widget.room.ownerId!=widget.repository.currentUserId) return;
    try {
      final code=await widget.repository.privateInvite(widget.room.id);
      if (!mounted) return;
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('دعوة الغرفة الخاصة'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('شارك هذا الرمز خارج التطبيق مع العضو المقصود فقط.'),
          const SizedBox(height:12),
          SelectableText(code,textAlign:TextAlign.center),
        ]),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),
          child:const Text('تم'))],
      ));
    } catch(error) {
      _show('تعذر إنشاء دعوة حقيقية: $error');
    }
  }

  Future<void> _openGifts() async {
    if (!_joined || _leaving) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => GiftSheet(
        api: TotiChatServices(widget.repository.client),
        roomId: widget.room.id,
        members: _members,
      ),
    );
    if (confirmed == true && mounted) {
      _show('تم إرسال الهدية بعد تأكيد الخادم');
      await _refresh();
    }
  }

  Future<void> _memberActions(RoomMember member, int seat) async {
    if (member.userId == widget.repository.currentUserId) {
      await _seat(seat);
      return;
    }
    await showModalBottomSheet<void>(context: context, builder: (sheetContext) =>
      SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(member.displayName),
          subtitle: const Text('مستخدم داخل الغرفة الحقيقية')),
        ListTile(leading: const Icon(Icons.mail_outline_rounded),
          title: const Text('مراسلة خاصة'),
          onTap: () async {
            Navigator.pop(sheetContext);
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DmThread(
                api: TotiChatServices(widget.repository.client),
                peerId: member.userId,
                title: member.displayName,
              ),
            ));
          }),
        ListTile(leading: const Icon(Icons.card_giftcard_outlined),
          title: const Text('إهداء'),
          onTap: () {
            Navigator.pop(sheetContext);
            _openGifts();
          }),
      ])));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    final live=_liveChannel;
    _liveChannel=null;
    if(live!=null)unawaited(widget.repository.client.removeChannel(live));
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
        canPop: _leaving || widget.minimized,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !widget.minimized) _leave();
        },
        child: Scaffold(
          backgroundColor: TotiColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: TotiColors.ink,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.room.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(_joined ? '${_members.length} أعضاء متصلون' : 'جارٍ الاتصال بالخادم',
                style: const TextStyle(fontSize: 12, color: TotiColors.muted)),
            ]),
            leading: IconButton(
              onPressed: _leaving ? null : _roomControls,
              icon: const Icon(Icons.more_horiz_rounded),
              tooltip: 'Room controls'),
            actions: [
              IconButton(onPressed:_joined?_openMusicQueue:null,
                icon:const Icon(Icons.library_music_outlined),
                tooltip:'Saved room playlist'),
              IconButton(onPressed:_joined?_openGame:null,
                icon:const Icon(Icons.videogame_asset_outlined),
                tooltip:'لعبة إكس أو الحقيقية'),
              if(widget.room.ownerId==widget.repository.currentUserId)
                IconButton(onPressed:_joined?_openModeration:null,
                  icon:const Icon(Icons.admin_panel_settings_outlined),
                  tooltip:'إدارة الغرفة'),
              if(widget.room.isPrivate &&
                  widget.room.ownerId==widget.repository.currentUserId)
                IconButton(onPressed:_showInvite,
                  icon:const Icon(Icons.person_add_alt_rounded),
                  tooltip:'دعوة عضو'),
            ],
          ),
          body: TotiAtmosphere(child: _joining ? const Center(child: CircularProgressIndicator()) :
            !_joined ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error ?? 'تعذّر دخول الغرفة',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TotiColors.ink)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _leaving ? null : _retryJoin,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة محاولة الدخول'),
                ),
              ]))) :
            Column(children: [
              RealGiftTicker(client:widget.repository.client),
              if (_error != null) Container(
                width: double.infinity, color: Colors.red.shade900,
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: const TextStyle(color: Colors.white))),
              if (_seatDecorationError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(_seatDecorationError!,
                    style: const TextStyle(
                      color: TotiColors.plum, fontSize: 11))),
              if (widget.room.welcomeMessage?.isNotEmpty == true)
                Padding(padding: const EdgeInsets.all(12),
                  child: Text(widget.room.welcomeMessage!,
                    style: const TextStyle(color: TotiColors.muted))),
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
                    final decoration = occupant == null
                      ? null : _seatDecorations[occupant.userId];
                    return InkWell(
                      onTap: _workingSeat || _workingAudio || _leaving
                        ? null : () => occupant == null
                            ? _seat(seat) : _memberActions(occupant, seat),
                      borderRadius: BorderRadius.circular(14),
                      child: Column(children: [
                        Expanded(child: RoomSeatVisual(
                          member: occupant,
                          isOwner: occupant?.userId == widget.room.ownerId,
                          decoration: decoration,
                        )),
                        const SizedBox(height: 5),
                        Text(occupant?.displayName ?? '$seat',
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
                    onPressed: _workingAudio || _workingSeat || _leaving
                      ? null : (_voice.connected ? _toggleMic : _connectAudio),
                    icon: Icon(!_voice.connected ? Icons.headphones_rounded :
                      _voice.publishing ? Icons.mic_rounded : Icons.mic_off_rounded),
                    label: Text(!_voice.connected ? 'الاتصال بالصوت' :
                      _voice.publishing ? 'إيقاف المايك' : 'تشغيل المايك'),
                  )),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _workingAudio || _workingSeat ||
                        !_voice.connected ? null : _hangUpAudio,
                    icon: const Icon(Icons.call_end_rounded)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  FilledButton.tonalIcon(
                    onPressed: _joined && !_leaving ? _openGifts : null,
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: const Text('صندوق الهدايا'),
                  ),
                ]),
              ),
              const Divider(color: TotiColors.outline),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(alignment: Alignment.centerRight,
                  child: Text('دردشة الغرفة', style: TextStyle(
                    color: TotiColors.plum, fontWeight: FontWeight.w700)))),
              Expanded(child: _messages.isEmpty ?
                const Center(child: Text('لا توجد رسائل حقيقية بعد',
                  style: TextStyle(color: TotiColors.muted))) :
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
                        color: TotiColors.plum, fontWeight: FontWeight.w700)),
                      subtitle: Text(message.body,
                        style: const TextStyle(color: TotiColors.ink)),
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
            ])),
        ),
      ),
    );
  }
}
