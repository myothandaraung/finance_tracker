import 'package:flutter/material.dart';

import '../../core/domain/order_status.dart';
import '../../core/domain/quotation_status.dart';
import '../../core/theme/app_colors.dart';

/// Small coloured pill used for order and quotation statuses.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.color, {super.key, this.dense = false});

  /// Chip for an order status.
  factory StatusChip.order(OrderStatus status, {bool dense = false}) =>
      StatusChip(status.label, status.color, dense: dense);

  /// Chip for a quotation status.
  factory StatusChip.quotation(QuotationStatus status, {bool dense = false}) =>
      StatusChip(status.label, status.color, dense: dense);

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Renders a coloured amount: green when positive, red when negative.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.textStyle,
    this.showSign = false,
    this.colorize = false,
  });

  final String amount;
  final TextStyle? textStyle;
  final bool showSign;
  final bool colorize;

  @override
  Widget build(BuildContext context) {
    final isNegative = amount.trim().startsWith('-');
    final isPositive = amount.trim().startsWith('+');

    Color? color;
    if (colorize && isNegative) {
      color = AppColors.negative;
    } else if (colorize && isPositive) {
      color = AppColors.positive;
    }

    final text = showSign && isPositive ? '+$amount' : amount;

    return Text(
      text,
      style: textStyle ??
          TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
