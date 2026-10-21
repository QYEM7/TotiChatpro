import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/reference_visuals.dart';
import '../core/ui_text.dart';
import '../data/admin_session_repository.dart';

/// Board #16. In-app, server-authorized admin read-only landing.
/// No fake metrics or role escalation; mutation screens are deliberately
/// absent until their RPC permissions and device behavior pass QA.
class AdminCenterScreen extends StatefulWidget {
  const AdminCenterScreen({super.key});

  @override
  State<AdminCenterScreen> createState() => _AdminCenterScreenState();
}

class _AdminCenterScreenState extends State<AdminCenterScreen> {
  late Future<AdminSession> _session =
      AdminSessionRepository(Supabase.instance.client).current();

  Future<void> _refresh() async {
    final next = AdminSessionRepository(Supabase.instance.client).current();
    setState(() => _session = next);
    try {
      await next;
    } catch (_) {
      // Renders permission/error message instead of hiding authorization errors.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('reference-admin-center'),
    backgroundColor: ReferencePalette.canvas,
    appBar: AppBar(
      backgroundColor: ReferencePalette.canvas,
      centerTitle: true,
      title: Text(UiText.get('admin_center'),
        style: const TextStyle(
          color: ReferencePalette.ink,
          fontWeight: FontWeight.w900,
        )),
      actions: [
        IconButton(
          tooltip: UiText.get('refresh'),
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded,
            color: ReferencePalette.deep),
        ),
      ],
    ),
    body: FutureBuilder<AdminSession>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(
            color: ReferencePalette.teal));
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            !snapshot.requireData.canEnterCenter) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shield_outlined,
                color: ReferencePalette.gold, size: 56),
              const SizedBox(height: 14),
              Text(UiText.get('admin_denied'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: ReferencePalette.ink,
                  fontWeight: FontWeight.w800)),
            ]),
          ));
        }
        final session = snapshot.requireData;
        final tiles = <({IconData icon, String label})>[
          if (session.canReadReports ||
              session.permissions.contains('reports.read'))
            (icon: Icons.insert_chart_outlined,
              label: UiText.get('admin_reports_permission')),
          if (session.canManageCatalogs)
            (icon: Icons.inventory_2_outlined,
              label: UiText.get('admin_catalog_permission')),
          if (session.canManageHostAgencies)
            (icon: Icons.groups_2_outlined,
              label: UiText.get('admin_agencies_permission')),
          if (session.permissions.contains('banners.propose'))
            (icon: Icons.campaign_outlined,
              label: UiText.get('reference_admin_banners')),
        ];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const Key('reference-admin-menu'),
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00382F),
                      Color(0xFF126B54),
                      Color(0xFF002C26),
                    ],
                  ),
                  border: Border.all(
                    color: ReferencePalette.gold.withValues(alpha: .7)),
                ),
                child: Row(children: [
                  Container(
                    height: 60, width: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x253BD3A0),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                      color: ReferencePalette.paleGold, size: 36),
                  ),
                  const SizedBox(width: 15),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(UiText.get('reference_admin_heading'),
                        style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w900, fontSize: 19)),
                      const SizedBox(height: 5),
                      Text(session.role,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ReferencePalette.paleGold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(UiText.get('reference_admin_secure'),
                        style: const TextStyle(
                          color: Color(0xFFBAE9D9), fontSize: 11)),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 22),
              ReferenceSection(
                title: UiText.get('reference_admin_sections'),
              ),
              const SizedBox(height: 12),
              if (tiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(UiText.get('reference_admin_no_sections'),
                    textAlign: TextAlign.center),
                ),
              for (final tile in tiles)
                ReferenceInfoTile(
                  key: Key('reference-admin-${tile.icon.codePoint}'),
                  title: tile.label,
                  icon: tile.icon,
                  subtitle: UiText.get('reference_admin_readonly'),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ReferencePalette.paleMint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFC6E7D8)),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user_outlined,
                    size: 27, color: ReferencePalette.deep),
                  const SizedBox(width: 12),
                  Expanded(child: Text(UiText.get('admin_beta_readonly'),
                    style: const TextStyle(
                      fontSize: 12, color: ReferencePalette.deep))),
                ]),
              ),
            ],
          ),
        );
      },
    ),
  );
}
