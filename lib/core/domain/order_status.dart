import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lifecycle of an order. The transitions are enforced by
/// `rpc_update_order_status` in the database; [allowedNext] mirrors that
/// matrix so the UI only ever offers legal actions.
enum OrderStatus {
  draft('draft', 'Draft'),
  confirmed('confirmed', 'Confirmed'),
  inProgress('in_progress', 'In production'),
  onHold('on_hold', 'On hold'),
  completed('completed', 'Completed'),
  delivered('delivered', 'Delivered'),
  closed('closed', 'Closed'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static OrderStatus fromDb(String? value) {
    return OrderStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => OrderStatus.draft,
    );
  }

  bool get isTerminal =>
      this == OrderStatus.closed || this == OrderStatus.cancelled;

  /// Orders that are not cancelled still count towards receivables.
  bool get countsAsReceivable => this != OrderStatus.cancelled;

  /// Revenue is recognised on delivery (and inherited by `closed`).
  bool get isRevenueRecognised =>
      this == OrderStatus.delivered || this == OrderStatus.closed;

  /// Line items can only be edited before production starts.
  bool get allowsItemEditing =>
      this == OrderStatus.draft ||
      this == OrderStatus.confirmed ||
      this == OrderStatus.onHold;

  /// Statuses a user can move an order to from the current one.
  Set<OrderStatus> get allowedNext => switch (this) {
        OrderStatus.draft => {
            OrderStatus.confirmed,
            OrderStatus.cancelled,
          },
        OrderStatus.confirmed => {
            OrderStatus.inProgress,
            OrderStatus.onHold,
            OrderStatus.cancelled,
          },
        OrderStatus.inProgress => {
            OrderStatus.completed,
            OrderStatus.onHold,
            OrderStatus.cancelled,
          },
        OrderStatus.onHold => {
            OrderStatus.inProgress,
            OrderStatus.confirmed,
            OrderStatus.cancelled,
          },
        OrderStatus.completed => {
            OrderStatus.delivered,
            OrderStatus.inProgress,
          },
        OrderStatus.delivered => {
            OrderStatus.closed,
            OrderStatus.cancelled,
          },
        OrderStatus.closed => const {},
        OrderStatus.cancelled => const {},
      };

  Color get color => switch (this) {
        OrderStatus.draft => AppColors.textSecondary,
        OrderStatus.confirmed => AppColors.info,
        OrderStatus.inProgress => AppColors.accent,
        OrderStatus.onHold => AppColors.warning,
        OrderStatus.completed => AppColors.primary,
        OrderStatus.delivered => AppColors.success,
        OrderStatus.closed => AppColors.textPrimary,
        OrderStatus.cancelled => AppColors.danger,
      };
}
