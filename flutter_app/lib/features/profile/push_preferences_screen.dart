import 'package:flutter/material.dart';

import '../../data/push_preference_models.dart';
import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Account-scoped push privacy controls. No Firebase SDK, token collection,
/// background receiver, or FCM delivery is implied by consent.
class PushPreferencesScreen extends StatefulWidget {
  const PushPreferencesScreen({super.key, required this.api});

  final TotiChatServices api;

  @override
  State<PushPreferencesScreen> createState() =>
      _PushPreferencesScreenState();
}

class _PushPreferencesScreenState extends State<PushPreferencesScreen> {
  late Future<PushPreferenceState> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.pushStatus();
  }

  void _reload() {
    if (_busy || !mounted) return;
    setState(() => _future = widget.api.pushStatus());
  }

  Future<void> _changeConsent(bool next) async {
    if (_busy || !mounted) return;
    if (next) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save device notification consent?'),
          content: const Text(
            'This stores your preference on TotiChat Staging. '
            'FCM background delivery is NOT available in this build. '
            'No device token will be collected or registered yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save consent')),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final state = await widget.api.setPushConsent(next);
      if (!mounted) return;
      setState(() => _future = Future.value(state));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next
          ? 'Your consent is saved. Background delivery is not active.'
          : 'Push consent disabled. Registered devices were cleared.'),
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _future = widget.api.pushStatus());
        showApiError(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeDevice(RegisteredPushDevice device) async {
    if (_busy || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove registered device?'),
        content: Text(
          'Revoke the ${device.platform} / ${device.provider} '
          'device from your account. This cannot be undone here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove device')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final state = await widget.api.unregisterPushDevice(device.deviceId);
      if (!mounted) return;
      setState(() => _future = Future.value(state));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Device removal confirmed by the server.'),
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _future = widget.api.pushStatus());
        showApiError(context, error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Device notifications & privacy'),
        actions: [
          IconButton(
            tooltip: 'Refresh server preferences',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh_rounded)),
        ]),
      body: ServerPanel<PushPreferenceState>(
        future: _future,
        retry: _reload,
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Notification preferences',
              style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            Card(
              child: SwitchListTile.adaptive(
                value: state.enabled,
                onChanged: _busy ? null : _changeConsent,
                title: const Text('Allow future device notifications'),
                subtitle: const Text(
                  'A saved preference only. No automatic FCM registration '
                  'or background delivery is included in this build.'),
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(state.deliveryConfigured
                  ? Icons.info_outline : Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(state.deliveryConfigured
                  ? 'The server reports delivery configured. '
                    'This app build has no device registration client.'
                  : 'FCM sending is not deployed. In-app notifications '
                    'remain available in the notification center.')),
              ]),
            )),
            const SizedBox(height: 24),
            Text('Registered devices (${state.devices.length} / 5)',
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('This list comes from your authenticated account. '
              'Device registration tokens are never shown here.'),
            const SizedBox(height: 8),
            if (state.devices.isEmpty)
              const NoRecords('No push devices registered for this account.'),
            for (final device in state.devices)
              Card(child: ListTile(
                leading: const Icon(Icons.phonelink_erase_outlined),
                title: Text(
                  '${device.platform.toUpperCase()} · '
                  '${device.provider.toUpperCase()}'),
                subtitle: Text(
                  'Last updated: ${device.refreshedAt.toLocal()}'),
                trailing: IconButton(
                  onPressed: _busy ? null : () => _removeDevice(device),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Revoke this registered device'),
              )),
          ],
        ),
      ),
    ),
  );
}
