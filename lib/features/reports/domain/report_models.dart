import '../../../core/money/money.dart';

/// Headline numbers of the dashboard for one period.
class DashboardSummary {
  const DashboardSummary({
    required this.from,
    required this.to,
    required this.ordersCount,
    required this.ordersDelivered,
    required this.ordersOpen,
    required this.ordersOverdue,
    required this.cashCollected,
    required this.revenue,
    required this.expenses,
    required this.productionCost,
    required this.receivables,
    required this.profit,
    required this.expensesByCategory,
  });

  final DateTime from;
  final DateTime to;
  final int ordersCount;
  final int ordersDelivered;
  final int ordersOpen;
  final int ordersOverdue;
  final Money cashCollected;
  final Money revenue;
  final Money expenses;
  final Money productionCost;
  final Money receivables;
  final Money profit;
  final List<CategoryTotal> expensesByCategory;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      from: DateTime.tryParse('${json['from']}') ?? DateTime.now(),
      to: DateTime.tryParse('${json['to']}') ?? DateTime.now(),
      ordersCount: (json['orders_count'] as int?) ?? 0,
      ordersDelivered: (json['orders_delivered'] as int?) ?? 0,
      ordersOpen: (json['orders_open'] as int?) ?? 0,
      ordersOverdue: (json['orders_overdue'] as int?) ?? 0,
      cashCollected: Money(json['cash_collected_cents'] as int? ?? 0),
      revenue: Money(json['revenue_cents'] as int? ?? 0),
      expenses: Money(json['expenses_cents'] as int? ?? 0),
      productionCost: Money(json['production_cost_cents'] as int? ?? 0),
      receivables: Money(json['receivables_cents'] as int? ?? 0),
      profit: Money(json['profit_cents'] as int? ?? 0),
      expensesByCategory: ((json['expenses_by_category'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => CategoryTotal.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

/// One slice of a breakdown (expenses by category).
class CategoryTotal {
  const CategoryTotal({
    this.categoryId,
    required this.name,
    required this.amount,
  });

  final String? categoryId;
  final String name;
  final Money amount;

  factory CategoryTotal.fromJson(Map<String, dynamic> json) {
    return CategoryTotal(
      categoryId: json['category_id'] as String?,
      name: (json['name'] as String?) ?? 'Uncategorised',
      amount: Money(json['amount_cents'] as int? ?? 0),
    );
  }
}

/// One point of a monthly series.
class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.label,
    required this.revenue,
    required this.cashCollected,
    this.expenses = Money.zero,
    this.productionCost = Money.zero,
  });

  final String month;
  final String label;
  final Money revenue;
  final Money cashCollected;
  final Money expenses;
  final Money productionCost;

  Money get profit => revenue - productionCost;

  factory MonthPoint.fromJson(Map<String, dynamic> json) {
    return MonthPoint(
      month: (json['month'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      revenue: Money(json['revenue_cents'] as int? ?? 0),
      cashCollected: Money(json['cash_collected_cents'] as int? ?? 0),
      expenses: Money(json['expenses_cents'] as int? ?? 0),
      productionCost: Money(json['production_cost_cents'] as int? ?? 0),
    );
  }
}

/// Totals of the sales report.
class SalesSummary {
  const SalesSummary({
    required this.from,
    required this.to,
    required this.ordersCount,
    required this.revenue,
    required this.profit,
    required this.byMonth,
    required this.byStatus,
  });

  final DateTime from;
  final DateTime to;
  final int ordersCount;
  final Money revenue;
  final Money profit;
  final List<MonthPoint> byMonth;
  final List<StatusCount> byStatus;

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] as Map? ?? const {});
    return SalesSummary(
      from: DateTime.tryParse('${json['from']}') ?? DateTime.now(),
      to: DateTime.tryParse('${json['to']}') ?? DateTime.now(),
      ordersCount: (totals['orders_count'] as int?) ?? 0,
      revenue: Money(totals['revenue_cents'] as int? ?? 0),
      profit: Money(totals['profit_cents'] as int? ?? 0),
      byMonth: ((json['by_month'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => MonthPoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      byStatus: ((json['by_status'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => StatusCount.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

/// Number of orders in one status.
class StatusCount {
  const StatusCount({required this.status, required this.count});

  final String status;
  final int count;

  factory StatusCount.fromJson(Map<String, dynamic> json) {
    return StatusCount(
      status: (json['status'] as String?) ?? '',
      count: (json['count'] as int?) ?? 0,
    );
  }
}

/// One row of the profitability report.
class ProfitabilityRow {
  const ProfitabilityRow({
    required this.orderId,
    required this.orderNo,
    required this.customerName,
    required this.status,
    this.deliveredAt,
    required this.netSales,
    required this.estimatedCost,
    required this.actualCost,
    required this.profit,
    this.marginPercent,
  });

  final String orderId;
  final String orderNo;
  final String customerName;
  final String status;
  final DateTime? deliveredAt;
  final Money netSales;
  final Money estimatedCost;
  final Money actualCost;
  final Money profit;
  final double? marginPercent;

  factory ProfitabilityRow.fromJson(Map<String, dynamic> json) {
    return ProfitabilityRow(
      orderId: (json['order_id'] as String?) ?? '',
      orderNo: (json['order_no'] as String?) ?? '',
      customerName: (json['customer_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      deliveredAt: DateTime.tryParse('${json['delivered_at']}'),
      netSales: Money(json['net_sales_cents'] as int? ?? 0),
      estimatedCost: Money(json['estimated_cost_cents'] as int? ?? 0),
      actualCost: Money(json['actual_cost_cents'] as int? ?? 0),
      profit: Money(json['profit_cents'] as int? ?? 0),
      marginPercent: (json['margin_pct'] as num?)?.toDouble(),
    );
  }
}

/// Totals and rows of the profitability report.
class ProfitabilityReport {
  const ProfitabilityReport({
    required this.from,
    required this.to,
    required this.revenue,
    required this.estimatedCost,
    required this.actualCost,
    required this.profit,
    required this.rows,
  });

  final DateTime from;
  final DateTime to;
  final Money revenue;
  final Money estimatedCost;
  final Money actualCost;
  final Money profit;
  final List<ProfitabilityRow> rows;

  factory ProfitabilityReport.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] as Map? ?? const {});
    return ProfitabilityReport(
      from: DateTime.tryParse('${json['from']}') ?? DateTime.now(),
      to: DateTime.tryParse('${json['to']}') ?? DateTime.now(),
      revenue: Money(totals['revenue_cents'] as int? ?? 0),
      estimatedCost: Money(totals['estimated_cost_cents'] as int? ?? 0),
      actualCost: Money(totals['actual_cost_cents'] as int? ?? 0),
      profit: Money(totals['profit_cents'] as int? ?? 0),
      rows: ((json['rows'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ProfitabilityRow.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

/// One row of the receivables report.
class ReceivableRow {
  const ReceivableRow({
    required this.orderId,
    required this.orderNo,
    required this.customerName,
    required this.status,
    required this.total,
    required this.paid,
    required this.outstanding,
    this.dueDate,
    this.daysOverdue,
    required this.ageBucket,
  });

  final String orderId;
  final String orderNo;
  final String customerName;
  final String status;
  final Money total;
  final Money paid;
  final Money outstanding;
  final DateTime? dueDate;
  final int? daysOverdue;
  final String ageBucket;

  String get ageLabel => switch (ageBucket) {
        'current' => 'Current',
        '1_30' => '1–30 days',
        '31_60' => '31–60 days',
        '61_90' => '61–90 days',
        '90_plus' => '90+ days',
        _ => 'No due date',
      };

  factory ReceivableRow.fromJson(Map<String, dynamic> json) {
    return ReceivableRow(
      orderId: (json['order_id'] as String?) ?? '',
      orderNo: (json['order_no'] as String?) ?? '',
      customerName: (json['customer_name'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      total: Money(json['total_cents'] as int? ?? 0),
      paid: Money(json['paid_cents'] as int? ?? 0),
      outstanding: Money(json['outstanding_cents'] as int? ?? 0),
      dueDate: DateTime.tryParse('${json['due_date']}'),
      daysOverdue: (json['days_overdue'] as int?),
      ageBucket: (json['age_bucket'] as String?) ?? 'no_due_date',
    );
  }
}

/// Totals and rows of the receivables report.
class ReceivablesReport {
  const ReceivablesReport({
    required this.asOf,
    required this.total,
    required this.overdue,
    required this.rows,
  });

  final DateTime asOf;
  final Money total;
  final Money overdue;
  final List<ReceivableRow> rows;

  factory ReceivablesReport.fromJson(Map<String, dynamic> json) {
    return ReceivablesReport(
      asOf: DateTime.tryParse('${json['as_of']}') ?? DateTime.now(),
      total: Money(json['total_cents'] as int? ?? 0),
      overdue: Money(json['overdue_cents'] as int? ?? 0),
      rows: ((json['rows'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ReceivableRow.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
