import '../../../core/domain/quotation_status.dart';
import '../../../core/money/money.dart';

/// A line item of a quotation.
class QuotationItem {
  const QuotationItem({
    this.id,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.estimatedCost = Money.zero,
    this.position = 0,
  });

  final String? id;
  final String? productId;
  final String description;
  final double quantity;
  final Money unitPrice;
  final Money lineTotal;
  final Money estimatedCost;
  final int position;

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    return QuotationItem(
      id: json['id'] as String?,
      productId: json['product_id'] as String?,
      description: (json['description'] as String?) ?? 'Item',
      quantity: ((json['quantity'] as num?) ?? 1).toDouble(),
      unitPrice: Money(json['unit_price_cents'] as int? ?? 0),
      lineTotal: Money(json['line_total_cents'] as int? ?? 0),
      estimatedCost: Money(json['estimated_cost_cents'] as int? ?? 0),
      position: (json['position'] as int?) ?? 0,
    );
  }

  /// Payload used when saving a quotation or an order.
  Map<String, dynamic> toRpcPayload() => {
    'product_id': productId,
    'description': description,
    'quantity': quantity,
    'unit_price_cents': unitPrice.cents,
    'estimated_cost_cents': estimatedCost.cents,
    'position': position,
  };
}

/// A quotation sent to a customer.
class Quotation {
  const Quotation({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.quotationNo,
    required this.status,
    this.validUntil,
    this.notes,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.totalAmount,
    required this.netSales,
    required this.estimatedCost,
    this.assignedTo,
    this.convertedOrderId,
    this.createdAt,
    this.items = const [],
  });

  final String id;
  final String customerId;
  final String customerName;
  final String quotationNo;
  final QuotationStatus status;
  final DateTime? validUntil;
  final String? notes;
  final Money subtotal;
  final String discountType;
  final double discountValue;
  final Money discountAmount;
  final Money totalAmount;
  final Money netSales;
  final Money estimatedCost;
  final String? assignedTo;
  final String? convertedOrderId;
  final DateTime? createdAt;
  final List<QuotationItem> items;

  bool get canConvert => status.canConvert;

  factory Quotation.fromJson(
    Map<String, dynamic> json, {
    String customerName = '',
    List<QuotationItem> items = const [],
  }) {
    return Quotation(
      id: json['id'] as String,
      customerId: (json['customer_id'] as String?) ?? '',
      customerName: customerName,
      quotationNo: (json['quotation_no'] as String?) ?? '',
      status: QuotationStatus.fromDb(json['status'] as String?),
      validUntil: _date(json['valid_until']),
      notes: json['notes'] as String?,
      subtotal: Money(json['subtotal_cents'] as int? ?? 0),
      discountType: (json['discount_type'] as String?) ?? 'none',
      discountValue: ((json['discount_value'] as num?) ?? 0).toDouble(),
      discountAmount: Money(json['discount_amount_cents'] as int? ?? 0),
      totalAmount: Money(json['total_amount_cents'] as int? ?? 0),
      netSales: Money(json['net_sales_cents'] as int? ?? 0),
      estimatedCost: Money(json['estimated_cost_cents'] as int? ?? 0),
      assignedTo: json['assigned_to'] as String?,
      convertedOrderId: json['converted_order_id'] as String?,
      createdAt: _date(json['created_at']),
      items: items,
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
