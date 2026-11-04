import '../../../core/data/supabase_repository.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/report_models.dart';

/// Report queries. Every report is a security-definer function on the
/// server, so the client only sends the business and the period.
class ReportRepository extends SupabaseRepository {
  const ReportRepository(super.client);

  Future<DashboardSummary> dashboardSummary({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await callRpc(
      'rpc_dashboard_summary',
      params: {
        'p_business_id': businessId,
        'p_from': AppDate.isoDate(from),
        'p_to': AppDate.isoDate(to),
      },
    );
    return DashboardSummary.fromJson(result);
  }

  Future<SalesSummary> salesSummary({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await callRpc(
      'rpc_sales_summary',
      params: {
        'p_business_id': businessId,
        'p_from': AppDate.isoDate(from),
        'p_to': AppDate.isoDate(to),
      },
    );
    return SalesSummary.fromJson(result);
  }

  Future<ProfitabilityReport> profitability({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await callRpc(
      'rpc_profitability_report',
      params: {
        'p_business_id': businessId,
        'p_from': AppDate.isoDate(from),
        'p_to': AppDate.isoDate(to),
      },
    );
    return ProfitabilityReport.fromJson(result);
  }

  Future<ReceivablesReport> receivables({
    required String businessId,
    DateTime? asOf,
  }) async {
    final result = await callRpc(
      'rpc_receivables_report',
      params: {
        'p_business_id': businessId,
        'p_as_of': AppDate.isoDate(asOf ?? DateTime.now()),
      },
    );
    return ReceivablesReport.fromJson(result);
  }

  Future<List<MonthPoint>> monthlyTrends({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await callRpc(
      'rpc_monthly_trends',
      params: {
        'p_business_id': businessId,
        'p_from': AppDate.isoDate(from),
        'p_to': AppDate.isoDate(to),
      },
    );
    return ((result['rows'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => MonthPoint.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
