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
        home: Scaffold(body: StatusChip.order(OrderStatus.inProgress)),
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

  testWidgets('a catalog product replaces the initial empty line', (
    tester,
  ) async {
    var lines = const [
      LineInput(description: '', quantity: 1, unitPrice: Money.zero),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: LineEditor(
              lines: lines,
              products: const [
                (
                  id: 'cake',
                  name: 'Birthday cake',
                  price: Money(2000000),
                  productionCost: Money(1700000),
                ),
              ],
              onChanged: (value) => setState(() => lines = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('From catalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birthday cake'));
    await tester.pumpAndSettle();

    expect(lines, hasLength(1));
    expect(lines.single.productId, 'cake');
    expect(find.text('Birthday cake'), findsOneWidget);
    expect(find.textContaining('20,000.00'), findsOneWidget);
  });

  testWidgets('line fields stay in sync when the model is replaced', (
    tester,
  ) async {
    late StateSetter update;
    var line = const LineInput(
      description: '',
      quantity: 1,
      unitPrice: Money.zero,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: LineEditor(lines: [line], onChanged: (_) {}),
            );
          },
        ),
      ),
    );

    update(() {
      line = const LineInput(
        productId: 'cake',
        description: 'Birthday cake',
        quantity: 2,
        unitPrice: Money(2000000),
        estimatedUnitCost: Money(1700000),
      );
    });
    await tester.pump();

    expect(find.text('Birthday cake'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('20000.00'), findsOneWidget);
    expect(find.text('17000.00'), findsOneWidget);
    expect(find.textContaining('40,000.00'), findsOneWidget);
  });
}
