import 'package:flutter_test/flutter_test.dart';
import 'package:mto_finance/core/export/csv_exporter.dart';

void main() {
  test('encodes a simple table', () {
    final csv = CsvExporter.encode([
      ['Order', 'Total'],
      ['ORD-2026-0001', '2240.00'],
    ]);

    expect(csv, 'Order,Total\r\nORD-2026-0001,2240.00');
  });

  test('quotes fields that contain a comma or a quote', () {
    final csv = CsvExporter.encode([
      ['Customer', 'Note'],
      ['Acme, Inc.', 'Says "hello"'],
    ]);

    expect(csv, 'Customer,Note\r\n"Acme, Inc.","Says ""hello"""');
  });

  test('renders null as an empty field', () {
    final csv = CsvExporter.encode([
      ['A', 'B'],
      [null, 1],
    ]);

    expect(csv, 'A,B\r\n,1');
  });
}
