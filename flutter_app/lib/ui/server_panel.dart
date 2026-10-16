import 'package:flutter/material.dart';

/// Do not substitute a fake empty state when the authenticated API fails.
class ServerPanel<T> extends StatelessWidget {
  const ServerPanel({
    super.key, required this.future, required this.builder, required this.retry,
  });
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: Padding(padding: EdgeInsets.all(35),
          child: CircularProgressIndicator()));
      }
      if (snap.hasError || !snap.hasData) {
        return Center(child: Padding(padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: 10),
            const Text('تعذّر جلب البيانات الحقيقية من الخادم',
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة')),
          ])));
      }
      return builder(context, snap.data as T);
    },
  );
}

class NoRecords extends StatelessWidget {
  const NoRecords(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Center(child: Text(message, textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.black54))),
  );
}

void showApiError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('تعذر إكمال العملية: $error'), duration: const Duration(seconds: 4)));
}

Widget recordCard(BuildContext context, {
  required String title, String? description, IconData icon = Icons.article_outlined,
  VoidCallback? onTap, Widget? trailing,
}) => Card(child: ListTile(
  leading: CircleAvatar(child: Icon(icon)),
  title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
  subtitle: description == null ? null : Text(description,
    maxLines: 3, overflow: TextOverflow.ellipsis),
  onTap: onTap, trailing: trailing,
));
