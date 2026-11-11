import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../reports/providers/report_providers.dart';

/// Period selector shared by the dashboard and the report screens.
class PeriodSelectorBar extends ConsumerWidget {
  const PeriodSelectorBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final notifier = ref.read(reportPeriodProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _PeriodChip(
            label: 'This month',
            selected: _isSameMonth(period.from, period.to, DateTime.now()),
            onTap: notifier.thisMonth,
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: 'Last month',
            selected: _isLastMonth(period.from, period.to),
            onTap: notifier.lastMonth,
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: 'Last 12 months',
            selected: _isLast12Months(period.from, period.to),
            onTap: notifier.last12Months,
          ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range_outlined, size: 16),
            label: Text(
              '${AppDate.formatShort(period.from)} – ${AppDate.formatShort(period.to)}',
            ),
            onPressed: () => _pickRange(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final period = ref.read(reportPeriodProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: period.from, end: period.to),
    );
    if (picked == null) return;
    ref.read(reportPeriodProvider.notifier).setRange(picked.start, picked.end);
  }

  bool _isSameMonth(DateTime from, DateTime to, DateTime reference) =>
      from.year == reference.year &&
      from.month == reference.month &&
      to.year == reference.year &&
      to.month == reference.month;

  bool _isLastMonth(DateTime from, DateTime to) {
    final reference = DateTime.now();
    final lastMonth = DateTime(reference.year, reference.month - 1, 1);
    return from.year == lastMonth.year &&
        from.month == lastMonth.month &&
        to.year == lastMonth.year &&
        to.month == lastMonth.month;
  }

  bool _isLast12Months(DateTime from, DateTime to) {
    final reference = DateTime.now();
    return from.year == reference.year - 1 &&
        from.month == reference.month &&
        to.year == reference.year &&
        to.month == reference.month + 1;
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
