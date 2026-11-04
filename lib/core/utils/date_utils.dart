import 'package:intl/intl.dart';

/// Date helpers used by filters, reports and period pickers.
class AppDate {
  const AppDate._();

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateShort = DateFormat('dd MMM');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, h:mm a');
  static final DateFormat _month = DateFormat('MMMM yyyy');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  static String format(DateTime? value) =>
      value == null ? '—' : _date.format(value);

  static String formatShort(DateTime? value) =>
      value == null ? '—' : _dateShort.format(value);

  static String formatDateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value);

  static String formatMonth(DateTime value) => _month.format(value);

  /// `yyyy-MM-dd` used for database filters and CSV headers.
  static String isoDate(DateTime value) => _isoDate.format(value);

  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59);

  static DateTime startOfMonth(DateTime value) =>
      DateTime(value.year, value.month, 1);

  static DateTime endOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 1).subtract(const Duration(days: 1));

  /// Inclusive range for the current month.
  static ({DateTime from, DateTime to}) currentMonth() {
    final now = DateTime.now();
    return (from: startOfMonth(now), to: endOfMonth(now));
  }

  /// Inclusive range for the previous month.
  static ({DateTime from, DateTime to}) previousMonth() {
    final now = DateTime.now();
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final lastOfPrevious = firstOfThisMonth.subtract(const Duration(days: 1));
    return (
      from: DateTime(lastOfPrevious.year, lastOfPrevious.month, 1),
      to: lastOfPrevious,
    );
  }

  /// Inclusive range for the last [days] days, ending today.
  static ({DateTime from, DateTime to}) lastDays(int days) {
    final now = DateTime.now();
    return (
      from: startOfDay(now).subtract(Duration(days: days - 1)),
      to: endOfDay(now),
    );
  }

  /// Inclusive range covering [months] months up to (and including) this month.
  static ({DateTime from, DateTime to}) lastMonths(int months) {
    final now = DateTime.now();
    return (
      from: DateTime(now.year, now.month - (months - 1), 1),
      to: endOfMonth(now),
    );
  }

  /// "3 days ago", "in 2 hours" ... falls back to a formatted date.
  static String relative(DateTime? value) {
    if (value == null) return '—';
    final difference = DateTime.now().difference(value);
    final future = difference.isNegative;
    final duration = difference.abs();

    String unit;
    if (duration.inMinutes < 1) {
      unit = 'just now';
      if (!future) return unit;
    } else if (duration.inMinutes < 60) {
      unit = '${duration.inMinutes} min';
    } else if (duration.inHours < 24) {
      unit = '${duration.inHours} hr';
    } else if (duration.inDays < 30) {
      unit = '${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inDays < 365) {
      final months = duration.inDays ~/ 30;
      unit = '$months month${months == 1 ? '' : 's'}';
    } else {
      final years = duration.inDays ~/ 365;
      unit = '$years year${years == 1 ? '' : 's'}';
    }

    if (unit == 'just now') return unit;
    return future ? 'in $unit' : '$unit ago';
  }
}
