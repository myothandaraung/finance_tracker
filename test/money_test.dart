import 'package:flutter_test/flutter_test.dart';
import 'package:mto_finance/core/money/money.dart';

void main() {
  group('Money.tryParse', () {
    test('parses plain amounts', () {
      expect(Money.tryParse('1234.50')?.cents, 123450);
      expect(Money.tryParse('1234')?.cents, 123400);
      expect(Money.tryParse('0.05')?.cents, 5);
      expect(Money.tryParse('.5')?.cents, 50);
    });

    test('ignores the currency symbol and grouping', () {
      expect(Money.tryParse('₱1,234.50')?.cents, 123450);
      expect(Money.tryParse('PHP 1234')?.cents, 123400);
      expect(Money.tryParse('1 234.50')?.cents, 123450);
    });

    test('handles negative amounts', () {
      expect(Money.tryParse('-12.05')?.cents, -1205);
    });

    test('rejects invalid input', () {
      expect(Money.tryParse(''), isNull);
      expect(Money.tryParse('abc'), isNull);
      expect(Money.tryParse('1.234'), isNull);
      expect(Money.tryParse('1.2.3'), isNull);
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts without floating point drift', () {
      expect((Money(10) + Money(20)).cents, 30);
      expect((Money(10) - Money(30)).cents, -20);
      expect(Money.zero.cents, 0);
    });

    test('multiplies a quantity and rounds half away from zero', () {
      expect(Money(1000).multiply(2.5).cents, 2500);
      expect(Money(333).multiply(3).cents, 999);
      // 12.345 rounds to 12.35
      expect(Money(1235).multiply(1).cents, 1235);
      expect(Money(100).multiply(0.5).cents, 50);
      expect(Money(101).multiply(0.5).cents, 51);
    });

    test('computes percentages', () {
      expect(Money.percentOf(Money(10000), 12).cents, 1200);
      expect(Money.percentOf(Money(999), 12).cents, 120);
      expect(Money.percentOf(Money(0), 12).cents, 0);
    });
  });

  group('Money formatting', () {
    test('renders a plain decimal', () {
      expect(Money(123450).plain, '1234.50');
      expect(Money(-5).plain, '-0.05');
      expect(Money(0).plain, '0.00');
    });
  });
}
