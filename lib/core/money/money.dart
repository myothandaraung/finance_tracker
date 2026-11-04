/// Immutable monetary value expressed in **integer minor units** (centavos).
///
/// The database stores money as `numeric(15,2)`. Every value that crosses the
/// API boundary is converted to cents so that no floating point arithmetic
/// ever touches a financial figure.
///
/// Rounding is always *half away from zero* and matches the Postgres
/// implementation (`round()`), so the client preview and the stored value
/// agree.
class Money implements Comparable<Money> {
  const Money(this.cents);

  /// 123450 == ₱1,234.50
  final int cents;

  static const Money zero = Money(0);

  factory Money.fromCents(int cents) => Money(cents);

  /// Builds a value from a `numeric`/JSON number (used only when reading
  /// legacy columns that have no `_cents` companion).
  factory Money.fromDouble(num value) =>
      Money((value * 100).round().toInt());

  /// Parses `1,234.50`, `₱1234.5`, `PHP 1234` or `-12` into centavos.
  ///
  /// Returns `null` when the text is not a valid amount. More than two
  /// decimals is rejected rather than silently rounded.
  static Money? tryParse(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    text = text.replaceAll(',', '').replaceAll(' ', '');
    text = text.replaceAll('₱', '').replaceAll('PHP', '').replaceAll('php', '');
    text = text.replaceAll('Ks', '').replaceAll('ks', '').replaceAll('MMK', '').replaceAll('mmk', '');
    text = text.replaceAll('Ks', '').replaceAll('ks', '').replaceAll('MMK', '').replaceAll('mmk', '');
    text = text.trim();
    if (text.isEmpty) return null;

    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }
    if (text.isEmpty) return null;

    final parts = text.split('.');
    if (parts.length > 2) return null;

    final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    if (whole == null) return null;

    var fraction = 0;
    if (parts.length == 2) {
      final rawFraction = parts[1];
      if (rawFraction.length > 2) return null;
      if (rawFraction.isNotEmpty && int.tryParse(rawFraction) == null) {
        return null;
      }
      fraction = int.parse(rawFraction.padRight(2, '0'));
    }

    final value = whole * 100 + fraction;
    return Money(negative ? -value : value);
  }

  /// Like [tryParse] but throws a [FormatException] on invalid input.
  factory Money.parse(String raw) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      throw FormatException('Not a valid amount', raw);
    }
    return parsed;
  }

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;
  bool get isPositive => cents > 0;

  /// Only for display/charting. Never use for balance arithmetic.
  double get asDouble => cents / 100;

  /// Plain decimal text, e.g. `1234.50` or `-12.05`.
  String get plain {
    final sign = cents < 0 ? '-' : '';
    final absolute = cents.abs();
    final fraction = (absolute % 100).toString().padLeft(2, '0');
    return '$sign${absolute ~/ 100}.$fraction';
  }

  Money operator +(Money other) => Money(cents + other.cents);

  Money operator -(Money other) => Money(cents - other.cents);

  Money operator -() => Money(-cents);

  bool operator <(Money other) => cents < other.cents;

  bool operator <=(Money other) => cents <= other.cents;

  bool operator >(Money other) => cents > other.cents;

  bool operator >=(Money other) => cents >= other.cents;

  /// Multiplies by a quantity (for example a line-item quantity), rounding
  /// half away from zero to the nearest cent.
  Money multiply(num factor) {
    final scaled = (factor.abs() * 1000).round();
    final product = cents * scaled;
    final rounded = (product.abs() + 500) ~/ 1000;
    return Money(product < 0 ? -rounded : rounded);
  }

  /// `base * percent / 100`, rounded half away from zero.
  static Money percentOf(Money base, num percent) {
    final milliPercent = (percent.abs() * 1000).round();
    final product = base.cents * milliPercent;
    final rounded = (product.abs() + 50000) ~/ 100000;
    return Money(product < 0 ? -rounded : rounded);
  }

  /// Tax on a taxable base, using the same rule as [percentOf].
  static Money taxOn(Money taxable, num rate) => percentOf(taxable, rate);

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Money($plain)';
}
