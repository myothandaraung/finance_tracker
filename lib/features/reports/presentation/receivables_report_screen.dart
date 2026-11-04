import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/export/csv_exporter.dart';
import '../../../core/export/export_service.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/metric_card.dart';
import '../domain/report_models.dart';
import '../providers/report_providers.dart';

/// Outstanding balances and their ageing.
class ReceivablesReportScreen extends ConsumerWidget {
  const ReceivablesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(receivablesReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receivables'),
        actions: [
          report.maybeWhen(
            data: (data) => data.rows.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: 'Export as CSV',
                    onPressed: () => _export(context, data),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(receivablesReportProvider),
        ),
        data: (data) {
          if (data.rows.isEmpty) {
            return const EmptyState(
              title: 'Nothing outstanding',
              message: 'Every order is fully paid.',
              icon: Icons.check_circle_outline,
            );
          }

          final buckets = <String, int>{};
          for (final row in data.rows) {
            buckets[row.ageBucket] = (buckets[row.ageBucket] ?? 0) +
                row.outstanding.cents;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Outstanding',
                      value: MoneyFormatter.format(data.total),
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      label: 'Overdue',
                      value: MoneyFormatter.format(data.overdue),
                      icon: Icons.schedule,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ageing',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final entry in buckets.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _bucketLabel(entry.key),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                MoneyFormatter.format(
                                  _toMoney(entry.value),
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final row in data.rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        row.orderNo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          row.customerName,
                          if (row.dueDate != null)
                            'due ${AppDate.formatShort(row.dueDate)}',
                          row.ageLabel,
                        ].join(' · '),
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            MoneyFormatter.format(row.outstanding),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'of ${MoneyFormatter.format(row.total)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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

  static Money _toMoney(int cents) => Money(cents);

  String _bucketLabel(String bucket) => switch (bucket) {
        'current' => 'Current',
        '1_30' => '1–30 days overdue',
        '31_60' => '31–60 days overdue',
        '61_90' => '61–90 days overdue',
        '90_plus' => 'More than 90 days',
        _ => 'No due date',
      };

  Future<void> _export(
    BuildContext context,
    ReceivablesReport report,
  ) async {
    final rows = <List<dynamic>>[
      [
        'Order',
        'Customer',
        'Status',
        'Total',
        'Paid',
        'Outstanding',
        'Due date',
        'Days overdue',
        'Age bucket',
      ],
      for (final row in report.rows)
        [
          row.orderNo,
          row.customerName,
          row.status,
          row.total.plain,
          row.paid.plain,
          row.outstanding.plain,
          row.dueDate == null ? '' : AppDate.isoDate(row.dueDate!),
          row.daysOverdue ?? '',
          row.ageBucket,
        ],
    ];

    try {
      final path = await ExportService.saveCsv(
        content: CsvExporter.encode(rows),
        filename: 'receivables-${AppDate.isoDate(DateTime.now())}.csv',
      );
      if (!context.mounted) return;
      showAppSnackBar(context, 'Exported to $path');
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(context, 'Could not export the report', isError: true);
    }
  }
}
