import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/section_title.dart';
import '../domain/report_models.dart';
import '../providers/report_providers.dart';
import 'period_selector_bar.dart';

/// Revenue, cash collected and the mix of orders for a period.
class SalesReportScreen extends ConsumerWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(salesSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales report')),
      body: Column(
        children: [
          const PeriodSelectorBar(),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(salesSummaryProvider),
              ),
              data: (data) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Revenue',
                          value: MoneyFormatter.format(data.revenue),
                          icon: Icons.trending_up,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          label: 'Profit',
                          value: MoneyFormatter.format(data.profit),
                          icon: Icons.savings_outlined,
                          color: data.profit.cents >= 0
                              ? AppColors.positive
                              : AppColors.negative,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  MetricCard(
                    label: 'Delivered orders',
                    value: '${data.ordersCount}',
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  if (data.byMonth.length > 1)
                    _MonthlyChart(points: data.byMonth),
                  if (data.byStatus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          const SectionTitle('Orders by status'),
                          for (final status in data.byStatus)
                            ListTile(
                              dense: true,
                              title: Text(status.status),
                              trailing: Text(
                                '${status.count}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.points});

  final List<MonthPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<double>(
      0,
      (max, point) => point.revenue.cents > point.cashCollected.cents
          ? point.revenue.cents.toDouble()
          : point.cashCollected.cents.toDouble(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Revenue vs cash collected',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxValue <= 0 ? 100 : maxValue * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: maxValue <= 0
                            ? 50
                            : (maxValue / 4).ceilToDouble(),
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            MoneyFormatter.formatCompact(Money(value.round())),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              points[index].label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var index = 0; index < points.length; index++)
                          FlSpot(
                            index.toDouble(),
                            points[index].revenue.cents.toDouble(),
                          ),
                      ],
                      isCurved: true,
                      color: AppColors.success,
                      barWidth: 2.4,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: [
                        for (var index = 0; index < points.length; index++)
                          FlSpot(
                            index.toDouble(),
                            points[index].cashCollected.cents.toDouble(),
                          ),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.4,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
