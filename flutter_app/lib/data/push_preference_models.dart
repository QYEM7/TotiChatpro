/// Authenticated device-notification preferences returned by Staging.
/// An opt-in is not proof that background FCM delivery is deployed.
class PushPreferenceState {
  const PushPreferenceState({
    required this.userId,
    required this.enabled,
    required this.deliveryConfigured,
    required this.devices,
  });

  final String userId;
  final bool enabled;
  final bool deliveryConfigured;
  final List<RegisteredPushDevice> devices;

  factory PushPreferenceState.fromJson(
    Object? raw, {
    required String expectedUserId,
  }) {
    if (raw is! Map) {
      throw const FormatException('Invalid device notification status');
    }
    final data = Map<String, dynamic>.from(raw);
    final id = data['userId'];
    final enabled = data['pushEnabled'];
    final configured = data['deliveryConfigured'];
    final rows = data['devices'];
    if (id != expectedUserId ||
        id is! String || id.isEmpty ||
        enabled is! bool ||
        configured is! bool ||
        rows is! List || rows.length > 5) {
      throw const FormatException('Unverified push preference response');
    }

    final seen = <String>{};
    final devices = <RegisteredPushDevice>[];
    for (final row in rows) {
      final device = RegisteredPushDevice.fromJson(row);
      if (!seen.add(device.deviceId)) {
        throw const FormatException('Duplicate device in server response');
      }
      devices.add(device);
    }

    return PushPreferenceState(
      userId: id,
      enabled: enabled,
      deliveryConfigured: configured,
      devices: List.unmodifiable(devices),
    );
  }
}

class RegisteredPushDevice {
  const RegisteredPushDevice({
    required this.deviceId,
    required this.platform,
    required this.provider,
    required this.registeredAt,
    required this.refreshedAt,
  });

  final String deviceId;
  final String platform;
  final String provider;
  final DateTime registeredAt;
  final DateTime refreshedAt;

  factory RegisteredPushDevice.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid registered push device');
    }
    final data = Map<String, dynamic>.from(raw);
    final id = data['device_id'];
    final platform = data['platform'];
    final provider = data['provider'];
    final created = data['registered_at'];
    final refreshed = data['refreshed_at'];

    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
    );
    final initialTime = created is String ? DateTime.tryParse(created) : null;
    final latestTime = refreshed is String ? DateTime.tryParse(refreshed) : null;
    if (id is! String || !uuid.hasMatch(id) ||
        platform is! String || platform.isEmpty ||
        provider is! String || provider.isEmpty ||
        initialTime == null || latestTime == null) {
      throw const FormatException('Incomplete push device record');
    }
    return RegisteredPushDevice(
      deviceId: id,
      platform: platform,
      provider: provider,
      registeredAt: initialTime,
      refreshedAt: latestTime,
    );
  }
}
