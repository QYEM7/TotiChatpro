import 'package:flutter/material.dart';

import '../../data/notification_models.dart';
import '../../data/totichat_services.dart';
import '../community/support_tickets_screen.dart';

/// In-app authenticated server notifications. This does not claim FCM delivery.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends State<NotificationCenterScreen> {
  static const _pageSize = 30;
  final List<NotificationEntry> _items = [];
  int _unread = 0;
  int? _before;
  int _generation = 0;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _marking = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final page = await widget.api.notificationPage(limit: _pageSize);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _unread = page.unreadCount;
        _before = page.nextBefore;
        _hasMore = page.items.length == _pageSize;
        _initialLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _initialLoading = false;
      });
    }
  }

  Future<void> _older() async {
    if (_initialLoading || _loadingMore || !_hasMore || _before == null) {
      return;
    }
    final generation = _generation;
    final cursor = _before!;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.api.notificationPage(
        before: cursor, limit: _pageSize);
      if (!mounted || generation != _generation) return;
      // The server uses id < cursor. Never display a duplicate or an
      // inconsistent page when notifications arrive between requests.
      if (page.items.any((item) => item.id >= cursor)) {
        throw StateError('Notification cursor sequence changed');
      }
      final seen = _items.map((x) => x.id).toSet();
      setState(() {
        _items.addAll(page.items.where((item) => seen.add(item.id)));
        _before = page.nextBefore ?? cursor;
        _unread = page.unreadCount;
        _hasMore = page.items.length == _pageSize;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load older notifications: $error')));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _markRead({int? id}) async {
    if (_marking || _initialLoading) return;
    setState(() => _marking = true);
    try {
      final changed = id == null
        ? await widget.api.readNotifications()
        : await widget.api.markSelectedNotificationsRead([id]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Server confirmed $changed read updates.')));
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not update notification: $error')));
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _openSupportTicket(NotificationEntry event) async {
    final ticketId = event.supportTicketId;
    if (ticketId == null || _marking) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SupportTicketThreadScreen(
        api: widget.api,
        ticketId: ticketId,
        title: 'Official support ticket',
      ),
    ));
    if (!mounted) return;
    // Mark the original event only after opening a server-authorized thread.
    if (event.unread) {
      await _markRead(id: event.id);
    } else {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _marking ? null : _reload,
            tooltip: 'Refresh server notifications',
            icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _initialLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off_outlined, size: 45),
                const SizedBox(height: 12),
                const Text('Failed to load server notifications.'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again')),
              ])))
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                children: [
                  Row(children: [
                    Expanded(child: Text(
                      'Unread: $_unread',
                      style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800))),
                    TextButton.icon(
                      onPressed: _marking || _unread == 0
                        ? null : () => _markRead(),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Mark all read')),
                  ]),
                  const SizedBox(height: 10),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: Text(
                        'No notifications recorded for this account.'))),
                  for (final event in _items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Icon(event.unread
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_none_outlined,
                                color: event.unread
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey),
                              const SizedBox(width: 9),
                              Expanded(child: Text(
                                event.displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: event.unread
                                    ? FontWeight.w800
                                    : FontWeight.w500))),
                              if (event.unread)
                                TextButton(
                                  onPressed: _marking ? null :
                                    () => _markRead(id: event.id),
                                  child: const Text('Read')),
                            ]),
                            if (event.displayMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(event.displayMessage!,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis)),
                            if (event.supportTicketId != null)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton.icon(
                                  onPressed: _marking ? null
                                    : () => _openSupportTicket(event),
                                  icon: const Icon(Icons.support_agent_outlined),
                                  label: const Text('Open support ticket'),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(event.createdAt.toLocal()
                              .toString().split('.').first,
                              style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: OutlinedButton.icon(
                        onPressed: _marking || _loadingMore ? null : _older,
                        icon: _loadingMore
                          ? const SizedBox(width: 15, height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2))
                          : const Icon(Icons.expand_more),
                        label: const Text('Older notifications')),
                    ),
                ],
              ),
            ),
    ),
  );
}
