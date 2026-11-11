import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../../orders/providers/order_providers.dart';
import '../data/payment_repository.dart';
import '../domain/payment_entry.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(supabaseClientProvider));
});

/// Cash collected in a period, enriched with the order number.
final paymentsLedgerProvider = FutureProvider<List<PaymentEntry>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];

  final repository = ref.watch(paymentRepositoryProvider);
  final rows = await repository.listPaymentRows(businessId);

  final orderRows = await ref
      .watch(orderRepositoryProvider)
      .listOrderRows(businessId);
  final orderNumbers = {
    for (final row in orderRows) row['id'] as String: row['order_no'] as String,
  };

  return rows
      .map((row) => PaymentEntry.fromJson(row, orderNumbers[row['order_id']]))
      .toList(growable: false);
});

/// Refunds issued in a period.
final refundsLedgerProvider = FutureProvider<List<PaymentEntry>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) return const [];

  final repository = ref.watch(paymentRepositoryProvider);
  final rows = await repository.listRefundRows(businessId);

  final orderRows = await ref
      .watch(orderRepositoryProvider)
      .listOrderRows(businessId);
  final orderNumbers = {
    for (final row in orderRows) row['id'] as String: row['order_no'] as String,
  };

  return rows
      .map(
        (row) =>
            PaymentEntry.fromRefundJson(row, orderNumbers[row['order_id']]),
      )
      .toList(growable: false);
});
