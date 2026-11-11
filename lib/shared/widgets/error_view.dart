import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Error state with a retry action. Permission errors and empty states are
/// rendered differently so a denied query never looks like "no data".
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final appError = error is AppException
        ? error as AppException
        : AppException(error.toString());

    final isPermission = appError.isPermissionDenied;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission ? Icons.lock_outline : Icons.error_outline,
              size: compact ? 32 : 44,
              color: isPermission ? AppColors.warning : AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.translate(
                isPermission ? 'Permission denied' : 'Something went wrong',
              ),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              appError.displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.translate('Try again')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
