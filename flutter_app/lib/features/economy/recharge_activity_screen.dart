import 'package:flutter/material.dart';

import '../../data/totichat_services.dart';
import '../../ui/server_panel.dart';

/// Read-only customer receipt history from the verified Staging backend.
/// This deliberately does not sell coins or direct Play users to an
/// alternative payment provider.
class RechargeActivityScreen extends StatefulWidget {
  const RechargeActivityScreen({super.key, required this.api});
  final TotiChatServices api;

  @override
  State<RechargeActivityScreen> createState() =>
      _RechargeActivityScreenState();
}

class _RechargeActivityScreenState extends State<RechargeActivityScreen> {
  late Future<Map<String, dynamic>> _state;

  @override
  void initState() {
    super.initState();
    _state = widget.api.rechargeState();
  }

  void _refresh() => setState(() { _state = widget.api.rechargeState(); });

  static String _status(Object? value) {
    switch (value) {
      case 'pending':
        return 'قيد المراجعة';
      case 'completed':
        return 'مكتمل';
      case 'failed':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغى';
      default:
        return 'حالة غير معروفة';
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('سجل الشحن'),
        actions: [
          IconButton(
            tooltip: 'تحديث السجل',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ServerPanel<Map<String, dynamic>>(
        future: _state,
        retry: _refresh,
        builder: (context, state) {
          final uid = widget.api.userId;
          final requests = (state['requests'] as List? ?? [])
              .whereType<Map>()
              .where((r) => r['user_id']?.toString() == uid)
              .toList(growable: false);
          final claims = (state['claims'] as List? ?? [])
              .whereType<Map>()
              .where((r) => r['user_id']?.toString() == uid)
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _state;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text('العمليات المسجلة بالخادم',
                  style: TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                const Text(
                  'هذا سجل اطلاع فقط. لا يجري دفع أو شحن من هذه الشاشة.'),
                const SizedBox(height: 16),
                if (requests.isEmpty)
                  const NoRecords('لا توجد طلبات شحن مسجلة على حسابك.'),
                ...requests.map((r) => recordCard(context,
                  title: 'طلب ' + (r['id']?.toString() ?? '—'),
                  icon: Icons.receipt_long_outlined,
                  description: [
                    'الحالة: ' + _status(r['status']),
                    'الكوينز: ' + (r['coins']?.toString() ?? '—'),
                    'القيمة المسجلة: ' +
                      (r['price_usd']?.toString() ?? '—') + ' USD',
                    'التاريخ: ' + (r['created_at']?.toString() ?? '—'),
                  ].join('\n'),
                )),
                if (claims.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('مكافآت الشحن الموثقة',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...claims.map((r) => recordCard(context,
                    title: 'مكافأة مسجلة',
                    icon: Icons.verified_outlined,
                    description: 'تاريخ الاستحقاق: ' +
                      (r['created_at']?.toString() ?? '—'),
                  )),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
