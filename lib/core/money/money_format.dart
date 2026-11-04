import 'package:intl/intl.dart';

import 'money.dart';

/// Formats [Money] for display. The app is PHP-first (`₱`) but the currency
/// symbol is applied by the caller when a business uses another currency.
class MoneyFormatter {
  const MoneyFormatter._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Ks',
    decimalDigits: 2,
  );

  static final NumberFormat _compact = NumberFormat.compactCurrency(
    locale: 'en_US',
    symbol: 'Ks',
    decimalDigits: 1,
  );

  /// `Ks1,234.50`
  static String format(Money? value, {String symbol = 'Ks'}) {
    if (value == null) return '${symbol}0.00';
    if (symbol == 'Ks') return _currency.format(value.asDouble);
    return '$symbol${NumberFormat('#,##0.00').format(value.asDouble)}';
  }

  /// `Ks1.2K` — used on dashboard cards where space is tight.
  static String formatCompact(Money? value, {String symbol = 'Ks'}) {
    if (value == null) return symbol;
    if (symbol == 'Ks') return _compact.format(value.asDouble);
    return '$symbol${NumberFormat.compact().format(value.asDouble)}';
  }

  /// Plain decimal text without grouping separators, e.g. `1234.50`.
  static String plain(Money? value) => (value ?? Money.zero).plain;

  /// Parses user input into a [Money]; returns `null` for invalid text.
  static Money? parse(String raw) => Money.tryParse(raw);
}
