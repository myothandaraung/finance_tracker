import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lifecycle of a quotation.
enum QuotationStatus {
  draft('draft', 'Draft'),
  sent('sent', 'Sent'),
  accepted('accepted', 'Accepted'),
  rejected('rejected', 'Rejected'),
  expired('expired', 'Expired'),
  converted('converted', 'Converted'),
  cancelled('cancelled', 'Cancelled');

  const QuotationStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static QuotationStatus fromDb(String? value) {
    return QuotationStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => QuotationStatus.draft,
    );
  }

  bool get isTerminal => switch (this) {
        QuotationStatus.rejected ||
        QuotationStatus.expired ||
        QuotationStatus.converted ||
        QuotationStatus.cancelled =>
          true,
        _ => false,
      };

  /// Only an accepted quotation can become an order.
  bool get canConvert => this == QuotationStatus.accepted;

  /// Line items stay editable while the quotation is a draft or sent.
  bool get allowsEditing =>
      this == QuotationStatus.draft || this == QuotationStatus.sent;

  Set<QuotationStatus> get allowedNext => switch (this) {
        QuotationStatus.draft => {
            QuotationStatus.sent,
            QuotationStatus.cancelled,
          },
        QuotationStatus.sent => {
            QuotationStatus.accepted,
            QuotationStatus.rejected,
            QuotationStatus.expired,
          },
        QuotationStatus.accepted => {QuotationStatus.converted},
        QuotationStatus.rejected => const {},
        QuotationStatus.expired => const {},
        QuotationStatus.converted => const {},
        QuotationStatus.cancelled => const {},
      };

  Color get color => switch (this) {
        QuotationStatus.draft => AppColors.textSecondary,
        QuotationStatus.sent => AppColors.info,
        QuotationStatus.accepted => AppColors.success,
        QuotationStatus.rejected => AppColors.danger,
        QuotationStatus.expired => AppColors.warning,
        QuotationStatus.converted => AppColors.primary,
        QuotationStatus.cancelled => AppColors.danger,
      };
}
