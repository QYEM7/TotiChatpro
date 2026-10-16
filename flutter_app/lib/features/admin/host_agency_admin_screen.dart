import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Owner-only host agency administration. Permissions and registration
/// decisions are also enforced by the server, never by a client-side role flag.
class HostAgencyAdminScreen extends StatefulWidget {
  const HostAgencyAdminScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<HostAgencyAdminScreen> createState() => _HostAgencyAdminScreenState();
}

class _HostAgencyAdminScreenState extends State<HostAgencyAdminScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  String? _pendingId, _pendingSignature;

  @override
  void initState() {
    super.initState();
    _future = widget.api.agencyState();
  }

  void _refresh() => setState(() => _future = widget.api.agencyState());

  Future<void> _review(Map<dynamic, dynamic> registration, bool approve) async {
    if (_busy) return;
    final id = registration['id']?.toString() ?? '';
    if (id.isEmpty || registration['kind'] != 'host' ||
        registration['status'] != 'pending') return;

    final noteController = TextEditingController();
    final commissionController = TextEditingController();
    final decision = await showDialog<({String note, String commission})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'الموافقة على وكالة مضيفين' : 'رفض طلب وكالة'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(registration['name']?.toString() ?? 'Agency request'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController, maxLength: 500, maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ملاحظة القرار *'),
            ),
            if (approve) TextField(
              controller: commissionController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true),
              decoration: const InputDecoration(
                labelText: 'نسبة العمولة المتفق عليها % *',
                helperText: 'من 0 إلى 100، وتُحفظ بالخادم'),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              note: noteController.text.trim(),
              commission: commissionController.text.trim(),
            )),
            child: const Text('تأكيد القرار'),
          ),
        ],
      ),
    );
    noteController.dispose();
    commissionController.dispose();

    if (!mounted || decision == null) return;
    final commission = approve
        ? double.tryParse(decision.commission.replaceAll(',', '.'))
        : null;
    if (decision.note.length < 3 || decision.note.length > 500 ||
        (approve && (commission == null ||
          !commission.isFinite || commission < 0 || commission > 100))) {
      showApiError(context, 'ملاحظة القرار أو نسبة العمولة غير صالحة.');
      return;
    }

    final action = approve ? 'approve_registration' : 'reject_registration';
    final signature = [
      id, action, decision.note,
      if (approve) commission!.toString(),
    ].join('|');
    if (_pendingSignature != null && _pendingSignature != signature) {
      showApiError(context,
        'يوجد قرار سابق لم نتأكد من نتيجته. أعد المحاولة بنفس '
        'التفاصيل لتجنب تسجيل قرارين مختلفين.');
      return;
    }
    _pendingSignature = signature;
    _pendingId ??= TotiChatServices.requestId();
    setState(() => _busy = true);
    try {
      await widget.api.reviewHostRegistration(
        registrationId: id, approve: approve,
        note: decision.note, commissionPercent: commission,
        requestId: _pendingId!,
      );
      _pendingId = null;
      _pendingSignature = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل قرار الوكالة على الخادم')));
        _refresh();
      }
    } catch (error) {
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إدارة وكالات المضيفين'),
        actions: [
          IconButton(onPressed: _refresh,
            icon: const Icon(Icons.refresh)),
        ]),
      body: ServerPanel<Map<String, dynamic>>(
        future: _future, retry: _refresh,
        builder: (context, state) {
          final authority = state['authority'];
          // Fail closed even if someone navigates here directly.
          if (authority is! Map || authority['isOwner'] != true) {
            return const NoRecords('هذه الصفحة متاحة للمالك فقط.');
          }
          final requests = (state['registrations'] as List? ?? [])
              .whereType<Map>()
              .where((x) => x['kind'] == 'host' &&
                             x['status'] == 'pending').toList();
          final agencies = (state['agencies'] as List? ?? [])
              .whereType<Map>()
              .where((x) => x['kind'] == 'host').toList();
          final members = (state['members'] as List? ?? [])
              .whereType<Map>().toList();

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text('طلبات فتح الوكالات',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (requests.isEmpty)
                  const NoRecords('لا توجد طلبات فتح معلقة.'),
                ...requests.map((r) => recordCard(context,
                  title: r['name']?.toString() ?? 'Host registration',
                  icon: Icons.pending_actions_outlined,
                  description: 'رقم الطلب: ' +
                    (r['id']?.toString() ?? '—'),
                  trailing: Wrap(spacing: 8, children: [
                    FilledButton.tonal(
                      onPressed: _busy ? null : () => _review(r, true),
                      child: const Text('موافقة')),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _review(r, false),
                      child: const Text('رفض')),
                  ]),
                )),
                const SizedBox(height: 24),
                const Text('وكالات المضيفين المسجلة',
                  style: TextStyle(fontSize: 19,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (agencies.isEmpty)
                  const NoRecords('لا توجد وكالات مضيفين مسجلة.'),
                ...agencies.map((a) {
                  final count = members.where(
                    (m) => m['agency_id'] == a['id']).length;
                  return recordCard(context,
                    title: a['name']?.toString() ?? 'Host agency',
                    icon: Icons.business_outlined,
                    description: [
                      'الحالة: ' +
                        (a['is_active'] == true ? 'فعّالة' : 'مغلقة'),
                      'المضيفون المسجلون: ' + count.toString(),
                      'العمولة: ' +
                        (a['commission_percent']?.toString() ?? '—') + '%',
                    ].join('\n'),
                  );
                }),
              ],
            ),
          );
        },
      ),
    ),
  );
}
