import 'package:flutter_test/flutter_test.dart';
import 'package:mto_finance/core/money/document_totals.dart';
import 'package:mto_finance/core/money/money.dart';

void main() {
  const lines = [
    LineInput(
      description: 'Table',
      quantity: 2,
      unitPrice: Money(50000),
      estimatedUnitCost: Money(20000),
    ),
    LineInput(
      description: 'Chair',
      quantity: 4,
      unitPrice: Money(25000),
      estimatedUnitCost: Money(10000),
    ),
  ];

  test('calculates the subtotal of the lines', () {
    final totals = DocumentTotals.calculate(
      lines: lines,
      discountType: 'none',
      discountValue: 0,
    );

    expect(totals.subtotal.cents, 200000);
    expect(totals.netSales.cents, 200000);
    expect(totals.total.cents, 200000);
    expect(totals.estimatedCost.cents, 80000);
  });

  test('applies a percentage discount before the tax', () {
    final totals = DocumentTotals.calculate(
      lines: lines,
      discountType: 'percent',
      discountValue: 10,
    );

    // 200000 - 10% = 180000 net
    expect(totals.discountAmount.cents, 20000);
    expect(totals.netSales.cents, 180000);
    expect(totals.total.cents, 180000);
  });

  test('applies a fixed discount and never goes below zero', () {
    final totals = DocumentTotals.calculate(
      lines: lines,
      discountType: 'amount',
      discountValue: 500000,
    );

    expect(totals.discountAmount.cents, 200000);
    expect(totals.netSales.cents, 0);
    expect(totals.total.cents, 0);
  });

  test('keeps the server rounding for a line with a fraction', () {
    final totals = DocumentTotals.calculate(
      lines: const [
        LineInput(
          description: 'Custom',
          quantity: 3,
          unitPrice: Money(3333),
        ),
      ],
      discountType: 'none',
      discountValue: 0,
    );

    // 3 x 33.33 = 99.99
    expect(totals.subtotal.cents, 9999);
  });
}
