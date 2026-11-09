import 'package:flutter_test/flutter_test.dart';
import 'package:mto_finance/core/domain/order_status.dart';
import 'package:mto_finance/core/domain/quotation_status.dart';
import 'package:mto_finance/core/money/money.dart';
import 'package:mto_finance/features/orders/domain/order.dart';
import 'package:mto_finance/features/products/domain/product.dart';
import 'package:mto_finance/features/quotations/domain/quotation.dart';

void main() {
  test('reads a quotation from the database row', () {
    final quotation = Quotation.fromJson(
      {
        'id': 'q1',
        'customer_id': 'c1',
        'quotation_no': 'QUO-2026-0001',
        'status': 'sent',
        'valid_until': '2026-12-31',
        'subtotal_cents': 200000,
        'discount_type': 'percent',
        'discount_value': 10,
        'discount_amount_cents': 20000,
        'tax_rate': 12,
        'tax_amount_cents': 21600,
        'total_amount_cents': 201600,
        'net_sales_cents': 180000,
        'estimated_cost_cents': 80000,
        'created_at': '2026-10-01T08:00:00Z',
      },
      customerName: 'Juan Dela Cruz',
    );

    expect(quotation.quotationNo, 'QUO-2026-0001');
    expect(quotation.customerName, 'Juan Dela Cruz');
    expect(quotation.status, QuotationStatus.sent);
    expect(quotation.totalAmount, Money(201600));
    expect(quotation.netSales, Money(180000));
    expect(quotation.validUntil, DateTime(2026, 12, 31));
    expect(quotation.status.allowsEditing, isTrue);
  });

  test('reads the order detail returned by the report function', () {
    final detail = OrderDetail.fromJson({
      'order': {
        'id': 'o1',
        'order_no': 'ORD-2026-0001',
        'customer_id': 'c1',
        'status': 'delivered',
        'subtotal_cents': 200000,
        'discount_type': 'none',
        'discount_value': 0,
        'discount_amount_cents': 0,
        'tax_rate': 12,
        'tax_amount_cents': 24000,
        'total_amount_cents': 224000,
        'net_sales_cents': 200000,
        'estimated_cost_cents': 80000,
        'actual_cost_cents': 75000,
        'delivered_at': '2026-10-10T08:00:00Z',
      },
      'financials': {
        'total_cents': 224000,
        'net_sales_cents': 200000,
        'paid_cents': 224000,
        'refunded_cents': 0,
        'outstanding_cents': 0,
        'estimated_cost_cents': 80000,
        'actual_cost_cents': 75000,
        'profit_cents': 125000,
      },
      'items': [
        {
          'id': 'i1',
          'description': 'Table',
          'quantity': 2,
          'unit_price_cents': 100000,
          'line_total_cents': 200000,
          'position': 0,
        },
      ],
      'payments': [
        {
          'id': 'pay1',
          'order_id': 'o1',
          'kind': 'final',
          'amount_cents': 224000,
          'method': 'cash',
          'paid_at': '2026-10-10T09:00:00Z',
          'status': 'successful',
        },
      ],
      'refunds': <dynamic>[],
      'costs': <dynamic>[],
      'history': [
        {
          'id': 'h1',
          'from_status': 'confirmed',
          'to_status': 'delivered',
          'changed_at': '2026-10-10T08:00:00Z',
        },
      ],
    });

    expect(detail.order.orderNo, 'ORD-2026-0001');
    expect(detail.order.status, OrderStatus.delivered);
    expect(detail.items.single.description, 'Table');
    expect(detail.payments.single.amount, Money(224000));
    expect(detail.financials.isFullyPaid, isTrue);
    expect(detail.financials.profit, Money(125000));
    expect(detail.financials.marginPercent, closeTo(62.5, 0.01));
    expect(detail.history.single.toStatus, 'delivered');
  });

  test('maps the status transition matrix', () {
    expect(OrderStatus.draft.allowedNext, {OrderStatus.confirmed, OrderStatus.cancelled});
    expect(OrderStatus.closed.allowedNext, isEmpty);
    expect(OrderStatus.completed.allowsItemEditing, isFalse);
    expect(OrderStatus.onHold.allowsItemEditing, isTrue);
  });

  test('reads the product production cost and computes the margin', () {
    final product = Product.fromJson({
      'id': 'p1',
      'name': 'Custom Cake',
      'base_price_cents': 450000,
      'production_cost_cents': 210000,
      'unit': 'cake',
      'is_active': true,
    });

    expect(product.productionCost, Money(210000));
    expect(product.marginPercent, closeTo(53.33, 0.01));
  });
}
