import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../business/providers/business_providers.dart';
import '../../reports/domain/report_models.dart';
import '../../reports/presentation/period_selector_bar.dart';
import '../../reports/providers/report_providers.dart';

/// Landing screen: the money picture of the business for a chosen period.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final trends = ref.watch(monthlyTrendsProvider);
    final membership = ref.watch(activeMembershipProvider);
    final role = ref.watch(currentRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(membership?.name ?? 'Dashboard'),
        actions: [
          if (membership != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  membership.role.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: role.canManageOperations
          ? FloatingActionButton.extended(
              onPressed: () => _showQuickActions(context),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
          ref.invalidate(monthlyTrendsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const PeriodSelectorBar(),
            summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(dashboardSummaryProvider),
                ),
              ),
              data: (data) => _DashboardBody(summary: data),
            ),
            const SizedBox(height: 8),
            trends.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (points) => points.length < 2
                  ? const SizedBox.shrink()
                  : _TrendCard(points: points),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.request_quote_outlined),
              title: const Text('New quotation'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/app/quotations/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('New order'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/app/orders/new');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('New customer'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/app/customers/new');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Cash collected',
                      value: MoneyFormatter.format(summary.cashCollected),
                      icon: Icons.payments_outlined,
                      color: AppColors.primary,
                      hint: 'Payments minus refunds',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      label: 'Revenue',
                      value: MoneyFormatter.format(summary.revenue),
                      icon: Icons.trending_up,
                      color: AppColors.success,
                      hint: 'Delivered orders, net of tax',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Production cost',
                      value: MoneyFormatter.format(summary.productionCost),
                      icon: Icons.precision_manufacturing_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      label: 'Operating expenses',
                      value: MoneyFormatter.format(summary.expenses),
                      icon: Icons.receipt_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Profit',
                      value: MoneyFormatter.format(summary.profit),
                      icon: Icons.savings_outlined,
                      color: summary.profit.isNegative
                          ? AppColors.danger
                          : AppColors.positive,
                      isHighlighted: true,
                      hint: 'Revenue minus production cost',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      label: 'Receivables',
                      value: MoneyFormatter.format(summary.receivables),
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.info,
                      hint: 'Outstanding on all orders',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusPill(
                    label: 'Open orders',
                    value: summary.ordersOpen,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(
                    label: 'Delivered',
                    value: summary.ordersDelivered,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(
                    label: 'Overdue',
                    value: summary.ordersOverdue,
                    color: AppColors.danger,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (summary.expensesByCategory.isNotEmpty)
          _ExpenseBreakdown(categories: summary.expensesByCategory),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseBreakdown extends StatelessWidget {
  const _ExpenseBreakdown({required this.categories});

  final List<CategoryTotal> categories;

  static const _colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.info,
    AppColors.warning,
    AppColors.danger,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(
      0,
      (sum, category) => sum + category.amount.cents,
    );
    if (total <= 0) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expenses by category',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: [
                        for (var index = 0; index < categories.length; index++)
                          PieChartSectionData(
                            value: categories[index].amount.cents.toDouble(),
                            color: _colors[index % _colors.length],
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < categories.length; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _colors[index % _colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  categories[index].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                              Text(
                                MoneyFormatter.format(categories[index].amount),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.points});

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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
              height: 190,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxValue <= 0 ? 100 : maxValue * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.divider,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: maxValue <= 0 ? 50 : (maxValue / 4).ceilToDouble(),
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            MoneyFormatter.formatCompact(
                              _toMoney(value),
                            ),
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
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.textPrimary,
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                            '${spot.barIndex == 0 ? 'Revenue' : 'Cash'}\n'
                            '${MoneyFormatter.format(_toMoney(spot.y))}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
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
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.success.withValues(alpha: 0.08),
                      ),
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

  /// The chart works in centavos, so the value only has to be wrapped.
  static Money _toMoney(double value) => Money(value.round());
}
