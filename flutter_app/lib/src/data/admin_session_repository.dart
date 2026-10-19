import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSession {
  const AdminSession({
    required this.role,
    required this.isOwner,
    required this.isMainPartner,
    required this.canReadReports,
    required this.canManageCatalogs,
    required this.canManageHostAgencies,
    required this.permissions,
  });

  final String role;
  final bool isOwner;
  final bool isMainPartner;
  final bool canReadReports;
  final bool canManageCatalogs;
  final bool canManageHostAgencies;
  final List<String> permissions;

  bool get canEnterCenter =>
      isOwner ||
      isMainPartner ||
      canReadReports ||
      canManageCatalogs ||
      permissions.contains('reports.read') ||
      permissions.contains('banners.propose');

  factory AdminSession.fromJson(Map<String, dynamic> row) => AdminSession(
        role: (row['role'] as String?) ?? 'user',
        isOwner: row['isOwner'] == true,
        isMainPartner: row['isMainPartner'] == true,
        canReadReports: row['canReadReports'] == true,
        canManageCatalogs: row['canManageCatalogs'] == true,
        canManageHostAgencies: row['canManageHostAgencies'] == true,
        permissions: (row['permissions'] as List?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
      );
}

class AdminSessionRepository {
  AdminSessionRepository(this.client);
  final SupabaseClient client;

  Future<AdminSession> current() async {
    final data = await client.rpc('phase3_admin_session');
    if (data is! Map) throw StateError('Admin role not authenticated');
    return AdminSession.fromJson(Map<String, dynamic>.from(data));
  }
}
