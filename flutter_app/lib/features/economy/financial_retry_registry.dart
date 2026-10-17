import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks unresolved financial commands while this app process is running.
///
/// Each Supabase client has its own journal. Every scope contains the actor's
/// authenticated ID and the operation family, so another signed-in account
/// never inherits an unresolved request from the previous one.
///
/// The only safe way to clear a request is a server-verified receipt. Never
/// clear it on timeouts, navigation, changed catalog data or a generic error.
/// This is *in-memory* protection, not crash-proof persistence; reconciliation
/// after force-stop must still be verified with server-side records.
class FinancialPendingIntent {
  const FinancialPendingIntent({
    required this.requestId,
    required this.signature,
  });

  final String requestId;
  final String signature;
}

class FinancialRetryRegistry {
  FinancialRetryRegistry._();

  static final Expando<FinancialRetryRegistry> _byClient =
      Expando<FinancialRetryRegistry>('TotiChat financial retry journal');

  static FinancialRetryRegistry forClient(Object client) =>
      _byClient[client] ??= FinancialRetryRegistry._();

  /// Distinguish a gift and a store purchase and isolate signed-in accounts.
  /// A test Fake may not implement auth; that fallback is only a local journal
  /// namespace, never permission to execute a financial RPC.
  static String scopeFor(SupabaseClient client, String family) {
    if (family != 'gift' && family != 'store') {
      throw ArgumentError('Unsupported financial operation');
    }
    String? actor;
    try {
      actor = client.auth.currentUser?.id;
    } catch (_) {
      // Some pure widget tests deliberately use a client with no auth stack.
    }
    return '$family:${actor ?? 'not-signed-in'}';
  }

  final Map<String, FinancialPendingIntent> _pending = {};

  FinancialPendingIntent? pending(String scope) => _pending[scope];

  FinancialPendingIntent reserve({
    required String scope,
    required String signature,
    required String Function() newRequestId,
  }) {
    if (scope.isEmpty || signature.isEmpty) {
      throw ArgumentError('Financial command needs a nonempty scope and signature');
    }
    final prior = _pending[scope];
    if (prior != null) {
      if (prior.signature != signature) {
        throw StateError(
          'Unresolved financial request: retry the exact same purchase '
          'before choosing a different item or recipient.',
        );
      }
      return prior;
    }
    final requestId = newRequestId();
    if (requestId.isEmpty) throw StateError('Missing transaction request ID');
    final intent = FinancialPendingIntent(
      requestId: requestId, signature: signature,
    );
    _pending[scope] = intent;
    return intent;
  }

  void confirm({
    required String scope,
    required String requestId,
  }) {
    final prior = _pending[scope];
    if (prior == null || prior.requestId != requestId) {
      throw StateError('A different purchase request was confirmed');
    }
    _pending.remove(scope);
  }
}
