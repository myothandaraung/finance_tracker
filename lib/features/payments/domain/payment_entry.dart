import '../../../core/money/money.dart';

/// A row of the cash ledger: a payment or a refund.
class PaymentEntry {
  const PaymentEntry({
    required this.id,
    required this.orderId,
    this.orderNo,
    required this.amount,
    required this.method,
    required this.kind,
    this.reference,
    this.reason,
    this.occurredAt,
    required this.status,
  });

  final String id;
  final String orderId;
  final String? orderNo;
  final Money amount;
  final String method;
  final String kind;
  final String? reference;
  final String? reason;
  final DateTime? occurredAt;
  final String status;

  bool get isRefund => kind == 'refund';

  /// Human label of the payment type.
  String get kindLabel => switch (kind) {
        'deposit' => 'Deposit',
        'installment' => 'Installment',
        'final' => 'Final payment',
        'adjustment' => 'Adjustment',
        'refund' => 'Refund',
        _ => kind,
      };

  factory PaymentEntry.fromJson(
    Map<String, dynamic> json, [
    String? orderNo,
  ]) {
    return PaymentEntry(
      id: json['id'] as String,
      orderId: (json['order_id'] as String?) ?? '',
      orderNo: orderNo,
      amount: Money(json['amount_cents'] as int? ?? 0),
      method: (json['method'] as String?) ?? 'cash',
      kind: (json['kind'] as String?) ?? 'installment',
      reference: json['reference'] as String?,
      occurredAt: DateTime.tryParse('${json['paid_at']}'),
      status: (json['status'] as String?) ?? 'successful',
    );
  }

  factory PaymentEntry.fromRefundJson(
    Map<String, dynamic> json, [
    String? orderNo,
  ]) {
    return PaymentEntry(
      id: json['id'] as String,
      orderId: (json['order_id'] as String?) ?? '',
      orderNo: orderNo,
      amount: Money(json['amount_cents'] as int? ?? 0),
      method: (json['method'] as String?) ?? 'cash',
      kind: 'refund',
      reason: json['reason'] as String?,
      occurredAt: DateTime.tryParse('${json['refunded_at']}'),
      status: 'successful',
    );
  }
}
