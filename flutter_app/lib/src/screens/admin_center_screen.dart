import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ui_text.dart';
import '../data/admin_session_repository.dart';

/// Authorized, read-only beta admin entry. Mutating admin actions are not
/// exposed until role-specific server actions are tested end-to-end.
class AdminCenterScreen extends StatefulWidget {
  const AdminCenterScreen({super.key});

  @override
  State<AdminCenterScreen> createState() => _AdminCenterScreenState();
}

class _AdminCenterScreenState extends State<AdminCenterScreen> {
  late Future<AdminSession> _session =
      AdminSessionRepository(Supabase.instance.client).current();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(UiText.get('admin_center'))),
        body: FutureBuilder<AdminSession>(
          future: _session,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: Text(UiText.get('admin_loading')));
            }
            if (snapshot.hasError || !snapshot.requireData.canEnterCenter) {
              return Center(child: Text(UiText.get('admin_denied')));
            }
            final authority = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: () async {
                final next =
                    AdminSessionRepository(Supabase.instance.client).current();
                setState(() => _session = next);
                await next;
              },
              child: ListView(padding: const EdgeInsets.all(18), children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(UiText.get('admin_center')),
                    subtitle: Text(authority.role),
                  ),
                ),
                if (authority.canReadReports)
                  ListTile(
                    leading: const Icon(Icons.assessment_outlined),
                    title: Text(UiText.get('admin_reports_permission')),
                  ),
                if (authority.canManageCatalogs)
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(UiText.get('admin_catalog_permission')),
                  ),
                if (authority.canManageHostAgencies)
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(UiText.get('admin_agencies_permission')),
                  ),
                const Divider(),
                Text(UiText.get('admin_beta_readonly'),
                    textAlign: TextAlign.center),
              ]),
            );
          },
        ),
      );
}
