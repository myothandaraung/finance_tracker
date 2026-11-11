import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/metric_card.dart';
import '../domain/payment_entry.dart';
import '../providers/payment_providers.dart';

/// The cash ledger: every payment and refund, newest first.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(paymentsLedgerProvider);
    final refunds = ref.watch(refundsLedgerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cash ledger')),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(paymentsLedgerProvider),
        ),
        data: (entries) {
          final refundEntries = refunds.value ?? <PaymentEntry>[];
          final collected = entries
              .where((entry) => entry.status == 'successful')
              .fold<int>(0, (sum, entry) => sum + entry.amount.cents);
          final refunded = refundEntries.fold<int>(
            0,
            (sum, entry) => sum + entry.amount.cents,
          );

          if (entries.isEmpty && refundEntries.isEmpty) {
            return const EmptyState(
              title: 'No cash movement yet',
              message: 'Payments recorded on an order show up here.',
              icon: Icons.payments_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Collected',
                      value: MoneyFormatter.format(Money(collected)),
                      icon: Icons.south_west,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      label: 'Refunded',
                      value: MoneyFormatter.format(Money(refunded)),
                      icon: Icons.north_east,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MetricCard(
                label: 'Net cash',
                value: MoneyFormatter.format(Money(collected - refunded)),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
                isHighlighted: true,
              ),
              const SizedBox(height: 16),
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        entry.isRefund ? Icons.undo : Icons.south_west,
                        color: entry.isRefund
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      title: Text(
                        '${entry.orderNo ?? 'Order'} · ${entry.kindLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          AppDate.formatDateTime(entry.occurredAt),
                          entry.method,
                          if (entry.reference != null) entry.reference!,
                        ].join(' · '),
                      ),
                      trailing: Text(
                        MoneyFormatter.format(entry.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: entry.isRefund
                              ? AppColors.warning
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
