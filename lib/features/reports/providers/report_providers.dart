import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../business/providers/business_providers.dart';
import '../data/report_repository.dart';
import '../domain/report_models.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(supabaseClientProvider));
});

/// The period every report is built for.
class ReportPeriod {
  const ReportPeriod({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  String get label {
    if (from.year == to.year && from.month == to.month) {
      return '${from.month}/${from.year}';
    }
    return '${from.day}/${from.month}/${from.year} – ${to.day}/${to.month}/${to.year}';
  }
}

class ReportPeriodNotifier extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() {
    final now = DateTime.now();
    return ReportPeriod(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month + 1, 0),
    );
  }

  void setRange(DateTime from, DateTime to) {
    state = ReportPeriod(from: from, to: to);
  }

  void thisMonth() {
    final now = DateTime.now();
    setRange(DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
  }

  void lastMonth() {
    final now = DateTime.now();
    setRange(
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month, 0),
    );
  }

  void last12Months() {
    final now = DateTime.now();
    setRange(DateTime(now.year - 1, now.month, 1), DateTime(now.year, now.month + 1, 0));
  }
}

final reportPeriodProvider =
    NotifierProvider<ReportPeriodNotifier, ReportPeriod>(ReportPeriodNotifier.new);

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) throw StateError('No business selected');

  final period = ref.watch(reportPeriodProvider);
  return ref.watch(reportRepositoryProvider).dashboardSummary(
        businessId: businessId,
        from: period.from,
        to: period.to,
      );
});

final salesSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) throw StateError('No business selected');

  final period = ref.watch(reportPeriodProvider);
  return ref.watch(reportRepositoryProvider).salesSummary(
        businessId: businessId,
        from: period.from,
        to: period.to,
      );
});

final profitabilityReportProvider =
    FutureProvider<ProfitabilityReport>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) throw StateError('No business selected');

  final period = ref.watch(reportPeriodProvider);
  return ref.watch(reportRepositoryProvider).profitability(
        businessId: businessId,
        from: period.from,
        to: period.to,
      );
});

final receivablesReportProvider =
    FutureProvider<ReceivablesReport>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) throw StateError('No business selected');

  return ref.watch(reportRepositoryProvider).receivables(businessId: businessId);
});

final monthlyTrendsProvider = FutureProvider<List<MonthPoint>>((ref) async {
  final businessId = ref.watch(activeBusinessIdProvider);
  if (businessId == null) throw StateError('No business selected');

  final period = ref.watch(reportPeriodProvider);
  return ref.watch(reportRepositoryProvider).monthlyTrends(
        businessId: businessId,
        from: period.from,
        to: period.to,
      );
});
