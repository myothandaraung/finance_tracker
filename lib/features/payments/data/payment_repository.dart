import '../../../core/data/supabase_repository.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';

/// Result of a payment submission.
class PaymentResult {
  const PaymentResult({
    required this.paymentId,
    required this.amount,
    required this.outstanding,
    required this.isDuplicate,
  });

  final String paymentId;
  final Money amount;
  final Money outstanding;

  /// True when the same submission was already recorded.
  final bool isDuplicate;
}

class PaymentRepository extends SupabaseRepository {
  const PaymentRepository(super.client);

  /// Records a payment. The idempotency key makes a retry safe: the server
  /// returns the original payment instead of charging twice.
  Future<PaymentResult> recordPayment({
    required String orderId,
    required Money amount,
    required String kind,
    required String method,
    String? reference,
    DateTime? paidAt,
    required String idempotencyKey,
    String? receiptPath,
    bool allowOverpayment = false,
  }) async {
    final result = await callRpc(
      'rpc_record_payment',
      params: {
        'p_order_id': orderId,
        'p_amount_cents': amount.cents,
        'p_kind': kind,
        'p_method': method,
        'p_reference': reference,
        'p_paid_at': (paidAt ?? DateTime.now()).toIso8601String(),
        'p_idempotency_key': idempotencyKey,
        'p_receipt_path': receiptPath,
        'p_allow_overpayment': allowOverpayment,
      },
    );

    final payment = Map<String, dynamic>.from(result['payment'] as Map);
    return PaymentResult(
      paymentId: payment['id'] as String,
      amount: Money(payment['amount_cents'] as int? ?? amount.cents),
      outstanding: Money(result['outstanding_cents'] as int? ?? 0),
      isDuplicate: (result['duplicate'] as bool?) ?? false,
    );
  }

  Future<Money> recordRefund({
    required String paymentId,
    required Money amount,
    String? reason,
    String? method,
  }) async {
    final result = await callRpc(
      'rpc_record_refund',
      params: {
        'p_payment_id': paymentId,
        'p_amount_cents': amount.cents,
        'p_reason': reason,
        'p_method': method,
      },
    );
    return Money(result['outstanding_cents'] as int? ?? 0);
  }

  Future<void> voidPayment({
    required String paymentId,
    String? reason,
  }) async {
    await callRpc(
      'rpc_void_payment',
      params: {
        'p_payment_id': paymentId,
        'p_reason': reason,
      },
    );
  }

  /// Payments of a business in a period (the cash ledger).
  Future<List<Map<String, dynamic>>> listPaymentRows(
    String businessId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = client.from('payments').select().eq('business_id', businessId);
      if (from != null) query = query.gte('paid_at', from.toIso8601String());
      if (to != null) query = query.lte('paid_at', to.toIso8601String());
      return await query.order('paid_at', ascending: false);
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }

  Future<List<Map<String, dynamic>>> listRefundRows(
    String businessId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = client.from('refunds').select().eq('business_id', businessId);
      if (from != null) query = query.gte('refunded_at', from.toIso8601String());
      if (to != null) query = query.lte('refunded_at', to.toIso8601String());
      return await query.order('refunded_at', ascending: false);
    } catch (error) {
      throw AppException.fromSupabase(error);
    }
  }
}
