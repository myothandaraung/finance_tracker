import '../../../core/domain/order_status.dart';
import '../../../core/money/money.dart';

/// A line item of an order. The unit price is a snapshot: changing the
/// catalog price never changes a historic order.
class OrderItem {
  const OrderItem({
    this.id,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.position = 0,
  });

  final String? id;
  final String? productId;
  final String description;
  final double quantity;
  final Money unitPrice;
  final Money lineTotal;
  final int position;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String?,
      productId: json['product_id'] as String?,
      description: (json['description'] as String?) ?? 'Item',
      quantity: ((json['quantity'] as num?) ?? 1).toDouble(),
      unitPrice: Money(json['unit_price_cents'] as int? ?? 0),
      lineTotal: Money(json['line_total_cents'] as int? ?? 0),
      position: (json['position'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toRpcPayload() => {
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'unit_price_cents': unitPrice.cents,
        'position': position,
      };
}

/// A production cost entry (material, labour, overhead).
class OrderCost {
  const OrderCost({
    required this.id,
    required this.costType,
    this.materialId,
    required this.description,
    required this.quantity,
    required this.unitCost,
    required this.amount,
    required this.costDate,
  });

  final String id;
  final String costType;
  final String? materialId;
  final String description;
  final double quantity;
  final Money unitCost;
  final Money amount;
  final DateTime? costDate;

  factory OrderCost.fromJson(Map<String, dynamic> json) {
    return OrderCost(
      id: json['id'] as String,
      costType: (json['cost_type'] as String?) ?? 'other',
      materialId: json['material_id'] as String?,
      description: (json['description'] as String?) ?? '',
      quantity: ((json['quantity'] as num?) ?? 1).toDouble(),
      unitCost: Money(json['unit_cost_cents'] as int? ?? 0),
      amount: Money(json['amount_cents'] as int? ?? 0),
      costDate: DateTime.tryParse('${json['cost_date']}'),
    );
  }
}

/// One entry of the status timeline.
class OrderStatusEntry {
  const OrderStatusEntry({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.note,
    this.changedBy,
    this.changedAt,
  });

  final String id;
  final String? fromStatus;
  final String toStatus;
  final String? note;
  final String? changedBy;
  final DateTime? changedAt;

  factory OrderStatusEntry.fromJson(Map<String, dynamic> json) {
    return OrderStatusEntry(
      id: json['id'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: (json['to_status'] as String?) ?? '',
      note: json['note'] as String?,
      changedBy: json['changed_by'] as String?,
      changedAt: DateTime.tryParse('${json['changed_at']}'),
    );
  }
}

/// Money already collected on an order.
class OrderFinancials {
  const OrderFinancials({
    required this.totalAmount,
    required this.netSales,
    required this.paidAmount,
    required this.refundedAmount,
    required this.outstandingAmount,
    required this.estimatedCost,
    required this.actualCost,
    required this.profit,
  });

  final Money totalAmount;
  final Money netSales;
  final Money paidAmount;
  final Money refundedAmount;
  final Money outstandingAmount;
  final Money estimatedCost;
  final Money actualCost;
  final Money profit;

  bool get isFullyPaid => outstandingAmount <= Money.zero;

  double get marginPercent {
    if (netSales.cents == 0) return 0;
    return profit.cents / netSales.cents * 100;
  }

  factory OrderFinancials.fromJson(Map<String, dynamic> json) {
    return OrderFinancials(
      totalAmount: Money(json['total_cents'] as int? ?? 0),
      netSales: Money(json['net_sales_cents'] as int? ?? 0),
      paidAmount: Money(json['paid_cents'] as int? ?? 0),
      refundedAmount: Money(json['refunded_cents'] as int? ?? 0),
      outstandingAmount: Money(json['outstanding_cents'] as int? ?? 0),
      estimatedCost: Money(json['estimated_cost_cents'] as int? ?? 0),
      actualCost: Money(json['actual_cost_cents'] as int? ?? 0),
      profit: Money(json['profit_cents'] as int? ?? 0),
    );
  }
}

/// An order.
class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.totalAmount,
    required this.netSales,
    required this.estimatedCost,
    required this.actualCost,
    this.notes,
    this.dueDate,
    this.confirmedAt,
    this.deliveredAt,
    this.assignedTo,
    this.quotationId,
    this.createdAt,
    this.items = const [],
    this.financials,
  });

  final String id;
  final String orderNo;
  final String customerId;
  final String customerName;
  final OrderStatus status;
  final Money subtotal;
  final String discountType;
  final double discountValue;
  final Money discountAmount;
  final Money totalAmount;
  final Money netSales;
  final Money estimatedCost;
  final Money actualCost;
  final String? notes;
  final DateTime? dueDate;
  final DateTime? confirmedAt;
  final DateTime? deliveredAt;
  final String? assignedTo;
  final String? quotationId;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final OrderFinancials? financials;

  bool get allowsItemEditing => status.allowsItemEditing;

  factory Order.fromJson(
    Map<String, dynamic> json, {
    String customerName = '',
    List<OrderItem> items = const [],
    OrderFinancials? financials,
  }) {
    return Order(
      id: json['id'] as String,
      orderNo: (json['order_no'] as String?) ?? '',
      customerId: (json['customer_id'] as String?) ?? '',
      customerName: customerName,
      status: OrderStatus.fromDb(json['status'] as String?),
      subtotal: Money(json['subtotal_cents'] as int? ?? 0),
      discountType: (json['discount_type'] as String?) ?? 'none',
      discountValue: ((json['discount_value'] as num?) ?? 0).toDouble(),
      discountAmount: Money(json['discount_amount_cents'] as int? ?? 0),
      totalAmount: Money(json['total_amount_cents'] as int? ?? 0),
      netSales: Money(json['net_sales_cents'] as int? ?? 0),
      estimatedCost: Money(json['estimated_cost_cents'] as int? ?? 0),
      actualCost: Money(json['actual_cost_cents'] as int? ?? 0),
      notes: json['notes'] as String?,
      dueDate: _date(json['due_date']),
      confirmedAt: _date(json['confirmed_at']),
      deliveredAt: _date(json['delivered_at']),
      assignedTo: json['assigned_to'] as String?,
      quotationId: json['quotation_id'] as String?,
      createdAt: _date(json['created_at']),
      items: items,
      financials: financials,
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

/// The full detail of an order: header, items, money, costs and history.
class OrderDetail {
  const OrderDetail({
    required this.order,
    required this.items,
    required this.financials,
    required this.payments,
    required this.refunds,
    required this.costs,
    required this.history,
  });

  final Order order;
  final List<OrderItem> items;
  final OrderFinancials financials;
  final List<PaymentRecord> payments;
  final List<RefundRecord> refunds;
  final List<OrderCost> costs;
  final List<OrderStatusEntry> history;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final orderJson = Map<String, dynamic>.from(json['order'] as Map);
    final financialsJson = Map<String, dynamic>.from(json['financials'] as Map);

    final items = ((json['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return OrderDetail(
      order: Order.fromJson(
        orderJson,
        items: items,
        financials: OrderFinancials.fromJson(financialsJson),
      ),
      items: items,
      financials: OrderFinancials.fromJson(financialsJson),
      payments: ((json['payments'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => PaymentRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      refunds: ((json['refunds'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => RefundRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      costs: ((json['costs'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => OrderCost.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      history: ((json['history'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => OrderStatusEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

/// A payment received from a customer.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.orderId,
    required this.kind,
    required this.amount,
    required this.method,
    this.reference,
    this.receiptPath,
    required this.paidAt,
    required this.status,
  });

  final String id;
  final String orderId;
  final String kind;
  final Money amount;
  final String method;
  final String? reference;
  final String? receiptPath;
  final DateTime? paidAt;
  final String status;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      orderId: (json['order_id'] as String?) ?? '',
      kind: (json['kind'] as String?) ?? 'installment',
      amount: Money(json['amount_cents'] as int? ?? 0),
      method: (json['method'] as String?) ?? 'cash',
      reference: json['reference'] as String?,
      receiptPath: json['receipt_path'] as String?,
      paidAt: DateTime.tryParse('${json['paid_at']}'),
      status: (json['status'] as String?) ?? 'successful',
    );
  }
}

/// A refund of a previous payment.
class RefundRecord {
  const RefundRecord({
    required this.id,
    required this.orderId,
    this.paymentId,
    required this.amount,
    required this.method,
    this.reason,
    this.refundedAt,
  });

  final String id;
  final String orderId;
  final String? paymentId;
  final Money amount;
  final String method;
  final String? reason;
  final DateTime? refundedAt;

  factory RefundRecord.fromJson(Map<String, dynamic> json) {
    return RefundRecord(
      id: json['id'] as String,
      orderId: (json['order_id'] as String?) ?? '',
      paymentId: json['payment_id'] as String?,
      amount: Money(json['amount_cents'] as int? ?? 0),
      method: (json['method'] as String?) ?? 'cash',
      reason: json['reason'] as String?,
      refundedAt: DateTime.tryParse('${json['refunded_at']}'),
    );
  }
}
