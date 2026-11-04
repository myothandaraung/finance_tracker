import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mto_finance/core/domain/order_status.dart';
import 'package:mto_finance/core/money/document_totals.dart';
import 'package:mto_finance/core/money/money.dart';
import 'package:mto_finance/shared/widgets/document_editor.dart';
import 'package:mto_finance/shared/widgets/status_chip.dart';

void main() {
  testWidgets('the status chip shows the label of the status', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusChip.order(OrderStatus.inProgress),
        ),
      ),
    );

    expect(find.text('In production'), findsOneWidget);
  });

  testWidgets('the totals panel renders every amount', (tester) async {
    final totals = DocumentTotals.calculate(
      lines: const [
        LineInput(description: 'Table', quantity: 1, unitPrice: Money(100000)),
      ],
      discountType: 'percent',
      discountValue: 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TotalsPanel(
            totals: totals,
            discountType: 'percent',
            discountValue: 10,
          ),
        ),
      ),
    );

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.textContaining('1,000.00'), findsWidgets);
  });
}
