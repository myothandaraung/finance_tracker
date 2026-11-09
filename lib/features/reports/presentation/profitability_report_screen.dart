import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/metric_card.dart';
import '../providers/report_providers.dart';
import 'period_selector_bar.dart';

/// Margin of every order delivered in the period.
class ProfitabilityReportScreen extends ConsumerWidget {
  const ProfitabilityReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(profitabilityReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profitability')),
      body: Column(
        children: [
          const PeriodSelectorBar(),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(profitabilityReportProvider),
              ),
              data: (data) {
                if (data.rows.isEmpty) {
                  return const EmptyState(
                    title: 'Nothing delivered in this period',
                    message:
                        'Revenue is recognised when an order is delivered.',
                    icon: Icons.pie_chart_outline,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: 'Estimated cost',
                            value: MoneyFormatter.format(data.estimatedProductionCost),
                            icon: Icons.precision_manufacturing_outlined,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: 'Actual cost',
                            value: MoneyFormatter.format(data.actualCost),
                            icon: Icons.precision_manufacturing_outlined,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MetricCard(
                      label: 'Profit',
                      value: MoneyFormatter.format(data.profit),
                      icon: Icons.savings_outlined,
                      color: data.profit.cents >= 0
                          ? AppColors.positive
                          : AppColors.negative,
                      isHighlighted: true,
                      hint: data.profitEstimated == null
                          ? 'Estimated cost ${MoneyFormatter.format(data.estimatedCost)}'
                          : 'Estimated profit ${MoneyFormatter.format(data.profitEstimated!)}',
                    ),
                    const SizedBox(height: 12),
                    for (final row in data.rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(
                              row.orderNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                row.customerName,
                                AppDate.format(row.deliveredAt),
                                'cost ${MoneyFormatter.format(row.actualCost)}',
                                if (row.productionCostSource != null)
                                  'source ${row.productionCostSource}',
                                if (row.estimatedProductionCost.cents > 0)
                                  'est ${MoneyFormatter.format(row.estimatedProductionCost)}',
                              ].join(' · '),
                            ),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  MoneyFormatter.format(row.profit),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: row.profit.cents >= 0
                                        ? AppColors.positive
                                        : AppColors.negative,
                                  ),
                                ),
                                if (row.marginPercent != null)
                                  Text(
                                    '${row.marginPercent!.toStringAsFixed(1)}% margin',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                if (row.profitEstimated != null &&
                                    row.marginPercentEstimated != null)
                                  Text(
                                    'est ${row.marginPercentEstimated!.toStringAsFixed(1)}%',
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
          ),
        ],
      ),
    );
  }
}
